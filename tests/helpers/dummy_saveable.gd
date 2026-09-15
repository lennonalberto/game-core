extends Node

## Minimal dummy node implementing the "saveable" contract for unit testing.
##
## Architectural Rule: SaveManager only ever interacts with the "saveable" group
## and calls get_save_data() and apply_save_data(). It never references specific
## node classes.

var save_id: String = ""
var health: int = 100
var coins: int = 0
var custom_tag: String = "hero"


func _enter_tree() -> void:
	add_to_group("saveable")


func get_save_data() -> Dictionary:
	return {
		"health": health,
		"coins": coins,
		"custom_tag": custom_tag
	}


func apply_save_data(data: Dictionary) -> void:
	health = data.get("health", health)
	coins = data.get("coins", coins)
	custom_tag = data.get("custom_tag", custom_tag)
