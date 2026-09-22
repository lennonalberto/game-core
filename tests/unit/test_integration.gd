extends GutTest

## Phase 4 — End-to-End Integration Suite
##
## Validates the entire application lifecycle, cross-system boundaries,
## independent persistence domains (Settings vs Saves vs Achievements),
## multi-slot isolation, and architectural decoupling rules.

const MAIN_MENU_SCENE_PATH: String = "res://scenes/ui/main_menu/main_menu.tscn"
const LEVEL_SCENE_PATH: String = "res://scenes/levels/platformer_demo/platformer_demo.tscn"
const PLAYER_SCENE_PATH: String = "res://scenes/entities/player/player.tscn"
const COIN_SCENE_PATH: String = "res://scenes/entities/pickups/coin.tscn"
const CHECKPOINT_SCENE_PATH: String = "res://scenes/entities/checkpoint/checkpoint.tscn"
const HUD_SCENE_PATH: String = "res://scenes/ui/hud/hud.tscn"
const PAUSE_MENU_SCENE_PATH: String = "res://scenes/ui/pause_menu/pause_menu.tscn"

const SLOT_A: int = 1
const SLOT_B: int = 2


func before_each() -> void:
	SettingsManager.reset_to_default()
	AchievementManager.reset_all_achievements()
	if SaveManager.has_save(SLOT_A):
		SaveManager.delete_save(SLOT_A)
	if SaveManager.has_save(SLOT_B):
		SaveManager.delete_save(SLOT_B)
	SaveManager.current_slot = SLOT_A
	SaveManager.current_level_id = ""
	SaveManager.current_save = null


func after_each() -> void:
	SettingsManager.reset_to_default()
	AchievementManager.reset_all_achievements()
	get_tree().paused = false
	if SaveManager.has_save(SLOT_A):
		SaveManager.delete_save(SLOT_A)
	if SaveManager.has_save(SLOT_B):
		SaveManager.delete_save(SLOT_B)
	SaveManager.current_slot = 1
	if get_tree().current_scene is MainMenu:
		get_tree().current_scene.queue_free()
		get_tree().current_scene = null


func test_full_game_loop_e2e() -> void:
	# 1. Clean Main Menu: Continue should be disabled initially
	var menu_scene: PackedScene = load(MAIN_MENU_SCENE_PATH)
	var menu1: MainMenu = menu_scene.instantiate() as MainMenu
	add_child_autofree(menu1)

	assert_false(menu1.is_continue_enabled(), "Phase 4 E2E: Continue disabled on initial launch")

	# 2. Start New Game
	SaveManager.new_game(SLOT_A)
	assert_not_null(SaveManager.current_save, "SaveManager initialized for new game")

	# 3. Enter Level & Play
	var level_scene: PackedScene = load(LEVEL_SCENE_PATH)
	var level1: PlatformerDemo = level_scene.instantiate() as PlatformerDemo
	add_child_autofree(level1)

	assert_eq(SaveManager.current_level_id, "platformer_demo", "Level ID recorded on start")

	var player1: Player = level1.player
	var coin1: Coin = level1.get_node("Coins/Coin1") as Coin
	var coin2: Coin = level1.get_node("Coins/Coin2") as Coin
	var checkpoint: Checkpoint = level1.checkpoint

	# Collect Coin 1
	coin1.collect()
	assert_true(coin1.is_collected, "Coin 1 collected")
	assert_false(coin2.is_collected, "Coin 2 still uncollected")

	# Hit Checkpoint
	player1.global_position = checkpoint.global_position
	checkpoint._on_body_entered(player1)
	assert_true(checkpoint.is_reached, "Checkpoint reached")
	assert_true(AchievementManager.is_unlocked("checkpoint_reached"), "Checkpoint achievement unlocked")
	assert_true(SaveManager.has_save(SLOT_A), "Autosave triggered on checkpoint")

	# 4. Pause Menu
	var pause_menu: PauseMenu = level1.get_node("PauseMenu") as PauseMenu
	assert_not_null(pause_menu, "Level contains PauseMenu")
	pause_menu.open_pause_menu()
	assert_true(get_tree().paused, "Game tree is paused")

	# 5. Open Settings from Pause Menu & Adjust Volume
	pause_menu.get_settings_button().emit_signal("pressed")
	var pause_settings: SettingsMenu = pause_menu.get_settings_menu()
	assert_true(pause_settings.visible, "Settings overlay opened from pause")

	pause_settings.get_master_slider().value = 0.75
	assert_almost_eq(SettingsManager.get_volume(SettingsManager.BUS_MASTER), 0.75, 0.01)

	pause_settings.get_back_button().emit_signal("pressed")
	assert_false(pause_settings.visible, "Settings overlay closed")

	# 6. Quit to Main Menu
	pause_menu.get_quit_button().emit_signal("pressed")
	assert_false(get_tree().paused, "Tree unpaused upon return to Main Menu")

	# 7. Main Menu after save: Continue should now be enabled
	var menu2: MainMenu = menu_scene.instantiate() as MainMenu
	add_child_autofree(menu2)
	assert_true(menu2.is_continue_enabled(), "Phase 4 E2E: Continue button enabled after save exists")

	# 8. Continue Game: Restore level and state
	var level2: PlatformerDemo = level_scene.instantiate() as PlatformerDemo
	add_child_autofree(level2)

	var err: Error = SaveManager.load_game(SLOT_A)
	assert_eq(err, OK, "Save loaded successfully on continue")

	var coin1_reloaded: Coin = level2.get_node("Coins/Coin1") as Coin
	var coin2_reloaded: Coin = level2.get_node("Coins/Coin2") as Coin

	assert_true(coin1_reloaded.is_collected, "Coin 1 remained collected after continue")
	assert_false(coin2_reloaded.is_collected, "Coin 2 remained uncollected after continue")
	assert_almost_eq(level2.player.global_position.x, checkpoint.global_position.x, 1.0, "Player X restored to checkpoint")
	assert_almost_eq(level2.player.global_position.y, checkpoint.global_position.y, 1.0, "Player Y restored to checkpoint")
	assert_almost_eq(SettingsManager.get_volume(SettingsManager.BUS_MASTER), 0.75, 0.01, "Settings retained across session")
	assert_true(AchievementManager.is_unlocked("checkpoint_reached"), "Achievement remains unlocked")


