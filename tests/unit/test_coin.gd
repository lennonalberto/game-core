extends GutTest

## Unit tests for Coin pickup entity, EventBus decoupling, Saveable contract,
## and end-to-end Achievement integration.

const COIN_SCENE_PATH: String = "res://scenes/entities/pickups/coin.tscn"
const PLAYER_SCENE_PATH: String = "res://scenes/entities/player/player.tscn"
const TEST_SLOT: int = 95


func before_each() -> void:
	AchievementManager.reset_all_achievements()
	if SaveManager.has_save(TEST_SLOT):
		SaveManager.delete_save(TEST_SLOT)


func after_each() -> void:
	AchievementManager.reset_all_achievements()
	if SaveManager.has_save(TEST_SLOT):
		SaveManager.delete_save(TEST_SLOT)


func test_coin_scene_structure() -> void:
	var coin_scene: PackedScene = load(COIN_SCENE_PATH)
	assert_not_null(coin_scene, "Coin scene should load successfully")

	var coin: Coin = coin_scene.instantiate() as Coin
	add_child_autofree(coin)

	assert_not_null(coin.collision_shape, "Coin should have CollisionShape2D")
	assert_not_null(coin.sprite, "Coin should have Sprite2D")
	assert_not_null(coin.animation_player, "Coin should have AnimationPlayer")
	assert_true(coin.is_in_group("saveable"), "Coin must belong to 'saveable' group")
	assert_eq(coin.value, 1, "Default coin value should be 1")
	assert_false(coin.is_collected, "Coin should not be collected initially")
	assert_true(coin.visible, "Coin should be visible initially")


func test_coin_collected_on_player_overlap() -> void:
	var coin_scene: PackedScene = load(COIN_SCENE_PATH)
	var coin: Coin = coin_scene.instantiate() as Coin
	add_child_autofree(coin)

	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	var player: Player = player_scene.instantiate() as Player
	add_child_autofree(player)

	watch_signals(EventBus)
	coin._on_body_entered(player)

	assert_signal_emitted_with_parameters(EventBus, "coin_collected", [1])
	assert_true(coin.is_collected, "Coin should be marked as collected")
	assert_false(coin.visible, "Coin should be hidden after collection")

	# Subsequent triggers should not emit duplicate signals
	coin._on_body_entered(player)
	assert_signal_emit_count(EventBus, "coin_collected", 1, "Should not emit duplicate collection signals")


func test_non_player_overlap_ignored() -> void:
	var coin_scene: PackedScene = load(COIN_SCENE_PATH)
	var coin: Coin = coin_scene.instantiate() as Coin
	add_child_autofree(coin)

	var obstacle: StaticBody2D = StaticBody2D.new()
	add_child_autofree(obstacle)

	watch_signals(EventBus)
	coin._on_body_entered(obstacle)

	assert_signal_not_emitted(EventBus, "coin_collected", "Non-player bodies should not trigger collection")
	assert_false(coin.is_collected, "Coin should remain uncollected")
	assert_true(coin.visible, "Coin should remain visible")


func test_achievement_progress_and_unlock_end_to_end() -> void:
	var coin_scene: PackedScene = load(COIN_SCENE_PATH)
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	var player: Player = player_scene.instantiate() as Player
	add_child_autofree(player)

	assert_eq(AchievementManager.get_progress("coin_collector"), 0, "Initial progress should be 0")
	assert_false(AchievementManager.is_unlocked("coin_collector"), "Achievement should start locked")

	# Collect first coin
	var coin1: Coin = coin_scene.instantiate() as Coin
	add_child_autofree(coin1)
	coin1._on_body_entered(player)

	assert_eq(AchievementManager.get_progress("coin_collector"), 1, "Progress should increment to 1")
	assert_false(AchievementManager.is_unlocked("coin_collector"), "Achievement should still be locked at 1/5")

	watch_signals(EventBus)

	# Collect 4 more coins to reach target of 5
	for i in range(4):
		var coin: Coin = coin_scene.instantiate() as Coin
		add_child_autofree(coin)
		coin._on_body_entered(player)

	assert_eq(AchievementManager.get_progress("coin_collector"), 5, "Progress should reach target of 5")
	assert_true(AchievementManager.is_unlocked("coin_collector"), "Achievement should unlock upon reaching target")
	assert_signal_emitted(EventBus, "achievement_unlocked", "EventBus.achievement_unlocked should fire when unlocking")


func test_saveable_contract_and_persistence() -> void:
	var coin_scene: PackedScene = load(COIN_SCENE_PATH)
	var coin: Coin = coin_scene.instantiate() as Coin
	coin.save_id = "coin_test_01"
	add_child_autofree(coin)

	var save_data: Dictionary = coin.get_save_data()
	assert_eq(save_data.get("is_collected"), false, "Initial save data should record not collected")

	# Collect coin and save
	coin.collect()
	assert_true(coin.is_collected)

	SaveManager.new_game(TEST_SLOT)
	var save_err: Error = SaveManager.save_game(TEST_SLOT)
	assert_eq(save_err, OK, "SaveManager.save_game should succeed")

	# Reset coin in memory
	coin.is_collected = false
	coin.visible = true

	# Restore from save
	var load_err: Error = SaveManager.load_game(TEST_SLOT)
	assert_eq(load_err, OK, "SaveManager.load_game should succeed")
	assert_true(coin.is_collected, "SaveManager should restore is_collected=true")
	assert_false(coin.visible, "Coin should be deactivated/hidden after loading collected state")
