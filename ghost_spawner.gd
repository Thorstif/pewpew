extends Node3D

@export var ghost_scene: PackedScene
@export var spawn_radius: float = 5.0
@export var spawn_height: float = 2.0
@export var spawn_interval: float = 3.0
@export var max_ghosts: int = 10
@export var wall_spawn_enabled: bool = true
@export var wall_spawn_cone_angle: float = 45.0  # degrees
@export var wall_spawn_distance: float = 20.0

var spawn_timer: Timer
var current_ghosts: Array = []
var camera: Camera3D

func _ready():
	camera = get_viewport().get_camera_3d()
	setup_spawn_timer()

func setup_spawn_timer():
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	spawn_timer.start()

func _on_spawn_timer_timeout():
	current_ghosts = current_ghosts.filter(func(g): return is_instance_valid(g))
	
	if current_ghosts.size() < max_ghosts:
		if wall_spawn_enabled:
			spawn_ghost_on_wall()
		else:
			spawn_ghost()

func spawn_ghost_on_wall():
	if not camera:
		spawn_ghost()
		return
		
	var max_attempts = 5
	for attempt in max_attempts:
		# Random angle within cone
		var half_angle = deg_to_rad(wall_spawn_cone_angle) / 2
		var h_angle = randf_range(-half_angle, half_angle)
		var v_angle = randf_range(-half_angle, half_angle)

		# Create ray from camera
		var from = camera.global_position
		var forward = -camera.global_transform.basis.z
		var right = camera.global_transform.basis.x
		var up = camera.global_transform.basis.y

		var direction = forward + (right * tan(h_angle)) + (up * tan(v_angle))
		direction = direction.normalized()

		# Cast ray
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, from + direction * wall_spawn_distance)
		query.collision_mask = 1  # Only walls

		var result = space_state.intersect_ray(query)
		if result and result.collider.is_in_group("walls"):
			spawn_ghost_at(result.position + result.normal * 0.5)
			return

	# All attempts failed, fallback
	spawn_ghost()

func spawn_ghost_at(spawn_pos: Vector3):
	if not ghost_scene:
		push_error("Ghost scene not set in GhostSpawner")
		return
	
	var ghost = ghost_scene.instantiate()
	ghost.position = spawn_pos
	add_child(ghost)
	current_ghosts.append(ghost)
	ghost.ghost_died.connect(_on_ghost_died.bind(ghost))

func spawn_ghost():
	var angle = randf() * TAU
	var spawn_pos = Vector3(
		cos(angle) * spawn_radius,
		spawn_height,
		sin(angle) * spawn_radius
	)
	spawn_ghost_at(spawn_pos)

func _on_ghost_died(ghost):
	pass
