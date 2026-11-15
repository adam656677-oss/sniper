# Echo Ridge

Single-player first-person sniper game prototype built in Godot 4.7. Open `project.godot` in the editor and press F5.

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
| `autoload/game_state.gd` | `GameState` autoload: paused, finished, intel, mission signals |
| `scenes/player/` | First-person body and camera |
| `scenes/weapons/` | `WeaponRig` (ammunition, reload, firing, projectiles) and `WeaponProfile` resources under `profiles/` |
| `scenes/levels/test_range.tscn` | The test range level; targets are children of `Targets` |
| `scenes/targets/` | `TargetDummy` with hit zones |
| `scenes/weapons/aim_sway.gd` | Breath-hold and sway model |
| `scenes/ui/hud.gd`, `scope_overlay.gd` | HUD label and scope reticle |
| `ballistics.gd`, `gunsmith.gd` | Pure calculation modules |
| `tests/` | Headless test suites run by `scripts/validate.sh` and CI |

## Implemented

Test range scene (ground, cover blocks, three targets, intel terminal, extraction pad). First-person movement with gravity and fall reset. Three selectable weapon profiles: a bolt-action rifle that fires a simulated projectile with gravity, wind and swept collision, plus two hitscan shotgun profiles with pellet spread. Realistic rifle ballistics: drag, wind, adjustable zero turret, holdover reticle marks, laser rangefinder and wind readout. Suppressed sidearm. Long-shot slow motion. Magazine and reserve ammunition, timed reload, shot interval, per-weapon zoom. Stand, crouch and prone stances with breath-hold sway while aiming. Targets with head, torso and limb hit zones. Scope overlay with reticle and surface range readout. Intel-then-extract mission, pause on Escape and on window focus loss, restart.

## Controls

| Input | Action |
|---|---|
| W A S D | Move |
| Mouse | Aim |
| Left click | Fire (also resumes from pause) |
| Right click | Toggle zoom |
| 1, 2 | Rifle, sidearm |
| Shift (hold) | Hold breath while aiming |
| [ and ] | Zero turret down and up (100 m steps) |
| Space | Skip long-shot slow motion |
| C | Toggle crouch |
| Z | Toggle prone |
| R | Reload |
| E | Collect intel at the gold terminal, extract at the green pad |
| Escape | Pause or resume |
| N | Restart |

## Validation

```bash
scripts/validate.sh
```

Runs the editor import and every headless suite in `tests/`. Set `GODOT` to the path of a Godot 4.7 binary if it is not on `PATH`. CI runs the same steps and exports a Windows development build. See `docs/VALIDATION.md`.

## Limitations

This is a prototype, not a finished game. Targets are stationary dummies with no AI. There are no models, animations, sounds, menus, settings or saves. The scope is a field-of-view change with a drawn overlay, not a rendered optic. See `docs/CHECKLIST.md` for the full plan.
