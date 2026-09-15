# AGENTS.md

Instructions for coding agents (Claude Code, etc.) working on this project. This is a **reusable Godot 4.x 2D game template**, not a finished game. Every decision should optimize for: staying generic, staying decoupled, and being easy to extend later.

## Project Intent

This repo is a starting point for new 2D games. It provides:
- Core UI (main menu, HUD, pause, settings with rebindable keys + volume)
- A save system
- An achievement system
- A minimal placeholder platformer as a working example of how everything connects

Do not add game-specific content (specific story, specific art direction, specific mechanics beyond the placeholder) unless explicitly asked. When in doubt, favor the generic, reusable version of a feature over a specific one.

## Architecture Rules (must follow)

1. **Autoloads are the only singletons.** Business logic lives in `autoloads/`. Never create a second source of truth for state that an autoload already owns (e.g. don't cache volume levels in a UI script — read from `SettingsManager`).
2. **Decouple via EventBus.** Gameplay nodes, UI, and managers should not hold direct references to each other where avoidable. Emit/listen on `EventBus` signals instead. Direct references are fine within a single scene (e.g. Player → its own HitboxComponent), but never HUD → Player or Player → SaveManager.
3. **Data as Resources.** Achievements, save data, and settings are custom `Resource` subclasses (`.gd` scripts + `.tres` instances), not raw dictionaries or JSON blobs scattered in code. New content (a new achievement, a new save field) should be addable by creating a resource file, not by editing manager code, wherever feasible.
4. **Saveable contract.** Any node that needs to persist state joins the `"saveable"` group and implements `get_save_data() -> Dictionary` and `apply_save_data(data: Dictionary) -> void`. `SaveManager` only ever iterates this group — it must never contain hardcoded references to specific gameplay nodes.
5. **Settings vs. Save vs. Achievements are separate files on disk.** Never merge these persistence domains.
6. **UI is reactive, not authoritative.** HUD and menus display state and forward input; they don't own game state.
7. **Scenes own their scripts.** Keep `.tscn` and `.gd` together in the same folder under `scenes/`. Don't centralize all scripts in one folder.

## Folder Structure Reference

```
autoloads/       - singleton scripts (EventBus, GameManager, SaveManager,
                    SettingsManager, AchievementManager, AudioManager)
resources/       - custom Resource class definitions (.gd)
data/            - .tres instances of those resources (achievement defs,
                    input defaults) + runtime save data (gitignored)
scenes/ui/       - main_menu, hud, pause_menu, settings, achievement_popup,
                    components (reusable styled controls)
scenes/entities/ - player, enemies, pickups
scenes/levels/   - playable levels, incl. platformer_demo
assets/          - sprites, audio, fonts, themes
```

If a new file doesn't obviously belong in one of these, ask before inventing a new top-level folder.

## Coding Conventions

- **GDScript**, static typing wherever practical (`var health: int = 100`, typed function signatures).
- Use `snake_case` for files, functions, and variables; `PascalCase` for class names and node names.
- Every autoload script starts with `class_name` matching its filename (e.g. `class_name SaveManager`) even though it's also an autoload — improves type hinting elsewhere.
- Signals declared at the top of a script, before `@export` vars.
- No magic strings for EventBus signal names beyond the signal declaration itself — connect using the signal object, not `"signal_name"` string literals.
- Comment *why*, not *what*, especially in manager scripts — this is template code other people/agents will read to understand the pattern.

## What NOT to Do

- Don't use `get_node("../../SomeNode")`-style fragile traversal across unrelated branches of the tree. Use groups, signals, or exported NodePaths within a scene.
- Don't put gameplay logic in autoloads, and don't put persistence/settings logic in gameplay nodes.
- Don't hardcode input actions as raw key names in UI or gameplay scripts — always go through `InputMap` action names so rebinding works everywhere automatically.
- Don't introduce a third-party plugin/addon without flagging it first — the template should stay dependency-light.
- Don't write save/settings/achievement files with format changes that silently break old files — bump a `version` field if the schema changes.

## Testing Expectations

- **Framework:** [GUT (Godot Unit Test)](https://github.com/bitwes/Gut), installed under `addons/gut/`. Tests are written in GDScript.
- **Location:** `tests/unit/`, one file per manager, named `test_<manager_name>.gd`. Shared test fixtures (e.g. a minimal dummy node implementing the saveable contract) live in `tests/helpers/`.
- **Every manager built in Phase 1 (SettingsManager, SaveManager, AchievementManager, AudioManager) must ship with a corresponding test file before that phase item is considered done.** This is not optional polish — it's part of the Definition of Done.
- What to test (managers and contracts, not visuals):
  - SaveManager: save → load round-trips a `SaveData` object correctly; multiple save slots don't clobber each other; loading a missing/corrupt file fails gracefully instead of crashing; a dummy `"saveable"` node's data is collected and restored without `SaveManager` referencing it directly.
  - SettingsManager: setting a volume updates the correct `AudioServer` bus; rebinding a key updates `InputMap`; `reset_to_default()` restores baseline values.
  - AchievementManager: progress accumulates correctly; unlocking an achievement fires its signal exactly once, not repeatedly; unlocked/progress state persists after a simulated reload.
  - EventBus: signals exist with the parameter signatures other systems expect (a contract-drift check, not behavior).
- What NOT to test: UI layout/appearance, animations, gameplay feel (movement tuning, jump height) — verify those manually instead.
- **When modifying a manager's behavior, update its test file in the same change.** A manager change without a corresponding test update should be treated as incomplete, not deferred.
- Tests should be runnable headless (`--headless -s addons/gut/gut_cmdln.gd`) so they can be run without manual interaction in the editor.

## When Extending the Template

If asked to add a new system (inventory, dialogue, etc.), follow the existing pattern:
1. Does it need persistent state? → Add fields to a `Resource`, implement the saveable contract.
2. Does it need to talk to other systems? → Add signals to `EventBus`, don't wire nodes directly.
3. Does it need UI? → Build it as a reactive component under `scenes/ui/`, styled via the existing theme.
4. Is it generic template functionality or specific to one game? → If specific, it probably shouldn't be in this repo at all — flag that to the user.