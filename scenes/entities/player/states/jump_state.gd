class_name JumpState
extends State

## Active when the player initiates a jump and moves upward through the air.
## Emits EventBus.player_jumped on enter, and transitions to Fall once vertical velocity crosses zero.

var player: CharacterBody2D:
	get:
		return entity


func enter(msg: Dictionary = {}) -> void:
	if player == null:
		return

	# Only apply initial jump velocity and emit signal if not resolving from saved state
	if not msg.get("preserve_velocity", false):
		var jump_impulse: float = player.jump_velocity if "jump_velocity" in player else -350.0
		player.velocity.y = jump_impulse
		EventBus.player_jumped.emit()

	if "animation_player" in player and player.animation_player:
		if player.animation_player.has_animation("jump"):
			player.animation_player.play("jump")


func physics_update(delta: float) -> void:
	if player == null:
		return

	# Mid-air horizontal steering
	var dir: float = Input.get_axis("move_left", "move_right")
	var move_speed: float = player.speed if "speed" in player else 200.0
	player.velocity.x = dir * move_speed

	if "sprite" in player and player.sprite:
		if dir > 0.0:
			player.sprite.flip_h = false
		elif dir < 0.0:
			player.sprite.flip_h = true

	# Apply gravity
	var grav: float = player.gravity if "gravity" in player else 980.0
	player.velocity.y += grav * delta

	player.move_and_slide()

	# Transition to Fall once ascending velocity crosses zero or points downward
	if player.velocity.y >= 0.0:
		transitioned.emit("Fall", {})
