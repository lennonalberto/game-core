# 2D Game Template (Godot 4.x)

A clean, scalable starting point for 2D games. Includes the boring-but-essential stuff every indie game needs, wired together with a small placeholder platformer as a working example.

## Features

- **Main Menu** — New Game / Continue / Settings / Quit
- **HUD** — generic, reactive overlay (health/score placeholders)
- **Pause Menu** — pauses gameplay without freezing UI
- **Settings** — rebindable controls, audio volume sliders (music/SFX/master), basic video options
- **Save System** — slot-based saving/loading via a simple "saveable" component contract
- **Achievement System** — data-driven achievements defined as resource files, with unlock popups
- **Placeholder Platformer** — a minimal player, a coin pickup, and one level demonstrating how everything above connects

This is meant to be **cloned/forked as a starting point**, not used as-is. Strip out or replace the placeholder gameplay when starting a real project; keep the systems around it.

## Requirements

- Godot 4.x (stable)

## Getting Started

1. Clone this repo.
2. Open the project in Godot.
3. Run `scenes/main/main.tscn`.
4. Play through the placeholder level to see the save system, achievements, and settings in action (collect a coin, hit the checkpoint, pause and rebind a key, check the settings menu).

## Project Structure

```
autoloads/       Singletons: EventBus, GameManager, SaveManager,
                  SettingsManager, AchievementManager, AudioManager
resources/        Custom Resource class scripts (save data, settings, achievements)
data/             Resource instances (.tres) — achievement definitions, default keybinds
                  + runtime save files (not committed)
scenes/
  main/           Bootstraps the game
  ui/             Main menu, HUD, pause menu, settings, achievement popups, reusable components
  entities/       Player, enemies, pickups
  levels/         Playable levels, including the placeholder demo
assets/           Sprites, audio, fonts, theme resources
```

See `AGENTS.md` for the architectural rules and conventions this project follows — useful reading before contributing, human or AI.

## Core Architecture (short version)

- **Autoloads own state.** Everything else reads from them, never duplicates their state locally.
- **EventBus decouples systems.** Gameplay emits signals; UI, save, and achievement systems listen. Nothing reaches into anything else directly.
- **Data lives in Resources.** Achievements and save data are `.tres` files, not hardcoded logic — add a new achievement by adding a file.
- **Saving is contract-based.** Any node that needs to persist joins the `"saveable"` group and implements two methods. `SaveManager` doesn't need to know what it's saving.

## Extending This Template

- **New achievement:** add a new `AchievementDefinition` resource under `data/achievements/`, no code changes needed.
- **New save data:** implement the saveable contract on your node; it's picked up automatically.
- **New menu/UI:** build it under `scenes/ui/`, reuse the existing themed components for consistency.
- **New gameplay:** replace the contents of `scenes/entities/` and `scenes/levels/platformer_demo/` — the systems around them don't need to change.

## License

*(fill in your license here)*
