extends GutTest

## Unit tests for reactive AchievementPopup toast overlay and FIFO queuing.

const POPUP_SCENE_PATH: String = "res://scenes/ui/achievement_popup/achievement_popup.tscn"


func test_popup_initial_state() -> void:
	var scene: PackedScene = load(POPUP_SCENE_PATH)
	assert_not_null(scene, "AchievementPopup scene should load")

	var popup: AchievementPopup = scene.instantiate() as AchievementPopup
	add_child_autofree(popup)

	assert_false(popup.is_toast_visible(), "Toast panel should initially be hidden")
	assert_false(popup.is_showing, "is_showing should be false initially")
	assert_eq(popup.get_queue_count(), 0, "Queue should be empty initially")


func test_single_achievement_unlock_displays() -> void:
	var scene: PackedScene = load(POPUP_SCENE_PATH)
	var popup: AchievementPopup = scene.instantiate() as AchievementPopup
	add_child_autofree(popup)

	EventBus.achievement_unlocked.emit("ach_1", "Coin Master", "Collect all coins")

	assert_true(popup.is_showing, "Popup should be active")
	assert_true(popup.is_toast_visible(), "Toast panel should become visible")
	assert_eq(popup.get_displayed_title(), "Coin Master", "Title should match unlocked achievement")
	assert_eq(popup.get_displayed_description(), "Collect all coins", "Description should match")
	assert_eq(popup.get_queue_count(), 0, "Queue count should be 0 since it is currently displaying")


func test_rapid_sequential_unlocks_queue_without_overlap() -> void:
	var scene: PackedScene = load(POPUP_SCENE_PATH)
	var popup: AchievementPopup = scene.instantiate() as AchievementPopup
	add_child_autofree(popup)

	# Unlock first achievement
	EventBus.achievement_unlocked.emit("ach_1", "First Unlock", "Did thing one")
	assert_true(popup.is_showing)
	assert_eq(popup.get_displayed_title(), "First Unlock")
	assert_eq(popup.get_queue_count(), 0)

	# Rapidly unlock second achievement while first is still showing
	EventBus.achievement_unlocked.emit("ach_2", "Second Unlock", "Did thing two")

	# Verify second achievement is queued and first achievement is STILL showing (no overlap / clobber)
	assert_eq(popup.get_queue_count(), 1, "Second achievement must be queued")
	assert_eq(popup.get_displayed_title(), "First Unlock", "First achievement should still be on screen")

	# Dismiss the first toast (simulating time expiry or dismiss)
	popup.dismiss_current()

	# Verify second achievement is now displayed and queue is empty
	assert_true(popup.is_showing, "Popup should remain showing for second achievement")
	assert_true(popup.is_toast_visible(), "Toast panel should remain visible")
	assert_eq(popup.get_displayed_title(), "Second Unlock", "Second achievement should now be visible")
	assert_eq(popup.get_displayed_description(), "Did thing two", "Second description should match")
	assert_eq(popup.get_queue_count(), 0, "Queue should now be empty")

	# Dismiss the second toast
	popup.dismiss_current()
	assert_false(popup.is_showing, "Popup should no longer be showing after queue drains")
	assert_false(popup.is_toast_visible(), "Toast panel should be hidden")


func test_decoupling_rules() -> void:
	var scene: PackedScene = load(POPUP_SCENE_PATH)
	var popup: AchievementPopup = scene.instantiate() as AchievementPopup
	add_child_autofree(popup)

	assert_false("player" in popup, "AchievementPopup must not hold a direct player reference")
	assert_false("level" in popup, "AchievementPopup must not hold a direct level reference")
