# Validation and development builds

CI pins Godot 4.7 stable for repeatability. Three workflows exist:

- **Validate and build** (`build.yml`): runs `scripts/validate.sh --export`, which imports the project, runs every suite in `tests/`, exports a Windows x86-64 development build, and uploads it as `EchoRidge-Windows-development`. CI and local validation are the same script.
- **Projectile regression tests** (`projectiles.yml`): import plus the ballistics and projectile suites only.
- **Windows runtime smoke test** (`windows-runtime.yml`): after a successful validate run, launches the exported executable headlessly on a Windows runner for 120 frames and checks the log.

Steps fail only on `SCRIPT ERROR:` or `FAIL:` lines. Plain `ERROR:` lines are not treated as failures because the headless dummy renderer prints `ERROR: Parameter "m" is null` for every `BoxMesh` created without a display; that line is benign. Earlier versions of the workflows matched it and never went green.

## Local validation

```bash
GODOT=/path/to/Godot_v4.7-stable_linux.x86_64 scripts/validate.sh
```

Add `--export` to also produce `builds/windows/EchoRidge.exe` (requires the 4.7 export templates in the user data directory).

## Test suites

| Suite | File | Covers |
|---|---|---|
| Smoke (34 checks) | `tests/smoke.gd` | Scene load, player and camera, targets, floor collision, intel and extraction rules, timed reload, reserve transfer, pause freezing reload and physics, cooldown, completion HUD |
| Focus | `tests/focus.gd` | Focus-loss pause, mouse release, reload freeze, explicit resume, completed-mission input blocking |
| Ballistics (8 checks) | `tests/ballistics_test.gd` | Integration step with gravity and wind, segment tracing |
| Projectiles | `tests/projectiles.gd` | Rifle projectile travel, drop, range limit, target hits |
| Gunsmith | `tests/gunsmith.gd` | Part compatibility and stat calculation |
| Weapons | `tests/weapons.gd` | Weapon switching, per-weapon ammunition, fictional names |
| Aim | `tests/aim.gd` | Stances (collider, eye height, speed), sway amplitude by stance, breath hold, exhaustion and recovery, camera sway application |
| Range | `tests/range.gd` | 1000 m range layout, rangefinder, holdover-corrected hits at 300, 600 and 1000 m, crosswind miss and drift-corrected hit at 800 m, plate reset, range completion |
| Scope | `tests/scope.gd` | Zero turret steps and clamps, holdover, launch elevation, reticle marks, rangefinder, wind readout, kill-cam trigger and time scale |
| Targets | `tests/targets.gd` | Hit zones (head, torso, limb), damage multipliers, death removal, live projectile headshot |

Not covered: visual appearance, audio, aim feel, Windows launch beyond a headless 120-frame run, performance, enemy behaviour (none exists).

## Playtest log

Record every human playtest here: date, build (commit or run id), machine, outcome.

| Date | Build | Machine | Outcome |
|---|---|---|---|
| none yet | | | |
