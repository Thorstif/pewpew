extends CharacterBody3D

signal ghost_died

@export var move_speed: float = 1.0
@export var health: int = 1
@export var implode_duration: float = 0.5
@export var float_amplitude: float = 0.3
@export var float_frequency: float = 2.0
@export var fade_in_duration: float = 0.5  # NEW

@onready var mesh_instance = $MeshInstance3D
@onready var collision_shape = $CollisionShape3D

var player_target: Node3D
var is_dying: bool = false
var time_passed: float = 0.0
var original_position: Vector3
var implode_tween: Tween

func _ready():
	collision_layer = 2
	collision_mask = 0
	
	add_to_group("ghosts")
	original_position = global_position
	
	# Find the XR camera (player's head)
	var xr_cameras = get_tree().get_nodes_in_group("xr_camera")
	if xr_cameras.size() > 0:
		player_target = xr_cameras[0]
	else:
		var xr_origin = get_node_or_null("/root/Main/XROrigin3D")
		if xr_origin:
			player_target = xr_origin.get_node("XRCamera3D")
			
	fade_in()
	
func fade_in():
	if mesh_instance and mesh_instance.material_override:
		var mat = mesh_instance.material_override
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0
		
		var tween = create_tween()
		tween.tween_property(mat, "albedo_color:a", 1.0, fade_in_duration)

func _physics_process(delta):
	if is_dying:
		return
		
	if player_target:
		# Move towards player
		var direction = (player_target.global_position - global_position).normalized()
		direction.y = 0  # Keep ghost at same height
		
		velocity = direction * move_speed
		
		# Add floating motion
		time_passed += delta
		var float_offset = sin(time_passed * float_frequency) * float_amplitude
		velocity.y = float_offset
		
		# Look at player
		look_at(player_target.global_position, Vector3.UP)
		
		move_and_slide()
		
		var distance = global_position.distance_to(player_target.global_position)
		if distance < 1:
			die()

func take_damage(damage: int = 1):
	if is_dying:
		return
		
	hit_reaction()
	
	health -= damage
	if health <= 0:
		die()

func hit_reaction():
	# Simple hit flash
	if mesh_instance and mesh_instance.material_override:
		var original_material = mesh_instance.material_override
		var flash_material = original_material.duplicate()
		flash_material.albedo_color = Color.RED
		mesh_instance.material_override = flash_material
		
		await get_tree().create_timer(0.075).timeout
		mesh_instance.material_override = original_material

func die():
	is_dying = true
	emit_signal("ghost_died")
	
	# Disable collision
	if collision_shape:
		collision_shape.disabled = true
	
	# Implode animation
	implode()

func implode():
	if implode_tween:
		implode_tween.kill()
	
	implode_tween = create_tween()
	implode_tween.set_parallel(true)
	
	# Scale down to zero
	implode_tween.tween_property(self, "scale", Vector3.ZERO, implode_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	
	# Rotate while imploding
	implode_tween.tween_property(self, "rotation", rotation + Vector3(0, TAU * 2, 0), implode_duration)
	
	# Optional: Add particle effect here
	
	await implode_tween.finished
	queue_free()
