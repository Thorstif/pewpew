extends Node3D

@export var lifetime: float = 0.15
@export var flash_colors: Array[Color] = [
	Color(1.0, 0.9, 0.7, 1.0),  # Warm white
	Color(1.0, 0.8, 0.4, 1.0),  # Yellow-orange
	Color(1.0, 0.6, 0.2, 1.0)   # Orange
]

var time_elapsed: float = 0.0
var initial_scales: Array[Vector3] = []
var mesh_instances: Array[MeshInstance3D] = []

func _ready():
	setup_flash_components()
	animate_flash()

func setup_flash_components():
	# Create multiple overlapping star-shaped meshes for complexity
	for i in range(3):
		var mesh_instance = create_star_mesh(i)
		add_child(mesh_instance)
		mesh_instances.append(mesh_instance)
		initial_scales.append(mesh_instance.scale)

func create_star_mesh(index: int) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	
	# Create a quad mesh (we'll use multiple rotated quads)
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.15, 0.15) * (1.0 - index * 0.2)  # Varying sizes
	mesh_instance.mesh = quad_mesh
	
	# Create emissive material
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = flash_colors[index]
	material.emission_enabled = true
	material.emission = flash_colors[index]
	material.emission_energy_multiplier = 3.0 - index * 0.5
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED  # Always face camera
	material.no_depth_test = true  # Render on top
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	mesh_instance.material_override = material
	
	# Rotate each layer for star effect
	mesh_instance.rotation.z = deg_to_rad(index * 45)
	
	# Randomize initial rotation for variety
	mesh_instance.rotation.y = randf() * TAU
	
	return mesh_instance

func animate_flash():
	# Create animation with tween
	var tween = create_tween()
	tween.set_parallel(true)
	
	for i in range(mesh_instances.size()):
		var mesh = mesh_instances[i]
		var mat = mesh.material_override as StandardMaterial3D
		
		# Scale animation - quick expand then shrink
		tween.tween_property(mesh, "scale", 
			initial_scales[i] * 1.5, 
			lifetime * 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		
		tween.tween_property(mesh, "scale", 
			Vector3.ZERO, 
			lifetime * 0.7).set_ease(Tween.EASE_IN).set_delay(lifetime * 0.3)
		
		# Fade out emission intensity using emission_energy_multiplier
		tween.tween_property(mat, "emission_energy_multiplier", 
			0.0, 
			lifetime).set_ease(Tween.EASE_OUT)
		
		# Fade out alpha
		tween.tween_property(mat, "albedo_color:a", 
			0.0, 
			lifetime).set_ease(Tween.EASE_OUT)
		
		# Rotate for dynamic effect
		tween.tween_property(mesh, "rotation:z", 
			mesh.rotation.z + deg_to_rad(90), 
			lifetime)
	
	# Add particle burst
	create_particle_burst()
	
	# Queue free when done
	tween.tween_callback(queue_free).set_delay(lifetime)

func create_particle_burst():
	var particles = GPUParticles3D.new()
	add_child(particles)
	
	# Configure particle system
	particles.emitting = true
	particles.amount = 12
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.speed_scale = 2.0
	particles.amount_ratio = 1.0
	
	# Create process material
	var process_mat = ParticleProcessMaterial.new()
	process_mat.direction = Vector3.ZERO
	process_mat.initial_velocity_min = 0.5
	process_mat.initial_velocity_max = 1.5
	process_mat.angular_velocity_min = -180.0
	process_mat.angular_velocity_max = 180.0
	process_mat.spread = 45.0
	process_mat.scale_min = 0.02
	process_mat.scale_max = 0.05
	process_mat.scale_curve = create_scale_curve()
	process_mat.color = Color(1.0, 0.8, 0.4, 1.0)
	
	particles.process_material = process_mat
	
	# Create particle mesh
	var particle_mesh = SphereMesh.new()
	particle_mesh.radius = 0.01
	particle_mesh.height = 0.02
	particles.draw_pass_1 = particle_mesh
	
	# Create particle material
	var particle_mat = StandardMaterial3D.new()
	particle_mat.emission_enabled = true
	particle_mat.emission = Color(1.0, 0.9, 0.5)
	particle_mat.emission_energy_multiplier = 2.0
	particle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particles.material_override = particle_mat

func create_scale_curve() -> Curve:
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.5, 0.5))
	curve.add_point(Vector2(1.0, 0.0))
	return curve
