extends Node3D

@export var flash_duration: float = 0.1
@export var smoke_duration: float = 0.5

func _ready():
	create_flash()
	create_smoke_puff()
	
	# Auto-remove
	await get_tree().create_timer(max(flash_duration, smoke_duration)).timeout
	queue_free()

func create_flash():
	# Main flash - bright center
	var center_flash = create_flash_plane(0.1, Color(1.0, 1.0, 0.9), 5.0, 0)
	add_child(center_flash)
	animate_flash_plane(center_flash, flash_duration * 0.8)
	
	# Secondary flashes - colored rings
	for i in range(3):
		var angle = i * 60
		var size = 0.08 - i * 0.02
		var color = Color(1.0, 0.8 - i * 0.1, 0.3, 0.8)
		var energy = 3.0 - i * 0.5
		
		var flash = create_flash_plane(size, color, energy, angle)
		flash.position.z = -i * 0.01  # Slight depth offset
		add_child(flash)
		animate_flash_plane(flash, flash_duration)

func create_flash_plane(size: float, color: Color, energy: float, rotation_deg: float) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	
	# Use a quad mesh for the flash
	var quad = QuadMesh.new()
	quad.size = Vector2(size, size)
	mesh_instance.mesh = quad
	
	# Create bright material
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy = energy
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD  # Additive blending for glow
	
	mesh_instance.material_override = mat
	mesh_instance.rotation.z = deg_to_rad(rotation_deg)
	
	return mesh_instance

func animate_flash_plane(flash: MeshInstance3D, duration: float):
	var tween = create_tween()
	
	# Quick scale pop
	flash.scale = Vector3.ONE * 0.5
	tween.tween_property(flash, "scale", Vector3.ONE * 1.2, duration * 0.3)
	tween.tween_property(flash, "scale", Vector3.ZERO, duration * 0.7)
	
	# Fade out
	tween.parallel().tween_property(
		flash.material_override, "emission_energy_multiplier", 
		0.0, duration
	).set_ease(Tween.EASE_OUT)

func create_smoke_puff():
	# Create a simple expanding smoke sphere
	var smoke = MeshInstance3D.new()
	
	var sphere = SphereMesh.new()
	sphere.radius = 0.02
	sphere.height = 0.04
	smoke.mesh = sphere
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.8, 0.8, 0.8, 0.3)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke.material_override = mat
	
	add_child(smoke)
	
	# Animate smoke
	var tween = create_tween()
	tween.tween_property(smoke, "scale", Vector3.ONE * 3, smoke_duration)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, smoke_duration)
	
	# Move smoke slightly forward
	tween.parallel().tween_property(smoke, "position:z", -0.1, smoke_duration)
