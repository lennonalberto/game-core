class_name SettingsData
extends Resource

## Data model for persistent user settings (audio volumes, keybindings, and display).
##
## Architectural Rule: Settings are stored as a custom Resource subclass, not raw
## dictionaries or scattered variables. This file is saved independently from game
## save slots and achievement files on disk.

## Schema version for migration safeguards per AGENTS.md.
@export var version: int = 1

# --- Audio Settings (linear scale 0.0 to 1.0) ---
@export_range(0.0, 1.0, 0.01) var master_volume: float = 1.0
@export_range(0.0, 1.0, 0.01) var music_volume: float = 1.0
@export_range(0.0, 1.0, 0.01) var sfx_volume: float = 1.0

# --- Video / Display Settings ---
@export var window_mode: int = DisplayServer.WINDOW_MODE_WINDOWED
@export var vsync_mode: int = DisplayServer.VSYNC_ENABLED

# --- Input / Keybindings ---
## Dictionary mapping action names (String) to Array of InputEvent objects.
@export var keybinds: Dictionary = {}


## Returns a duplicate of this SettingsData instance.
func clone() -> SettingsData:
	var dup: SettingsData = SettingsData.new()
	dup.version = version
	dup.master_volume = master_volume
	dup.music_volume = music_volume
	dup.sfx_volume = sfx_volume
	dup.window_mode = window_mode
	dup.vsync_mode = vsync_mode
	
	# Deep copy keybinds dictionary and its event arrays
	var copied_keybinds: Dictionary = {}
	for action: String in keybinds:
		var events: Array = keybinds[action]
		var copied_events: Array = []
		for event in events:
			if event is InputEvent:
				copied_events.append(event.duplicate())
			else:
				copied_events.append(event)
		copied_keybinds[action] = copied_events
	dup.keybinds = copied_keybinds
	
	return dup


## Creates a new SettingsData instance with default baseline configuration.
static func create_default() -> SettingsData:
	var data: SettingsData = SettingsData.new()
	data.version = 1
	data.master_volume = 1.0
	data.music_volume = 1.0
	data.sfx_volume = 1.0
	data.window_mode = DisplayServer.WINDOW_MODE_WINDOWED
	data.vsync_mode = DisplayServer.VSYNC_ENABLED
	data.keybinds = {}
	return data
