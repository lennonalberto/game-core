class_name AchievementDefinition
extends Resource

## Data model for an achievement definition.
##
## Architectural Rule: Achievements are defined as custom Resources (.tres instances),
## not hardcoded in manager code. New achievements can be added by creating resource
## files without modifying manager code.

## Unique identifier for this achievement (e.g. "first_step", "coin_collector").
@export var id: String = ""

## Display title shown in popups and menus.
@export var title: String = ""

## Detailed description explaining how to unlock this achievement.
@export_multiline var description: String = ""

## Optional icon texture for display in UI toasts and achievement menus.
@export var icon: Texture2D = null

## Target progress count required to unlock (1 for one-time unlocks, >1 for progressive goals).
@export var target_progress: int = 1

## If true, details are obscured in UI until unlocked.
@export var is_hidden: bool = false
