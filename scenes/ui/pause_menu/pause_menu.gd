class_name PauseMenu
extends CanvasLayer

## Pause menu overlay and coordinator.
##
## Architectural Rule: Pauses the game tree via get_tree().paused, keeping the
## pause menu interactive via process_mode = PROCESS_MODE_ALWAYS.
## Emits EventBus.game_paused so gameplay systems and audio can react.

signal resume_requested
signal settings_requested
signal quit_requested

@export var pause_action: String = "pause"

@onready var backdrop: Control = %Backdrop
@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if resume_button:
		resume_button.pressed.connect(_on_resume_button_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_button_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(pause_action):
		toggle_pause()
		get_viewport().set_input_as_handled()


## Pauses the scene tree, displays the overlay, and focuses the resume button.
func open_pause_menu() -> void:
	get_tree().paused = true
	visible = true

	if resume_button:
		resume_button.grab_focus()

	EventBus.game_paused.emit(true)


## Unpauses the scene tree and hides the overlay.
func close_pause_menu() -> void:
	get_tree().paused = false
	visible = false

	EventBus.game_paused.emit(false)
	resume_requested.emit()


## Toggles pause state.
func toggle_pause() -> void:
	if is_paused():
		close_pause_menu()
	else:
		open_pause_menu()


func _on_resume_button_pressed() -> void:
	close_pause_menu()


func _on_settings_button_pressed() -> void:
	settings_requested.emit()


func _on_quit_button_pressed() -> void:
	close_pause_menu()
	quit_requested.emit()
	GameManager.quit_to_main_menu()


# --- Public Query API (for verification and tests) ---

func is_paused() -> bool:
	return get_tree().paused and visible


func get_resume_button() -> Button:
	return resume_button


func get_settings_button() -> Button:
	return settings_button


func get_quit_button() -> Button:
	return quit_button
