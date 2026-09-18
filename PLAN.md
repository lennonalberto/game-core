# PLAN.md

Build order for the 2D game template. Work through phases **in order** — each item should be verified against its "Definition of Done" before moving to the next. Don't start UI (Phase 3) items before the manager/gameplay signals they bind to already exist and work.

See `AGENTS.md` for architectural rules that apply throughout, and the architecture doc for folder structure and system design.

---

## Phase 0 — Skeleton

- [ ] Create full folder structure (`autoloads/`, `resources/`, `data/`, `scenes/ui/...`, `scenes/entities/...`, `scenes/levels/...`, `assets/...`)
- [ ] Register autoload scripts in Project Settings (order: EventBus, GameManager, SettingsManager, SaveManager, AchievementManager, AudioManager)
- [ ] Define initial Input Map actions (movement, jump, pause) — unbound keys are fine for now
- [ ] Write `EventBus.gd` — signal declarations only, no logic
- [ ] Install GUT (`addons/gut/`), enable the plugin, create `tests/unit/` and `tests/helpers/` folders

**Definition of Done:** Project opens with no errors; all autoloads are registered and empty/stubbed; `EventBus` signals are declared and visible in code completion elsewhere; GUT panel appears in the editor and runs an empty test suite successfully.

---

## Phase 1 — Foundational Managers

### 1. SettingsManager
- [ ] Define `SettingsData` Resource (master/music/sfx volume, keybind map, video options)
- [ ] Load/save `SettingsData` to its own file, separate from save games
- [ ] Apply volume values to audio buses
- [ ] Apply keybind values to `InputMap`
- [ ] Expose `reset_to_default()`
- [ ] Write `tests/unit/test_settings_manager.gd` covering volume changes, keybind changes, and reset-to-default

**Definition of Done:** Changing a value via a debug script or inspector call persists across a full editor restart; `test_settings_manager.gd` passes under GUT.

### 2. SaveManager
- [ ] Define `SaveData` Resource (player state, level id, collected items, playtime, version field)
- [ ] Implement save/load to file, support multiple slots
- [ ] Implement `"saveable"` group iteration — call `get_save_data()` / `apply_save_data()` on all members
- [ ] Test with one dummy saveable node (no real gameplay yet) — implement as `tests/helpers/dummy_saveable.gd`
- [ ] Write `tests/unit/test_save_manager.gd` covering round-trip save/load, multiple slots not clobbering each other, and graceful failure on a missing/corrupt file

**Definition of Done:** Save then load round-trips the dummy node's state correctly after a restart; `test_save_manager.gd` passes under GUT.

### 3. AchievementManager
- [ ] Define `AchievementDefinition` Resource (id, title, description, icon, condition type/target)
- [ ] Create 2–3 sample `.tres` achievement definitions in `data/achievements/`
- [ ] Load definitions at startup, track progress in a runtime dict
- [ ] Persist unlocked/progress state to its own file (separate from save slots)
- [ ] Expose `unlock(id)`, `is_unlocked(id)`, `add_progress(id, amount)`
- [ ] Connect to relevant `EventBus` signals (even if nothing emits them yet)
- [ ] Write `tests/unit/test_achievement_manager.gd` covering progress accumulation, single-fire unlock signal, and persistence after reload

**Definition of Done:** Manually calling `unlock()` on a sample achievement persists across restart; `test_achievement_manager.gd` passes under GUT.

### 4. AudioManager
- [ ] Expose `play_sfx(id)`, `play_music(id)`, `stop_music()`
- [ ] Read volume levels from `SettingsManager`
- [ ] React to `EventBus.settings_changed` (or equivalent) to update live volume
- [ ] Write `tests/unit/test_audio_manager.gd` covering that bus volume reads correctly from `SettingsManager`

**Definition of Done:** Playing a sound respects current volume settings; changing volume mid-playback updates it live; `test_audio_manager.gd` passes under GUT.

---

## Phase 2 — Placeholder Gameplay

