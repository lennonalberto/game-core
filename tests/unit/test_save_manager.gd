extends GutTest

## Unit tests for SaveManager covering SaveData round-tripping, "saveable" group
## contracts, slot isolation, graceful corruption handling, and EventBus signals.

const TEST_SLOTS: Array[int] = [10, 11, 20, 21, 30, 40, 888]
var DummySaveableScript = load("res://tests/helpers/dummy_saveable.gd")


func before_each() -> void:
	_cleanup_test_slots()
	SaveManager.current_save = null
	SaveManager.current_slot = 1


func after_each() -> void:
	_cleanup_test_slots()


func _cleanup_test_slots() -> void:
	for slot in TEST_SLOTS:
		if SaveManager.has_save(slot):
			SaveManager.delete_save(slot)


func test_save_and_load_round_trip() -> void:
	SaveManager.new_game(10)
	SaveManager.current_save.level_id = "level_01"
	SaveManager.current_save.playtime = 123.45
	SaveManager.current_save.collected_items = ["coin_1", "coin_2", "key_gold"]
	SaveManager.current_save.player_state = {"health": 80, "position": Vector2(100, 200)}

	var err: Error = SaveManager.save_game(10)
	assert_eq(err, OK, "save_game should return OK")
	assert_true(SaveManager.has_save(10), "Save file should exist after saving")

	# Clear current memory state
	SaveManager.current_save = null

	# Load back
	var load_err: Error = SaveManager.load_game(10)
	assert_eq(load_err, OK, "load_game should return OK")
	assert_not_null(SaveManager.current_save, "current_save should not be null after loading")
	assert_eq(SaveManager.current_save.level_id, "level_01", "level_id should round-trip accurately")
	assert_almost_eq(SaveManager.current_save.playtime, 123.45, 0.01, "playtime should round-trip accurately")
	assert_eq(SaveManager.current_save.collected_items.size(), 3, "collected_items size should match")
	assert_true(SaveManager.current_save.collected_items.has("key_gold"), "collected_items should contain saved keys")
	assert_eq(SaveManager.current_save.player_state.get("health"), 80, "player_state health should match")


func test_saveable_node_contract_collected_and_restored() -> void:
	var dummy = DummySaveableScript.new()
	dummy.name = "TestDummyNode"
	dummy.save_id = "dummy_hero"
	dummy.health = 55
	dummy.coins = 12
	dummy.custom_tag = "custom_val"
	add_child_autofree(dummy)

	var save_err: Error = SaveManager.save_game(11)
	assert_eq(save_err, OK, "Saving game with saveable node should succeed")
	assert_true(SaveManager.current_save.node_states.has("dummy_hero"), "SaveData.node_states should contain key 'dummy_hero'")

	# Mutate dummy's values
	dummy.health = 10
	dummy.coins = 0
	dummy.custom_tag = "altered"

	# Load game back
	var load_err: Error = SaveManager.load_game(11)
	assert_eq(load_err, OK, "Loading game should succeed")

	assert_eq(dummy.health, 55, "Dummy health should be restored to 55")
	assert_eq(dummy.coins, 12, "Dummy coins should be restored to 12")
	assert_eq(dummy.custom_tag, "custom_val", "Dummy custom_tag should be restored")


func test_multiple_slots_do_not_clobber_each_other() -> void:
	var dummy = DummySaveableScript.new()
	dummy.save_id = "multi_slot_node"
	add_child_autofree(dummy)

	# Save slot 20 with health 100
	dummy.health = 100
	SaveManager.save_game(20)

	# Save slot 21 with health 200
	dummy.health = 200
	SaveManager.save_game(21)

	# Load slot 20 and verify health is 100
	SaveManager.load_game(20)
	assert_eq(dummy.health, 100, "Slot 20 should have health 100")

	# Load slot 21 and verify health is 200
	SaveManager.load_game(21)
	assert_eq(dummy.health, 200, "Slot 21 should have health 200")


func test_missing_file_fails_gracefully() -> void:
	assert_false(SaveManager.has_save(999), "Non-existent slot 999 should not have save")
	var err: Error = SaveManager.load_game(999)
	assert_eq(err, ERR_FILE_NOT_FOUND, "Loading missing slot should return ERR_FILE_NOT_FOUND")


func test_corrupt_file_fails_gracefully() -> void:
	# Write corrupt garbage data into slot 888 file
	var corrupt_path: String = SaveManager.get_save_file_path(888)
	var f = FileAccess.open(corrupt_path, FileAccess.WRITE)
	assert_not_null(f, "FileAccess should be able to create corrupt file")
	f.store_string("THIS IS COMPLETELY CORRUPTED TEXT NOT A VALID GODOT RESOURCE")
	f.close()

	assert_true(SaveManager.has_save(888), "Corrupt file should exist on disk")

	# Attempt to load corrupt file
	var err: Error = SaveManager.load_game(888)
	assert_ne(err, OK, "Loading corrupted save file should return an error code")
	assert_eq(err, ERR_FILE_CORRUPT, "Loading corrupted save file should return ERR_FILE_CORRUPT")

	# Mark the expected corruption parsing errors as handled so GUT does not fail the test
	var tracker = GutUtils.get_error_tracker()
	if tracker != null:
		for tracked_err in tracker.get_current_test_errors():
			tracked_err.handled = true


func test_metadata_reading() -> void:
	SaveManager.new_game(30)
	SaveManager.current_save.level_id = "dungeon_01"
	SaveManager.current_save.playtime = 450.0
	SaveManager.save_game(30)

	var meta: Dictionary = SaveManager.get_save_metadata(30)
	assert_true(meta.get("exists", false), "Metadata should report exists = true")
	assert_eq(meta.get("slot"), 30, "Metadata slot should match")
	assert_eq(meta.get("level_id"), "dungeon_01", "Metadata level_id should match")
	assert_almost_eq(meta.get("playtime"), 450.0, 0.01, "Metadata playtime should match")

	var missing_meta: Dictionary = SaveManager.get_save_metadata(999)
	assert_false(missing_meta.get("exists", true), "Non-existent slot metadata should report exists = false")


func test_save_signals_emitted() -> void:
	watch_signals(EventBus)

	SaveManager.new_game(40)
	SaveManager.save_game(40)

	assert_signal_emitted(EventBus, "save_started", "EventBus.save_started should be emitted")
	assert_signal_emitted_with_parameters(EventBus, "save_completed", [40])

	SaveManager.load_game(40)

	assert_signal_emitted(EventBus, "load_started", "EventBus.load_started should be emitted")
	assert_signal_emitted_with_parameters(EventBus, "load_completed", [40])
