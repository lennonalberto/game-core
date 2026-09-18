class_name State
extends Node

## Base class for all states in the node-based finite state machine.
##
## Architectural Rule: Any entity with distinct behavioral states uses this
## shared framework under scenes/entities/state_machine/.
## A state requests a transition by emitting its own transitioned signal.
## It never calls another state directly, and the state machine owns switching logic.
## Gameplay EventBus signals tied to a state transition (e.g. player_jumped)
## are emitted by the state itself, not by the state machine or entity script.

signal transitioned(new_state_name: String, msg: Dictionary)

## Reference to the state machine owning this state.
var state_machine: Node = null

## Resolves the entity this state controls (scene owner or parent of StateMachine).
var entity: CharacterBody2D:
	get:
		if _entity != null:
			return _entity
		if owner is CharacterBody2D:
			return owner as CharacterBody2D
		if get_parent() and get_parent().owner is CharacterBody2D:
			return get_parent().owner as CharacterBody2D
		if get_parent() and get_parent().get_parent() is CharacterBody2D:
			return get_parent().get_parent() as CharacterBody2D
		return null
	set(value):
		_entity = value

var _entity: CharacterBody2D = null


## Called when entering this state. Optional msg dictionary carries transition context.
func enter(_msg: Dictionary = {}) -> void:
	pass


## Called when exiting this state.
func exit() -> void:
	pass


## Called every physics frame while this state is active.
func physics_update(_delta: float) -> void:
	pass


## Called on unhandled or dispatched input events.
func handle_input(_event: InputEvent) -> void:
	pass
