class_name PlatformerDemo
extends Node2D

## Platformer demonstration level showcasing player movement, pickups, and checkpoints.
##
## Architectural Rule: Decoupled from managers. Emits EventBus.level_started on _ready
## so SaveManager and UI react without holding direct level references.

@export var level_id: String = "platformer_demo"

@onready var player: Player = $Player
@onready var checkpoint: Checkpoint = $Checkpoint


func _enter_tree() -> void:
	add_to_group("saveable")


func _ready() -> void:
	EventBus.level_started.emit(level_id)


# --- Saveable Contract ---

func get_save_data() -> Dictionary:
	return {
		"level_id": level_id
	}


func apply_save_data(data: Dictionary) -> void:
	level_id = data.get("level_id", level_id)
