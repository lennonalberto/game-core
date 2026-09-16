extends Node

## Manages playback of music, ambient tracks, and sound effects.
##
## Architectural Rule: AudioManager reads volume configurations directly from
## SettingsManager or reacts to EventBus settings signals. It does not maintain
## its own divergent copy of volume settings.
## Audio streams are routed to designated engine audio buses ("Music" and "SFX").

const BUS_MASTER: String = "Master"
const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"
const SFX_POOL_SIZE: int = 8
const MUSIC_DIR: String = "res://assets/audio/music"
const SFX_DIR: String = "res://assets/audio/sfx"

## Dedicated audio player for background music tracks.
var music_player: AudioStreamPlayer

## Pre-allocated pool of audio players for sound effects.
var sfx_pool: Array[AudioStreamPlayer] = []

## Registry mapping String IDs to AudioStream resources.
var music_library: Dictionary = {}
var sfx_library: Dictionary = {}

## Identifier of the active music track, if any.
var current_music_id: String = ""

## Active tween for volume fading transitions.
var fade_tween: Tween = null


func _ready() -> void:
	_setup_music_player()
	_setup_sfx_pool()
	_connect_event_bus()
	_scan_audio_directories()


# --- Public Music API ---

## Plays background music track by resource or registered ID.
## Supports optional fade transitions in seconds.
func play_music(music: Variant, fade_duration: float = 0.0) -> void:
	var stream: AudioStream = _resolve_stream(music, music_library)
	if stream == null:
		push_warning("AudioManager: Could not resolve music stream for '%s'" % str(music))
		return

	if music_player.stream == stream and music_player.playing:
		return

	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()

	current_music_id = str(music) if music is String else ""

	if fade_duration > 0.0 and music_player.playing:
		fade_tween = create_tween()
		fade_tween.tween_property(music_player, "volume_db", -80.0, fade_duration * 0.5)
		fade_tween.tween_callback(func():
			music_player.stream = stream
			music_player.play()
			music_player.volume_db = -80.0
		)
		fade_tween.tween_property(music_player, "volume_db", 0.0, fade_duration * 0.5)
	else:
		music_player.volume_db = 0.0
		music_player.stream = stream
		music_player.play()


## Stops music playback immediately or with a fade-out transition.
func stop_music(fade_duration: float = 0.0) -> void:
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()

	if fade_duration > 0.0 and music_player.playing:
		fade_tween = create_tween()
		fade_tween.tween_property(music_player, "volume_db", -80.0, fade_duration)
		fade_tween.tween_callback(func():
			music_player.stop()
			music_player.stream = null
			music_player.volume_db = 0.0
			current_music_id = ""
		)
	else:
		music_player.stop()
		music_player.stream = null
		music_player.volume_db = 0.0
		current_music_id = ""


## Returns true if background music is actively playing.
func is_music_playing() -> bool:
	return music_player != null and music_player.playing


## Returns the ID of the current playing track, if set.
func get_current_music_id() -> String:
	return current_music_id


# --- Public SFX API ---

## Plays a sound effect by resource or registered ID.
## Acquires an idle player from the pool and returns it.
func play_sfx(sound: Variant, pitch_scale: float = 1.0, volume_offset_db: float = 0.0) -> AudioStreamPlayer:
	var stream: AudioStream = _resolve_stream(sound, sfx_library)
	if stream == null:
		push_warning("AudioManager: Could not resolve SFX stream for '%s'" % str(sound))
		return null

	var player: AudioStreamPlayer = _get_available_sfx_player()
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.volume_db = volume_offset_db
	player.play()
	return player


# --- Registration & Query API ---

## Registers an AudioStream resource under a String ID for music playback.
func register_music(id: String, stream: AudioStream) -> void:
	music_library[id] = stream


## Registers an AudioStream resource under a String ID for SFX playback.
func register_sfx(id: String, stream: AudioStream) -> void:
	sfx_library[id] = stream


## Reads the current linear volume directly from SettingsManager (Single Source of Truth).
func get_bus_volume(bus_name: String) -> float:
	return SettingsManager.get_volume(bus_name)


# --- Internal Setup & Helpers ---

func _setup_music_player() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = BUS_MUSIC
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music_player)


func _setup_sfx_pool() -> void:
	for i in range(SFX_POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.bus = BUS_SFX
		add_child(p)
		sfx_pool.append(p)


func _connect_event_bus() -> void:
	EventBus.volume_changed.connect(_on_volume_changed)
	EventBus.settings_changed.connect(_on_settings_changed)


func _get_available_sfx_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in sfx_pool:
		if not player.playing:
			return player

	# Pool exhausted: expand pool dynamically
	var new_player: AudioStreamPlayer = AudioStreamPlayer.new()
	new_player.name = "SFXPlayer_%d" % sfx_pool.size()
	new_player.bus = BUS_SFX
	add_child(new_player)
	sfx_pool.append(new_player)
	return new_player


func _resolve_stream(source: Variant, library: Dictionary) -> AudioStream:
	if source is AudioStream:
		return source
	if source is String:
		if library.has(source):
			return library[source]
		if ResourceLoader.exists(source):
			var res = ResourceLoader.load(source)
			if res is AudioStream:
				return res
	return null


func _scan_audio_directories() -> void:
	_scan_dir_into_library(MUSIC_DIR, music_library)
	_scan_dir_into_library(SFX_DIR, sfx_library)


func _scan_dir_into_library(dir_path: String, library: Dictionary) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and (file_name.ends_with(".ogg") or file_name.ends_with(".wav") or file_name.ends_with(".mp3")):
			var id: String = file_name.get_basename()
			var full_path: String = dir_path.path_join(file_name)
			var res = ResourceLoader.load(full_path)
			if res is AudioStream:
				library[id] = res
		file_name = dir.get_next()
	dir.list_dir_end()


# --- Event Handlers ---

func _on_volume_changed(bus_name: String, _linear_volume: float) -> void:
	# AudioServer bus volumes are updated by SettingsManager.
	# AudioManager handles any active player volume sync here if needed.
	pass


func _on_settings_changed() -> void:
	pass
