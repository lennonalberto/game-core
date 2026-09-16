extends Node

## Tracks, calculates, and persists player achievements.
##
## Architectural Rule: Achievements are data-driven custom Resources (.tres instances),
## not hardcoded code logic. New achievements can be added by creating resource files
## without modifying manager code. Progress and unlock states are persisted to an
## independent achievements file on disk (user://achievements.tres), separated from game save slots.
## Listens to EventBus signals to decouple gameplay from achievement logic.

const ACHIEVEMENTS_FILE_PATH: String = "user://achievements.tres"
const DEFINITIONS_DIR: String = "res://data/achievements"

## Dictionary mapping achievement IDs (String) to AchievementDefinition resources.
var definitions: Dictionary = {}

## The active in-memory achievement save data resource.
var save_data: AchievementSaveData = null


func _ready() -> void:
	load_definitions()
	load_progress()
	_connect_event_bus()


# --- Definition Loading ---

## Discovers and loads all AchievementDefinition resources from disk.
func load_definitions(dir_path: String = DEFINITIONS_DIR) -> void:
	definitions.clear()
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_warning("Could not open achievements directory: %s" % dir_path)
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path: String = dir_path.path_join(file_name)
			var res = ResourceLoader.load(full_path)
			if res is AchievementDefinition:
				if not res.id.is_empty():
					definitions[res.id] = res
				else:
					push_warning("Achievement definition at %s is missing an id" % full_path)
		file_name = dir.get_next()
	dir.list_dir_end()


# --- Public Queries ---

## Returns true if the achievement with the given ID is unlocked.
func is_unlocked(id: String) -> bool:
	if save_data == null:
		return false
	return save_data.unlocked_achievements.has(id)


## Returns current progress count for the given achievement ID.
func get_progress(id: String) -> int:
	if save_data == null:
		return 0
	return save_data.progress.get(id, 0)


## Returns target progress count required to unlock the achievement.
func get_target_progress(id: String) -> int:
	if definitions.has(id):
		return (definitions[id] as AchievementDefinition).target_progress
	return 1


## Returns the definition resource for the given achievement ID.
func get_definition(id: String) -> AchievementDefinition:
	return definitions.get(id, null)


## Returns an array of all loaded achievement definitions.
func get_all_definitions() -> Array:
	return definitions.values()


# --- Progress & Unlocking ---

## Unlocks an achievement immediately if not already unlocked.
## Fires EventBus.achievement_unlocked exactly once per achievement.
func unlock(id: String) -> bool:
	if is_unlocked(id):
		return false

	if not definitions.has(id):
		push_warning("Attempted to unlock undefined achievement: %s" % id)
		return false

	var def: AchievementDefinition = definitions[id]
	save_data.unlocked_achievements.append(id)
	save_data.unlock_timestamps[id] = int(Time.get_unix_time_from_system())
	save_data.progress[id] = def.target_progress

	save_progress()
	EventBus.achievement_unlocked.emit(id, def.title, def.description)
	return true


## Adds progress toward an achievement. Automatically unlocks when target is met.
func add_progress(id: String, amount: int = 1) -> void:
	if is_unlocked(id):
		return

	if not definitions.has(id):
		push_warning("Attempted to add progress to undefined achievement: %s" % id)
		return

	var target: int = get_target_progress(id)
	var current: int = mini(get_progress(id) + amount, target)
	save_data.progress[id] = current

	EventBus.achievement_progress_updated.emit(id, current, target)

	if current >= target:
		unlock(id)
	else:
		save_progress()


# --- Persistence ---

## Saves achievement progress to disk.
func save_progress(file_path: String = ACHIEVEMENTS_FILE_PATH) -> Error:
	if save_data == null:
		save_data = AchievementSaveData.create_default()
	var err: Error = ResourceSaver.save(save_data, file_path)
	if err != OK:
		push_error("Failed to save achievements to %s: Error %d" % [file_path, err])
	return err


## Loads achievement progress from disk with graceful fallback if missing or corrupt.
func load_progress(file_path: String = ACHIEVEMENTS_FILE_PATH) -> void:
	if FileAccess.file_exists(file_path):
		var loaded = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if loaded is AchievementSaveData:
			save_data = loaded
			return
		else:
			push_warning("Corrupted achievements file at %s. Falling back to default." % file_path)

	save_data = AchievementSaveData.create_default()
	save_progress(file_path)


## Resets all achievements and progress to baseline.
func reset_all_achievements(file_path: String = ACHIEVEMENTS_FILE_PATH) -> void:
	save_data = AchievementSaveData.create_default()
	save_progress(file_path)


# --- EventBus Integration ---

## Subscribes to EventBus signals to drive achievement unlocks and progress without direct coupling.
func _connect_event_bus() -> void:
	EventBus.coin_collected.connect(_on_coin_collected)
	EventBus.checkpoint_reached.connect(_on_checkpoint_reached)
	EventBus.player_jumped.connect(_on_player_jumped)


func _on_coin_collected(amount: int) -> void:
	add_progress("coin_collector", amount)


func _on_checkpoint_reached(_checkpoint_id: String, _position: Vector2) -> void:
	unlock("checkpoint_reached")


func _on_player_jumped() -> void:
	unlock("first_step")
