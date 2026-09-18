# 2D Game Template (Godot 4.x)

A clean, modular, and scalable starting point for 2D games in Godot 4.x. Provides foundational architecture, decoupled event-driven systems, persistent user preferences, slot-based game saves, data-driven achievements, audio management, and unit testing via GUT.

---

## Current Status: Phase 0, Phase 1 & Phase 2 Complete

The core architectural skeleton, foundational managers, and placeholder gameplay systems have been implemented, verified, and unit-tested:

- [x] **Phase 0 — Skeleton**: Clean folder structure, autoload order, initial input map, decoupled EventBus signal hub, and GUT test runner setup.
- [x] **Phase 1.1 — SettingsManager**: Audio bus layout, `SettingsData` resource, live `InputMap` key rebinding, display options, and isolated persistence.
- [x] **Phase 1.2 — SaveManager**: `SaveData` resource, slot-based persistence, contract-based `"saveable"` group iteration, and multi-slot isolation.
- [x] **Phase 1.3 — AchievementManager**: `AchievementDefinition` and `AchievementSaveData` resources, data-driven `.tres` discovery, progress tracking, and EventBus signal integration.
- [x] **Phase 1.4 — AudioManager**: Background music routing with fades, sound effects pooling, strict `SettingsManager` volume delegation, and live playback volume reactivity.
- [x] **Phase 2.1 — Player & State Machine**: Generic `StateMachine` framework, `CharacterBody2D` Player with movement states (`Idle`, `Run`, `Jump`, `Fall`, `Die`), `HitboxComponent`, `"saveable"` contract integration without persisting state names, and decoupled `EventBus` signals.
- [x] **Phase 2.2 — Pickup (Coin)**: `Area2D` coin pickup, `EventBus.coin_collected` emission, end-to-end integration with `"coin_collector"` achievement, and saveable persistence.
- [x] **Phase 2.3 — Level + Checkpoint**: `PlatformerDemo` level with platforms, player, coins, and `Checkpoint` trigger. Automatically records `level_id` into `SaveData` via `EventBus.level_started` and unlocks `"checkpoint_reached"` achievement.
- [ ] **Phase 3 — Core UI** *(Upcoming)*
- [ ] **Phase 4 — Integration Pass** *(Upcoming)*

---

## Implemented Architecture & Systems

### 1. EventBus (`autoloads/event_bus.gd`)
A centralized, typed signal hub that decouples gameplay, UI, and persistence managers:
- **Lifecycle Signals**: `game_started`, `game_paused(is_paused: bool)`, `level_started(level_id: String)`, `level_completed(level_id: String)`, `checkpoint_reached(checkpoint_id: String, position: Vector2)`.
- **Gameplay & Player Signals**: `player_spawned(player: Node2D)`, `player_jumped`, `player_landed`, `player_died`, `player_health_changed(current_health: int, max_health: int)`.
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

### 6. Generic State Machine Framework (`scenes/entities/state_machine/`)
A modular, node-based finite state machine framework reusable across any entity:
- **Base State Class**: `State` (`scenes/entities/state_machine/state.gd`) exposes lifecycle hooks (`enter`, `exit`, `physics_update`, `handle_input`), a typed `entity` getter resolving the controlling `CharacterBody2D`, and emits `transitioned(new_state_name, msg)`.
- **StateMachine Controller**: `StateMachine` (`scenes/entities/state_machine/state_machine.gd`) auto-discovers child states on `_ready()`, validates transitions, ensures previous states exit before new ones enter, and safely ignores signals from inactive states.
- **Signal Ownership**: States (not entities or managers) emit gameplay `EventBus` signals directly as the source of truth (e.g. `player_jumped`, `player_landed`, `player_died`).

### 7. Player Entity & Components (`scenes/entities/player/`)
A generic `CharacterBody2D` platformer player with static GDScript typing:
- **Zero Movement Branching**: `_physics_process()` strictly delegates to `state_machine.physics_update(delta)`.
- **Movement States**:
  - `IdleState`: Decelerates horizontally, resolves airborne states if not on floor, transitions to `Run` or `Jump`.
  - `RunState`: Horizontal velocity input, sprite flip orientation, transitions to `Idle`, `Jump`, or `Fall`.
  - `JumpState`: Vertical impulse, emits `EventBus.player_jumped`, air steering, transitions to `Fall` upon vertical apex (`velocity.y >= 0`).
  - `FallState`: Applies gravity, air steering, detects floor collision to emit `EventBus.player_landed`, and transitions to `Idle` or `Run`.
  - `DieState`: Depleted health handler, halts movement, and emits `EventBus.player_died`.
