class_name SettingsMenu
extends CanvasLayer

## Settings menu overlay for audio volumes, input keybinding, and display options.
##
## Architectural Rule: Reads directly from SettingsManager and applies changes live.
## Never caches or creates a second source of truth for volume or keybindings.
## All modifications persist to disk when the menu is closed or settings reset.

signal back_requested
signal settings_saved

const REBINDABLE_ACTIONS: Array[Dictionary] = [
	{"action": "move_left", "label": "Move Left"},
	{"action": "move_right", "label": "Move Right"},
	{"action": "move_up", "label": "Move Up"},
	{"action": "move_down", "label": "Move Down"},
	{"action": "jump", "label": "Jump"},
	{"action": "pause", "label": "Pause"},
]

@onready var master_slider: HSlider = %MasterSlider
@onready var master_value_label: Label = %MasterValueLabel
@onready var music_slider: HSlider = %MusicSlider
@onready var music_value_label: Label = %MusicValueLabel
@onready var sfx_slider: HSlider = %SFXSlider
@onready var sfx_value_label: Label = %SFXValueLabel

@onready var controls_list_container: VBoxContainer = %ControlsListContainer
@onready var rebind_prompt: Control = %RebindPrompt
@onready var rebind_prompt_label: Label = %RebindPromptLabel

@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var vsync_check_button: CheckButton = %VSyncCheckButton

@onready var reset_button: Button = %ResetButton
@onready var back_button: Button = %BackButton

var _rebinding_action: String = ""
var _rebind_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if rebind_prompt:
		rebind_prompt.visible = false

	_setup_audio_tab()
	_setup_controls_tab()
	_setup_video_tab()

	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	EventBus.settings_changed.connect(_on_external_settings_changed)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if _rebinding_action != "":
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == KEY_ESCAPE:
				cancel_rebind()
			else:
				var new_key: InputEventKey = InputEventKey.new()
				new_key.physical_keycode = event.physical_keycode
				new_key.keycode = event.keycode
				SettingsManager.set_keybind(_rebinding_action, [new_key])
				_update_action_button_text(_rebinding_action)
				_rebinding_action = ""
				if rebind_prompt:
					rebind_prompt.visible = false
				SettingsManager.save_settings()
				settings_saved.emit()
			get_viewport().set_input_as_handled()


## Opens the settings menu and synchronizes all widgets with current settings.
func open_settings() -> void:
	visible = true
	_refresh_all_ui()
	if back_button:
		back_button.grab_focus()


## Closes the settings menu, cancels active rebinds, and saves settings to disk.
func close_settings() -> void:
	cancel_rebind()
	visible = false
	SettingsManager.save_settings()
	settings_saved.emit()
	back_requested.emit()


## Initiates the capture-a-key rebind flow for the specified action.
func start_rebind(action_name: String) -> void:
	_rebinding_action = action_name
	if _rebind_buttons.has(action_name):
		var btn: Button = _rebind_buttons[action_name]
		btn.text = "[Press key...]"

	if rebind_prompt:
		rebind_prompt.visible = true
	if rebind_prompt_label:
		rebind_prompt_label.text = "Press any key for '%s' (Esc to cancel)..." % action_name


## Cancels the current rebind operation and restores the button text.
func cancel_rebind() -> void:
	if _rebinding_action != "":
		_update_action_button_text(_rebinding_action)
		_rebinding_action = ""
	if rebind_prompt:
		rebind_prompt.visible = false


func _setup_audio_tab() -> void:
	if master_slider:
		master_slider.value_changed.connect(_on_master_slider_changed)
	if music_slider:
		music_slider.value_changed.connect(_on_music_slider_changed)
	if sfx_slider:
		sfx_slider.value_changed.connect(_on_sfx_slider_changed)


func _setup_controls_tab() -> void:
	if not controls_list_container:
		return

	# Clear existing children if any
	for child in controls_list_container.get_children():
		child.queue_free()
	_rebind_buttons.clear()

	for entry in REBINDABLE_ACTIONS:
		var action_name: String = entry["action"]
		var action_label_text: String = entry["label"]

		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label: Label = Label.new()
		label.text = action_label_text
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(160, 28)
		btn.text = _get_action_display_text(action_name)
		btn.pressed.connect(func(): start_rebind(action_name))
		row.add_child(btn)

		_rebind_buttons[action_name] = btn
		controls_list_container.add_child(row)


