class_name HitboxComponent
extends Area2D

## Reusable entity component for collision and damage interactions.
##
## Architectural Rule: Direct references are fine within a single scene
## (e.g. Player -> HitboxComponent). This component acts as a generic contact
## or damage receiver/dealer attached to entities.

signal hit_received(damage: int)

@export var damage: int = 10


## Applies damage through this component, notifying listeners (such as the owning entity).
func take_damage(amount: int) -> void:
	hit_received.emit(amount)
