extends GutTest

## Unit tests for MainMenu screen, save detection, SettingsMenu overlay,
## GameManager routing, and the full navigation loop (Definition of Done).

const MAIN_MENU_SCENE_PATH: String = "res://scenes/ui/main_menu/main_menu.tscn"
const LEVEL_SCENE_PATH: String = "res://scenes/levels/platformer_demo/platformer_demo.tscn"
const TEST_SLOT: int = 1


func before_each() -> void:
	SettingsManager.reset_to_default()
	SaveManager.current_slot = TEST_SLOT
	if SaveManager.has_save(TEST_SLOT):
		SaveManager.delete_save(TEST_SLOT)


func after_each() -> void:
	SettingsManager.reset_to_default()
	get_tree().paused = false
	if SaveManager.has_save(TEST_SLOT):
		SaveManager.delete_save(TEST_SLOT)
	SaveManager.current_slot = 1
	if get_tree().current_scene is MainMenu:
		get_tree().current_scene.queue_free()
		get_tree().current_scene = null


func test_main_menu_initial_state_no_save() -> void:
	var scene: PackedScene = load(MAIN_MENU_SCENE_PATH)
	assert_not_null(scene, "MainMenu scene should load")

	var menu: MainMenu = scene.instantiate() as MainMenu
	add_child_autofree(menu)

	assert_not_null(menu.get_new_game_button(), "New Game button should exist")
	assert_not_null(menu.get_continue_button(), "Continue button should exist")
	assert_not_null(menu.get_settings_button(), "Settings button should exist")
	assert_not_null(menu.get_quit_button(), "Quit button should exist")

	assert_false(menu.is_continue_enabled(), "Continue button should be disabled when no save exists")
	assert_true(menu.get_continue_button().disabled, "Continue button widget should have disabled = true")


func test_main_menu_initial_state_with_save() -> void:
	# Create a save in TEST_SLOT
	SaveManager.save_game(TEST_SLOT)
	assert_true(SaveManager.has_save(TEST_SLOT))

	var scene: PackedScene = load(MAIN_MENU_SCENE_PATH)
	var menu: MainMenu = scene.instantiate() as MainMenu
	add_child_autofree(menu)

	assert_true(menu.is_continue_enabled(), "Continue button should be enabled when save exists")
	assert_false(menu.get_continue_button().disabled, "Continue button widget should have disabled = false")


func test_settings_button_opens_settings_menu() -> void:
	var scene: PackedScene = load(MAIN_MENU_SCENE_PATH)
	var menu: MainMenu = scene.instantiate() as MainMenu
	add_child_autofree(menu)

	var settings: SettingsMenu = menu.get_settings_menu()
	assert_not_null(settings, "MainMenu should contain SettingsMenu instance")
	assert_false(settings.visible, "SettingsMenu should start hidden")

	# Click Settings
	menu.get_settings_button().emit_signal("pressed")
	assert_true(settings.visible, "SettingsMenu should open")
	assert_false(menu.main_buttons_container.visible, "Main menu card should hide while in settings")

	# Click Back
	settings.get_back_button().emit_signal("pressed")
	assert_false(settings.visible, "SettingsMenu should close after Back")
	assert_true(menu.main_buttons_container.visible, "Main menu card should restore after Back")
	assert_true(menu.get_settings_button().has_focus(), "Settings button should regain focus")


func test_game_manager_level_paths() -> void:
	assert_eq(GameManager.get_level_scene_path("platformer_demo"), "res://scenes/levels/platformer_demo/platformer_demo.tscn")
	assert_eq(GameManager.get_level_scene_path("unknown_level"), "res://scenes/levels/platformer_demo/platformer_demo.tscn", "Unknown levels fall back to default level")


func test_decoupling_rules() -> void:
	var scene: PackedScene = load(MAIN_MENU_SCENE_PATH)
	var menu: MainMenu = scene.instantiate() as MainMenu
	add_child_autofree(menu)

	assert_false("player" in menu, "MainMenu must not reference player directly")
	assert_false("level" in menu, "MainMenu must not reference level directly")


