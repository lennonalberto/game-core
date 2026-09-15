extends Node

## Single source of truth for persistent user preferences.
##
## Architectural Rule: Never create a second source of truth for state that an
## autoload owns (e.g. do not cache volume levels or input bindings in UI scripts).
## UI controls display current SettingsManager values and forward user changes back to it.
## Settings data is persisted to its own dedicated configuration file, strictly separated
## from gameplay save files.

const SETTINGS_FILE_PATH: String = "user://settings.tres"
const BUS_MASTER: String = "Master"
const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"

## The active in-memory settings data resource.
var settings_data: SettingsData

## Baseline default keybinds captured from InputMap at project initialization.
var default_keybinds: Dictionary = {}


func _ready() -> void:
	_capture_default_keybinds()
	load_settings()
	_apply_all_settings()


# --- Public Audio API ---

## Returns the current linear volume (0.0 to 1.0) for the specified audio bus.
func get_volume(bus_name: String) -> float:
	match bus_name:
		BUS_MASTER:
			return settings_data.master_volume
		BUS_MUSIC:
			return settings_data.music_volume
		BUS_SFX:
			return settings_data.sfx_volume
		_:
			push_warning("Unknown audio bus: %s" % bus_name)
			return 1.0


## Sets the linear volume (0.0 to 1.0) for the specified audio bus and applies it to AudioServer.
func set_volume(bus_name: String, linear_value: float) -> void:
	linear_value = clampf(linear_value, 0.0, 1.0)
	match bus_name:
		BUS_MASTER:
			settings_data.master_volume = linear_value
		BUS_MUSIC:
			settings_data.music_volume = linear_value
		BUS_SFX:
			settings_data.sfx_volume = linear_value
		_:
			push_warning("Unknown audio bus: %s" % bus_name)
			return

	_apply_bus_volume(bus_name, linear_value)
	EventBus.volume_changed.emit(bus_name, linear_value)
	EventBus.settings_changed.emit()


# --- Public Keybindings API ---

## Returns an Array of InputEvent objects bound to the specified action.
func get_keybinds(action_name: String) -> Array:
	if settings_data.keybinds.has(action_name):
		return settings_data.keybinds[action_name]
	if InputMap.has_action(action_name):
		return InputMap.action_get_events(action_name)
	return []


## Rebinds an action to the given array of InputEvent objects and applies them to InputMap.
func set_keybind(action_name: String, events: Array) -> void:
	settings_data.keybinds[action_name] = events
	_apply_action_keybinds(action_name, events)
	EventBus.settings_changed.emit()


# --- Public Video / Display API ---

## Returns the configured window mode (DisplayServer.WindowMode).
func get_window_mode() -> int:
	return settings_data.window_mode


## Sets and applies the display window mode.
func set_window_mode(mode: int) -> void:
	settings_data.window_mode = mode
	DisplayServer.window_set_mode(mode as DisplayServer.WindowMode)
	EventBus.settings_changed.emit()


## Returns the configured V-Sync mode (DisplayServer.VSyncMode).
func get_vsync_mode() -> int:
	return settings_data.vsync_mode


## Sets and applies the display V-Sync mode.
func set_vsync_mode(mode: int) -> void:
	settings_data.vsync_mode = mode
	DisplayServer.window_set_vsync_mode(mode as DisplayServer.VSyncMode)
	EventBus.settings_changed.emit()


# --- Reset & Persistence ---

## Restores all settings to their original project baseline defaults, re-applies them, and saves.
func reset_to_default() -> void:
	settings_data.master_volume = 1.0
	settings_data.music_volume = 1.0
	settings_data.sfx_volume = 1.0
	settings_data.window_mode = DisplayServer.WINDOW_MODE_WINDOWED
	settings_data.vsync_mode = DisplayServer.VSYNC_ENABLED

	# Restore baseline keybinds
	var restored_keybinds: Dictionary = {}
	for action_name: String in default_keybinds:
		var events: Array = []
		for event in default_keybinds[action_name]:
			if event is InputEvent:
				events.append(event.duplicate())
			else:
				events.append(event)
		restored_keybinds[action_name] = events
	settings_data.keybinds = restored_keybinds

	_apply_all_settings()
	save_settings()

	# Notify listeners of reset
	EventBus.volume_changed.emit(BUS_MASTER, settings_data.master_volume)
	EventBus.volume_changed.emit(BUS_MUSIC, settings_data.music_volume)
	EventBus.volume_changed.emit(BUS_SFX, settings_data.sfx_volume)
	EventBus.settings_changed.emit()


