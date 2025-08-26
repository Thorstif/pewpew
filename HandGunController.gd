# HandGunController.gd
# Attach this to both LeftHandTracker and RightHandTracker nodes
extends XRNode3D

@export var aim_ray_length: float = 50.0
@export var aim_time_required: float = 1.0
@export var shot_cooldown: float = 0.2
@export var debug_draw: bool = true
@export var is_left_hand: bool = true  # Set this in inspector for each hand

# Shot effect settings
@export var muzzle_flash_scene: PackedScene
@export var bullet_trail_scene: PackedScene
@export var impact_effect_scene: PackedScene

# Hand tracking references
@onready var skeleton = $OpenXRFbHandTrackingMesh
@onready var pose_detector = $HandPoseController

# Finger gun state
var raycast: RayCast3D
var current_target: Node3D = null
var aim_timer: float = 0.0
var last_shot_time: float = 0.0
var is_pointing: bool = false
var joints_loaded: bool = false

# Visual feedback
var aim_indicator: MeshInstance3D
var ray_visual: MeshInstance3D
var index_tip_attachment: BoneAttachment3D

func _ready():
	# Determine which hand this is from the node path
	is_left_hand = "Left" in name or "left" in name
	
	# Connect pose detection signals
	if pose_detector:
		pose_detector.pose_started.connect(_on_pose_detected)
		pose_detector.pose_ended.connect(_on_pose_released)
	
	setup_aim_indicator()
	
	# Wait for hand tracking data to be available
	set_process(true)

func _process(delta):
	# Setup joints once tracking data is available
	if not joints_loaded:
		var tracker_path = "/user/hand_tracker/left" if is_left_hand else "/user/hand_tracker/right"
		var tracker = XRServer.get_tracker(tracker_path)
		if tracker and tracker.has_tracking_data:
			setup_index_joints()
			joints_loaded = true
	
	# Handle aiming and shooting
	if is_pointing and raycast:
		process_aiming(delta)

func setup_index_joints():
	print("Setting up finger joints for %s hand" % ("left" if is_left_hand else "right"))
	
	# Index finger tip is joint 9 (based on OpenXR hand joint indices)
	var index_tip_joint = 9
	
	# Create visual indicators for joints (optional, for debugging)
	for joint_id in range(6, 10):  # Index finger joints (6-9)
		if debug_draw:
			var sphere_mesh := SphereMesh.new()
			sphere_mesh.radius = 0.01
			sphere_mesh.height = 0.02
			
			var mesh_instance := MeshInstance3D.new()
			mesh_instance.mesh = sphere_mesh
			
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color.GREEN if joint_id == index_tip_joint else Color.YELLOW
			mesh_instance.material_override = mat
			
			var bone_attachment := BoneAttachment3D.new()
			bone_attachment.bone_idx = joint_id
			bone_attachment.add_child(mesh_instance)
			skeleton.add_child(bone_attachment)
		
		# Add raycast and visual ray at index tip
		if joint_id == index_tip_joint:
			setup_finger_ray(joint_id)

func setup_finger_ray(joint_id: int):
	# Create bone attachment for index finger tip
	index_tip_attachment = BoneAttachment3D.new()
	index_tip_attachment.bone_idx = joint_id
	skeleton.add_child(index_tip_attachment)
	
	# Create a root node for ray components
	var ray_root := Node3D.new()
	index_tip_attachment.add_child(ray_root)
	
	# Setup RayCast3D
	raycast = RayCast3D.new()
	raycast.enabled = true
	raycast.target_position = Vector3(0, aim_ray_length, 0)  # Will be rotated
	raycast.collision_mask = 1  # Adjust based on your ghost layer
	ray_root.add_child(raycast)
	
	# Create visual ray (optional, for debugging or visual feedback)
	if debug_draw:
		var ray_mesh := CylinderMesh.new()
		ray_mesh.height = 2.0  # Visual representation length
		ray_mesh.top_radius = 0.002
		ray_mesh.bottom_radius = 0.004
		
		ray_visual = MeshInstance3D.new()
		ray_visual.mesh = ray_mesh
		ray_visual.position.y = 1.0  # Position along ray
		
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0, 1, 1, 0.3)  # Semi-transparent cyan
		mat.emission_enabled = true
		mat.emission = Color.CYAN * 0.5
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ray_visual.material_override = mat
		ray_visual.visible = false
		
		ray_root.add_child(ray_visual)
	
	# Rotate the ray to point forward from finger
	# Adjust these angles based on your hand model orientation
	if is_left_hand:
		ray_root.rotation = Vector3(deg_to_rad(0), deg_to_rad(0), deg_to_rad(0))
	else:
		ray_root.rotation = Vector3(deg_to_rad(30), deg_to_rad(0), deg_to_rad(0))

func setup_aim_indicator():
	# Create a small sphere to show where we're aiming
	aim_indicator = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.05
	sphere_mesh.height = 0.1
	aim_indicator.mesh = sphere_mesh
	
	# Create material that changes color based on aim progress
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.YELLOW
	material.emission_enabled = true
	material.emission = Color.YELLOW * 0.5
	aim_indicator.material_override = material
	
	get_tree().current_scene.add_child(aim_indicator)
	aim_indicator.visible = false

func _on_pose_detected(pose_name: String):
	if pose_name == "Point Thumb Up":
		is_pointing = true
		if ray_visual:
			ray_visual.visible = true
		print("%s hand: Finger gun gesture detected!" % ("Left" if is_left_hand else "Right"))

func _on_pose_released(pose_name: String):
	if pose_name == "Point Thumb Up":
		is_pointing = false
		if ray_visual:
			ray_visual.visible = false
		reset_aim()
		print("%s hand: Finger gun gesture released" % ("Left" if is_left_hand else "Right"))

