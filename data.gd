extends Node

signal settings_changed()
signal maps_changed()

signal shortcut_pressed(shortcut_name: String)
signal key_pressed(key_name: String)

const INFO_PATH := "info.json"
const MAPS_PATH := "data/maps.json"
const CONSTANTS_PATH := "data/constants.json"
const SETTINGS_PATH := "data/settings.json"

const REQUIRED_INFO_ELEMENTS: Array[String] = [
	"version",
]
const REQUIRED_MAPS_SECTIONS: Array[String] = [
	"key",
	"mouse_button",
]
const REQUIRED_SETTINGS_SECTIONS: Array[String] = [
	"settings",
	"keybinds",
	"shortcuts",
]

const REQUIRED_SETTINGS_VALUES: Array[String] = [
	"debug_mode",
]

var debug_mode: bool = false # set in parse_settings()

var shortcuts_enabled: bool = true

## priority list; most prioritised element is at index 0
var focussed_button_group: Array[CustomButtonGroup]

var _info: Dictionary[String, Variant] = {}
var _maps: Dictionary[String, Dictionary] = {}
var _constants: Dictionary[String, Variant]
var _settings: Dictionary[String, Dictionary] = {}

var _actions: Array[String] = []

func _ready() -> void:
	reload_data()


func _shortcut_input(event: InputEvent) -> void:
	if not shortcuts_enabled:
		return

	if not event is InputEventKey:
		return

	if not event.is_pressed():
		return

	if event.is_echo():
		return

	var keycode: Key = (event as InputEventKey).keycode
	var key_name: Variant = _maps.key.find_key(float(keycode))
	if not key_name is String:
		return

	key_pressed.emit(str(key_name).trim_prefix("KEY_"))

	for shortcut: String in _settings.shortcuts.keys():
		var dict: Dictionary[String, String] = {}
		dict.assign(_settings.shortcuts[shortcut])

		var modifier: String = dict.modifier

		var modifier_key: int = maps("key", modifier, KEY_NONE, modifier != "")
		if modifier != "":
			if modifier_key == KEY_NONE:
				push_error("Couldn't find keycode of '%s'" % modifier)
				return
			if not Input.is_key_pressed(modifier_key as int):
				continue

		var pressed: bool = false
		if key_name == dict.key:
			pressed = true
		elif key_name == dict.alt_key:
			pressed = true
		if not pressed:
			continue

		shortcut_pressed.emit(shortcut)


func constants(key: String) -> Variant:
	if not _constants.has(key):
		push_error("Invalid key '%s' in constants" % key)
		return null

	return _constants[key]


func info(key: String) -> Variant:
	if not _info.has(key):
		push_error("Invalid key '%s' in info" % key)
		return null

	return _info[key]


func input_action_event_name(key: String) -> String:
	if not _settings.keybinds.has(key):
		push_error("Invalid key '%s' in keybinds" % key)
		return ""

	return _settings.keybinds[key]


func settings(key: String) -> Variant:
	if not _settings.settings.has(key):
		push_error("Invalid key '%s' in settings" % key)
		return null

	return _settings.settings[key]


func shortcut_dict(key: String) -> Dictionary[String, String]:
	if not _settings.shortcuts.has(key):
		push_error("Invalid key '%s' in shortcuts" % key)
		return {}

	var ret: Dictionary[String, String] = {}
	ret.assign(_settings.shortcuts[key])

	return ret


func maps(section: String, key: String, default: Variant = null, error: bool = true) -> Variant:
	if not _maps.has(section):
		if error:
			push_error("Section '%s' not found in '%s'" % [section, MAPS_PATH])
		return default
	if not _maps[section].has(key):
		if error:
			push_error("Key '%s' not found in '%s::%s'" % [key, MAPS_PATH, section])
		return default
	return _maps[section][key]


func maps_find_key(section: String, value: Variant) -> String:
	if not _maps.has(section):
		push_error("Section '%s' not found in '%s'" % [section, MAPS_PATH])
		return ""

	if value is int:
		value = float(value as int) # because JSON only has float

	var result_var: Variant = _maps[section].find_key(value)
	if result_var == null:
		push_error("Section '%s' in '%s' does not contain value '%s'" % [section, MAPS_PATH, value])
		return ""

	return str(result_var)


