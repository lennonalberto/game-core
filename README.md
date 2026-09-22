# 2D Game Template (Godot 4.x)

A clean, modular, and scalable starting point for 2D games in Godot 4.x. Provides foundational architecture, decoupled event-driven systems, persistent user preferences, slot-based game saves, data-driven achievements, audio management, reactive UI overlays, and unit & integration testing via GUT.

---

## Current Status: All Phases Complete (Phases 0 — 4)

The core architectural skeleton, foundational managers, placeholder gameplay systems, full UI suite, and end-to-end integration passes have been implemented, verified, and unit-tested:

- [x] **Phase 0 — Skeleton**: Clean folder structure, autoload order, initial input map, decoupled EventBus signal hub, and GUT test runner setup.
- [x] **Phase 1.1 — SettingsManager**: Audio bus layout, `SettingsData` resource, live `InputMap` key rebinding, display options, and isolated persistence.
- [x] **Phase 1.2 — SaveManager**: `SaveData` resource, slot-based persistence, contract-based `"saveable"` group iteration, and multi-slot isolation.
- [x] **Phase 1.3 — AchievementManager**: `AchievementDefinition` and `AchievementSaveData` resources, data-driven `.tres` discovery, progress tracking, and EventBus signal integration.
- [x] **Phase 1.4 — AudioManager**: Background music routing with fades, sound effects pooling, strict `SettingsManager` volume delegation, and live playback volume reactivity.
- [x] **Phase 2.1 — Player & State Machine**: Generic `StateMachine` framework, `CharacterBody2D` Player with movement states (`Idle`, `Run`, `Jump`, `Fall`, `Die`), `HitboxComponent`, `"saveable"` contract integration without persisting state names, and decoupled `EventBus` signals.
- [x] **Phase 2.2 — Pickup (Coin)**: `Area2D` coin pickup, `EventBus.coin_collected` emission, end-to-end integration with `"coin_collector"` achievement, and saveable persistence.
- [x] **Phase 2.3 — Level + Checkpoint**: `PlatformerDemo` level with platforms, player, coins, and `Checkpoint` trigger. Automatically records `level_id` into `SaveData` via `EventBus.level_started` and unlocks `"checkpoint_reached"` achievement.
- [x] **Phase 3.1 — HUD Overlay**: Reactive `CanvasLayer` displaying health bar/label, coin counter, score, and animated checkpoint banner without direct references to gameplay entities.
- [x] **Phase 3.2 — Achievement Popup**: Non-overlapping toast overlay with FIFO queue displaying unlocked achievements sequentially via smooth tween animations.
- [x] **Phase 3.3 — Pause Menu**: `process_mode = PROCESS_MODE_ALWAYS` pause overlay freezing the scene tree, handling keyboard/controller/mouse navigation, with Resume, Settings, and Quit to Main Menu options.
- [x] **Phase 3.4 — Settings Menu**: Reusable settings modal featuring Audio volume sliders, Controls tab with interactive capture-a-key rebinding, Video options (Window Mode, V-Sync), and Reset to Default.
- [x] **Phase 3.5 — Main Menu**: Complete game entry point (`run/main_scene`) with New Game, dynamic Continue (enabled only when a save exists), embedded Settings, and Quit, routed through `GameManager`.
- [x] **Phase 4 — Integration Pass**: End-to-end validation of the full game loop (Main Menu → Play → Checkpoint Save → Pause → Settings → Main Menu → Continue), verification of independent persistence domains, multi-slot isolation, and architectural decoupling.

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
- **Registry**: Automatically registers audio files from `res://assets/audio/music/` and `res://assets/audio/sfx/`.

### 6. Generic State Machine Framework (`scenes/entities/state_machine/`)
A modular, node-based finite state machine framework reusable across any entity:
- **Base State Class**: `State` (`scenes/entities/state_machine/state.gd`) exposes lifecycle hooks (`enter`, `exit`, `physics_update`, `handle_input`), a typed `entity` getter resolving the controlling `CharacterBody2D`, and emits `transitioned(new_state_name, msg)`.
- **StateMachine Controller**: `StateMachine` (`scenes/entities/state_machine/state_machine.gd`) auto-discovers child states on `_ready()`, validates transitions, ensures previous states exit before new ones enter, and safely ignores signals from inactive states.
- **Signal Ownership**: States (not entities or managers) emit gameplay `EventBus` signals directly as the source of truth (e.g. `player_jumped`, `player_landed`, `player_died`).

