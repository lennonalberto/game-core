class_name FallState
extends State

## Active when the player is airborne with downward vertical velocity.
## Emits EventBus.player_landed upon landing and transitions to Idle or Run depending on input.

var player: CharacterBody2D:
	get:
		return entity


func enter(_msg: Dictionary = {}) -> void:
	if player and "animation_player" in player and player.animation_player:
		if player.animation_player.has_animation("fall"):
			player.animation_player.play("fall")


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

	# Handle floor collision
	if player.is_on_floor():
		EventBus.player_landed.emit()
		if not is_zero_approx(dir):
			transitioned.emit("Run", {})
		else:
			transitioned.emit("Idle", {})
		return