- **HitboxComponent**: Reusable `HitboxComponent` (`scenes/entities/components/hitbox_component.gd`) handling damage reception.
- **Saveable Contract**: Persists `position`, `velocity`, and `health`. Does **not** persist state names — the state machine self-resolves dynamically on load from physical state (`is_on_floor()`, `velocity`).

### 8. Collectibles & Checkpoints (`scenes/entities/pickups/`, `scenes/entities/checkpoint/`)
- **Coin Pickup (`scenes/entities/pickups/coin.gd`)**: `Area2D` that detects player overlap, emits `EventBus.coin_collected(value)`, visually and collision-wise deactivates, and implements the `"saveable"` contract so collected coins stay collected after saving.
- **Checkpoint Trigger (`scenes/entities/checkpoint/checkpoint.gd`)**: `Area2D` that detects player overlap, turns green, emits `EventBus.checkpoint_reached` (which automatically unlocks the `"checkpoint_reached"` achievement), triggers `SaveManager.save_game()`, and persists its state.

### 9. Platformer Demo Level (`scenes/levels/platformer_demo/`)
Playable demo level (`platformer_demo.tscn`) configured as `run/main_scene`:
- Contains solid ground and platforms, Player instance, 3 Coins (`coin_demo_1`, `coin_demo_2`, `coin_demo_3`), and Checkpoint trigger.
- Emits `EventBus.level_started("platformer_demo")` on `_ready()`.
- `SaveManager` automatically listens to `level_started` to record `level_id` into `SaveData` during saves, completely decoupling the level from save managers.

---

## Testing & Quality Assurance

The template uses [GUT (Godot Unit Test)](https://github.com/bitwes/Gut) (`v9.7.1`) installed under `addons/gut/`.

### Running Unit Tests Headless
You can execute the entire test suite from the terminal:
```powershell
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit
```

### Test Coverage (46/46 Passing)
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
- **`tests/unit/test_state_machine.gd`** (5 tests):
  - Child state discovery and default initial state
  - Explicit initial state assignment
  - State enter/exit lifecycle and payload propagation
  - Rejection of transitions from inactive states
  - Idempotent self-transitions (no-op)
- **`tests/unit/test_player.gd`** (8 tests):
  - Scene node structure and component verification
  - Saveable contract round-trip (position, velocity, health) without persisting state name
  - SaveManager group integration
  - Jump state entering emits `EventBus.player_jumped`
  - Vertical apex transitions from Jump to Fall
  - Hitbox damage reception and Die state transition emitting `EventBus.player_died`
  - Airborne self-resolution upon loading mid-air save
  - Real 2D collision landing with StaticBody2D emitting `EventBus.player_landed`
- **`tests/unit/test_coin.gd`** (5 tests):
  - Scene structure, components, and saveable group membership
  - Player overlap detection, single-fire collection, and hiding
  - Non-player body rejection
  - End-to-end achievement progression and unlock (`coin_collector`)
  - Saveable contract persistence round-trip via SaveManager
- **`tests/unit/test_level.gd`** (4 tests):
  - Platformer demo scene hierarchy and coin placement
  - Level started signal updates `SaveManager.current_level_id`
  - Checkpoint trigger emits `checkpoint_reached` and unlocks achievement
  - Full cycle Definition of Done: coin collection -> checkpoint hit -> save -> reload restoring player position, level ID, and coin collection state

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
  entities/          Player, enemies, pickups, checkpoint, components, state_machine
    checkpoint/      Checkpoint trigger (checkpoint.gd, checkpoint.tscn)
    components/      Reusable components (hitbox_component.gd)
    pickups/         Collectible items (coin.gd, coin.tscn)
    player/          Player CharacterBody2D (player.gd, player.tscn, states/)
    state_machine/   Generic FSM framework (state.gd, state_machine.gd)
  levels/            Playable levels and demo scenes
    platformer_demo/ PlatformerDemo level (platformer_demo.gd, platformer_demo.tscn)
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
