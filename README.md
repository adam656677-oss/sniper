# Echo Ridge

Single-player first-person sniper game prototype built in Godot 4.7. Open `project.godot` in the editor and press F5 for the main menu.

Planning and status live in `docs/`:

- `docs/CHECKLIST.md`: the phased production checklist and exit gates.
- `docs/STATUS.md`: audit of what works, what is broken and why.
- `docs/superpowers/specs/2026-11-15-echo-ridge-design.md`: design document and open questions.
- `docs/TOOLING.md`: tools, asset sources, licences and what the owner needs to provide.
- `docs/VALIDATION.md`: how to run the tests and builds.

## Layout

| Path | Role |
|---|---|
| `main.tscn`, `mission.gd` | Mission root: wires level, player, weapon rig and HUD; routes input actions |
| `autoload/game_state.gd` | `GameState` autoload: paused, finished, failed, intel, difficulty |
| `autoload/settings.gd` | `Settings` autoload: config file, input remapping, sensitivity, difficulty, kill cam |
| `autoload/loadout.gd` | `Loadout` autoload: installed gunsmith parts per weapon family |
| `autoload/save_system.gd` | `SaveSystem` autoload: versioned JSON saves, checkpoints, quick save and load |
| `scenes/player/` | First-person body and camera |
| `scenes/weapons/` | `WeaponRig` (ammunition, reload, firing, projectiles) and `WeaponProfile` resources under `profiles/` |
| `scenes/levels/level_base.gd` | Level contract: spawn, wind, targets, interact, objective, completion |
| `scenes/levels/test_range.tscn` | The intel mission level; targets are children of `Targets` |
| `scenes/levels/shooting_range.tscn` | The 1000 m plate range |
| `scenes/targets/` | `TargetDummy` with hit zones, `SteelPlate` range target, shared hit-zone helpers |
| `scenes/enemies/` | `Enemy` state machine, `Perception`, `AlertCoordinator` |
| `scenes/missions/` | `MissionLog` objectives and `TriggerZone` |
| `scenes/weapons/aim_sway.gd` | Breath-hold and sway model |
| `scenes/player/stealth_kit.gd` | Binoculars, tagging, footstep noise, stones |
| `scenes/ui/` | HUD, main menu, mission catalog, settings screen, workbench, pause menu, results screen |
| `scope_overlay.gd` | Scope reticle |
| `ballistics.gd`, `gunsmith.gd` | Pure calculation modules |
| `tests/` | Headless test suites run by `scripts/validate.sh` and CI |

## Implemented

Test range scene (ground, cover blocks, three targets, intel terminal, extraction pad). First-person movement with gravity and fall reset. Three selectable weapon profiles: a bolt-action rifle that fires a simulated projectile with gravity, wind and swept collision, plus two hitscan shotgun profiles with pellet spread. Realistic rifle ballistics: drag, wind, adjustable zero turret, holdover reticle marks, laser rangefinder and wind readout. Suppressed sidearm. Long-shot slow motion. Magazine and reserve ammunition, timed reload, shot interval, per-weapon zoom. Stand, crouch and prone stances with breath-hold sway while aiming. Targets and hostiles with head, torso and limb hit zones. Hostiles with vision cones, hearing, a patrol-suspicious-investigate-alert-search-flee state machine, squad contact sharing, return fire, body discovery, lockdown and reinforcements. Player health, regeneration and mission failure. Binoculars with target tagging, a stance-based noise meter and throwable stones. Three difficulty levels. Primary, secondary and optional objectives per mission with trigger zones and kill, accuracy and detection statistics. Scope overlay with reticle and surface range readout. Intel-then-extract mission, pause on Escape and on window focus loss, restart.

## Scenes

| Scene | What it is |
|---|---|
| `scenes/ui/main_menu.tscn` | Main menu: continue, missions, settings. The default scene (F5). |
| `main.tscn` | Echo Ridge recon mission: collect intel at the terminal, extract. |
| `compound_mission.tscn` | Walled compound with four patrolling hostiles. Perception, alert states, squad coordination, return fire, lockdown reinforcements. Eliminate every hostile to complete. Open it and press F6. |
| `range_mission.tscn` | 1000 m shooting range with a steel plate every 100 m on its own bearing. Open it and press F6. Rings every plate to complete. |

## Controls

| Input | Action |
|---|---|
| W A S D | Move |
| Mouse | Aim |
| Left click | Fire (also resumes from pause) |
| Right click | Toggle zoom |
| 1, 2 | Rifle, sidearm |
| B | Toggle binoculars (left click or T tags the hostile under the crosshair) |
| G | Throw a stone to draw a guard |
| Shift (hold) | Hold breath while aiming |
| [ and ] | Zero turret down and up (100 m steps) |
| Space | Skip long-shot slow motion |
| C | Toggle crouch |
| Z | Toggle prone |
| R | Reload |
| E | Collect intel at the gold terminal, extract at the green pad |
| Escape | Pause or resume |
| F5 / F9 | Quick save / quick load (falls back to the last checkpoint) |
| N | Restart |

## Validation

```bash
scripts/validate.sh
```

Runs the editor import and every headless suite in `tests/`. Set `GODOT` to the path of a Godot 4.7 binary if it is not on `PATH`. CI runs the same steps and exports a Windows development build. See `docs/VALIDATION.md`.

## Limitations

This is a prototype, not a finished game. Hostiles are box figures without animation. There are no models, animations or sounds, and the menus are unstyled. The scope is a field-of-view change with a drawn overlay, not a rendered optic. See `docs/CHECKLIST.md` for the full plan.