### 5. Player
- [ ] Build the generic state machine framework under `scenes/entities/state_machine/`: `state_machine.gd` (holds `current_state`, connects to each child state's `transitioned` signal on `_ready()`, exposes `transition_to(state_name, msg := {})` and `current_state_name`) and `state.gd` (base class, `class_name State`, with `enter(msg := {})`, `exit()`, `physics_update(delta)`, `handle_input(event)`, and `signal transitioned(new_state_name, msg)`)
- [ ] `CharacterBody2D` Player with `Sprite2D`, `CollisionShape2D`, `AnimationPlayer`, a `StateMachine` child node, and `HitboxComponent`
- [ ] Player keeps tunable `@export` values (speed, gravity, jump_velocity); `_physics_process` delegates to `state_machine.current_state.physics_update(delta)` — no movement branching in `player.gd` itself
- [ ] Implement four states under `scenes/entities/player/states/`: `idle_state.gd`, `run_state.gd`, `jump_state.gd`, `fall_state.gd`, each extending `State`
  - Idle → Run (direction input), Idle → Fall (not on floor), Idle → Jump (jump pressed)
  - Run → Idle (no direction), Run → Fall (not on floor), Run → Jump (jump pressed)
  - Jump `enter()`: set vertical velocity, emit `EventBus.player_jumped`; transitions to Fall once velocity.y crosses zero
  - Fall: applies gravity; on `is_on_floor()` transitions to Idle or Run depending on input, emits `EventBus.player_landed`
- [ ] States (not the state machine or Player) emit gameplay `EventBus` signals (`player_jumped`, `player_landed`, `player_died`) — each state is the source of truth for when its own event is real
- [ ] Join `"saveable"` group; implement `get_save_data()` / `apply_save_data()` covering position, velocity, and health — **do not persist `current_state_name`**; let the state machine self-resolve on load based on `is_on_floor()`/velocity

**Definition of Done:** Player moves/jumps correctly through all four states with correct transitions; position round-trips through save/load and the state machine resolves correctly on the first physics frame after load. State-transition tests are optional/lower priority — see `AGENTS.md` Testing Expectations.

### 6. Pickup (coin)
- [ ] Area2D that emits `EventBus.coin_collected` on overlap with player
- [ ] Connect a sample achievement's progress to this signal

**Definition of Done:** Collecting a coin in-game unlocks or progresses the connected achievement, end to end.

### 7. Level + checkpoint
- [ ] Build one `TileMap` level using the placeholder player and a few coins
- [ ] Add a checkpoint trigger that calls `SaveManager.save_game()`
- [ ] Confirm level id is recorded in `SaveData`

**Definition of Done:** Hitting checkpoint → relaunching game → loading save restores player position, level, and collected coins correctly.

---

## Phase 3 — UI

### 8. HUD
- [ ] `CanvasLayer` overlay, reactive only
- [ ] Listens to `EventBus` for health/score-equivalent updates from placeholder gameplay

**Definition of Done:** HUD updates live from gameplay events without holding a direct reference to the player.

### 9. Achievement popup
- [ ] Listens for `achievement_unlocked`
- [ ] Queues toasts if multiple unlock at once

**Definition of Done:** Unlocking two achievements in quick succession shows both, sequentially, without overlap.

### 10. Pause menu
- [ ] Separate `CanvasLayer`, `process_mode = ALWAYS`
- [ ] Toggled by pause input action; sets `get_tree().paused`
- [ ] Resume / Settings / Quit to Main Menu options

**Definition of Done:** Pausing freezes gameplay but pause menu remains fully interactive.

### 11. Settings menu
- [ ] Audio tab — sliders bound live to `SettingsManager`
- [ ] Controls tab — list of rebindable actions, capture-a-key rebind flow, writes through `SettingsManager`
- [ ] Video tab (optional) — fullscreen/resolution toggle
- [ ] Reset to Default button

**Definition of Done:** Rebinding a key and changing volume both persist after restart and are reflected immediately in gameplay.

### 12. Main menu
- [ ] New Game / Continue / Settings / Quit
- [ ] Continue disabled/hidden if no save exists
- [ ] Scene transitions routed through `GameManager`

**Definition of Done:** Full navigation loop works: Main Menu → New Game → play → pause → Settings → back → Main Menu → Continue restores correctly.

---

## Phase 4 — Integration Pass

- [ ] Full loop test: Main Menu → New Game → play → checkpoint save → quit → relaunch → Continue → correct state restored
- [ ] Settings persist independently of save slots across restart
- [ ] Achievements persist independently of save slots across restart
- [ ] Multiple save slots don't overwrite each other
- [ ] No autoload holds a direct reference to another autoload where a signal would do (spot-check against `AGENTS.md` rules)
- [ ] No gameplay node reaches directly into UI or vice versa
- [ ] Full GUT suite (`tests/unit/`) passes headless in one run

**Definition of Done:** A fresh clone of the repo, run from a clean state, supports the full menu → play → save → settings → achievements loop with no manual setup beyond opening the project.

---

## Notes for the Agent

- Treat each numbered item as one task — verify its Definition of Done before starting the next.
- If implementing an item requires inventing a signal or method not already specified, stop and flag it rather than guessing silently.
- Do not skip ahead to Phase 3 UI for a system whose Phase 1/2 signals don't exist yet.
- A Phase 1 manager item is not done until its test file exists and passes — see `AGENTS.md` Testing Expectations.