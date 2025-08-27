extends Node

@onready var scene_manager: OpenXRFbSceneManager = $OpenXRFbSceneManager

func _ready():
	scene_manager.openxr_fb_scene_data_missing.connect(_scene_data_missing)
	scene_manager.openxr_fb_scene_capture_completed.connect(_scene_capture_completed)

func _scene_data_missing() -> void:
	if scene_manager.is_scene_capture_enabled():
		scene_manager.request_scene_capture()
	else:
		print("Scene capture is not enabled.")

func _scene_capture_completed(success: bool) -> void:
	if success == false:
		return

	# Delete any existing anchors, since the user may have changed them.
	if scene_manager.are_scene_anchors_created():
		scene_manager.remove_scene_anchors()

	# Create scene_anchors for the freshly captured scene
	scene_manager.create_scene_anchors()
