extends Node3D

@onready var world_environment: WorldEnvironment = $WorldEnvironment
var xr_interface: XRInterface

@onready var left_skeleton = $XROrigin3D/LeftHandTracker/OpenXRFbHandTrackingMesh
@onready var right_skeleton = $XROrigin3D/RightHandTracker/OpenXRFbHandTrackingMesh

var left_joints_loaded := false
var right_joints_loaded := false

func _ready():
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		print("OpenXR initialized successfully")

		# Turn off v-sync!
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

		# Change our main viewport to output to the HMD
		get_viewport().use_xr = true
	else:
		print("OpenXR not initialized, please check if your headset is connected")
		
	if xr_interface.get_supported_environment_blend_modes().has(XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND):
		get_viewport().transparent_bg = true
		world_environment.environment.background_mode = Environment.BG_COLOR
		world_environment.environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
		xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
	else:
		get_viewport().transparent_bg = false
		world_environment.environment.background_mode = Environment.BG_SKY
		xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_OPAQUE
		
func _process(_delta):
	if not left_joints_loaded:
		var tracker = XRServer.get_tracker("/user/hand_tracker/left")
		if tracker and tracker.has_tracking_data:
			setup_index_joints(0, tracker, left_skeleton)
			left_joints_loaded = true
	
	if not right_joints_loaded:
		var tracker = XRServer.get_tracker("/user/hand_tracker/right")
		if tracker and tracker.has_tracking_data:
			setup_index_joints(1, tracker, right_skeleton)
			right_joints_loaded = true
				
func setup_index_joints(hand_idx: int, hand_tracker: XRHandTracker, skeleton: OpenXRFbHandTrackingMesh) -> void:
	for joint_id in range(6, 10):  # Index finger joints
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = 0.01
		sphere_mesh.height = 0.02
		
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = sphere_mesh
		
		var bone_attachment := BoneAttachment3D.new()
		bone_attachment.bone_idx = joint_id
		bone_attachment.add_child(mesh_instance)
		skeleton.add_child(bone_attachment)
		
		# Add ray from tip
		if joint_id == 9:  # Index tip
			var ray_mesh := BoxMesh.new()
			ray_mesh.size = Vector3(0.002, 2.0, 0.002)  # Thin 2m ray
			
			var ray_instance := MeshInstance3D.new()
			ray_instance.mesh = ray_mesh
			ray_instance.position.y = 1.0  # Center the 2m ray
			
			# Make it glow
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color.CYAN
			mat.emission_enabled = true
			mat.emission = Color.CYAN
			#mat.emission_intensity = 2.0
			ray_instance.material_override = mat
			
			mesh_instance.add_child(ray_instance)