func maps_section(section: String) -> Dictionary[String, Variant]:
	if not _maps.has(section):
		push_error("Section '%s' not found in '%s'" % [section , MAPS_PATH])
		return {}
	var ret: Dictionary[String, Variant] = {}
	ret.assign(_maps[section])
	return ret


func set_settings(key: String, value: Variant, write_file: bool = true) -> bool:
	if not _settings.settings.has(key):
		push_error("key '%s' not found in '%s'" % [key, SETTINGS_PATH])
		return false

	_settings.settings[key] = value

	if write_file:
		write_settings_to_file()

	_settings_changed()

	return true


func write_settings_to_file() -> void:
	write_json(SETTINGS_PATH, _settings)


func set_maps(section: String, key: String, value: Variant, write_file: bool = true) -> bool:
	if not _maps.has(section):
		push_error("Section '%s' not found in '%s'" % [section, MAPS_PATH])
		return false

	_maps[section][key] = value

	if write_file:
		write_json(MAPS_PATH, _maps)

	maps_changed.emit()

	return true


func set_maps_section(section: String, value: Dictionary, write_file: bool = true) -> bool:
	if not _maps.has(section):
		push_error("Section '%s' not found in '%s'" % [section , MAPS_PATH])
		return false

	_maps[section] = value

	if write_file:
		write_json(MAPS_PATH, _maps)

	maps_changed.emit()

	return true


func set_keybinding(key: String, value: String, write_file: bool = true) -> bool:
	if not _settings.keybinds.has(key):
		push_error("Key '%s' not found in '%s::keybinds'" % [key, SETTINGS_PATH])
		return false

	_settings.keybinds[key] = value

	if write_file:
		write_settings_to_file()

	reload_inputs()

	return true


func set_shortcut_element(key: String, element: String, value: String, write_file: bool = true) -> bool:
	if not _settings.shortcuts.has(key):
		push_error("Key '%s' not found in '%s::keybinds'" % [key, SETTINGS_PATH])
		return false

	if not _settings.shortcuts[key].has(element):
		push_error("Unrecognised shortcut element '%s' (in key '%s')" % [element, key])
		return false

	_settings.shortcuts[key][element] = value

	if write_file:
		write_settings_to_file()

	reload_shortcuts()

	return true


func set_shortcuts_enabled(value: bool) -> void:
	shortcuts_enabled = value


func enable_shortcuts() -> void:
	set_shortcuts_enabled(true)


func disable_shortcuts() -> void:
	set_shortcuts_enabled(false)


func reload_data() -> void:
	parse_info()
	parse_maps()
	parse_constants()
	parse_settings()
	reload_inputs()
	reload_shortcuts()


func parse_info_keep() -> void:
	if _info.size() == 0:
		parse_info()


func parse_info() -> void:
	_info.assign(parse_json(INFO_PATH))
	if _info.size() == 0:
		push_error("Error loading/parsing '%s'" % INFO_PATH)
		return

	for element in REQUIRED_INFO_ELEMENTS:
		if not _info.has(element):
			push_error("'%s' is missing section '%s'" % [INFO_PATH, element])


func parse_maps_keep() -> void:
	if _maps.size() == 0:
		parse_maps()


func parse_maps() -> void:
	_maps.assign(parse_json(MAPS_PATH))
	if _maps.size() == 0:
		push_error("Error loading/parsing '%s'" % MAPS_PATH)
		return

	for section in REQUIRED_MAPS_SECTIONS:
		if not _maps.has(section):
			push_error("'%s' is missing section '%s'" % [MAPS_PATH, section])


func parse_constants() -> void:
	_constants.assign(parse_json(CONSTANTS_PATH));
	if _constants.size() == 0:
		push_error("Error loading/parsing '%s'" % CONSTANTS_PATH)
		return


func parse_settings_keep() -> void:
	if _settings.size() == 0:
		parse_settings()


func parse_settings() -> void:
	_settings.assign(parse_json(SETTINGS_PATH))
	if _settings.size() == 0:
		push_error("Error loading/parsing '%s'" % SETTINGS_PATH)
		return

	for section: String in REQUIRED_SETTINGS_SECTIONS:
		if not _settings.has(section):
			push_error("'%s' is missing section '%s'" % [SETTINGS_PATH, section])

	for value: String in REQUIRED_SETTINGS_VALUES:
		if not _settings.settings.has(value):
			push_error("'%s::settings' is missing value '%s'" % [SETTINGS_PATH, value])

	_settings_changed()


