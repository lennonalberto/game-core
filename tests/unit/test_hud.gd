extends GutTest

## Unit tests for reactive HUD overlay, EventBus decoupled updates, and display queries.

const HUD_SCENE_PATH: String = "res://scenes/ui/hud/hud.tscn"


func test_hud_scene_structure_and_initial_state() -> void:
	var hud_scene: PackedScene = load(HUD_SCENE_PATH)
	assert_not_null(hud_scene, "HUD scene should load successfully")

	var hud: HUD = hud_scene.instantiate() as HUD
	add_child_autofree(hud)

	assert_not_null(hud.health_bar, "HUD should contain HealthBar")
	assert_not_null(hud.health_label, "HUD should contain HealthLabel")
	assert_not_null(hud.coin_label, "HUD should contain CoinLabel")
	assert_not_null(hud.checkpoint_banner, "HUD should contain CheckpointBanner")

	assert_eq(hud.get_displayed_health(), 100, "Initial displayed health should be 100")
	assert_eq(hud.get_displayed_max_health(), 100, "Initial displayed max health should be 100")
	assert_eq(hud.get_displayed_coins(), 0, "Initial displayed coins should be 0")
	assert_false(hud.checkpoint_banner.visible, "Checkpoint banner should be hidden initially")


func test_reactive_health_updates() -> void:
	var hud_scene: PackedScene = load(HUD_SCENE_PATH)
	var hud: HUD = hud_scene.instantiate() as HUD
	add_child_autofree(hud)

	EventBus.player_health_changed.emit(75, 100)
	assert_eq(hud.get_displayed_health(), 75, "Health should reactively update to 75")
	assert_eq(hud.health_bar.value, 75.0, "HealthBar value should match")
	assert_eq(hud.health_label.text, "75 / 100", "HealthLabel text should display '75 / 100'")

	# Update with modified max health
	EventBus.player_health_changed.emit(40, 150)
	assert_eq(hud.get_displayed_health(), 40, "Health should update to 40")
	assert_eq(hud.get_displayed_max_health(), 150, "Max health should update to 150")
	assert_eq(hud.health_bar.max_value, 150.0, "HealthBar max_value should update to 150")
	assert_eq(hud.health_label.text, "40 / 150", "HealthLabel text should display '40 / 150'")


func test_reactive_coin_and_score_updates() -> void:
	var hud_scene: PackedScene = load(HUD_SCENE_PATH)
	var hud: HUD = hud_scene.instantiate() as HUD
	add_child_autofree(hud)

	EventBus.coin_collected.emit(1)
	assert_eq(hud.get_displayed_coins(), 1, "Coins should increment to 1")
	assert_eq(hud.coin_label.text, "1", "CoinLabel should show '1'")

	EventBus.coin_collected.emit(4)
	assert_eq(hud.get_displayed_coins(), 5, "Coins should accumulate to 5")
	assert_eq(hud.coin_label.text, "5", "CoinLabel should show '5'")

	EventBus.score_changed.emit(350)
	assert_eq(hud.get_displayed_score(), 350, "Score should update to 350")
	assert_eq(hud.score_label.text, "350", "ScoreLabel should show '350'")


func test_checkpoint_banner_visibility_on_signal() -> void:
	var hud_scene: PackedScene = load(HUD_SCENE_PATH)
	var hud: HUD = hud_scene.instantiate() as HUD
	add_child_autofree(hud)

	assert_false(hud.checkpoint_banner.visible, "Banner should start hidden")

	EventBus.checkpoint_reached.emit("checkpoint_1", Vector2(200, 300))
	assert_true(hud.checkpoint_banner.visible, "Banner should become visible upon checkpoint_reached")


func test_level_started_resets_counters() -> void:
	var hud_scene: PackedScene = load(HUD_SCENE_PATH)
	var hud: HUD = hud_scene.instantiate() as HUD
	add_child_autofree(hud)

	EventBus.coin_collected.emit(3)
	EventBus.score_changed.emit(100)
	assert_eq(hud.get_displayed_coins(), 3)
	assert_eq(hud.get_displayed_score(), 100)

	EventBus.level_started.emit("new_level")
	assert_eq(hud.get_displayed_coins(), 0, "Coins should reset on level_started")
	assert_eq(hud.get_displayed_score(), 0, "Score should reset on level_started")
	assert_eq(hud.coin_label.text, "0")


func test_decoupling_no_direct_player_reference() -> void:
	var hud_scene: PackedScene = load(HUD_SCENE_PATH)
	var hud: HUD = hud_scene.instantiate() as HUD
	add_child_autofree(hud)

	assert_false("player" in hud, "HUD must not have an authoritative player reference")
	assert_false("character" in hud, "HUD must not reference character directly")