func test_settings_persist_independently_of_save_slots() -> void:
	# Set non-default settings
	SettingsManager.set_volume(SettingsManager.BUS_MASTER, 0.42)
	SettingsManager.set_volume(SettingsManager.BUS_MUSIC, 0.88)
	var err: Error = SettingsManager.save_settings()
	assert_eq(err, OK)

	# Mutate, create, and delete save slots
	SaveManager.new_game(SLOT_A)
	SaveManager.save_game(SLOT_A)
	SaveManager.load_game(SLOT_A)
	SaveManager.delete_save(SLOT_A)

	# Verify settings in memory are completely untouched
	assert_almost_eq(SettingsManager.get_volume(SettingsManager.BUS_MASTER), 0.42, 0.001)
	assert_almost_eq(SettingsManager.get_volume(SettingsManager.BUS_MUSIC), 0.88, 0.001)

	# Mutate in-memory volume without saving to disk, then reload from disk
	SettingsManager.settings_data.master_volume = 1.0
	SettingsManager.settings_data.music_volume = 1.0
	SettingsManager.load_settings()
	assert_almost_eq(SettingsManager.get_volume(SettingsManager.BUS_MASTER), 0.42, 0.001, "Settings on disk unaffected by save slot operations")
	assert_almost_eq(SettingsManager.get_volume(SettingsManager.BUS_MUSIC), 0.88, 0.001, "Settings on disk unaffected by save slot operations")


func test_achievements_persist_independently_of_save_slots() -> void:
	AchievementManager.unlock("checkpoint_reached")
	AchievementManager.add_progress("coin_collector", 2)

	assert_true(AchievementManager.is_unlocked("checkpoint_reached"))
	assert_eq(AchievementManager.get_progress("coin_collector"), 2)

	# Reset and delete save games
	SaveManager.new_game(SLOT_A)
	SaveManager.save_game(SLOT_A)
	SaveManager.delete_save(SLOT_A)

	# Verify achievements in memory remain intact
	assert_true(AchievementManager.is_unlocked("checkpoint_reached"), "Achievements unaffected by save deletion")
	assert_eq(AchievementManager.get_progress("coin_collector"), 2)

	# Mutate in-memory achievement state without saving, then reload from disk to verify persistence
	AchievementManager.save_data.unlocked_achievements.clear()
	AchievementManager.save_data.progress.clear()
	AchievementManager.load_progress()
	assert_true(AchievementManager.is_unlocked("checkpoint_reached"), "Achievements persist independently on disk")
	assert_eq(AchievementManager.get_progress("coin_collector"), 2)


