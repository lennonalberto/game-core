extends GutTest

## Unit tests for Player entity, StateMachine integration, Saveable contract,
## and EventBus signal decoupling.

const PLAYER_SCENE_PATH: String = "res://scenes/entities/player/player.tscn"
const TEST_SLOT: int = 99


func before_each() -> void:
	if SaveManager.has_save(TEST_SLOT):
		SaveManager.delete_save(TEST_SLOT)


func after_each() -> void:
	if SaveManager.has_save(TEST_SLOT):
		SaveManager.delete_save(TEST_SLOT)


func test_player_scene_structure_and_components() -> void:
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	assert_not_null(player_scene, "Player scene should load successfully")

	var player: Player = player_scene.instantiate() as Player
	add_child_autofree(player)

	assert_not_null(player.sprite, "Player should have Sprite2D component")
	assert_not_null(player.animation_player, "Player should have AnimationPlayer component")
	assert_not_null(player.state_machine, "Player should have StateMachine component")
	assert_not_null(player.hitbox_component, "Player should have HitboxComponent")
	assert_true(player.is_in_group("saveable"), "Player must be in the 'saveable' group")
	assert_eq(player.state_machine.current_state_name, "Idle", "Player should start in Idle state by default")


func test_saveable_contract_round_trip() -> void:
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	var player: Player = player_scene.instantiate() as Player
	add_child_autofree(player)

	player.global_position = Vector2(150.0, 320.0)
	player.velocity = Vector2(45.0, -120.0)
	player.health = 75

	var save_data: Dictionary = player.get_save_data()
	assert_true(save_data.has("position"), "Save data should contain position")
	assert_true(save_data.has("velocity"), "Save data should contain velocity")
	assert_true(save_data.has("health"), "Save data should contain health")
	assert_false(save_data.has("current_state_name"), "Must NOT persist current_state_name per AGENTS.md rule 8")
	assert_false(save_data.has("state"), "Must NOT persist state name")

	# Modify player and restore via apply_save_data
	player.global_position = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player.health = 100

	player.apply_save_data(save_data)
	assert_eq(player.global_position, Vector2(150.0, 320.0), "Position should be restored")
	assert_eq(player.velocity, Vector2(45.0, -120.0), "Velocity should be restored")
	assert_eq(player.health, 75, "Health should be restored")


func test_save_manager_integration() -> void:
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	var player: Player = player_scene.instantiate() as Player
	player.save_id = "test_player"
	player.global_position = Vector2(240.0, 180.0)
	player.health = 60
	add_child_autofree(player)

	SaveManager.new_game(TEST_SLOT)
	var save_err: Error = SaveManager.save_game(TEST_SLOT)
	assert_eq(save_err, OK, "SaveManager.save_game should succeed")

	# Mutate player state
	player.global_position = Vector2.ZERO
	player.health = 100

	# Reload save slot
	var load_err: Error = SaveManager.load_game(TEST_SLOT)
	assert_eq(load_err, OK, "SaveManager.load_game should succeed")
	assert_eq(player.global_position, Vector2(240.0, 180.0), "SaveManager should restore player position via saveable group")
	assert_eq(player.health, 60, "SaveManager should restore player health via saveable group")


func test_jump_state_emits_player_jumped() -> void:
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	var player: Player = player_scene.instantiate() as Player
	add_child_autofree(player)

	watch_signals(EventBus)
	player.state_machine.transition_to("Jump")

	assert_signal_emitted(EventBus, "player_jumped", "Entering Jump state must emit EventBus.player_jumped")
	assert_eq(player.velocity.y, player.jump_velocity, "Jump state should apply jump_velocity")


func test_jump_transitions_to_fall_when_velocity_y_crosses_zero() -> void:
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	var player: Player = player_scene.instantiate() as Player
	add_child_autofree(player)

	player.state_machine.transition_to("Jump")
	assert_eq(player.state_machine.current_state_name, "Jump")

	# Simulate upward jump apex reaching downward velocity
	player.velocity.y = 5.0
	player.state_machine.physics_update(0.016)

	assert_eq(player.state_machine.current_state_name, "Fall", "Jump should transition to Fall once velocity.y >= 0")


func test_hitbox_damage_and_die_state() -> void:
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	var player: Player = player_scene.instantiate() as Player
	add_child_autofree(player)

	watch_signals(EventBus)
	player.hitbox_component.take_damage(40)

	assert_eq(player.health, 60, "Health should decrease by 40")
	assert_signal_emitted_with_parameters(EventBus, "player_health_changed", [60, 100])

	# Deal lethal damage
	player.hitbox_component.take_damage(60)
	assert_eq(player.health, 0, "Health should reach 0")
	assert_eq(player.state_machine.current_state_name, "Die", "Player should transition to Die state upon depletion")
	assert_signal_emitted(EventBus, "player_died", "Die state must emit EventBus.player_died")


func test_state_machine_self_resolves_airborne_on_load() -> void:
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	var player: Player = player_scene.instantiate() as Player
	add_child_autofree(player)

	# Simulate loading mid-air downward velocity
	player.apply_save_data({
		"position": Vector2(500.0, 100.0),
		"velocity": Vector2(0.0, 50.0),
		"health": 100
	})

	# On first physics frame in Idle without floor contact, should resolve to Fall
	player.state_machine.physics_update(0.016)
	assert_eq(player.state_machine.current_state_name, "Fall", "Airborne player should self-resolve to Fall")


func test_fall_landing_with_static_body() -> void:
	var floor_body: StaticBody2D = StaticBody2D.new()
	floor_body.collision_layer = 1
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(500, 20)
	shape.shape = rect
	floor_body.position = Vector2(0, 50)
	floor_body.add_child(shape)
	add_child_autofree(floor_body)

	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	var player: Player = player_scene.instantiate() as Player
	player.position = Vector2(0, 0)
	add_child_autofree(player)

	player.state_machine.transition_to("Fall")
	watch_signals(EventBus)

	# Run physics frames until player collides with floor_body
	for i in range(30):
		player.state_machine.physics_update(0.016)
		if player.is_on_floor():
			break

	assert_true(player.is_on_floor(), "Player should detect floor collision via move_and_slide")
	assert_signal_emitted(EventBus, "player_landed", "Falling onto floor must emit EventBus.player_landed")
	assert_eq(player.state_machine.current_state_name, "Idle", "Player should transition to Idle upon landing without input")
