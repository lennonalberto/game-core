# 2D Game Template (Godot 4.x)

A clean, modular, and scalable starting point for 2D games in Godot 4.x. Provides foundational architecture, decoupled event-driven systems, persistent user preferences, slot-based game saves, data-driven achievements, audio management, and unit testing via GUT.

---

## Current Status: Phase 0 & Phase 1 Complete

The core architectural skeleton and all foundational managers have been implemented, verified, and unit-tested:

- [x] **Phase 0 — Skeleton**: Clean folder structure, autoload order, initial input map, decoupled EventBus signal hub, and GUT test runner setup.
- [x] **Phase 1.1 — SettingsManager**: Audio bus layout, `SettingsData` resource, live `InputMap` key rebinding, display options, and isolated persistence.
- [x] **Phase 1.2 — SaveManager**: `SaveData` resource, slot-based persistence, contract-based `"saveable"` group iteration, and multi-slot isolation.
- [x] **Phase 1.3 — AchievementManager**: `AchievementDefinition` and `AchievementSaveData` resources, data-driven `.tres` discovery, progress tracking, and EventBus signal integration.
- [x] **Phase 1.4 — AudioManager**: Background music routing with fades, sound effects pooling, strict `SettingsManager` volume delegation, and live playback volume reactivity.
- [ ] **Phase 2 — Placeholder Gameplay** *(Upcoming)*
- [ ] **Phase 3 — Core UI** *(Upcoming)*
- [ ] **Phase 4 — Integration Pass** *(Upcoming)*

---

## Implemented Architecture & Systems

### 1. EventBus (`autoloads/event_bus.gd`)
A centralized, typed signal hub that decouples gameplay, UI, and persistence managers:
- **Lifecycle Signals**: `game_started`, `game_paused(is_paused: bool)`, `level_started(level_id: String)`, `level_completed(level_id: String)`, `checkpoint_reached(checkpoint_id: String, position: Vector2)`.
- **Gameplay & Player Signals**: `player_spawned(player: Node2D)`, `player_jumped`, `player_died`, `player_health_changed(current_health: int, max_health: int)`.
- **Collectibles Signals**: `coin_collected(amount: int)`, `score_changed(new_score: int)`.
- **Settings Signals**: `settings_changed`, `volume_changed(bus_name: String, volume_linear: float)`.
- **Save/Load Signals**: `save_started`, `save_completed(slot: int)`, `load_started`, `load_completed(slot: int)`.
- **Achievement Signals**: `achievement_unlocked(id: String, title: String, description: String)`, `achievement_progress_updated(id: String, current: int, max: int)`.

### 2. SettingsManager (`autoloads/settings_manager.gd`)
The single source of truth for user preferences:
- **Audio Integration**: Controls `Master`, `Music`, and `SFX` buses on `AudioServer` with live linear-to-dB conversion and muting at `0.0`.
- **Controls & Keybinding**: Live query and rebinding of `InputMap` actions (`get_keybinds()`, `set_keybind()`).
- **Display Options**: Window mode (`DisplayServer.WindowMode`) and V-Sync configuration.
- **Persistence**: Stored independently in `user://settings.tres` using `SettingsData` (`resources/settings/settings_data.gd`).
- **Reset**: `reset_to_default()` restores baseline volumes, initial keybindings, and display settings.

### 3. SaveManager (`autoloads/save_manager.gd`)
Orchestrates game state persistence across multiple independent save slots (`user://saves/slot_<slot_id>.tres`):
- **Saveable Contract**: Iterates nodes in the `"saveable"` group. Any persistent node implements:
  - `get_save_data() -> Dictionary`
  - `apply_save_data(data: Dictionary) -> void`
  - `SaveManager` contains zero hardcoded references to specific gameplay classes.
- **Save Data Model**: `SaveData` (`resources/save/save_data.gd`) tracks `version`, `save_slot`, `timestamp`, `playtime`, `level_id`, `player_state`, `collected_items`, and `node_states`.
- **Slot Management**: Supports `has_save()`, `list_save_slots()`, `delete_save()`, and `get_save_metadata()`.
- **Robust Error Handling**: Missing files return `ERR_FILE_NOT_FOUND`; corrupt files return `ERR_FILE_CORRUPT` without crashing.

### 4. AchievementManager (`autoloads/achievement_manager.gd`)
A fully data-driven achievement system:
- **Data as Resources**: Achievements are `.tres` instances of `AchievementDefinition` (`resources/achievements/achievement_definition.gd`). Adding a new achievement requires adding a file to `data/achievements/`, no code changes.
- **Sample Achievements Included**:
  - `first_step.tres` ("First Step" — target: 1)
  - `coin_collector.tres` ("Treasure Hunter" — target: 5 coins)
  - `checkpoint_reached.tres` ("Safe Haven" — target: 1)
