class_name IdleState
extends State

## Active when the player is resting on the floor without movement inputs.
## Transitions to Run on directional input, Jump on jump action, or Fall if airborne.

var player: CharacterBody2D:
	get:
		return entity


func enter(_msg: Dictionary = {}) -> void:
	if player and "animation_player" in player and player.animation_player:
		if player.animation_player.has_animation("idle"):
			player.animation_player.play("idle")


func physics_update(delta: float) -> void:
	if player == null:
		return

	# Decelerate horizontal velocity to zero
	var move_speed: float = player.speed if "speed" in player else 200.0
	player.velocity.x = move_toward(player.velocity.x, 0.0, move_speed)

	# Apply gravity to maintain floor contact
	var grav: float = player.gravity if "gravity" in player else 980.0
	player.velocity.y += grav * delta

	player.move_and_slide()

	# Self-resolve transitions when airborne (e.g. initial spawn, platform dropped, or loaded save)
	if not player.is_on_floor():
		if player.velocity.y < 0.0:
			transitioned.emit("Jump", {"preserve_velocity": true})
		else:
			transitioned.emit("Fall", {})
		return

	# Handle jump input
	if Input.is_action_just_pressed("jump"):
		transitioned.emit("Jump", {})
		return

	# Handle horizontal movement input
	var dir: float = Input.get_axis("move_left", "move_right")
	if not is_zero_approx(dir):
		transitioned.emit("Run", {})
		return
