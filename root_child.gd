@abstract
class_name RootChild
extends Control

func setup_root() -> void:
	if not Data.shortcut_pressed.is_connected(_shortcut_pressed):
		Data.shortcut_pressed.connect(_shortcut_pressed)

# - virtual

@abstract func shortcut_pressed(shortcut_name: String) -> void

func get_console_message_origin() -> Vector2:
	return Vector2(0, get_viewport_rect().size.y)

# - signals

func _shortcut_pressed(_shortcut_name: String) -> void:
	pass