- **Progress & Unlocks**: Supports one-time unlocks and progressive achievements (`add_progress()`). Unlock signals fire **exactly once** per achievement.
- **Persistence**: Saved independently in `user://achievements.tres` using `AchievementSaveData` (`resources/achievements/achievement_save_data.gd`).
- **EventBus Integration**: Automatically advances progress or unlocks via `EventBus.coin_collected`, `EventBus.checkpoint_reached`, and `EventBus.player_jumped`.

### 5. AudioManager (`autoloads/audio_manager.gd`)
Unified sound and music playback:
- **Music Playback**: Plays on the `"Music"` bus using `PROCESS_MODE_ALWAYS` so music continues during pause. Supports optional smooth fade-in and fade-out transitions.
- **SFX Pooling**: Pre-allocated pool of `AudioStreamPlayer` nodes on the `"SFX"` bus, dynamically expanding if exhausted.
- **Single Source of Truth**: Delegates volume queries to `SettingsManager.get_volume()`.
- **Live Reactivity**: Volume adjustments mid-playback update the audio bus live without interrupting playback.
- **Registry**: Automatically registers audio files from `res://assets/audio/music/` and `res://assets/audio/sfx/`, with programmatic `register_music()` and `register_sfx()` methods.

---

## Testing & Quality Assurance

The template uses [GUT (Godot Unit Test)](https://github.com/bitwes/Gut) (`v9.7.1`) installed under `addons/gut/`.

### Running Unit Tests Headless
You can execute the entire test suite from the terminal:
```powershell
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit
```

### Test Coverage (24/24 Passing)
- **`tests/unit/test_settings_manager.gd`** (6 tests):
  - Audio bus volume updates & mute behavior
  - Keybind rebinding & `InputMap` updates
  - `reset_to_default()` baseline restoration
  - Disk persistence round-trip
  - Graceful fallback on missing file
  - `EventBus` signal emissions
- **`tests/unit/test_save_manager.gd`** (7 tests):
  - `SaveData` round-trip fidelity
  - `"saveable"` group collection & restoration via `DummySaveable` fixture
  - Multi-slot isolation (slots 20 & 21 do not clobber each other)
  - Graceful failure on missing file (`ERR_FILE_NOT_FOUND`)
  - Graceful failure on corrupt file (`ERR_FILE_CORRUPT`)
  - Metadata reading
  - `EventBus` save/load signals
- **`tests/unit/test_achievement_manager.gd`** (6 tests):
  - Startup discovery of `.tres` definitions
  - Single-fire unlock signal behavior
  - Progressive accumulation and auto-unlock at target
  - Unlocks and progress persistence across reload
  - Reactive unlocking via `EventBus` signals
  - Graceful fallback on missing file
- **`tests/unit/test_audio_manager.gd`** (5 tests):
  - Volume delegation to `SettingsManager`
  - Music playback routing and stopping
  - SFX playback pooling and pitch/volume tuning
  - Live volume adjustments during active playback
  - `EventBus` signal reactions

---

## Project Structure

```
autoloads/           Singletons (EventBus, GameManager, SettingsManager, SaveManager, AchievementManager, AudioManager)
resources/           Custom Resource class definitions (.gd)
  achievements/      AchievementDefinition, AchievementSaveData
  save/              SaveData
  settings/          SettingsData
data/                Resource instances (.tres) + runtime data
  achievements/      Sample achievement definitions (first_step, coin_collector, checkpoint_reached)
  saves/             Runtime save slots (gitignored)
scenes/
  main/              Game bootstrap scene
  ui/                UI menus, HUD, pause, settings, components
  entities/          Player, enemies, pickups
  levels/            Playable levels and demo scenes
assets/              Sprites, audio (music, sfx), fonts, themes
tests/
  unit/              GUT unit test files (test_*.gd)
  helpers/           Shared test fixtures (dummy_saveable.gd)
addons/gut/          Godot Unit Test framework
default_bus_layout.tres Audio bus configuration (Master, Music, SFX)
```

---

## Core Architecture Rules

1. **Autoloads are the only singletons.** Business logic lives in `autoloads/`. Never cache autoload state elsewhere.
2. **Decouple via EventBus.** Gameplay, UI, and managers communicate through signals, avoiding direct cross-branch references.
3. **Data as Resources.** Settings, save games, and achievement definitions are custom `Resource` subclasses (`.gd` + `.tres`).
4. **Saveable Contract.** Persistent nodes join the `"saveable"` group and implement `get_save_data()` and `apply_save_data()`.
5. **Separation of Concerns on Disk.** Settings (`user://settings.tres`), save slots (`user://saves/slot_<N>.tres`), and achievements (`user://achievements.tres`) are strictly separated files.
6. **UI is reactive.** Menus and HUD display state and forward input; they do not own authoritative game state.

---

## Requirements

- **Godot 4.x** (Forward+ or Mobile rendering)
- **GUT 9.x** (Included in `addons/gut/`)

---

## License

*(fill in your license here)*
