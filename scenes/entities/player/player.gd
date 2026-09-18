class_name Player
extends CharacterBody2D

## Playable CharacterBody2D entity for 2D platforming.
##
## Architectural Rules:
## 1. No movement branching in player.gd — _physics_process strictly delegates
##    to state_machine.physics_update(delta).
## 2. Implements the "saveable" contract: persists position, velocity, and health,
##    never persisting current_state_name.
## 3. Direct references are limited to components within this scene.

# --- Tunable Movement & Physics Parameters ---
@export var speed: float = 200.0
@export var gravity: float = 980.0
@export var jump_velocity: float = -350.0

# --- Health & Gameplay Parameters ---
@export var max_health: int = 100
var health: int = 100

## Identifier used by SaveManager to key this node's state dictionary.
@export var save_id: String = "player"

# --- Child Node References ---
@onready var state_machine: StateMachine = $StateMachine
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hitbox_component: HitboxComponent = $HitboxComponent


func _enter_tree() -> void:
	add_to_group("saveable")


func _ready() -> void:
	if hitbox_component:
		hitbox_component.hit_received.connect(take_damage)

	EventBus.player_spawned.emit(self)


func _physics_process(delta: float) -> void:
	if state_machine:
		state_machine.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if state_machine:
		state_machine.handle_input(event)


## Reduces player health by the specified damage amount.
func take_damage(amount: int) -> void:
	if health <= 0:
		return

	health = max(0, health - amount)
	EventBus.player_health_changed.emit(health, max_health)

	if health <= 0 and state_machine:
		state_machine.transition_to("Die")


# --- Saveable Contract ---

## Returns the dictionary of properties to persist in save games.
## Architectural Rule: Do not persist current_state_name. Let the state machine
## self-resolve on load based on physical state (position, velocity, is_on_floor()).
func get_save_data() -> Dictionary:
	return {
		"position": global_position,
		"velocity": velocity,
		"health": health
	}


## Restores player state from persisted data.
func apply_save_data(data: Dictionary) -> void:
	if data.has("position"):
		var pos = data["position"]
		if pos is Vector2:
			global_position = pos
		elif pos is Dictionary:
			global_position = Vector2(pos.get("x", global_position.x), pos.get("y", global_position.y))

	if data.has("velocity"):
		var vel = data["velocity"]
		if vel is Vector2:
			velocity = vel
		elif vel is Dictionary:
			velocity = Vector2(vel.get("x", velocity.x), vel.get("y", velocity.y))

	if data.has("health"):
		health = int(data["health"])
		EventBus.player_health_changed.emit(health, max_health)
