extends StaticBody3D

const WIREFRAME_MATERIAL: Material = preload("res://assets/wireframe-material.tres")

@onready var label: Label3D = $Label3D
var mesh_instance: MeshInstance3D
var debug_draw: bool = true

func setup_scene(entity: OpenXRFbSpatialEntity) -> void:
	var semantic_labels: PackedStringArray = entity.get_semantic_labels()
	
	if semantic_labels[0] == "wall_face":
		add_to_group("walls")

	var collision_shape = entity.create_collision_shape()
	if collision_shape:
		add_child(collision_shape)
		
	# Wall exists on layer 1, collides with nothing
	collision_layer = 1
	collision_mask = 0

	if debug_draw:
		label.text = semantic_labels[0]
		
		var mesh_array: Array = entity.get_triangle_mesh()
		if not mesh_array.is_empty():
			mesh_instance = MeshInstance3D.new()

			var vertices := PackedVector3Array()
			vertices.resize(mesh_array[Mesh.ARRAY_INDEX].size())
			for i in range(mesh_array[Mesh.ARRAY_INDEX].size()):
				vertices[i] = mesh_array[Mesh.ARRAY_VERTEX][mesh_array[Mesh.ARRAY_INDEX][i]]

			mesh_array[Mesh.ARRAY_VERTEX] = vertices
			mesh_array[Mesh.ARRAY_INDEX] = null

			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_array)
			mesh_instance.mesh = mesh

			mesh_instance.set_surface_override_material(0, WIREFRAME_MATERIAL)
			add_child(mesh_instance)
