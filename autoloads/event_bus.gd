extends Node

## Central event hub that decouples gameplay, UI, and managers.
##
## Architectural Rule: Gameplay nodes, UI, and managers should not hold direct
## references to each other where avoidable. Instead, emit and listen to signals
## declared on this bus. Direct references are reserved for tightly-coupled nodes
## within the same isolated scene (e.g., Player -> HitboxComponent).
##
## Connect using signal objects (e.g., EventBus.coin_collected.connect(...))
## rather than string literal names to benefit from static type checks and autocomplete.

# --- Game Lifecycle & Navigation Signals ---
# Emitted to coordinate high-level flow without scenes knowing about each other.
signal game_started
signal game_paused(is_paused: bool)
signal level_started(level_id: String)
signal level_completed(level_id: String)
signal checkpoint_reached(checkpoint_id: String, position: Vector2)

# --- Player & Gameplay Signals ---
# Emitted by gameplay entities to notify UI (HUD) and managers without tight coupling.
signal player_spawned(player: Node2D)
signal player_jumped
signal player_died
signal player_health_changed(current_health: int, max_health: int)

# --- Pickups & Collectibles Signals ---
# Emitted when items are gathered; listened to by HUD and AchievementManager.
signal coin_collected(amount: int)
signal score_changed(new_score: int)

# --- Settings & Options Signals ---
# Emitted when user configuration changes so audio buses and input maps can react.
signal settings_changed
signal volume_changed(bus_name: String, volume_linear: float)

# --- Save & Load Signals ---
# Emitted during persistence cycles to inform UI or gameplay managers of save activity.
signal save_started
signal save_completed(slot: int)
signal load_started
signal load_completed(slot: int)

# --- Achievement Signals ---
# Emitted when achievements make progress or unlock to feed UI notification toasts.
signal achievement_unlocked(achievement_id: String, title: String, description: String)
signal achievement_progress_updated(achievement_id: String, current: int, max: int)
