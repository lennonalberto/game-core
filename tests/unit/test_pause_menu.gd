extends GutTest

## Unit tests for PauseMenu overlay, scene tree pausing, interactive buttons, and decoupling.

const PAUSE_MENU_SCENE_PATH: String = "res://scenes/ui/pause_menu/pause_menu.tscn"


func after_each() -> void:
	# Ensure tree pause state is reset between tests
	get_tree().paused = false


func test_pause_menu_initial_state() -> void:
	var scene: PackedScene = load(PAUSE_MENU_SCENE_PATH)
	assert_not_null(scene, "PauseMenu scene should load")

	var pause_menu: PauseMenu = scene.instantiate() as PauseMenu
	add_child_autofree(pause_menu)

	assert_false(pause_menu.visible, "PauseMenu should initially be hidden")
	assert_false(get_tree().paused, "Scene tree should initially not be paused")
	assert_false(pause_menu.is_paused(), "is_paused() should return false initially")
	assert_not_null(pause_menu.get_resume_button(), "Resume button should be present")
	assert_not_null(pause_menu.get_settings_button(), "Settings button should be present")
	assert_not_null(pause_menu.get_quit_button(), "Quit button should be present")


func test_open_pause_menu_freezes_tree_and_shows_ui() -> void:
	var scene: PackedScene = load(PAUSE_MENU_SCENE_PATH)
	var pause_menu: PauseMenu = scene.instantiate() as PauseMenu
	add_child_autofree(pause_menu)
	watch_signals(EventBus)

	pause_menu.open_pause_menu()

	assert_true(get_tree().paused, "Scene tree should be paused")
	assert_true(pause_menu.visible, "PauseMenu should be visible")
	assert_true(pause_menu.is_paused(), "is_paused() should return true")
	assert_signal_emitted_with_parameters(EventBus, "game_paused", [true])
	assert_true(pause_menu.get_resume_button().has_focus(), "Resume button should grab focus")


func test_close_pause_menu_unfreezes_tree_and_hides_ui() -> void:
	var scene: PackedScene = load(PAUSE_MENU_SCENE_PATH)
	var pause_menu: PauseMenu = scene.instantiate() as PauseMenu
	add_child_autofree(pause_menu)

	pause_menu.open_pause_menu()
	assert_true(get_tree().paused)

	watch_signals(EventBus)
	watch_signals(pause_menu)

	pause_menu.close_pause_menu()

	assert_false(get_tree().paused, "Scene tree should be unpaused")
	assert_false(pause_menu.visible, "PauseMenu should be hidden")
	assert_false(pause_menu.is_paused(), "is_paused() should return false")
	assert_signal_emitted_with_parameters(EventBus, "game_paused", [false])
	assert_signal_emitted(pause_menu, "resume_requested")


func test_toggle_pause() -> void:
	var scene: PackedScene = load(PAUSE_MENU_SCENE_PATH)
	var pause_menu: PauseMenu = scene.instantiate() as PauseMenu
	add_child_autofree(pause_menu)

	pause_menu.toggle_pause()
	assert_true(pause_menu.is_paused(), "First toggle should pause")
	assert_true(get_tree().paused)

	pause_menu.toggle_pause()
	assert_false(pause_menu.is_paused(), "Second toggle should resume")
	assert_false(get_tree().paused)


func test_resume_button_press() -> void:
	var scene: PackedScene = load(PAUSE_MENU_SCENE_PATH)
	var pause_menu: PauseMenu = scene.instantiate() as PauseMenu
	add_child_autofree(pause_menu)

	pause_menu.open_pause_menu()
	assert_true(pause_menu.is_paused())

	watch_signals(pause_menu)
	pause_menu.get_resume_button().emit_signal("pressed")

	assert_false(get_tree().paused, "Pressing resume button should unpause")
	assert_false(pause_menu.visible, "Pressing resume button should hide menu")
	assert_signal_emitted(pause_menu, "resume_requested")


func test_settings_button_press() -> void:
	var scene: PackedScene = load(PAUSE_MENU_SCENE_PATH)
	var pause_menu: PauseMenu = scene.instantiate() as PauseMenu
	add_child_autofree(pause_menu)

	watch_signals(pause_menu)
	pause_menu.get_settings_button().emit_signal("pressed")

	assert_signal_emitted(pause_menu, "settings_requested")


func test_quit_button_press() -> void:
	var scene: PackedScene = load(PAUSE_MENU_SCENE_PATH)
	var pause_menu: PauseMenu = scene.instantiate() as PauseMenu
	add_child_autofree(pause_menu)

	pause_menu.open_pause_menu()
	assert_true(get_tree().paused)

	watch_signals(pause_menu)
	pause_menu.get_quit_button().emit_signal("pressed")

	assert_false(get_tree().paused, "Quit button must unpause the tree")
	assert_false(pause_menu.visible, "Quit button should hide the menu")
	assert_signal_emitted(pause_menu, "quit_requested")


func test_gameplay_frozen_while_pause_menu_interactive() -> void:
	var scene: PackedScene = load(PAUSE_MENU_SCENE_PATH)
	var pause_menu: PauseMenu = scene.instantiate() as PauseMenu
	add_child_autofree(pause_menu)

	var dummy_gameplay_node: Node = Node.new()
	dummy_gameplay_node.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child_autofree(dummy_gameplay_node)

	# Before pause: both can process
	assert_true(dummy_gameplay_node.can_process(), "Gameplay node can process before pause")
	assert_true(pause_menu.can_process(), "PauseMenu can process")

	pause_menu.open_pause_menu()

	# While paused: gameplay node cannot process, but pause menu can process
	assert_false(dummy_gameplay_node.can_process(), "Gameplay node is frozen while paused")
	assert_true(pause_menu.can_process(), "PauseMenu remains interactive while paused")

	# Pause menu is fully interactive: pressing resume works while tree is paused
	pause_menu.get_resume_button().emit_signal("pressed")
	assert_false(get_tree().paused, "Tree unpaused successfully via button while frozen")
	assert_true(dummy_gameplay_node.can_process(), "Gameplay node can process again after resume")


func test_decoupling_rules() -> void:
	var scene: PackedScene = load(PAUSE_MENU_SCENE_PATH)
	var pause_menu: PauseMenu = scene.instantiate() as PauseMenu
	add_child_autofree(pause_menu)

	assert_false("player" in pause_menu, "PauseMenu must not hold a direct player reference")
	assert_false("level" in pause_menu, "PauseMenu must not hold a direct level reference")
