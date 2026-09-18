class_name RunState
extends State

## Active when the player is moving horizontally across the floor.
## Transitions to Idle when input ceases, Jump on jump action, or Fall if airborne.

var player: CharacterBody2D:
	get:
		return entity


func enter(_msg: Dictionary = {}) -> void:
	if player and "animation_player" in player and player.animation_player:
		if player.animation_player.has_animation("run"):
			player.animation_player.play("run")


func physics_update(delta: float) -> void:
	if player == null:
		return

	var dir: float = Input.get_axis("move_left", "move_right")
	var move_speed: float = player.speed if "speed" in player else 200.0
	player.velocity.x = dir * move_speed

	# Update visual facing orientation
	if "sprite" in player and player.sprite:
		if dir > 0.0:
			player.sprite.flip_h = false
		elif dir < 0.0:
			player.sprite.flip_h = true

	# Apply gravity to maintain floor contact
	var grav: float = player.gravity if "gravity" in player else 980.0
	player.velocity.y += grav * delta

	player.move_and_slide()

	# Transition to Fall if airborne (e.g. walked off ledge)
	if not player.is_on_floor():
		transitioned.emit("Fall", {})
		return

	# Handle jump input
	if Input.is_action_just_pressed("jump"):
		transitioned.emit("Jump", {})
		return

	# Transition to Idle when horizontal input ceases
	if is_zero_approx(dir):
		transitioned.emit("Idle", {})
		return
