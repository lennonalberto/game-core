extends Node

## Central coordinator for high-level game state, scene transitions, and game flow.
##
## Architectural Rule: Gameplay scenes and UI menus should not switch scenes or
## alter top-level game state directly. They request transitions or state changes
## via signals or through this manager, keeping tree management in one authoritative place.
