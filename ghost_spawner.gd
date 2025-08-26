extends Node3D

@export var ghost_scene: PackedScene
@export var spawn_radius: float = 10.0
@export var spawn_height: float = 2.0
@export var spawn_interval: float = 3.0
@export var max_ghosts: int = 10

var spawn_timer: Timer
var current_ghosts: Array = []

func _ready():
	setup_spawn_timer()

func setup_spawn_timer():
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	spawn_timer.start()

func _on_spawn_timer_timeout():
	# Clean up dead ghosts from array
	current_ghosts = current_ghosts.filter(func(g): return is_instance_valid(g))
	
	if current_ghosts.size() < max_ghosts:
		spawn_ghost()

func spawn_ghost():
	if not ghost_scene:
		push_error("Ghost scene not set in GhostSpawner")
		return
		
	var ghost = ghost_scene.instantiate()
	
	# Random position around player
	var angle = randf() * TAU
	var distance = spawn_radius
	var spawn_pos = Vector3(
		cos(angle) * distance,
		spawn_height,
		sin(angle) * distance
	)
	
	ghost.position = spawn_pos
	add_child(ghost)
	current_ghosts.append(ghost)
	
	# Connect death signal for scoring, effects, etc.
	ghost.ghost_died.connect(_on_ghost_died.bind(ghost))

func _on_ghost_died(ghost):
	# Handle scoring, effects, etc.
	pass
