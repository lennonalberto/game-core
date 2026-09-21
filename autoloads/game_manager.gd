extends Node

## Central coordinator for high-level game state, scene transitions, and game flow.
##
## Architectural Rule: Gameplay scenes and UI menus should not switch scenes or
## alter top-level game state directly. They request transitions or state changes
## via signals or through this manager, keeping tree management in one authoritative place.

const MAIN_MENU_SCENE_PATH: String = "res://scenes/ui/main_menu/main_menu.tscn"


## Safely unpauses the game tree and transitions to the main menu scene.
func quit_to_main_menu() -> void:
	if get_tree().paused:
		get_tree().paused = false
		EventBus.game_paused.emit(false)

	if ResourceLoader.exists(MAIN_MENU_SCENE_PATH):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	else:
		push_warning("Main menu scene does not exist yet at: %s" % MAIN_MENU_SCENE_PATH)
