extends Node

## Coordinates persistence of gameplay state across save slots.
##
## Architectural Rule: SaveManager must never contain hardcoded references to
## specific gameplay nodes. Any node requiring persistence must join the "saveable"
## group and implement the saveable contract:
##   - get_save_data() -> Dictionary
##   - apply_save_data(data: Dictionary) -> void
## SaveManager strictly iterates over the "saveable" tree group.
## All save data is kept in user://saves/ and separated from settings and achievements.

const SAVES_DIR: String = "user://saves"
const SAVEABLE_GROUP: String = "saveable"

## The active slot number currently loaded or being written to.
var current_slot: int = 1

## The active in-memory SaveData resource.
var current_save: SaveData = null

## Whether to automatically increment current_save.playtime in _process.
var is_tracking_playtime: bool = true

## Identifier of the active level, updated via EventBus.level_started.
var current_level_id: String = ""


func _ready() -> void:
	_ensure_saves_dir_exists()
	EventBus.level_started.connect(_on_level_started)


func _on_level_started(level_id: String) -> void:
	current_level_id = level_id
	if current_save != null:
		current_save.level_id = level_id


func _process(delta: float) -> void:
	if is_tracking_playtime and current_save != null and not get_tree().paused:
		current_save.playtime += delta


# --- Public Slot & File Management API ---

## Returns the absolute filesystem path for a given save slot.
func get_save_file_path(slot: int) -> String:
	return "%s/slot_%d.tres" % [SAVES_DIR, slot]


## Returns true if a valid save file exists for the given slot.
func has_save(slot: int) -> bool:
	return FileAccess.file_exists(get_save_file_path(slot))


## Scans the saves directory and returns a sorted list of all existing save slot numbers.
func list_save_slots() -> Array[int]:
	var slots: Array[int] = []
	var dir: DirAccess = DirAccess.open(SAVES_DIR)
	if dir == null:
		return slots

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with("slot_") and file_name.ends_with(".tres"):
			var slot_str: String = file_name.trim_prefix("slot_").trim_suffix(".tres")
			if slot_str.is_valid_int():
				slots.append(slot_str.to_int())
		file_name = dir.get_next()
	dir.list_dir_end()

	slots.sort()
	return slots


## Deletes the save file for a given slot from disk.
func delete_save(slot: int) -> Error:
	var path: String = get_save_file_path(slot)
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var err: Error = DirAccess.remove_absolute(path)
	if err != OK:
		push_error("Failed to delete save slot %d at %s: Error %d" % [slot, path, err])
	return err


## Reads and returns metadata for a save slot without loading it into active state.
func get_save_metadata(slot: int) -> Dictionary:
	var path: String = get_save_file_path(slot)
	if not FileAccess.file_exists(path):
		return {"exists": false}

	var loaded = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded is SaveData:
		return {
			"exists": true,
			"slot": loaded.save_slot,
			"version": loaded.version,
			"timestamp": loaded.timestamp,
			"playtime": loaded.playtime,
			"level_id": loaded.level_id
		}
	return {"exists": false, "corrupted": true}


## Initializes a fresh SaveData instance for a new game in the given slot.
func new_game(slot: int = 1) -> SaveData:
	current_slot = slot
	current_save = SaveData.create_default(slot)
	return current_save


# --- Save & Load Operations ---

## Gathers data from all nodes in the "saveable" group and writes the active save to disk.
func save_game(slot: int = current_slot) -> Error:
	EventBus.save_started.emit()
	_ensure_saves_dir_exists()

	if current_save == null:
		current_save = SaveData.create_default(slot)

	if current_save.level_id.is_empty() and not current_level_id.is_empty():
		current_save.level_id = current_level_id

	current_save.save_slot = slot
	current_save.timestamp = int(Time.get_unix_time_from_system())

	# Collect state from all nodes in the "saveable" group
	var saveables: Array[Node] = get_tree().get_nodes_in_group(SAVEABLE_GROUP)
	for node: Node in saveables:
		if node.has_method("get_save_data"):
			var key: String = _get_saveable_key(node)
			var data: Dictionary = node.get_save_data()
			current_save.node_states[key] = data

	var file_path: String = get_save_file_path(slot)
	var err: Error = ResourceSaver.save(current_save, file_path)
	if err != OK:
		push_error("Failed to save game to %s: Error %d" % [file_path, err])
		return err

	EventBus.save_completed.emit(slot)
	return OK


## Loads the save file for the given slot from disk and restores state to all "saveable" nodes.
func load_game(slot: int = current_slot) -> Error:
	var file_path: String = get_save_file_path(slot)
	if not FileAccess.file_exists(file_path):
		push_warning("Save file does not exist at %s" % file_path)
		return ERR_FILE_NOT_FOUND

	EventBus.load_started.emit()

	var loaded = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not (loaded is SaveData):
		push_error("Corrupted or invalid save file at %s" % file_path)
		return ERR_FILE_CORRUPT

	current_save = loaded
	current_slot = slot
	current_level_id = loaded.level_id

	# Restore state to all current nodes in the "saveable" group
	var saveables: Array[Node] = get_tree().get_nodes_in_group(SAVEABLE_GROUP)
	for node: Node in saveables:
		if node.has_method("apply_save_data"):
			var key: String = _get_saveable_key(node)
			if current_save.node_states.has(key):
				node.apply_save_data(current_save.node_states[key])

	EventBus.load_completed.emit(slot)
	return OK


# --- Internal Helpers ---

func _ensure_saves_dir_exists() -> void:
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		DirAccess.make_dir_recursive_absolute(SAVES_DIR)


## Generates a consistent, unique key for a saveable node without coupling to its class.
func _get_saveable_key(node: Node) -> String:
	if "save_id" in node and not str(node.save_id).is_empty():
		return str(node.save_id)
	if node.is_inside_tree():
		return str(node.get_path())
	return node.name