func _setup_video_tab() -> void:
	if window_mode_option:
		window_mode_option.clear()
		window_mode_option.add_item("Windowed", DisplayServer.WINDOW_MODE_WINDOWED)
		window_mode_option.add_item("Fullscreen", DisplayServer.WINDOW_MODE_FULLSCREEN)
		window_mode_option.add_item("Exclusive Fullscreen", DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		window_mode_option.item_selected.connect(_on_window_mode_selected)

	if vsync_check_button:
		vsync_check_button.toggled.connect(_on_vsync_toggled)


func _refresh_all_ui() -> void:
	# Audio
	if master_slider:
		master_slider.value = SettingsManager.get_volume(SettingsManager.BUS_MASTER)
		if master_value_label:
			master_value_label.text = "%d%%" % int(master_slider.value * 100)
	if music_slider:
		music_slider.value = SettingsManager.get_volume(SettingsManager.BUS_MUSIC)
		if music_value_label:
			music_value_label.text = "%d%%" % int(music_slider.value * 100)
	if sfx_slider:
		sfx_slider.value = SettingsManager.get_volume(SettingsManager.BUS_SFX)
		if sfx_value_label:
			sfx_value_label.text = "%d%%" % int(sfx_slider.value * 100)

	# Controls
	for action_name: String in _rebind_buttons:
		_update_action_button_text(action_name)

	# Video
	if window_mode_option:
		var current_mode: int = SettingsManager.get_window_mode()
		for i in range(window_mode_option.item_count):
			if window_mode_option.get_item_id(i) == current_mode:
				window_mode_option.select(i)
				break
	if vsync_check_button:
		vsync_check_button.button_pressed = (SettingsManager.get_vsync_mode() == DisplayServer.VSYNC_ENABLED)


func _update_action_button_text(action_name: String) -> void:
	if _rebind_buttons.has(action_name):
		var btn: Button = _rebind_buttons[action_name]
		btn.text = _get_action_display_text(action_name)


func _get_action_display_text(action_name: String) -> String:
	var events: Array = SettingsManager.get_keybinds(action_name)
	if events.is_empty():
		return "None"
	var text_parts: Array[String] = []
	for ev in events:
		if ev is InputEventKey:
			var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
			text_parts.append(OS.get_keycode_string(code))
		elif ev is InputEventMouseButton:
			text_parts.append("Mouse " + str(ev.button_index))
		elif ev is InputEventJoypadButton:
			text_parts.append("Joy " + str(ev.button_index))
		else:
			text_parts.append(ev.as_text())
	return " / ".join(text_parts)


func _on_master_slider_changed(value: float) -> void:
	SettingsManager.set_volume(SettingsManager.BUS_MASTER, value)
	if master_value_label:
		master_value_label.text = "%d%%" % int(value * 100)


func _on_music_slider_changed(value: float) -> void:
	SettingsManager.set_volume(SettingsManager.BUS_MUSIC, value)
	if music_value_label:
		music_value_label.text = "%d%%" % int(value * 100)


func _on_sfx_slider_changed(value: float) -> void:
	SettingsManager.set_volume(SettingsManager.BUS_SFX, value)
	if sfx_value_label:
		sfx_value_label.text = "%d%%" % int(value * 100)


func _on_window_mode_selected(index: int) -> void:
	if window_mode_option:
		var mode_id: int = window_mode_option.get_item_id(index)
		SettingsManager.set_window_mode(mode_id)


func _on_vsync_toggled(toggled_on: bool) -> void:
	var mode: int = DisplayServer.VSYNC_ENABLED if toggled_on else DisplayServer.VSYNC_DISABLED
	SettingsManager.set_vsync_mode(mode)


func _on_reset_pressed() -> void:
	SettingsManager.reset_to_default()
	_refresh_all_ui()


func _on_back_pressed() -> void:
	close_settings()


func _on_external_settings_changed() -> void:
	if visible and _rebinding_action == "":
		_refresh_all_ui()


# --- Public Query API (for verification and unit tests) ---

func get_master_slider() -> HSlider:
	return master_slider


func get_music_slider() -> HSlider:
	return music_slider


func get_sfx_slider() -> HSlider:
	return sfx_slider


func get_rebind_button(action_name: String) -> Button:
	return _rebind_buttons.get(action_name, null)


func get_window_mode_option() -> OptionButton:
	return window_mode_option


func get_vsync_button() -> CheckButton:
	return vsync_check_button


func get_reset_button() -> Button:
	return reset_button


func get_back_button() -> Button:
	return back_button


func is_rebinding() -> bool:
	return _rebinding_action != ""
