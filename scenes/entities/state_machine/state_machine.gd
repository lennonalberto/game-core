class_name StateMachine
extends Node

## Generic node-based finite state machine.
##
## Architectural Rule: State machines are node-based, not match-block FSMs.
## The StateMachine owns switching logic and state life cycles, discovering
## child State nodes on _ready(). Child states request transitions via signals
## and never call each other directly.

signal state_changed(from_state: String, to_state: String)

## Optional default state to activate upon ready. If unassigned, defaults to first child State.
@export var initial_state: State

## The currently active State instance.
var current_state: State = null

## The name of the currently active State.
var current_state_name: String:
	get:
		return current_state.name if current_state != null else ""

## Registry mapping lowercase state names to State instances.
var states: Dictionary = {}


func _ready() -> void:
	_init_states()


## Discovers child State nodes, binds their transitioned signals, and enters the initial state.
func _init_states() -> void:
	states.clear()
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.state_machine = self
			if not child.transitioned.is_connected(_on_child_transitioned):
				child.transitioned.connect(_on_child_transitioned.bind(child))

	if initial_state != null:
		transition_to(initial_state.name)
	elif get_child_count() > 0:
		for child in get_children():
			if child is State:
				transition_to(child.name)
				break


## Transitions from current_state to target_state_name if valid and not already active.
func transition_to(target_state_name: String, msg: Dictionary = {}) -> void:
	var key: String = target_state_name.to_lower()
	if not states.has(key):
		push_warning("StateMachine: Unknown target state '%s'." % target_state_name)
		return

	var target_state: State = states[key]
	if target_state == current_state:
		return

	var from_name: String = current_state_name
	if current_state != null:
		current_state.exit()

	current_state = target_state
	current_state.enter(msg)
	state_changed.emit(from_name, current_state.name)


## Receives transition requests from child states, verifying the request originated from the active state.
func _on_child_transitioned(new_state_name: String, msg: Dictionary, sender: State) -> void:
	if sender != current_state:
		return
	transition_to(new_state_name, msg)


## Delegates physics update ticks to the active state.
func physics_update(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)


## Delegates input events to the active state.
func handle_input(event: InputEvent) -> void:
	if current_state != null:
		current_state.handle_input(event)