func reload_shortcuts() -> void:
	parse_settings_keep()

	assert(_settings.get("shortcuts") is Dictionary, "Invalid/Missing shortcuts dictionary")
	for shortcut: String in _settings.shortcuts.keys():
		var shortcut_dict: Dictionary[String, String] = {}
		assert(_settings.shortcuts.get(shortcut) is Dictionary, "Invalid shortcut '%s'" % shortcut)
		shortcut_dict.assign(_settings.shortcuts[shortcut] as Dictionary)

		var modifier: String = shortcut_dict.modifier
		if modifier != "" and not _maps.key.has(modifier):
			push_error("Modifier '%s' not found in '%s::key'" % [modifier, MAPS_PATH])
			return

		var key: String = shortcut_dict.key
		if key == "":
			continue
		if not _maps.key.has(key):
			push_error("Key '%s' not found in '%s::key'" % [key, MAPS_PATH])
			return

		var alt_key: String = shortcut_dict.key
		if alt_key != "" and not _maps.key.has(alt_key):
			push_error("Alternative key '%s' not found in '%s::key'" % [key, MAPS_PATH])
			return


func reload_inputs() -> void:
	parse_settings_keep()
	clear_inputs()
	load_inputs()


func clear_inputs() -> void:
	for action: String in _actions:
		InputMap.erase_action(action)
	_actions.clear()


func load_inputs() -> void:
	for action_name: String in _settings.keybinds.keys():
		var value: Variant = _settings.keybinds.get(action_name)
		assert(value is String, "Invalid keybind value '%s' for key '%s'" % [str(value), action_name])
		add_input(action_name, value as String)
		_actions.push_back(action_name)


func add_input(action_name: String, event_name: String) -> void:
	if InputMap.has_action(action_name):
		push_error("Action '%s' already exists" % action_name)
		return

	var event := input_event(event_name)

	if event == null:
		push_error("Error retreiving code for event name '%s'" % event_name)
		return

	InputMap.add_action(action_name)
	InputMap.action_add_event(action_name, event)

# - utility

func parse_json(path: String) -> Dictionary[String, Variant]:
	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		push_error("Failed to open file '%s'" % path)
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())

	if not parsed is Dictionary:
		push_error("Failed to parse json at '%s' as dictionary" % path)
		return {}

	var json: Dictionary[String, Variant] = {}
	json.assign(parsed as Dictionary)

	return json


func write_json(path: String, value: Dictionary) -> void:
	var indent: Variant = settings("json_indent")
	if not indent is String:
		push_error("Failed to get setting 'json_indent' as String")
		return

	var file := FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		push_error("Failed to open/create file '%s'" % path)
		return

	const SORT_KEYS: bool = false
	const FULL_PRECISION: bool = false
	var content: String = JSON.stringify(value, indent as String, SORT_KEYS, FULL_PRECISION)

	file.store_string(content)


func input_event(event_name: String) -> InputEvent:
	if _maps.key.has(event_name):
		var event := InputEventKey.new()
		event.keycode = _maps.key[event_name]
		return event
	if _maps.mouse_button.has(event_name):
		var event := InputEventMouseButton.new()
		event.button_index = _maps.mouse_button[event_name]
		return event

	push_error("Unknown event name '%s'" % event_name)
	return null


func expand_array(original: Array, new_size: int, fill_value: Variant) -> Array:
	var copy: Array = original.duplicate(false)

	if original.size() >= new_size:
		return copy

	copy.resize(new_size)

	for i in range(original.size(), new_size):
		copy[i] = fill_value

	return copy

# - private

func _update_language() -> void:
	var language: String = settings("language")
	if language == "automatic":
		TranslationServer.set_locale(OS.get_locale_language())
	else:
		TranslationServer.set_locale(language)


func _set_debug_mode() -> void:
	var debug_mode_var: Variant = settings("debug_mode")
	if debug_mode_var is bool:
		debug_mode = debug_mode_var


func _settings_changed() -> void:
	_set_debug_mode()
	_update_language()
	settings_changed.emit()
