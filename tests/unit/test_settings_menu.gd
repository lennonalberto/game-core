extends GutTest

## Unit tests for SettingsMenu overlay, live audio sliders, key rebind flow,
## reset-to-default, PauseMenu integration, and restart persistence (Definition of Done).

const SETTINGS_MENU_SCENE_PATH: String = "res://scenes/ui/settings/settings_menu.tscn"
const PAUSE_MENU_SCENE_PATH: String = "res://scenes/ui/pause_menu/pause_menu.tscn"


func before_each() -> void:
	SettingsManager.reset_to_default()


func after_each() -> void:
	SettingsManager.reset_to_default()
	get_tree().paused = false


func test_settings_menu_initial_state() -> void:
	var scene: PackedScene = load(SETTINGS_MENU_SCENE_PATH)
	assert_not_null(scene, "SettingsMenu scene should load")

	var menu: SettingsMenu = scene.instantiate() as SettingsMenu
	add_child_autofree(menu)

	assert_false(menu.visible, "SettingsMenu should initially be hidden")
	assert_not_null(menu.get_master_slider(), "Master slider should exist")
	assert_not_null(menu.get_music_slider(), "Music slider should exist")
	assert_not_null(menu.get_sfx_slider(), "SFX slider should exist")
	assert_not_null(menu.get_window_mode_option(), "Window mode option should exist")
	assert_not_null(menu.get_vsync_button(), "VSync check button should exist")
	assert_not_null(menu.get_reset_button(), "Reset button should exist")
	assert_not_null(menu.get_back_button(), "Back button should exist")

	var jump_btn: Button = menu.get_rebind_button("jump")
	assert_not_null(jump_btn, "Rebind button for 'jump' should exist")
	assert_eq(jump_btn.text, "Space", "Initial jump button should display 'Space'")


func test_open_settings_syncs_with_settings_manager() -> void:
	SettingsManager.set_volume(SettingsManager.BUS_MASTER, 0.45)
	SettingsManager.set_volume(SettingsManager.BUS_MUSIC, 0.70)

	var scene: PackedScene = load(SETTINGS_MENU_SCENE_PATH)
	var menu: SettingsMenu = scene.instantiate() as SettingsMenu
	add_child_autofree(menu)

	menu.open_settings()

	assert_true(menu.visible, "Menu should be visible after open_settings()")
	assert_almost_eq(menu.get_master_slider().value, 0.45, 0.01, "Master slider should match SettingsManager")
	assert_almost_eq(menu.get_music_slider().value, 0.70, 0.01, "Music slider should match SettingsManager")


func test_audio_sliders_update_settings_manager_live() -> void:
	var scene: PackedScene = load(SETTINGS_MENU_SCENE_PATH)
	var menu: SettingsMenu = scene.instantiate() as SettingsMenu
	add_child_autofree(menu)

	menu.open_settings()
	menu.get_master_slider().value = 0.55

	assert_almost_eq(SettingsManager.get_volume(SettingsManager.BUS_MASTER), 0.55, 0.01, "Moving slider updates SettingsManager live")

	var master_idx: int = AudioServer.get_bus_index(SettingsManager.BUS_MASTER)
	assert_almost_eq(AudioServer.get_bus_volume_db(master_idx), linear_to_db(0.55), 0.1, "AudioServer volume updates live")


func test_key_rebind_flow() -> void:
	var scene: PackedScene = load(SETTINGS_MENU_SCENE_PATH)
	var menu: SettingsMenu = scene.instantiate() as SettingsMenu
	add_child_autofree(menu)

	menu.open_settings()
	menu.start_rebind("jump")

	assert_true(menu.is_rebinding(), "Menu should be in rebinding state")
	assert_eq(menu.get_rebind_button("jump").text, "[Press key...]")

	# Simulate pressing 'K'
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = KEY_K
	key_event.pressed = true
	menu._input(key_event)

	assert_false(menu.is_rebinding(), "Rebinding state should clear after input")
	assert_eq(menu.get_rebind_button("jump").text, "K", "Jump button should now show 'K'")

	# Verify InputMap and SettingsManager
	var bound_events: Array = SettingsManager.get_keybinds("jump")
	assert_eq(bound_events.size(), 1)
	assert_eq((bound_events[0] as InputEventKey).physical_keycode, KEY_K)


func test_key_rebind_cancel_on_escape() -> void:
	var scene: PackedScene = load(SETTINGS_MENU_SCENE_PATH)
	var menu: SettingsMenu = scene.instantiate() as SettingsMenu
	add_child_autofree(menu)

	menu.open_settings()
	menu.start_rebind("jump")
	assert_true(menu.is_rebinding())

	# Press Escape to cancel
	var esc_event: InputEventKey = InputEventKey.new()
	esc_event.physical_keycode = KEY_ESCAPE
	esc_event.pressed = true
	menu._input(esc_event)

	assert_false(menu.is_rebinding(), "Rebinding should cancel on Escape")
	assert_eq(menu.get_rebind_button("jump").text, "Space", "Jump button text should revert to 'Space'")