func test_definition_of_done_full_navigation_loop() -> void:
	# 1. Main Menu (no save exists yet)
	var menu_scene: PackedScene = load(MAIN_MENU_SCENE_PATH)
	var menu: MainMenu = menu_scene.instantiate() as MainMenu
	add_child_autofree(menu)

	assert_false(menu.is_continue_enabled(), "Step 1: Continue button must be disabled initially")

	# 2. New Game
	# Simulating player clicking New Game
	SaveManager.new_game(TEST_SLOT)

	# 3. Play level
	var level_scene: PackedScene = load(LEVEL_SCENE_PATH)
	var level: PlatformerDemo = level_scene.instantiate() as PlatformerDemo
	add_child_autofree(level)

	var player: Player = level.player
	var coins: Node2D = level.get_node("Coins")
	var coin1: Coin = coins.get_node("Coin1") as Coin
	var checkpoint: Checkpoint = level.checkpoint

	# Collect Coin 1
	coin1.collect()
	assert_true(coin1.is_collected, "Step 3a: Coin 1 collected during gameplay")

	# Hit Checkpoint and save
	player.global_position = checkpoint.global_position
	checkpoint._on_body_entered(player)
	assert_true(checkpoint.is_reached, "Step 3b: Checkpoint reached")
	assert_true(SaveManager.has_save(TEST_SLOT), "Step 3c: Save file created at checkpoint")

	# 4. Pause
	var pause_menu: PauseMenu = level.get_node("PauseMenu") as PauseMenu
	assert_not_null(pause_menu, "Level has PauseMenu")
	pause_menu.open_pause_menu()
	assert_true(get_tree().paused, "Step 4: Gameplay paused")
	assert_true(pause_menu.is_paused())

	# 5. Settings from Pause Menu
	pause_menu.get_settings_button().emit_signal("pressed")
	var pause_settings: SettingsMenu = pause_menu.get_settings_menu()
	assert_true(pause_settings.visible, "Step 5: Settings menu opened from pause")

	# Modify SFX volume in settings
	pause_settings.get_sfx_slider().value = 0.3
	assert_almost_eq(SettingsManager.get_volume(SettingsManager.BUS_SFX), 0.3, 0.01)

	# 6. Back to Pause Menu
	pause_settings.get_back_button().emit_signal("pressed")
	assert_false(pause_settings.visible, "Step 6: Settings closed, back in pause menu")
	assert_true(pause_menu.main_panel.visible)

	# 7. Quit to Main Menu
	pause_menu.get_quit_button().emit_signal("pressed")
	assert_false(get_tree().paused, "Step 7: Quitting to main menu unpauses tree")

	# 8. Continue from Main Menu restores correctly
	var menu2: MainMenu = menu_scene.instantiate() as MainMenu
	add_child_autofree(menu2)

	assert_true(menu2.is_continue_enabled(), "Step 8a: Continue button is now ENABLED on Main Menu")

	# Simulate continuing: load level and restore save data
	var level2: PlatformerDemo = level_scene.instantiate() as PlatformerDemo
	add_child_autofree(level2)

	var err: Error = SaveManager.load_game(TEST_SLOT)
	assert_eq(err, OK, "Step 8b: Loading saved game succeeded")

	var coin1_reloaded: Coin = level2.get_node("Coins/Coin1") as Coin
	assert_true(coin1_reloaded.is_collected, "Step 8c: Coin 1 remains collected after Continue")
	assert_almost_eq(level2.player.global_position.x, checkpoint.global_position.x, 1.0, "Step 8d: Player X position restored to checkpoint")
	assert_almost_eq(level2.player.global_position.y, checkpoint.global_position.y, 1.0, "Step 8e: Player Y position restored to checkpoint")
