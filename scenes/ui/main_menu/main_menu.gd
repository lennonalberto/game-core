class_name MainMenu
extends Control

## Main menu screen presenting game start, continue, settings, and quit options.
##
## Architectural Rule: UI is reactive and routes scene transitions through
## GameManager. Settings are displayed via the reusable SettingsMenu overlay.

@onready var main_buttons_container: Control = %MainButtonsContainer
@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var settings_menu: SettingsMenu = %SettingsMenu if has_node("%SettingsMenu") else null


func _ready() -> void:
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

	if settings_menu:
		settings_menu.back_requested.connect(_on_settings_back_requested)

	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if settings_menu and settings_menu.visible:
			settings_menu.close_settings()
			get_viewport().set_input_as_handled()


## Evaluates save availability, updates Continue button state, and sets initial focus.
func refresh() -> void:
	var can_continue: bool = SaveManager.has_save(SaveManager.current_slot)
	if not can_continue:
		var existing_slots: Array[int] = SaveManager.list_save_slots()
		if not existing_slots.is_empty():
			SaveManager.current_slot = existing_slots[0]
			can_continue = true

	if continue_button:
		continue_button.disabled = not can_continue

	if can_continue and continue_button:
		continue_button.grab_focus()
	elif new_game_button:
		new_game_button.grab_focus()


func _on_new_game_pressed() -> void:
	GameManager.start_new_game(SaveManager.current_slot)


func _on_continue_pressed() -> void:
	if SaveManager.has_save(SaveManager.current_slot):
		GameManager.continue_game(SaveManager.current_slot)


func _on_settings_pressed() -> void:
	if settings_menu:
		if main_buttons_container:
			main_buttons_container.visible = false
		settings_menu.open_settings()


func _on_settings_back_requested() -> void:
	if main_buttons_container:
		main_buttons_container.visible = true
	if settings_button:
		settings_button.grab_focus()


func _on_quit_pressed() -> void:
	GameManager.quit_game()


# --- Public Query API (for verification and tests) ---

func get_new_game_button() -> Button:
	return new_game_button


func get_continue_button() -> Button:
	return continue_button


func get_settings_button() -> Button:
	return settings_button


func get_quit_button() -> Button:
	return quit_button


func get_settings_menu() -> SettingsMenu:
	return settings_menu


func is_continue_enabled() -> bool:
	return continue_button != null and not continue_button.disabled
