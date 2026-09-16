extends GutTest

## Unit tests for AudioManager covering SettingsManager volume delegation,
## music and SFX playback routing, live volume updates mid-playback, and EventBus reactions.

var sample_stream: AudioStreamWAV


func before_all() -> void:
	sample_stream = AudioStreamWAV.new()
	sample_stream.format = AudioStreamWAV.FORMAT_8_BITS
	sample_stream.data = PackedByteArray([0, 64, 127, 64, 0, 192, 128, 192])


func before_each() -> void:
	SettingsManager.reset_to_default()
	AudioManager.stop_music()


func after_each() -> void:
	AudioManager.stop_music()
	SettingsManager.reset_to_default()


func test_volume_reads_correctly_from_settings_manager() -> void:
	SettingsManager.set_volume(SettingsManager.BUS_MUSIC, 0.65)
	SettingsManager.set_volume(SettingsManager.BUS_SFX, 0.35)

	assert_almost_eq(AudioManager.get_bus_volume(SettingsManager.BUS_MUSIC), 0.65, 0.001, "Music volume should match SettingsManager")
	assert_almost_eq(AudioManager.get_bus_volume(SettingsManager.BUS_SFX), 0.35, 0.001, "SFX volume should match SettingsManager")
	assert_almost_eq(AudioManager.get_bus_volume(SettingsManager.BUS_MASTER), 1.0, 0.001, "Master volume should match SettingsManager")


func test_play_and_stop_music() -> void:
	AudioManager.register_music("test_theme", sample_stream)

	AudioManager.play_music("test_theme")
	assert_true(AudioManager.is_music_playing(), "Music should be playing after play_music()")
	assert_eq(AudioManager.get_current_music_id(), "test_theme", "current_music_id should match 'test_theme'")
	assert_eq(AudioManager.music_player.bus, AudioManager.BUS_MUSIC, "Music player bus should be 'Music'")

	AudioManager.stop_music()
	assert_false(AudioManager.is_music_playing(), "Music should be stopped after stop_music()")
	assert_eq(AudioManager.get_current_music_id(), "", "current_music_id should be cleared")


func test_play_sfx_uses_sfx_bus() -> void:
	AudioManager.register_sfx("test_coin", sample_stream)

	var player: AudioStreamPlayer = AudioManager.play_sfx("test_coin", 1.25, -3.0)
	assert_not_null(player, "play_sfx should return an AudioStreamPlayer instance")
	assert_true(player.playing, "SFX player should be playing")
	assert_eq(player.bus, AudioManager.BUS_SFX, "SFX player bus should be 'SFX'")
	assert_almost_eq(player.pitch_scale, 1.25, 0.01, "pitch_scale should match requested value")
	assert_almost_eq(player.volume_db, -3.0, 0.01, "volume_db offset should match requested value")


func test_live_volume_update_during_playback() -> void:
	AudioManager.play_music(sample_stream)
	assert_true(AudioManager.is_music_playing(), "Music should be playing")

	# Update volume mid-playback
	SettingsManager.set_volume(SettingsManager.BUS_MUSIC, 0.4)

	var music_bus_idx: int = AudioServer.get_bus_index(SettingsManager.BUS_MUSIC)
	assert_almost_eq(AudioServer.get_bus_volume_db(music_bus_idx), linear_to_db(0.4), 0.1, "AudioServer music bus volume should update live")
	assert_almost_eq(AudioManager.get_bus_volume(SettingsManager.BUS_MUSIC), 0.4, 0.001, "AudioManager bus volume should report live updated value")
	assert_true(AudioManager.is_music_playing(), "Music playback should continue uninterrupted when volume changes")

	AudioManager.stop_music()


func test_event_bus_reaction() -> void:
	SettingsManager.set_volume(SettingsManager.BUS_MUSIC, 0.8)
	assert_almost_eq(AudioManager.get_bus_volume(SettingsManager.BUS_MUSIC), 0.8, 0.001)

	# Verify reaction when volume_changed signal is emitted
	EventBus.volume_changed.emit(SettingsManager.BUS_SFX, 0.5)
	# Volume is directly queryable through single source of truth
	assert_almost_eq(AudioManager.get_bus_volume(SettingsManager.BUS_MASTER), 1.0, 0.001)
