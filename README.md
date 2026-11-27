# Echo Ridge

Single-player first-person sniper game prototype built in Godot 4.7. Open `project.godot` in the editor and press F5 for the main menu.

Planning and status live in `docs/`:

- `docs/CHECKLIST.md`: the master start-to-finish production checklist, verification requirements and release exit gates.
- `docs/GAME-FLOW.md`: architecture and gameplay flow diagrams showing how the systems work together.
- `docs/STATUS.md`: current verified project status and remaining production gates.
- `docs/design/story-bible.md`: protagonist, story premise, characters, campaign arc and final boss plan.
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
| `autoload/progression.gd` | `Progression` autoload: per-mission records, the per-challenge leaderboard and ten achievements |
| `autoload/save_system.gd` | `SaveSystem` autoload: versioned JSON saves, checkpoints, quick save and load |
| `scenes/player/` | First-person body and camera |
| `scenes/weapons/` | `WeaponRig` (ammunition, reload, firing, projectiles) and `WeaponProfile` resources under `profiles/` |
| `scenes/levels/level_base.gd` | Level contract: spawn, wind, targets, interact, objective, completion |
| `scenes/levels/test_range.tscn` | The intel mission level; targets are children of `Targets` |
| `scenes/levels/shooting_range.tscn` | The 1000 m plate range |
| `scenes/levels/challenge_range.gd`, `scenes/challenges/` | Long-shot challenges on the range: the catalog with rules and score formula, and one scene per challenge |
| `scenes/targets/` | `TargetDummy` with hit zones, `SteelPlate` range target, shared hit-zone helpers |
| `scenes/enemies/` | `Enemy` state machine, `Perception`, `AlertCoordinator` |
| `scenes/missions/` | `MissionLog` objectives and `TriggerZone` |
| `scenes/weapons/aim_sway.gd` | Breath-hold and sway model |
| `scenes/player/stealth_kit.gd` | Binoculars, tagging, footstep noise, stones |
| `scenes/ui/` | HUD, main menu, mission catalog, settings screen, workbench, pause menu, results screen |
| `scope_overlay.gd` | Scope reticle |
| `ballistics.gd`, `gunsmith.gd` | Pure calculation modules |
| `translations/strings.csv` | Translation table; keys are the English text. Run `python3 tools/extract_strings.py` after adding UI text, then add a column per language |
| `tools/` | Screenshot capture and string extraction |
| `tests/` | Headless test suites run by `scripts/validate.sh` and CI |

## Implemented

Test range scene (ground, cover blocks, three targets, intel terminal, extraction pad). First-person movement with gravity and fall reset. Three selectable weapon profiles: a bolt-action rifle that fires a simulated projectile with gravity, wind and swept collision, plus two hitscan shotgun profiles with pellet spread. Realistic rifle ballistics: drag, wind, adjustable zero turret, holdover reticle marks, laser rangefinder and wind readout. Suppressed sidearm. Long-shot slow motion. Magazine and reserve ammunition, timed reload, shot interval, per-weapon zoom. Stand, crouch and prone stances with breath-hold sway while aiming. Sprint while standing and moving forward at the hip, with an eased field-of-view kick, louder footsteps and a brief sway penalty afterwards; a short camera dip on hard landings. Both camera effects are off with reduced motion. Targets and hostiles with head, torso and limb hit zones. Hostiles with vision cones, hearing, a patrol-suspicious-investigate-alert-search-flee state machine, squad contact sharing, return fire, body discovery, lockdown and reinforcements. Player health, regeneration and mission failure. Binoculars with target tagging, a stance-based noise meter and throwable stones. Three difficulty levels. Dawn, noon, dusk and night lighting with clear, windy, rain and dust weather that changes the wind, haze, and how far guards see and hear. Primary, secondary and optional objectives per mission with trigger zones and kill, accuracy and detection statistics. Scope overlay with reticle and surface range readout. Intel-then-extract mission, pause on Escape and on window focus loss, restart.

## Scenes

| Scene | What it is |
|---|---|
| `scenes/ui/main_menu.tscn` | Main menu: continue, missions, settings. The default scene (F5). |
| `main.tscn` | Echo Ridge recon mission: collect intel at the terminal, extract. |
| `compound_mission.tscn` | Walled compound with four patrolling hostiles. Perception, alert states, squad coordination, return fire, lockdown reinforcements. Eliminate every hostile to complete. Open it and press F6. |
| `range_mission.tscn` | 1000 m shooting range with a steel plate every 100 m on its own bearing. Open it and press F6. Rings every plate to complete. |
| `scenes/challenges/*.tscn` | Long-shot challenges on the same range, also under Missions: a calm warm-up (200, 300 and 400 m, six rounds), a gusting crosswind (700 and 800 m at dawn, six rounds), a kilometre shot (1000 m at dusk, three rounds) and a timed sequence (300 to 900 m in order, ten rounds, three minutes). Score: plate metres + 100 per unused round + 10 per second left on the clock; a failure scores 0. Best score, fewest rounds and fastest time are kept per challenge on the Records screen. No saves during a challenge. |

## Controls

| Input | Action |
|---|---|
| W A S D | Move |
| Mouse | Aim |
| Left click | Fire (also resumes from pause) |
| Right click | Aim through the scope |
| Mouse wheel | Scope magnification 4x to 12x while aiming |
| 1, 2 | Rifle, sidearm |
| B | Toggle binoculars (left click or T tags the hostile under the crosshair) |
| G | Throw a stone to draw a guard |
| Shift (hold) | Sprint while standing and moving forward; footsteps carry further |
| Shift (hold, while aiming) | Hold breath. A Shift still held from sprinting must be pressed again |
| [ and ] | Zero turret down and up (100 m steps) |
| Space | Skip long-shot slow motion |
| C | Toggle crouch |
| Z | Toggle prone |
| R | Reload |
| E | Interact: collect intel, extract, pick up or drop a body |
| Escape | Pause or resume |
| F5 / F9 | Quick save / quick load (falls back to the last checkpoint) |
| N | Restart |

### Controller

Left stick moves, right stick looks. Right trigger fires, left trigger aims while held. A interacts, B crouches, X reloads, Y raises binoculars, right bumper tags, left bumper switches weapon. Left stick click sprints while moving forward at the hip (until you stop, aim, crouch or click again) and holds breath while aiming; right stick click goes prone. D-pad up and down set the zero, left throws a stone, right zooms. Start pauses.

## Validation

```bash
scripts/validate.sh
```

Runs the editor import and every headless suite in `tests/`. Set `GODOT` to the path of a Godot 4.7 binary if it is not on `PATH`. CI runs the same steps and exports a Windows development build. See `docs/VALIDATION.md`.

## Limitations

This is a prototype, not a finished game. Hostiles are box figures without animation. The title screen and mission shell now use a shared dark tactical theme and procedural shader backdrop, but the game still needs production character and weapon models, authored animations, sound, finished terrain and a full visual playtest. See `docs/CHECKLIST.md` for the full plan.
