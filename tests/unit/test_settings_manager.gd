extends GutTest

## Unit tests for SettingsManager covering audio volume, keybindings, reset-to-default,
## and persistence contracts per AGENTS.md and PLAN.md.

const TEST_SAVE_PATH: String = "user://test_settings_temp.tres"


func before_each() -> void:
	# Ensure clean baseline before each test
	SettingsManager.reset_to_default()


func after_each() -> void:
	# Clean up any temporary test files
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)
	SettingsManager.reset_to_default()


func test_volume_updates_audio_server() -> void:
	# Test setting Master volume
	SettingsManager.set_volume(SettingsManager.BUS_MASTER, 0.5)
	assert_almost_eq(SettingsManager.get_volume(SettingsManager.BUS_MASTER), 0.5, 0.001, "SettingsManager should return set master volume")
	var master_idx: int = AudioServer.get_bus_index(SettingsManager.BUS_MASTER)
	assert_gt(master_idx, -1, "Master bus should exist")
	assert_almost_eq(AudioServer.get_bus_volume_db(master_idx), linear_to_db(0.5), 0.1, "AudioServer master bus volume in dB should match linear_to_db")

	# Test setting Music volume
	SettingsManager.set_volume(SettingsManager.BUS_MUSIC, 0.75)
	assert_almost_eq(SettingsManager.get_volume(SettingsManager.BUS_MUSIC), 0.75, 0.001, "SettingsManager should return set music volume")
	var music_idx: int = AudioServer.get_bus_index(SettingsManager.BUS_MUSIC)
	assert_gt(music_idx, -1, "Music bus should exist")
	assert_almost_eq(AudioServer.get_bus_volume_db(music_idx), linear_to_db(0.75), 0.1, "AudioServer music bus volume in dB should match linear_to_db")

	# Test setting SFX volume
	SettingsManager.set_volume(SettingsManager.BUS_SFX, 0.25)
	assert_almost_eq(SettingsManager.get_volume(SettingsManager.BUS_SFX), 0.25, 0.001, "SettingsManager should return set sfx volume")
	var sfx_idx: int = AudioServer.get_bus_index(SettingsManager.BUS_SFX)
	assert_gt(sfx_idx, -1, "SFX bus should exist")
	assert_almost_eq(AudioServer.get_bus_volume_db(sfx_idx), linear_to_db(0.25), 0.1, "AudioServer sfx bus volume in dB should match linear_to_db")

	# Test volume 0 mutes the bus
	SettingsManager.set_volume(SettingsManager.BUS_MASTER, 0.0)
	assert_true(AudioServer.is_bus_mute(master_idx), "Volume at 0 should mute the audio bus")


func test_rebinding_key_updates_input_map() -> void:
	var new_key: InputEventKey = InputEventKey.new()
	new_key.physical_keycode = KEY_P

	SettingsManager.set_keybind("jump", [new_key])

	assert_true(InputMap.action_has_event("jump", new_key), "InputMap should have the newly bound key for 'jump'")
	var bound_events: Array = SettingsManager.get_keybinds("jump")
	assert_eq(bound_events.size(), 1, "There should be exactly one key bound to 'jump'")
	assert_eq((bound_events[0] as InputEventKey).physical_keycode, KEY_P, "Bound key should be KEY_P")


func test_reset_to_default_restores_baseline() -> void:
	# Change volume and keybind
	SettingsManager.set_volume(SettingsManager.BUS_MASTER, 0.3)
	SettingsManager.set_volume(SettingsManager.BUS_MUSIC, 0.4)
	SettingsManager.set_volume(SettingsManager.BUS_SFX, 0.5)

	var temp_key: InputEventKey = InputEventKey.new()
	temp_key.physical_keycode = KEY_H
	SettingsManager.set_keybind("jump", [temp_key])

	# Reset
	SettingsManager.reset_to_default()

	# Assert volumes restored to baseline 1.0
	assert_almost_eq(SettingsManager.get_volume(SettingsManager.BUS_MASTER), 1.0, 0.001, "Master volume should reset to 1.0")
	assert_almost_eq(SettingsManager.get_volume(SettingsManager.BUS_MUSIC), 1.0, 0.001, "Music volume should reset to 1.0")
	assert_almost_eq(SettingsManager.get_volume(SettingsManager.BUS_SFX), 1.0, 0.001, "SFX volume should reset to 1.0")

	var master_idx: int = AudioServer.get_bus_index(SettingsManager.BUS_MASTER)
	assert_almost_eq(AudioServer.get_bus_volume_db(master_idx), linear_to_db(1.0), 0.1, "AudioServer master bus should be at 0 dB")

	# Assert jump keybind restored to baseline (KEY_SPACE)
	assert_false(InputMap.action_has_event("jump", temp_key), "InputMap should no longer contain temporary test key")
	var jump_events: Array = SettingsManager.get_keybinds("jump")
	assert_gt(jump_events.size(), 0, "Jump should have default keybind restored")
	var has_space: bool = false
	for ev in jump_events:
		if ev is InputEventKey and ev.physical_keycode == KEY_SPACE:
			has_space = true
	assert_true(has_space, "Jump should have KEY_SPACE restored as default")


func test_persistence_round_trip() -> void:
	SettingsManager.set_volume(SettingsManager.BUS_MASTER, 0.65)
	SettingsManager.set_volume(SettingsManager.BUS_MUSIC, 0.85)

	var err: Error = SettingsManager.save_settings(TEST_SAVE_PATH)
	assert_eq(err, OK, "Saving settings should succeed with OK")
	assert_true(FileAccess.file_exists(TEST_SAVE_PATH), "Settings file should exist on disk")

	# Reset memory to defaults
	SettingsManager.reset_to_default()
	assert_almost_eq(SettingsManager.get_volume(SettingsManager.BUS_MASTER), 1.0, 0.001)

	# Reload from test save path
	SettingsManager.load_settings(TEST_SAVE_PATH)
	assert_almost_eq(SettingsManager.get_volume(SettingsManager.BUS_MASTER), 0.65, 0.001, "Reloaded master volume should match saved value")
	assert_almost_eq(SettingsManager.get_volume(SettingsManager.BUS_MUSIC), 0.85, 0.001, "Reloaded music volume should match saved value")


func test_missing_file_graceful_fallback() -> void:
	var non_existent_path: String = "user://does_not_exist_987654.tres"
	if FileAccess.file_exists(non_existent_path):
		DirAccess.remove_absolute(non_existent_path)

	SettingsManager.load_settings(non_existent_path)
	assert_not_null(SettingsManager.settings_data, "SettingsData should not be null after fallback")
	assert_almost_eq(SettingsManager.get_volume(SettingsManager.BUS_MASTER), 1.0, 0.001, "Fallback settings should have default volume 1.0")

	# Clean up file created by fallback save
	if FileAccess.file_exists(non_existent_path):
		DirAccess.remove_absolute(non_existent_path)


func test_signals_emitted_on_changes() -> void:
	watch_signals(EventBus)

	SettingsManager.set_volume(SettingsManager.BUS_SFX, 0.45)
	assert_signal_emitted(EventBus, "settings_changed", "EventBus.settings_changed should be emitted on volume change")
	assert_signal_emitted_with_parameters(EventBus, "volume_changed", [SettingsManager.BUS_SFX, 0.45])

	var new_key: InputEventKey = InputEventKey.new()
	new_key.physical_keycode = KEY_ENTER
	SettingsManager.set_keybind("pause", [new_key])
	assert_signal_emitted(EventBus, "settings_changed", "EventBus.settings_changed should be emitted on keybind change")
