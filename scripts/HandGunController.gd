# HandGunController.gd
extends XRNode3D

@export var aim_ray_length: float = 50.0
@export var aim_time_required: float = 0.5
@export var shot_cooldown: float = 0.5

# Debug visualization
@export var debug_draw: bool = true

# Shot effect settings
@export_group("Effects")
@export var muzzle_flash_scene: PackedScene
@export var bullet_trail_scene: PackedScene
@export var impact_effect_scene: PackedScene

# Hand tracking references
@onready var skeleton = $OpenXRFbHandTrackingMesh
@onready var pose_detector = $HandPoseController

# Core functionality
var raycast: RayCast3D
var current_target: Node3D = null
var aim_timer: float = 0.0
var last_shot_time: float = 0.0
var is_pointing: bool = false
var joints_loaded: bool = false
var is_left_hand: bool = true

# Visual feedback
var ray_visual: MeshInstance3D
var index_base_attachment: BoneAttachment3D  # Joint 7 - aiming origin
var index_tip_attachment: BoneAttachment3D   # Joint 9 - effects origin
var thumb_indicator: MeshInstance3D  # Thumb visual indicator

# Constants
const INDEX_BASE_JOINT = 7  # Base of index finger for aiming
const INDEX_TIP_JOINT = 9   # Tip of index finger for effects
const THUMB_TIP_JOINT = 4   # Tip of thumb
const TIP_FORWARD_OFFSET = 0.02  # 2cm forward from base joint

func _ready():
	is_left_hand = "Left" in name or "left" in name
	
	if pose_detector:
		pose_detector.pose_started.connect(_on_pose_detected)
		pose_detector.pose_ended.connect(_on_pose_released)
	
	set_process(true)

func _process(delta):
	if not joints_loaded:
		var tracker_path = "/user/hand_tracker/left" if is_left_hand else "/user/hand_tracker/right"
		var tracker = XRServer.get_tracker(tracker_path)
		if tracker and tracker.has_tracking_data:
			setup_index_joints()
			setup_thumb_indicator()
			joints_loaded = true
			
			if skeleton:
				skeleton.get_mesh_instance().visible = debug_draw
	
	if is_pointing and raycast:
		process_aiming(delta)

func setup_thumb_indicator():
	# Create thumb attachment
	var thumb_attachment = BoneAttachment3D.new()
	thumb_attachment.bone_idx = THUMB_TIP_JOINT
	skeleton.add_child(thumb_attachment)
	
	# Create translucent sphere
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.015
	sphere_mesh.height = sphere_mesh.radius * 2
	
	thumb_indicator = MeshInstance3D.new()
	thumb_indicator.mesh = sphere_mesh
	thumb_indicator.visible = false  # Hidden by default
	
	# Translucent material
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.8, 1.0, 0.5)  # Light blue, 50% opacity
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color.CYAN * 0.3
	thumb_indicator.material_override = mat
	
	thumb_attachment.add_child(thumb_indicator)

func setup_index_joints():
	print("Setting up finger joints for %s hand" % ("left" if is_left_hand else "right"))
	
	# Debug spheres
	if debug_draw:
		for joint_id in range(6, 10):
			create_debug_sphere(joint_id, joint_id in [INDEX_BASE_JOINT, INDEX_TIP_JOINT])
	
	# Setup ray at base joint
	setup_finger_ray(INDEX_BASE_JOINT)
	
	# Setup attachment for tip effects
	index_tip_attachment = BoneAttachment3D.new()
	index_tip_attachment.bone_idx = INDEX_TIP_JOINT
	skeleton.add_child(index_tip_attachment)

func create_debug_sphere(joint_id: int, is_primary: bool):
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.012 if is_primary else 0.008
	sphere_mesh.height = sphere_mesh.radius * 2
	
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = sphere_mesh
	
	var mat := StandardMaterial3D.new()
	if joint_id == INDEX_BASE_JOINT:
		mat.albedo_color = Color.GREEN
	elif joint_id == INDEX_TIP_JOINT:
		mat.albedo_color = Color.RED
	else:
		mat.albedo_color = Color.YELLOW
	mesh_instance.material_override = mat
	
	var bone_attachment := BoneAttachment3D.new()
	bone_attachment.bone_idx = joint_id
	bone_attachment.add_child(mesh_instance)
	skeleton.add_child(bone_attachment)

