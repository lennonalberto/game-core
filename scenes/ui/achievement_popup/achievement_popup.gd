class_name AchievementPopup
extends CanvasLayer

## Toast notification overlay for unlocked achievements.
##
## Architectural Rule: Listens reactively to EventBus.achievement_unlocked.
## Queues incoming notifications in a FIFO queue so multiple achievements
## unlocked in quick succession display sequentially without overlapping.

@export var display_duration: float = 2.5
@export var animation_duration: float = 0.3

@onready var toast_panel: PanelContainer = %ToastPanel
@onready var icon_rect: TextureRect = %IconRect
@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel

var is_showing: bool = false

var _queue: Array[Dictionary] = []
var _current_tween: Tween = null
const DEFAULT_ICON = preload("res://icon.svg")


func _ready() -> void:
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)
	if toast_panel:
		toast_panel.visible = false


func _on_achievement_unlocked(id: String, title: String, description: String) -> void:
	_queue.append({
		"id": id,
		"title": title,
		"description": description
	})

	if not is_showing:
		_show_next_toast()


func _show_next_toast() -> void:
	if _queue.is_empty():
		is_showing = false
		if toast_panel:
			toast_panel.visible = false
		return

	is_showing = true
	var item: Dictionary = _queue.pop_front()

	if title_label:
		title_label.text = item.get("title", "")
	if description_label:
		description_label.text = item.get("description", "")

	if icon_rect:
		var def: AchievementDefinition = AchievementManager.get_definition(item.get("id", ""))
		if def != null and def.icon != null:
			icon_rect.texture = def.icon
		else:
			icon_rect.texture = DEFAULT_ICON

	if toast_panel:
		toast_panel.visible = true
		toast_panel.modulate.a = 0.0

		if _current_tween != null and _current_tween.is_valid():
			_current_tween.kill()

		_current_tween = create_tween()
		_current_tween.tween_property(toast_panel, "modulate:a", 1.0, animation_duration)
		_current_tween.tween_interval(display_duration)
		_current_tween.tween_property(toast_panel, "modulate:a", 0.0, animation_duration)
		_current_tween.tween_callback(_on_toast_completed)


func _on_toast_completed() -> void:
	if toast_panel:
		toast_panel.visible = false
	_show_next_toast()


## Immediately finishes the active toast and advances to the next item in the queue.
func dismiss_current() -> void:
	if not is_showing:
		return

	if _current_tween != null and _current_tween.is_valid():
		_current_tween.kill()

	_on_toast_completed()


# --- Public Query API (for verification and unit tests) ---

func get_queue_count() -> int:
	return _queue.size()


func get_displayed_title() -> String:
	return title_label.text if title_label else ""


func get_displayed_description() -> String:
	return description_label.text if description_label else ""


func is_toast_visible() -> bool:
	return toast_panel.visible if toast_panel else false
