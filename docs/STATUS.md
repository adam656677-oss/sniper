# Echo Ridge: project status audit

Audited 2026-11-15 against commit `71c37b9` (branch `main`). Every claim below was reproduced locally with Godot 4.7 stable headless unless marked otherwise.

## Update 2026-11-15 (branch `adam/eager-brown-kubebc`)

Items 0.1 through 0.8 and 0.11 of the checklist are done on this branch. The build is repaired and CI is green (first Windows build artefact produced). The four-layer inheritance chain is gone: the project is now `mission.gd` (root) + `GameState` autoload + `Player` scene + `WeaponRig` node with `WeaponProfile` resources + `TestRange` level scene + HUD and scope overlay. Input goes through `InputMap` actions. Weapon names are fictional. All six suites pass locally on a fresh import. The audit below describes `main` as found.

## Headline

- **The project does not currently load.** The last commit on `main` added `paused` and `reload_remaining` to `main.gd`, but `gameplay.gd` (which extends `main.gd`) already declares both. Godot 4 treats that as a parse error, so `gameplay.gd`, `weapons.gd` and `projectile_gameplay.gd` all fail to load and the main scene cannot run.
- **`scope_overlay.gd` has a second, independent parse error** (`var hit := ...intersect_ray(...)` cannot infer a type in 4.3; it needs `var hit: Dictionary = ...`).
- **CI has never been green.** All 29 workflow runs on `main` have failed or been skipped. Before the parse errors, the failure was a false positive: the headless dummy renderer prints `ERROR: Parameter "m" is null` nine times when the smoke test spawns `BoxMesh` nodes, and the workflow greps for `ERROR:` and fails the job even though the tests print `SMOKE TESTS PASSED`.
- **Last healthy commit: `7388d30`** ("Integrate travelling rifle projectiles"). At that commit, on a fresh import, the smoke (36 checks), focus, ballistics (8 checks), gunsmith and weapons suites all pass locally.
- **No Windows build has ever been produced**, because the export step never ran.

## What exists and works (as of `7388d30`)

| Area | State |
|---|---|
| Engine | Godot 4.7 stable, GL Compatibility renderer, 1280x720 |
| World | Procedurally spawned boxes: ground slab, three cover blocks, three red target blocks, gold intel terminal, green extraction pad |
| Player | `CharacterBody3D` capsule, WASD at 5 m/s, mouse look, gravity, fall-reset below y = -15 |
| Weapons | Three selectable profiles (recon rifle, Origin 12, KSG). Magazine, reserve, timed reload, shot interval, pellet spread, FOV zoom |
| Ballistics | Rifle fires a simulated projectile with gravity and wind acceleration, sub-stepped at 120 Hz with swept ray collision. Shotguns are hitscan |
| Scope | Full-screen reticle overlay with range readout to surface (broken by parse error on `main`) |
| Gunsmith | Pure calculation module for parts per slot; not wired to gameplay |
| Mission | Collect intel at terminal, return to extraction, press E; pause on Escape and on focus loss; N restarts |
| Tests | Six headless `SceneTree` scripts, all pass at `7388d30` |
| CI | Three workflows: validate+export, projectile regression, Windows runtime smoke. All currently failing |

## What does not exist

No enemy AI, no animation, no models or textures (all primitives), no audio, no menus or settings, no save or load, no input remapping, no controller support, no level beyond the test slab, no narrative, no localisation, no accessibility options, no performance budget, no packaging or signing, no store presence.

## Structural problems to fix before new features

1. **Four-deep script inheritance chain** (`main.gd` > `gameplay.gd` > `weapons.gd` > `projectile_gameplay.gd`) where each layer re-implements and overrides the previous one's reload, pause and fire logic, and patches the HUD text with string replacement. The latest commit tried to add features to the base layer that the child layers already own, which is what broke the build. This must be flattened into one game script plus composed systems (see the design doc).
2. **Two incompatible test APIs.** `tests/smoke.gd` drives `reserve`, `cooldown` and `start_reload()` (the base-layer names) while `tests/focus.gd` drives `reserve_ammo`, `shot_remaining`, `begin_reload()` and `set_paused()` (the child-layer names). Both cannot be satisfied by a clean design; the tests need to be consolidated onto one API.
3. **Everything is built in code in `_ready()`.** No `.tscn` scenes for player, weapon, target or level. That blocks artists and blocks the Godot editor workflow.
4. **CI greps `ERROR:` across all engine output.** It must match only `SCRIPT ERROR:` and test `FAIL:` lines, or filter the known dummy-renderer line.
5. **Direct pushes to `main` with no branch protection.** Every commit landed red. Work should go through pull requests gated on the validate workflow.
6. **README and VALIDATION.md are out of date** (they describe 16 and 28 checks; the suite has 36, and the control scheme differs from what the top-level script does).

## Reproduction

```bash
scripts/validate.sh
```

Requires the Godot 4.7 Linux binary on `PATH` as `godot` (or set `GODOT=/path/to/binary`). The script mirrors the CI steps and uses the corrected error matching.