func setup_finger_ray(joint_id: int):
	index_base_attachment = BoneAttachment3D.new()
	index_base_attachment.bone_idx = joint_id
	skeleton.add_child(index_base_attachment)
	
	var ray_root := Node3D.new()
	# Offset forward along the ray direction (Y axis after rotation)
	index_base_attachment.add_child(ray_root)
	
	# Setup RayCast3D
	raycast = RayCast3D.new()
	raycast.enabled = true
	# Ray points along Y, we'll offset along Y after rotation
	raycast.target_position = Vector3(0, aim_ray_length, 0)
	raycast.position.y = TIP_FORWARD_OFFSET  # Offset along ray direction
	raycast.collision_mask = 2 # only ghosts
	ray_root.add_child(raycast)
	
	# Optional debug beam
	if debug_draw:
		var ray_mesh := BoxMesh.new()
		ray_mesh.size = Vector3(0.005, 3.0, 0.005)  # thin 2m ray
		
		ray_visual = MeshInstance3D.new()
		ray_visual.mesh = ray_mesh
		ray_visual.position.y = 1.5 + TIP_FORWARD_OFFSET  # Match raycast offset
		
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0, 1, 1, 0.3)
		mat.emission_enabled = true
		mat.emission = Color.CYAN * 0.5
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ray_visual.material_override = mat
		ray_visual.visible = false
		
		ray_root.add_child(ray_visual)

func _on_pose_detected(pose_name: String):
	if pose_name == "Point Thumb Up":
		print("finger gun pose detected")
		is_pointing = true
		if thumb_indicator:
			thumb_indicator.visible = true
		if ray_visual:
			print("debug beam should be visible")
			ray_visual.visible = true

func _on_pose_released(pose_name: String):
	if pose_name == "Point Thumb Up":
		is_pointing = false
		if thumb_indicator:
			thumb_indicator.visible = false
		if ray_visual:
			ray_visual.visible = false
			pass
		reset_aim()

func process_aiming(delta: float):
	if not raycast or not raycast.is_enabled():
		return
	
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		
		if collider.is_in_group("ghosts"):
			if collider == current_target:
				aim_timer += delta
				
				if aim_timer >= aim_time_required:
					fire_shot()
			else:
				reset_aim()
				current_target = collider
				aim_timer = 0.0
		else:
			reset_aim()
	else:
		reset_aim()

func reset_aim():
	current_target = null
	aim_timer = 0.0

func fire_shot():
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_shot_time < shot_cooldown:
		return
	
	last_shot_time = current_time
	
	print("%s hand: Firing at %s" % [("Left" if is_left_hand else "Right"), current_target.name])
	
	if current_target and current_target.has_method("take_damage"):
		current_target.take_damage(1)
	
	spawn_muzzle_flash()
	spawn_bullet_trail()
	spawn_impact_effect()
	
	reset_aim()

func spawn_muzzle_flash():
	if not muzzle_flash_scene:
		return
	
	# Ensure tip attachment exists and is valid
	if not index_tip_attachment or not is_instance_valid(index_tip_attachment):
		return
		
	var flash = muzzle_flash_scene.instantiate()
	index_tip_attachment.add_child(flash)
	
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(flash):
		flash.queue_free()

func spawn_bullet_trail():
	if not raycast or not raycast.is_colliding():
		return
	
	# Trail starts from fingertip
	var start_pos = index_tip_attachment.global_position if index_tip_attachment else global_position
	var end_pos = raycast.get_collision_point()
	
	if bullet_trail_scene:
		var trail = bullet_trail_scene.instantiate()
		get_tree().current_scene.add_child(trail)
		
		if trail.has_method("setup_trail"):
			trail.setup_trail(start_pos, end_pos)
	else:
		# Simple trail fallback
		var trail = Node3D.new()
		get_tree().current_scene.add_child(trail)
		trail.global_position = start_pos
		trail.look_at(end_pos, Vector3.UP)
		
		var mesh_instance = MeshInstance3D.new()
		trail.add_child(mesh_instance)
		
		var cylinder = CylinderMesh.new()
		var distance = start_pos.distance_to(end_pos)
		var extension = 0.4
		cylinder.height = distance + extension
		cylinder.top_radius = 0.005
		cylinder.bottom_radius = 0.005
		mesh_instance.mesh = cylinder
		
		mesh_instance.position.z = (-cylinder.height / 2.0) - TIP_FORWARD_OFFSET
		mesh_instance.rotation.x = PI/2
		
		var material = StandardMaterial3D.new()
		material.albedo_color = Color.YELLOW
		material.emission_enabled = true
		material.emission = Color.YELLOW * 2.0
		material.emission_energy_multiplier = 2.0
		mesh_instance.material_override = material
		
		var tween = create_tween()
		tween.tween_property(material, "emission_energy_multiplier", 0.0, 0.3)
		tween.tween_callback(trail.queue_free)

func spawn_impact_effect():
	if not impact_effect_scene or not raycast or not raycast.is_colliding():
		return
	
	var impact = impact_effect_scene.instantiate()
	get_tree().current_scene.add_child(impact)
	impact.global_position = raycast.get_collision_point()
	
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(impact):
		impact.queue_free()
