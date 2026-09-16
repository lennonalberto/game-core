extends GutTest

## Unit tests for AchievementManager covering definition loading, progress accumulation,
## single-fire unlock signals, persistence round-tripping, and EventBus signal integration.

const TEST_PATH: String = "user://test_achievements_temp.tres"


func before_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	AchievementManager.reset_all_achievements()


func after_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
	AchievementManager.reset_all_achievements()


func test_definitions_loaded_at_startup() -> void:
	assert_gt(AchievementManager.definitions.size(), 0, "AchievementManager should load definitions from disk")
	assert_true(AchievementManager.definitions.has("first_step"), "Should load 'first_step' achievement")
	assert_true(AchievementManager.definitions.has("coin_collector"), "Should load 'coin_collector' achievement")
	assert_true(AchievementManager.definitions.has("checkpoint_reached"), "Should load 'checkpoint_reached' achievement")

	var coin_def: AchievementDefinition = AchievementManager.get_definition("coin_collector")
	assert_not_null(coin_def, "coin_collector definition should exist")
	assert_eq(coin_def.target_progress, 5, "coin_collector target_progress should be 5")
	assert_eq(coin_def.title, "Treasure Hunter", "coin_collector title should be 'Treasure Hunter'")


func test_unlock_achievement_and_single_fire() -> void:
	watch_signals(EventBus)

	var first_unlock: bool = AchievementManager.unlock("first_step")
	assert_true(first_unlock, "First unlock call should return true")
	assert_true(AchievementManager.is_unlocked("first_step"), "first_step should be marked unlocked")
	assert_signal_emitted(EventBus, "achievement_unlocked", "achievement_unlocked signal should be emitted")
	assert_signal_emit_count(EventBus, "achievement_unlocked", 1, "achievement_unlocked should emit exactly once")

	# Second unlock call should be ignored and not re-emit signal
	var second_unlock: bool = AchievementManager.unlock("first_step")
	assert_false(second_unlock, "Subsequent unlock call should return false")
	assert_signal_emit_count(EventBus, "achievement_unlocked", 1, "achievement_unlocked should not emit a second time")


func test_progress_accumulation_and_auto_unlock() -> void:
	watch_signals(EventBus)

	# Add 2 coins progress
	AchievementManager.add_progress("coin_collector", 2)
	assert_eq(AchievementManager.get_progress("coin_collector"), 2, "Progress should be 2")
	assert_false(AchievementManager.is_unlocked("coin_collector"), "Should not be unlocked yet")
	assert_signal_emitted(EventBus, "achievement_progress_updated", "Progress updated signal should be emitted")
	assert_signal_emit_count(EventBus, "achievement_unlocked", 0, "Should not emit unlock signal yet")

	# Add 3 more coins (total 5 = target)
	AchievementManager.add_progress("coin_collector", 3)
	assert_eq(AchievementManager.get_progress("coin_collector"), 5, "Progress should be 5")
	assert_true(AchievementManager.is_unlocked("coin_collector"), "Should automatically unlock at target")
	assert_signal_emitted(EventBus, "achievement_unlocked", "Unlock signal should be emitted upon meeting target")


func test_persistence_round_trip() -> void:
	AchievementManager.add_progress("coin_collector", 3)
	AchievementManager.unlock("first_step")

	var err: Error = AchievementManager.save_progress(TEST_PATH)
	assert_eq(err, OK, "Saving achievement progress should return OK")
	assert_true(FileAccess.file_exists(TEST_PATH), "Achievement save file should exist on disk")

	# Clear active state
	AchievementManager.save_data = AchievementSaveData.create_default()
	assert_false(AchievementManager.is_unlocked("first_step"), "Should be reset in memory")

	# Reload from file
	AchievementManager.load_progress(TEST_PATH)
	assert_true(AchievementManager.is_unlocked("first_step"), "first_step should be restored as unlocked")
	assert_eq(AchievementManager.get_progress("coin_collector"), 3, "coin_collector progress should be restored as 3")


func test_event_bus_signal_integration() -> void:
	# Emit coin_collected and verify progress advances
	EventBus.coin_collected.emit(1)
	assert_eq(AchievementManager.get_progress("coin_collector"), 1, "Emitting coin_collected should advance coin_collector")

	# Emit checkpoint_reached and verify unlock
	EventBus.checkpoint_reached.emit("cp_01", Vector2(100, 100))
	assert_true(AchievementManager.is_unlocked("checkpoint_reached"), "Emitting checkpoint_reached should unlock achievement")

	# Emit player_jumped and verify unlock
	EventBus.player_jumped.emit()
	assert_true(AchievementManager.is_unlocked("first_step"), "Emitting player_jumped should unlock first_step")


func test_missing_file_graceful_fallback() -> void:
	var non_existent_path: String = "user://missing_achiev_987654.tres"
	if FileAccess.file_exists(non_existent_path):
		DirAccess.remove_absolute(non_existent_path)

	AchievementManager.load_progress(non_existent_path)
	assert_not_null(AchievementManager.save_data, "AchievementSaveData should be initialized on missing file")
	assert_false(AchievementManager.is_unlocked("first_step"), "New default state should have no unlocks")

	if FileAccess.file_exists(non_existent_path):
		DirAccess.remove_absolute(non_existent_path)
