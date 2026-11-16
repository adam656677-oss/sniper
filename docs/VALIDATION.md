# Validation and development builds

CI pins Godot 4.7 stable for repeatability. Three workflows exist:

- **Validate and build** (`build.yml`): runs `scripts/validate.sh --export`, which imports the project, runs every suite in `tests/`, exports a Windows x86-64 development build, and uploads it as `EchoRidge-Windows-development`. CI and local validation are the same script.
- **Projectile regression tests** (`projectiles.yml`): import plus the ballistics and projectile suites only.
- **Windows runtime smoke test** (`windows-runtime.yml`): after a successful validate run, launches the exported executable headlessly on a Windows runner for 120 frames and checks the log.

Steps fail only on `SCRIPT ERROR:` or `FAIL:` lines. Plain `ERROR:` lines are not treated as failures because the headless dummy renderer prints `ERROR: Parameter "m" is null` for every `BoxMesh` created without a display; that line is benign. Earlier versions of the workflows matched it and never went green.

## Screenshots

`tools/capture.gd` renders the main menu, mission select, the compound at the hip, through the scope and through binoculars, and the range at the hip and at 12x. CI runs it under a virtual display after validation and uploads `EchoRidge-screenshots`. Locally:

```bash
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --script res://tools/capture.gd -- /tmp/shots
```

Screenshots are a visual check, not a playtest: they show framing, lighting and HUD layout but not feel.

## Local validation

```bash
GODOT=/path/to/Godot_v4.7-stable_linux.x86_64 scripts/validate.sh
```

Add `--export` to also produce `builds/windows/EchoRidge.exe` (requires the 4.7 export templates in the user data directory).

## Test suites

| Suite | File | Covers |
|---|---|---|
| Settings | `tests/settings.gd` | Defaults, unknown keys ignored, remapping and refusal, save and load round trip, reset, applying difficulty and bindings, kill cam and inverted look in a mission, event serialisation, a control for every setting, remapping by listening and cancelling, music bus volume, render scale, reduced motion, high-contrast reticle, realistic ranging, corrupt file fallback |
| Smoke (34 checks) | `tests/smoke.gd` | Scene load, player and camera, targets, floor collision, intel and extraction rules, timed reload, reserve transfer, pause freezing reload and physics, cooldown, completion HUD |
| Combat | `tests/combat.gd` | Suppression from incoming fire and its decay, HUD warning, flank points on opposite sides, alert guards moving to flank, carrying and dropping bodies, carry noise and speed, guards finding moved bodies, body positions in saves |
| Enemies | `tests/enemies.gd` | Perception cone, distance, stance exposure and occlusion; awareness thresholds; Patrol to Suspicious to Alert; squad contact sharing; difficulty scaling; return fire and regeneration; search and return to patrol; hearing loud, distant and suppressed shots; alert on hit; flee; body discovery; lockdown and reinforcements; navigation; mission failure |
| Focus | `tests/focus.gd` | Focus-loss pause, mouse release, reload freeze, explicit resume, completed-mission input blocking |
| Atmosphere | `tests/atmosphere.gd` | Visibility and hearing by time and weather, gusts above and below the mean without changing direction, per-level presets, sun and haze applied, guards seeing less at dusk, the rifle reading gusting wind |
| Ballistics (8 checks) | `tests/ballistics_test.gd` | Integration step with gravity and wind, segment tracing |
| Localisation | `tests/localisation.gd` | Every button, label, objective, tutorial step, mission title and tr() string in the source is a key in the translation table with English text, and the imported translation returns it |
| Loadout | `tests/loadout.gd` | Stock copies, compatible and incompatible installs, clearing, persistence and invalid entries dropped, mission rig carrying parts, aiming through the installed optic, workbench apply and presets |
| Menus | `tests/menus.gd` | Home, mission list and scene requests, settings screen apply and defaults, pause menu visibility and resume, results on completion, secondary objectives completing, score formula, checkpoint cleared on finish, continue from checkpoint |
| Missions | `tests/missions.gd` | Objective log (hidden, progress, completion, failure, round trip), test range intel and extraction, range plate progress and long-shot secondary, compound eliminate, exfil trigger, undetected and silent objectives, kill statistics, primary failure |
| Projectiles | `tests/projectiles.gd` | Rifle projectile travel, drop, range limit, target hits |
| Gunsmith | `tests/gunsmith.gd` | Part compatibility and stat calculation |
| Tutorial | `tests/tutorial.gd` | Controller bindings on every core action, stick look, bumper weapon cycle, trigger hold-to-aim, tutorial steps revealed in order, waiting for conditions, finished steps leaving the HUD, several steps completing at once |
| Weapons | `tests/weapons.gd` | Weapon switching, per-weapon ammunition, fictional names |
| Aim | `tests/aim.gd` | Stances (collider, eye height, speed), sway amplitude by stance, breath hold, exhaustion and recovery, camera sway application |
| Range | `tests/range.gd` | 1000 m range layout, rangefinder, holdover-corrected hits at 300, 600 and 1000 m, crosswind miss and drift-corrected hit at 800 m, plate reset, range completion |
| Saves | `tests/saves.gd` | Checkpoint on objective completion, quick save, full round trip of player, weapons, stealth kit, hostiles, objectives, statistics and difficulty, staged loads applied only by the matching scene, corrupt, wrong-version and incomplete saves rejected |
| Scope | `tests/scope.gd` | Zero turret steps and clamps, holdover, launch elevation, scope view following the camera, magnification range and clamps, reticle marks scaling with zoom, rangefinder, wind readout, kill-cam trigger and time scale |
| Stealth | `tests/stealth.gd` | Noise by stance and motion, footsteps making a patrol suspicious, binoculars, tagging, tag list pruning, stones drawing a guard, stone count, pause gating |
| Targets | `tests/targets.gd` | Hit zones (head, torso, limb), damage multipliers, death removal, live projectile headshot |

Not covered: visual appearance, audio, aim feel, Windows launch beyond a headless 120-frame run, performance, enemy behaviour (none exists).

## Playtest log

Record every human playtest here: date, build (commit or run id), machine, outcome.

| Date | Build | Machine | Outcome |
|---|---|---|---|
| none yet | | | |
