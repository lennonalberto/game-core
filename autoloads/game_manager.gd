extends Node

## Central coordinator for high-level game state, scene transitions, and game flow.
##
## Architectural Rule: Gameplay scenes and UI menus should not switch scenes or
## alter top-level game state directly. They request transitions or state changes
## via signals or through this manager, keeping tree management in one authoritative place.

const MAIN_MENU_SCENE_PATH: String = "res://scenes/ui/main_menu/main_menu.tscn"
const DEFAULT_LEVEL_SCENE_PATH: String = "res://scenes/levels/platformer_demo/platformer_demo.tscn"

const LEVEL_SCENE_PATHS: Dictionary = {
	"platformer_demo": "res://scenes/levels/platformer_demo/platformer_demo.tscn",
}

var _pending_load_slot: int = -1


func _ready() -> void:
	EventBus.level_started.connect(_on_level_started)


func _on_level_started(_level_id: String) -> void:
	if _pending_load_slot != -1:
		SaveManager.load_game(_pending_load_slot)
		_pending_load_slot = -1


## Returns the scene file path mapped to the given level identifier.
func get_level_scene_path(level_id: String) -> String:
	if LEVEL_SCENE_PATHS.has(level_id):
		return LEVEL_SCENE_PATHS[level_id]
	return DEFAULT_LEVEL_SCENE_PATH


## Initializes a fresh save slot and transitions to the starting level.
func start_new_game(slot: int = 1) -> void:
	if get_tree().paused:
		get_tree().paused = false
		EventBus.game_paused.emit(false)

	_pending_load_slot = -1
	SaveManager.new_game(slot)
	get_tree().change_scene_to_file(DEFAULT_LEVEL_SCENE_PATH)


## Continues a saved game, loading the appropriate level scene and restoring state.
func continue_game(slot: int = 1) -> void:
	if not SaveManager.has_save(slot):
		push_warning("Cannot continue: No save file found for slot %d" % slot)
		return

	if get_tree().paused:
		get_tree().paused = false
		EventBus.game_paused.emit(false)

	var meta: Dictionary = SaveManager.get_save_metadata(slot)
	var level_id: String = meta.get("level_id", "platformer_demo")
	var target_scene_path: String = get_level_scene_path(level_id)

	_pending_load_slot = slot
	var err: Error = get_tree().change_scene_to_file(target_scene_path)
	if err != OK:
		push_error("Failed to change scene to %s: Error %d" % [target_scene_path, err])
		_pending_load_slot = -1


## Safely unpauses the game tree and transitions to the main menu scene.
func quit_to_main_menu() -> void:
	if get_tree().paused:
		get_tree().paused = false
		EventBus.game_paused.emit(false)

	_pending_load_slot = -1

	if ResourceLoader.exists(MAIN_MENU_SCENE_PATH):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	else:
		push_warning("Main menu scene does not exist yet at: %s" % MAIN_MENU_SCENE_PATH)


## Safely terminates the game application.
func quit_game() -> void:
	get_tree().quit()
