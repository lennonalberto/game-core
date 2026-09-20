class_name HUD
extends CanvasLayer

## In-game heads-up display overlay.
##
## Architectural Rule: UI is reactive, not authoritative. HUD displays state
## received via EventBus signals (health, coins, score, checkpoints). It does NOT
## hold a direct reference to the player, level, or save managers.

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var coin_label: Label = %CoinLabel
@onready var score_label: Label = %ScoreLabel
@onready var checkpoint_banner: Label = %CheckpointBanner

var coins: int = 0
var score: int = 0
var current_health: int = 100
var max_health: int = 100

var _banner_tween: Tween = null


func _ready() -> void:
	_connect_event_bus()
	_update_health_display()
	_update_coin_display()
	_update_score_display()
	if checkpoint_banner:
		checkpoint_banner.visible = false


func _connect_event_bus() -> void:
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.coin_collected.connect(_on_coin_collected)
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.checkpoint_reached.connect(_on_checkpoint_reached)
	EventBus.level_started.connect(_on_level_started)


# --- Event Handlers ---

func _on_player_health_changed(current: int, max_hp: int) -> void:
	current_health = current
	max_health = max_hp
	_update_health_display()


func _on_coin_collected(amount: int) -> void:
	coins += amount
	_update_coin_display()


func _on_score_changed(new_score: int) -> void:
	score = new_score
	_update_score_display()


func _on_checkpoint_reached(_checkpoint_id: String, _position: Vector2) -> void:
	_show_checkpoint_banner()


func _on_level_started(_level_id: String) -> void:
	coins = 0
	score = 0
	_update_coin_display()
	_update_score_display()


# --- Display Helpers ---

func _update_health_display() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	if health_label:
		health_label.text = "%d / %d" % [current_health, max_health]


func _update_coin_display() -> void:
	if coin_label:
		coin_label.text = str(coins)


func _update_score_display() -> void:
	if score_label:
		score_label.text = str(score)


func _show_checkpoint_banner() -> void:
	if checkpoint_banner == null:
		return

	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()

	checkpoint_banner.visible = true
	checkpoint_banner.modulate.a = 1.0

	_banner_tween = create_tween()
	_banner_tween.tween_interval(1.5)
	_banner_tween.tween_property(checkpoint_banner, "modulate:a", 0.0, 0.5)
	_banner_tween.tween_callback(func(): checkpoint_banner.visible = false)


# --- Public Query API (for verification and unit tests) ---

func get_displayed_health() -> int:
	return current_health


func get_displayed_max_health() -> int:
	return max_health


func get_displayed_coins() -> int:
	return coins


func get_displayed_score() -> int:
	return score
