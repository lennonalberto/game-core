class_name AchievementSaveData
extends Resource

## Data model for persistent achievement progression and unlock state.
##
## Architectural Rule: Achievements are saved to their own file on disk (user://achievements.tres),
## completely separated from settings and game save slots.

## Schema version for migration safeguards per AGENTS.md.
@export var version: int = 1

## Array of unique identifiers of all unlocked achievements.
@export var unlocked_achievements: Array[String] = []

## Dictionary mapping achievement IDs to their current progress integer.
@export var progress: Dictionary = {}

## Dictionary mapping unlocked achievement IDs to UNIX timestamps when unlocked.
@export var unlock_timestamps: Dictionary = {}


## Returns a duplicate of this AchievementSaveData instance.
func clone() -> AchievementSaveData:
	var dup: AchievementSaveData = AchievementSaveData.new()
	dup.version = version
	dup.unlocked_achievements = unlocked_achievements.duplicate()
	dup.progress = progress.duplicate()
	dup.unlock_timestamps = unlock_timestamps.duplicate()
	return dup


## Creates a fresh default AchievementSaveData instance.
static func create_default() -> AchievementSaveData:
	var data: AchievementSaveData = AchievementSaveData.new()
	data.version = 1
	data.unlocked_achievements = []
	data.progress = {}
	data.unlock_timestamps = {}
	return data