func process_aiming(delta: float):
	if not raycast or not raycast.is_enabled():
		return
	
	# Force raycast update
	raycast.force_raycast_update()
	
	# Check what we're aiming at
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		
		if collider.is_in_group("ghosts"):
			if collider == current_target:
				# Continue aiming at same target
				aim_timer += delta
				update_aim_feedback()
				
				# Fire when aim time reached
				if aim_timer >= aim_time_required:
					fire_shot()
			else:
				# Started aiming at new target
				reset_aim()
				current_target = collider
				aim_timer = 0.0
		else:
			reset_aim()
		
		# Position aim indicator at collision point
		if aim_indicator:
			aim_indicator.global_position = raycast.get_collision_point()
			aim_indicator.visible = true
	else:
		reset_aim()

func update_aim_feedback():
	if not aim_indicator or not aim_indicator.material_override:
		return
	
	# Change color from yellow to red as we approach fire time
	var progress = aim_timer / aim_time_required
	var color = Color.YELLOW.lerp(Color.RED, progress)
	aim_indicator.material_override.albedo_color = color
	aim_indicator.material_override.emission = color * (0.5 + progress * 0.5)
	
	# Scale up slightly as we aim
	aim_indicator.scale = Vector3.ONE * (1.0 + progress * 0.5)
	
	# Make ray visual pulse
	if ray_visual and ray_visual.material_override:
		var ray_color = Color.CYAN.lerp(Color.RED, progress)
		ray_visual.material_override.emission = ray_color * (0.5 + progress)

func reset_aim():
	current_target = null
	aim_timer = 0.0
	if aim_indicator:
		aim_indicator.visible = false
		aim_indicator.scale = Vector3.ONE
	
	# Reset ray visual color
	if ray_visual and ray_visual.material_override:
		ray_visual.material_override.emission = Color.CYAN * 0.5

func fire_shot():
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_shot_time < shot_cooldown:
		return
	
	last_shot_time = current_time
	
	print("%s hand: BANG! Firing at %s" % ("Left" if is_left_hand else "Right"), current_target.name)
	
	# Apply damage to target
	if current_target and current_target.has_method("take_damage"):
		current_target.take_damage(1)
	
	# Visual effects
	spawn_muzzle_flash()
	spawn_bullet_trail()
	spawn_impact_effect()
	
	# Audio
	#play_shot_sound()
	
	# Flash the ray visual
	if ray_visual and ray_visual.material_override:
		ray_visual.material_override.emission = Color.WHITE * 3.0
		var tween = create_tween()
		tween.tween_property(ray_visual.material_override, "emission", Color.CYAN * 0.5, 0.2)
	
	# Reset aim for next shot
	reset_aim()

func spawn_muzzle_flash():
	if not muzzle_flash_scene or not index_tip_attachment:
		return
		
	var flash = muzzle_flash_scene.instantiate()
	index_tip_attachment.add_child(flash)
	
	# Auto-remove after a short time
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(flash):
		flash.queue_free()

func spawn_bullet_trail():
	if not bullet_trail_scene or not raycast or not raycast.is_colliding():
		# Create a simple trail even without a scene
		create_simple_trail()
		return
	
	var trail = bullet_trail_scene.instantiate()
	get_tree().current_scene.add_child(trail)
	
	# Position trail from hand to target
	var start_pos = index_tip_attachment.global_position if index_tip_attachment else global_position
	var end_pos = raycast.get_collision_point()
	
	if trail.has_method("setup_trail"):
		trail.setup_trail(start_pos, end_pos)

func create_simple_trail():
	if not raycast or not raycast.is_colliding():
		return
		
	# Create a simple line trail
	var trail = Node3D.new()
	get_tree().current_scene.add_child(trail)
	
	var mesh_instance = MeshInstance3D.new()
	trail.add_child(mesh_instance)
	
	var start_pos = index_tip_attachment.global_position if index_tip_attachment else global_position
	var end_pos = raycast.get_collision_point()
	
	var cylinder = CylinderMesh.new()
	cylinder.height = start_pos.distance_to(end_pos)
	cylinder.top_radius = 0.005
	cylinder.bottom_radius = 0.005
	mesh_instance.mesh = cylinder
	
	# Position and orient the trail
	mesh_instance.global_position = (start_pos + end_pos) / 2.0
	mesh_instance.look_at(end_pos, Vector3.UP)
	mesh_instance.rotate_x(PI/2)
	
	# Material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.YELLOW
	material.emission_enabled = true
	material.emission = Color.YELLOW * 2.0
	mesh_instance.material_override = material
	
	# Fade and remove
	var tween = create_tween()
	tween.tween_property(material, "emission", Color.TRANSPARENT, 0.3)
	tween.tween_callback(trail.queue_free)

func spawn_impact_effect():
	if not impact_effect_scene or not raycast or not raycast.is_colliding():
		return
		
	var impact = impact_effect_scene.instantiate()
	get_tree().current_scene.add_child(impact)
	impact.global_position = raycast.get_collision_point()
	
	# Auto-remove after effect plays
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(impact):
		impact.queue_free()

func play_shot_sound():
	# Create temporary audio player
	var audio_player = AudioStreamPlayer3D.new()
	index_tip_attachment.add_child(audio_player) if index_tip_attachment else add_child(audio_player)
	
	# You'll need to load a sound effect here
	# audio_player.stream = preload("res://sounds/laser_shot.ogg")
	# audio_player.play()
	
	# Clean up after playing
	audio_player.finished.connect(audio_player.queue_free)