func test_multiple_save_slots_do_not_clobber_each_other() -> void:
	var level_scene: PackedScene = load(LEVEL_SCENE_PATH)

	# Setup Slot 1 state: Player at (400, 276), Coin 1 collected
	var level1: PlatformerDemo = level_scene.instantiate() as PlatformerDemo
	add_child_autofree(level1)
	level1.player.global_position = Vector2(400, 276)
	(level1.get_node("Coins/Coin1") as Coin).collect()
	SaveManager.save_game(SLOT_A)
	level1.queue_free()

	# Setup Slot 2 state: Player at (80, 280), Coin 2 collected, Coin 1 not collected
	var level2: PlatformerDemo = level_scene.instantiate() as PlatformerDemo
	add_child_autofree(level2)
	level2.player.global_position = Vector2(80, 280)
	(level2.get_node("Coins/Coin2") as Coin).collect()
	SaveManager.save_game(SLOT_B)
	level2.queue_free()

	# Verify both exist
	assert_true(SaveManager.has_save(SLOT_A))
	assert_true(SaveManager.has_save(SLOT_B))

	# Load Slot 1 and verify
	var level_test_a: PlatformerDemo = level_scene.instantiate() as PlatformerDemo
	add_child_autofree(level_test_a)
	SaveManager.load_game(SLOT_A)
	assert_almost_eq(level_test_a.player.global_position.x, 400.0, 1.0, "Slot 1 player position restored")
	assert_true((level_test_a.get_node("Coins/Coin1") as Coin).is_collected, "Slot 1 Coin 1 collected")
	assert_false((level_test_a.get_node("Coins/Coin2") as Coin).is_collected, "Slot 1 Coin 2 uncollected")
	level_test_a.queue_free()

	# Load Slot 2 and verify
	var level_test_b: PlatformerDemo = level_scene.instantiate() as PlatformerDemo
	add_child_autofree(level_test_b)
	SaveManager.load_game(SLOT_B)
	assert_almost_eq(level_test_b.player.global_position.x, 80.0, 1.0, "Slot 2 player position restored")
	assert_false((level_test_b.get_node("Coins/Coin1") as Coin).is_collected, "Slot 2 Coin 1 uncollected")
	assert_true((level_test_b.get_node("Coins/Coin2") as Coin).is_collected, "Slot 2 Coin 2 collected")
	level_test_b.queue_free()

	# Reload Slot 1 again to ensure no cross-contamination
	var level_test_a2: PlatformerDemo = level_scene.instantiate() as PlatformerDemo
	add_child_autofree(level_test_a2)
	SaveManager.load_game(SLOT_A)
	assert_almost_eq(level_test_a2.player.global_position.x, 400.0, 1.0)
	assert_true((level_test_a2.get_node("Coins/Coin1") as Coin).is_collected)
	assert_false((level_test_a2.get_node("Coins/Coin2") as Coin).is_collected)


func test_architecture_decoupling_contracts() -> void:
	# 1. Player contract: joins "saveable", implements contract, no UI or SaveManager properties
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	var player: Player = player_scene.instantiate() as Player
	add_child_autofree(player)

	assert_true(player.is_in_group("saveable"), "Player must be in saveable group")
	assert_true(player.has_method("get_save_data"), "Player implements get_save_data")
	assert_true(player.has_method("apply_save_data"), "Player implements apply_save_data")
	assert_false("hud" in player, "Player must not reference HUD")
	assert_false("save_manager" in player, "Player must not reference SaveManager directly")

	# 2. Coin contract
	var coin_scene: PackedScene = load(COIN_SCENE_PATH)
	var coin: Coin = coin_scene.instantiate() as Coin
	add_child_autofree(coin)
	assert_true(coin.is_in_group("saveable"), "Coin must be in saveable group")

	# 3. Checkpoint contract
	var cp_scene: PackedScene = load(CHECKPOINT_SCENE_PATH)
	var cp: Checkpoint = cp_scene.instantiate() as Checkpoint
	add_child_autofree(cp)
	assert_true(cp.is_in_group("saveable"), "Checkpoint must be in saveable group")

	# 4. HUD contract: reactive only, no authoritative player reference
	var hud_scene: PackedScene = load(HUD_SCENE_PATH)
	var hud: HUD = hud_scene.instantiate() as HUD
	add_child_autofree(hud)
	assert_false("player" in hud, "HUD must not reference Player")
	assert_false("character" in hud, "HUD must not reference Character")

	# 5. Menus contract: no direct player or level references
	var pause_scene: PackedScene = load(PAUSE_MENU_SCENE_PATH)
	var pause: PauseMenu = pause_scene.instantiate() as PauseMenu
	add_child_autofree(pause)
	assert_false("player" in pause, "PauseMenu must not reference Player")
	assert_false("level" in pause, "PauseMenu must not reference Level")

	var menu_scene: PackedScene = load(MAIN_MENU_SCENE_PATH)
	var menu: MainMenu = menu_scene.instantiate() as MainMenu
	add_child_autofree(menu)
	assert_false("player" in menu, "MainMenu must not reference Player")
	assert_false("level" in menu, "MainMenu must not reference Level")