func test_reset_to_default_restores_all_controls() -> void:
	var scene: PackedScene = load(SETTINGS_MENU_SCENE_PATH)
	var menu: SettingsMenu = scene.instantiate() as SettingsMenu
	add_child_autofree(menu)

	menu.open_settings()

	# Change values
	menu.get_master_slider().value = 0.2
	menu.start_rebind("jump")
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = KEY_H
	key_event.pressed = true
	menu._input(key_event)

	# Trigger reset
	menu.get_reset_button().emit_signal("pressed")

	assert_almost_eq(menu.get_master_slider().value, 1.0, 0.01, "Slider should reset to 1.0")
	assert_almost_eq(SettingsManager.get_volume(SettingsManager.BUS_MASTER), 1.0, 0.01, "SettingsManager should reset to 1.0")
	assert_eq(menu.get_rebind_button("jump").text, "Space", "Jump keybind should reset to 'Space'")


func test_close_and_back_button_saves_and_emits_signal() -> void:
	var scene: PackedScene = load(SETTINGS_MENU_SCENE_PATH)
	var menu: SettingsMenu = scene.instantiate() as SettingsMenu
	add_child_autofree(menu)

	menu.open_settings()
	watch_signals(menu)

	menu.get_back_button().emit_signal("pressed")

	assert_false(menu.visible, "Menu should close on Back")
	assert_signal_emitted(menu, "back_requested")
	assert_signal_emitted(menu, "settings_saved")


func test_definition_of_done_persistence_across_restart() -> void:
	# 1. Setup initial scene and modify volume and keybind
	var scene: PackedScene = load(SETTINGS_MENU_SCENE_PATH)
	var menu: SettingsMenu = scene.instantiate() as SettingsMenu
	add_child_autofree(menu)

	menu.open_settings()
	menu.get_sfx_slider().value = 0.35

	# Rebind jump to KEY_U
	menu.start_rebind("jump")
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = KEY_U
	key_event.pressed = true
	menu._input(key_event)

	# 2. Click Back to persist settings
	menu.get_back_button().emit_signal("pressed")

	# 3. Simulate game restart:
	# Reload settings from disk into SettingsManager and instantiate a fresh SettingsMenu
	SettingsManager.load_settings()

	var fresh_menu: SettingsMenu = scene.instantiate() as SettingsMenu
	add_child_autofree(fresh_menu)
	fresh_menu.open_settings()

	# 4. Verify both volume and keybind persisted and apply immediately
	assert_almost_eq(fresh_menu.get_sfx_slider().value, 0.35, 0.01, "SFX volume persisted across restart")
	assert_almost_eq(SettingsManager.get_volume(SettingsManager.BUS_SFX), 0.35, 0.01, "SettingsManager kept SFX volume")
	assert_eq(fresh_menu.get_rebind_button("jump").text, "U", "Jump button text persisted as 'U'")

	var jump_events: Array = SettingsManager.get_keybinds("jump")
	assert_eq((jump_events[0] as InputEventKey).physical_keycode, KEY_U, "Keybind KEY_U persisted in SettingsManager")
	assert_true(InputMap.action_has_event("jump", jump_events[0]), "InputMap immediately has KEY_U active for gameplay")


func test_pause_menu_settings_navigation() -> void:
	var pause_scene: PackedScene = load(PAUSE_MENU_SCENE_PATH)
	var pause_menu: PauseMenu = pause_scene.instantiate() as PauseMenu
	add_child_autofree(pause_menu)

	pause_menu.open_pause_menu()
	assert_true(pause_menu.is_paused())

	var nested_settings: SettingsMenu = pause_menu.get_settings_menu()
	assert_not_null(nested_settings, "PauseMenu should contain SettingsMenu")
	assert_false(nested_settings.visible, "SettingsMenu should start hidden in pause menu")

	# Click Settings button
	pause_menu.get_settings_button().emit_signal("pressed")
	assert_true(nested_settings.visible, "SettingsMenu should open when Settings button clicked")
	assert_false(pause_menu.main_panel.visible, "Main pause panel should hide while in settings")

	# Click Back button on settings menu
	nested_settings.get_back_button().emit_signal("pressed")
	assert_false(nested_settings.visible, "SettingsMenu should hide after clicking Back")
	assert_true(pause_menu.main_panel.visible, "Main pause panel should restore after Back")
	assert_true(pause_menu.get_settings_button().has_focus(), "Settings button should regain focus")


func test_decoupling_rules() -> void:
	var scene: PackedScene = load(SETTINGS_MENU_SCENE_PATH)
	var menu: SettingsMenu = scene.instantiate() as SettingsMenu
	add_child_autofree(menu)

	assert_false("player" in menu, "SettingsMenu must not hold a direct player reference")
	assert_false("level" in menu, "SettingsMenu must not hold a direct level reference")
