@abstract
class_name RootChild
extends Control

const MAIN_MENU_SCENE: PackedScene = preload("uid://c5pkckdf46xep")

func setup_root() -> void:
	if not Data.shortcut_pressed.is_connected(_shortcut_pressed):
		Data.shortcut_pressed.connect(_shortcut_pressed)

# - virtual

@abstract func shortcut_pressed(shortcut_name: String) -> void

func get_console_message_origin() -> Vector2:
	return Vector2(0, get_viewport_rect().size.y)


func quit() -> void:
	if PeerManager.active:
		PeerManager.terminate()
	else:
		TreeManager.swap(MAIN_MENU_SCENE)

# - signals

func _shortcut_pressed(shortcut_name: String) -> void:
	if shortcut_name == "back":
		if _back():
			return
	# disgusting. no modularisation whatsoever.
	elif shortcut_name == "confirm":
		if Console.command_line_open:
			Console.command_line_confirm()
			return
	elif shortcut_name == "command_line":
		if not Console.command_line_open:
			Console.open_command_line()
			return
	shortcut_pressed(shortcut_name)

# - other

func _back() -> bool:
	if Console.command_line_open:
		Console.close_command_line()
		return true
	return false