### 7. Player Entity & Components (`scenes/entities/player/`)
A generic `CharacterBody2D` platformer player with static GDScript typing:
- **Zero Movement Branching**: `_physics_process()` strictly delegates to `state_machine.physics_update(delta)`.
- **Movement States**: `IdleState`, `RunState`, `JumpState`, `FallState`, `DieState`.
- **HitboxComponent**: Reusable `HitboxComponent` (`scenes/entities/components/hitbox_component.gd`) handling damage reception.
- **Saveable Contract**: Persists `position`, `velocity`, and `health`. Does **not** persist state names — the state machine self-resolves dynamically on load from physical state (`is_on_floor()`, `velocity`).

### 8. Reactive UI Suite (`scenes/ui/`)
All UI screens are strictly reactive and decoupled from authoritative game state:
- **HUD (`scenes/ui/hud/`)**: Displays player health, coin counter, score, and animated checkpoint confirmation.
- **Achievement Popup (`scenes/ui/achievement_popup/`)**: Queued toast notification overlay displaying unlocks sequentially without overlapping.
- **Pause Menu (`scenes/ui/pause_menu/`)**: Pauses tree via `get_tree().paused = true` while retaining full keyboard/gamepad focus.
- **Settings Menu (`scenes/ui/settings/`)**: Reusable settings modal with Audio sliders, Controls rebinding with capture flow, Video mode selector, and Reset to Default.
- **Main Menu (`scenes/ui/main_menu/`)**: Configured as `run/main_scene`, offering New Game, Continue (disabled if no save exists), Settings, and Quit.

### 9. Platformer Demo Level (`scenes/levels/platformer_demo/`)
Playable demo level containing solid ground, platforms, Player, Coins (`coin_demo_1`..`3`), Checkpoint trigger, HUD, AchievementPopup, and PauseMenu.

---

## Testing & Quality Assurance

The template uses [GUT (Godot Unit Test)](https://github.com/bitwes/Gut) (`v9.7.1`) installed under `addons/gut/`.

### Running Unit Tests Headless
You can execute the entire test suite from the terminal:
```powershell
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit
```

### Test Coverage (86/86 Passing across 14 Test Suites)
- **`tests/unit/test_settings_manager.gd`** (6 tests): Audio bus updates, key rebinding, reset-to-default, persistence, and fallback.
- **`tests/unit/test_save_manager.gd`** (7 tests): SaveData round-trip, saveable contract group iteration, slot isolation, and corrupt file handling.
- **`tests/unit/test_achievement_manager.gd`** (6 tests): Definition discovery, single-fire unlocks, progressive accumulation, and reload persistence.
- **`tests/unit/test_audio_manager.gd`** (5 tests): Volume delegation, music routing/fading, SFX pooling, and live reactivity.
- **`tests/unit/test_state_machine.gd`** (5 tests): State discovery, enter/exit lifecycle, inactive transition rejection, and idempotency.
- **`tests/unit/test_player.gd`** (8 tests): Components, saveable contract, jump/fall/die states, hitbox damage, and airborne resolution.
- **`tests/unit/test_coin.gd`** (5 tests): Collection detection, achievement progress, and saveable persistence.
- **`tests/unit/test_level.gd`** (4 tests): Platformer demo scene hierarchy, level started signals, and checkpoint save cycle.
- **`tests/unit/test_hud.gd`** (6 tests): Reactive health, coin, score updates, checkpoint banner animation, and decoupling.
- **`tests/unit/test_achievement_popup.gd`** (4 tests): Initial state, toast display, sequential FIFO queuing without overlap, and decoupling.
- **`tests/unit/test_pause_menu.gd`** (9 tests): Tree freezing, always-processing UI, resume/settings/quit button actions, and decoupling.
- **`tests/unit/test_settings_menu.gd`** (10 tests): Live audio sliders, key rebind flow, Escape-to-cancel, reset-to-default, and session persistence.
- **`tests/unit/test_main_menu.gd`** (6 tests): Save availability detection, navigation routing via GameManager, and full loop verification.
- **`tests/unit/test_integration.gd`** (5 tests): End-to-end lifecycle, persistence domain isolation (Settings vs Saves vs Achievements), multi-slot isolation, and architectural contracts.

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
