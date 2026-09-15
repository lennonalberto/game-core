class_name SaveData
extends Resource

## Data model for persistent gameplay save slots.
##
## Architectural Rule: Save games are persisted as custom Resource subclasses (.tres instances),
## not raw dictionaries or JSON blobs scattered in code. This file is stored under user://saves/
## and is completely separated from settings and achievements on disk.

## Schema version for migration safeguards per AGENTS.md.
@export var version: int = 1

## The slot number this save file corresponds to (e.g. 1, 2, 3).
@export var save_slot: int = 1

## UNIX timestamp recorded at the moment of saving.
@export var timestamp: int = 0

## Accumulated gameplay time in seconds.
@export var playtime: float = 0.0

## Identifier of the level or scene where the save occurred.
@export var level_id: String = ""

## Persistent player state (health, position, powerups, etc.).
@export var player_state: Dictionary = {}

## Array of unique identifiers for collected items (coins, keys, secrets).
@export var collected_items: Array[String] = []

## Generic dictionary mapping saveable node identifiers to their individual save data dictionaries.
## Used by SaveManager to restore nodes implementing the "saveable" contract.
@export var node_states: Dictionary = {}


## Returns a duplicate of this SaveData instance.
func clone() -> SaveData:
	var dup: SaveData = SaveData.new()
	dup.version = version
	dup.save_slot = save_slot
	dup.timestamp = timestamp
	dup.playtime = playtime
	dup.level_id = level_id
	dup.player_state = player_state.duplicate(true)
	dup.collected_items = collected_items.duplicate()
	dup.node_states = node_states.duplicate(true)
	return dup


## Creates a fresh default SaveData instance for a new game slot.
static func create_default(slot: int = 1) -> SaveData:
	var data: SaveData = SaveData.new()
	data.version = 1
	data.save_slot = slot
	data.timestamp = int(Time.get_unix_time_from_system())
	data.playtime = 0.0
	data.level_id = ""
	data.player_state = {}
	data.collected_items = []
	data.node_states = {}
	return data
