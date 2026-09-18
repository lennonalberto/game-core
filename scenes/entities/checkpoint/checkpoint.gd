class_name Checkpoint
extends Area2D

## Interactive checkpoint trigger entity.
##
## Architectural Rule: Decoupled via EventBus. On player overlap, emits
## EventBus.checkpoint_reached, triggers SaveManager.save_game(), and implements
## the "saveable" contract so its active state persists across save/load cycles.

@export var checkpoint_id: String = "checkpoint_1"
@export var save_id: String = "checkpoint_1"

var is_reached: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _enter_tree() -> void:
	add_to_group("saveable")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if is_reached:
		_update_visuals()


func _on_body_entered(body: Node2D) -> void:
	if is_reached:
		return

	if body is Player or body.is_in_group("player") or body.name == "Player":
		reach()


## Activates the checkpoint, emits EventBus signal, calls SaveManager.save_game(), and updates visuals.
func reach() -> void:
	if is_reached:
		return

	is_reached = true
	EventBus.checkpoint_reached.emit(checkpoint_id, global_position)
	SaveManager.save_game()
	_update_visuals()


func _update_visuals() -> void:
	if sprite:
		# Shift to green tone to indicate reached checkpoint
		sprite.modulate = Color(0.2, 0.9, 0.3, 1.0)


# --- Saveable Contract ---

func get_save_data() -> Dictionary:
	return {
		"is_reached": is_reached
	}


func apply_save_data(data: Dictionary) -> void:
	is_reached = data.get("is_reached", false)
	if is_reached:
		_update_visuals()
