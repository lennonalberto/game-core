class_name DieState
extends State

## Active when the player health is depleted.
## Emits EventBus.player_died on enter and stops further movement updates.

var player: CharacterBody2D:
	get:
		return entity


func enter(_msg: Dictionary = {}) -> void:
	if player:
		player.velocity = Vector2.ZERO
		if "animation_player" in player and player.animation_player:
			if player.animation_player.has_animation("die"):
				player.animation_player.play("die")

	EventBus.player_died.emit()


func physics_update(_delta: float) -> void:
	# No movement while dead
	if player:
		player.velocity = Vector2.ZERO
		player.move_and_slide()
