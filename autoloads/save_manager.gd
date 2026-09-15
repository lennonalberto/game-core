extends Node

## Coordinates persistence of gameplay state across save slots.
##
## Architectural Rule: SaveManager must never contain hardcoded references to
## specific gameplay nodes. Any node requiring persistence must join the "saveable"
## group and implement the saveable contract:
##   - get_save_data() -> Dictionary
##   - apply_save_data(data: Dictionary) -> void
## SaveManager strictly iterates over the "saveable" tree group.
