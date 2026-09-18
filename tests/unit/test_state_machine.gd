extends GutTest

## Unit tests for the generic node-based StateMachine framework.

class DummyTestState extends State:
	var enter_calls: int = 0
	var exit_calls: int = 0
	var last_msg: Dictionary = {}

	func enter(msg: Dictionary = {}) -> void:
		enter_calls += 1
		last_msg = msg

	func exit() -> void:
		exit_calls += 1


func test_state_discovery_and_initial_state() -> void:
	var fsm = StateMachine.new()
	var state_a = DummyTestState.new()
	state_a.name = "StateA"
	var state_b = DummyTestState.new()
	state_b.name = "StateB"

	fsm.add_child(state_a)
	fsm.add_child(state_b)
	add_child_autofree(fsm)

	assert_eq(fsm.states.size(), 2, "StateMachine should discover both child states")
	assert_eq(fsm.current_state_name, "StateA", "Default initial state should be the first child state")
	assert_eq(state_a.enter_calls, 1, "First child state should have enter() invoked")


func test_explicit_initial_state() -> void:
	var fsm = StateMachine.new()
	var state_a = DummyTestState.new()
	state_a.name = "StateA"
	var state_b = DummyTestState.new()
	state_b.name = "StateB"

	fsm.add_child(state_a)
	fsm.add_child(state_b)
	fsm.initial_state = state_b
	add_child_autofree(fsm)

	assert_eq(fsm.current_state_name, "StateB", "Initial state should match explicit assignment")
	assert_eq(state_b.enter_calls, 1, "StateB should have entered once")
	assert_eq(state_a.enter_calls, 0, "StateA should not have entered")


func test_transition_to_switches_states_and_triggers_lifecycle() -> void:
	var fsm = StateMachine.new()
	var state_a = DummyTestState.new()
	state_a.name = "StateA"
	var state_b = DummyTestState.new()
	state_b.name = "StateB"

	fsm.add_child(state_a)
	fsm.add_child(state_b)
	add_child_autofree(fsm)

	watch_signals(fsm)
	fsm.transition_to("StateB", {"speed": 100})

	assert_eq(fsm.current_state_name, "StateB", "Current state should now be StateB")
	assert_eq(state_a.exit_calls, 1, "Outgoing StateA should have exit() called")
	assert_eq(state_b.enter_calls, 1, "Incoming StateB should have enter() called")
	assert_eq(state_b.last_msg.get("speed"), 100, "Message payload should pass to enter()")
	assert_signal_emitted_with_parameters(fsm, "state_changed", ["StateA", "StateB"])


func test_transition_from_inactive_child_is_ignored() -> void:
	var fsm = StateMachine.new()
	var state_a = DummyTestState.new()
	state_a.name = "StateA"
	var state_b = DummyTestState.new()
	state_b.name = "StateB"

	fsm.add_child(state_a)
	fsm.add_child(state_b)
	add_child_autofree(fsm)

	# Currently in StateA. Attempt to trigger transition from inactive StateB
	state_b.transitioned.emit("StateA", {})
	assert_eq(fsm.current_state_name, "StateA", "Current state should remain StateA")
	assert_eq(state_a.exit_calls, 0, "StateA should not have exited")


func test_transition_to_same_state_is_noop() -> void:
	var fsm = StateMachine.new()
	var state_a = DummyTestState.new()
	state_a.name = "StateA"

	fsm.add_child(state_a)
	add_child_autofree(fsm)

	assert_eq(state_a.enter_calls, 1, "Entered once on ready")
	fsm.transition_to("StateA")
	assert_eq(state_a.enter_calls, 1, "Transition to same state should be a no-op")
	assert_eq(state_a.exit_calls, 0, "StateA should not exit when transitioning to itself")
