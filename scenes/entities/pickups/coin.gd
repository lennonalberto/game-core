class_name Coin
extends Area2D

## Collectible coin pickup entity.
##
## Architectural Rule: Decoupled via EventBus. Emits EventBus.coin_collected
## upon overlapping the player. Implements the "saveable" contract so its collected
## state persists across save slots without direct manager coupling.

@export var value: int = 1
@export var save_id: String = ""

var is_collected: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _enter_tree() -> void:
	add_to_group("saveable")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if is_collected:
		_deactivate()
	elif animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")


func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return

	if body is Player or body.is_in_group("player") or body.name == "Player":
		collect()


## Collects the coin, emits the EventBus signal, and deactivates the entity.
func collect() -> void:
	if is_collected:
		return

	is_collected = true
	EventBus.coin_collected.emit(value)
	_deactivate()


func _deactivate() -> void:
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)


# --- Saveable Contract ---

func get_save_data() -> Dictionary:
	return {
		"is_collected": is_collected
	}


func apply_save_data(data: Dictionary) -> void:
	is_collected = data.get("is_collected", false)
	if is_collected:
		_deactivate()
