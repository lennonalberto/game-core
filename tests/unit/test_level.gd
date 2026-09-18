extends GutTest

## Unit tests for PlatformerDemo level, Checkpoint trigger, SaveManager level_id recording,
## and end-to-end checkpoint save/reload cycle.

const LEVEL_SCENE_PATH: String = "res://scenes/levels/platformer_demo/platformer_demo.tscn"
const CHECKPOINT_SCENE_PATH: String = "res://scenes/entities/checkpoint/checkpoint.tscn"
const PLAYER_SCENE_PATH: String = "res://scenes/entities/player/player.tscn"
const TEST_SLOT: int = 90


func before_each() -> void:
	AchievementManager.reset_all_achievements()
	if SaveManager.has_save(TEST_SLOT):
		SaveManager.delete_save(TEST_SLOT)
	SaveManager.current_slot = TEST_SLOT
	SaveManager.current_level_id = ""
	SaveManager.current_save = null


func after_each() -> void:
	AchievementManager.reset_all_achievements()
	if SaveManager.has_save(TEST_SLOT):
		SaveManager.delete_save(TEST_SLOT)


func test_platformer_demo_scene_structure() -> void:
	var level_scene: PackedScene = load(LEVEL_SCENE_PATH)
	assert_not_null(level_scene, "PlatformerDemo scene should load successfully")

	var level: PlatformerDemo = level_scene.instantiate() as PlatformerDemo
	add_child_autofree(level)

	assert_not_null(level.player, "Level should have Player instance")
	assert_not_null(level.checkpoint, "Level should have Checkpoint instance")
	assert_true(level.is_in_group("saveable"), "Level must belong to 'saveable' group")
	assert_eq(level.level_id, "platformer_demo", "Default level_id should be 'platformer_demo'")

	var coins_container: Node2D = level.get_node_or_null("Coins") as Node2D
	assert_not_null(coins_container, "Level should have Coins container")
	assert_eq(coins_container.get_child_count(), 3, "Level should have 3 coins placed")


func test_level_started_records_level_id_in_save_manager() -> void:
	watch_signals(EventBus)

	var level_scene: PackedScene = load(LEVEL_SCENE_PATH)
	var level: PlatformerDemo = level_scene.instantiate() as PlatformerDemo
	add_child_autofree(level)

	assert_signal_emitted_with_parameters(EventBus, "level_started", ["platformer_demo"])
	assert_eq(SaveManager.current_level_id, "platformer_demo", "SaveManager should update current_level_id from EventBus.level_started")


func test_checkpoint_trigger_and_achievement() -> void:
	var cp_scene: PackedScene = load(CHECKPOINT_SCENE_PATH)
	var cp: Checkpoint = cp_scene.instantiate() as Checkpoint
	add_child_autofree(cp)

	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	var player: Player = player_scene.instantiate() as Player
	add_child_autofree(player)

	assert_false(cp.is_reached, "Checkpoint should not be active initially")
	assert_false(AchievementManager.is_unlocked("checkpoint_reached"), "Achievement should start locked")

	watch_signals(EventBus)
	cp._on_body_entered(player)

	assert_true(cp.is_reached, "Checkpoint should be marked as reached")
	assert_signal_emitted(EventBus, "checkpoint_reached", "Entering checkpoint should emit EventBus.checkpoint_reached")
	assert_true(AchievementManager.is_unlocked("checkpoint_reached"), "AchievementManager should unlock checkpoint_reached")


func test_definition_of_done_full_cycle() -> void:
	# 1. Instantiate level and add to scene tree
	var level_scene: PackedScene = load(LEVEL_SCENE_PATH)
	var level: PlatformerDemo = level_scene.instantiate() as PlatformerDemo
	add_child_autofree(level)

	assert_eq(SaveManager.current_level_id, "platformer_demo")

	var player: Player = level.player
	var coins_node: Node2D = level.get_node("Coins")
	var coin1: Coin = coins_node.get_node("Coin1") as Coin
	var coin2: Coin = coins_node.get_node("Coin2") as Coin
	var checkpoint: Checkpoint = level.checkpoint

	# 2. Collect Coin 1
	coin1.collect()
	assert_true(coin1.is_collected, "Coin1 should be collected")
	assert_false(coin2.is_collected, "Coin2 should remain uncollected")

	# 3. Move player to checkpoint and trigger checkpoint save
	player.global_position = checkpoint.global_position
	checkpoint._on_body_entered(player)

	assert_true(checkpoint.is_reached, "Checkpoint must be reached")
	assert_true(SaveManager.has_save(TEST_SLOT), "Save file should exist on disk")

	# 4. Verify save file metadata on disk contains level_id
	var meta: Dictionary = SaveManager.get_save_metadata(TEST_SLOT)
	assert_true(meta.get("exists", false), "Save metadata exists")
	assert_eq(meta.get("level_id"), "platformer_demo", "Save file must record level_id")

	# 5. Mutate state in memory (simulating quitting or restarting)
	player.global_position = Vector2.ZERO
	player.velocity = Vector2.ZERO
	coin1.is_collected = false
	coin1.visible = true

	# 6. Load game save
	var load_err: Error = SaveManager.load_game(TEST_SLOT)
	assert_eq(load_err, OK, "SaveManager.load_game should succeed")

	# 7. Assert state restored accurately:
	# - level_id
	assert_eq(SaveManager.current_save.level_id, "platformer_demo", "level_id restored")
	# - player position restored to checkpoint position
	assert_eq(player.global_position, checkpoint.global_position, "Player position restored to checkpoint")
	# - collected coin restored as collected and deactivated
	assert_true(coin1.is_collected, "Coin1 should be restored as collected")
	assert_false(coin1.visible, "Coin1 should be deactivated after load")
	# - uncollected coin remains uncollected
	assert_false(coin2.is_collected, "Coin2 should remain uncollected")