## Saves the current settings to disk.
func save_settings(file_path: String = SETTINGS_FILE_PATH) -> Error:
	var err: Error = ResourceSaver.save(settings_data, file_path)
	if err != OK:
		push_error("Failed to save settings to %s: Error %d" % [file_path, err])
	return err


## Loads settings from disk with graceful fallback if the file is missing or corrupted.
func load_settings(file_path: String = SETTINGS_FILE_PATH) -> void:
	if FileAccess.file_exists(file_path):
		var loaded = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if loaded is SettingsData:
			settings_data = loaded
			# Ensure keybinds dictionary has defaults for any missing project actions
			_ensure_keybind_completeness()
			return
		else:
			push_warning("Settings file at %s is corrupted or of invalid type. Falling back to default." % file_path)

	# Fallback to defaults
	settings_data = SettingsData.create_default()
	var initial_keybinds: Dictionary = {}
	for action_name: String in default_keybinds:
		var events: Array = []
		for event in default_keybinds[action_name]:
			if event is InputEvent:
				events.append(event.duplicate())
			else:
				events.append(event)
		initial_keybinds[action_name] = events
	settings_data.keybinds = initial_keybinds
	save_settings(file_path)


# --- Internal Helper Methods ---

## Captures non-built-in project actions from InputMap to serve as the default baseline.
func _capture_default_keybinds() -> void:
	default_keybinds.clear()
	var actions: Array[StringName] = InputMap.get_actions()
	for action: StringName in actions:
		var action_str: String = String(action)
		# Skip Godot's built-in editor / UI navigation actions unless custom
		if action_str.begins_with("ui_"):
			continue
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		var duplicated_events: Array = []
		for event in events:
			duplicated_events.append(event.duplicate())
		default_keybinds[action_str] = duplicated_events


## Ensures all baseline actions exist in settings_data.keybinds.
func _ensure_keybind_completeness() -> void:
	for action_name: String in default_keybinds:
		if not settings_data.keybinds.has(action_name):
			var events: Array = []
			for event in default_keybinds[action_name]:
				if event is InputEvent:
					events.append(event.duplicate())
				else:
					events.append(event)
			settings_data.keybinds[action_name] = events


## Applies all active settings to their corresponding engine systems.
func _apply_all_settings() -> void:
	_apply_bus_volume(BUS_MASTER, settings_data.master_volume)
	_apply_bus_volume(BUS_MUSIC, settings_data.music_volume)
	_apply_bus_volume(BUS_SFX, settings_data.sfx_volume)

	for action_name: String in settings_data.keybinds:
		_apply_action_keybinds(action_name, settings_data.keybinds[action_name])

	DisplayServer.window_set_mode(settings_data.window_mode as DisplayServer.WindowMode)
	DisplayServer.window_set_vsync_mode(settings_data.vsync_mode as DisplayServer.VSyncMode)


## Converts linear volume (0.0 to 1.0) to decibels and applies it to AudioServer.
func _apply_bus_volume(bus_name: String, linear_value: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return

	if linear_value <= 0.0001:
		AudioServer.set_bus_mute(bus_idx, true)
		AudioServer.set_bus_volume_db(bus_idx, -80.0)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_value))


## Erases existing events for an action in InputMap and replaces them with the new events.
func _apply_action_keybinds(action_name: String, events: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	InputMap.action_erase_events(action_name)
	for event in events:
		if event is InputEvent:
			InputMap.action_add_event(action_name, event)
