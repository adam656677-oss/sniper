# Echo Ridge

Single-player first-person action prototype for Godot 4.3. Import `project.godot` and press F5.

## Implemented in source

Procedural 3D test environment, player collision and first-person movement, mouse aiming, scoped sensitivity and zoom, three fictional weapon profiles, ammunition and timed reload handling, shotgun pellet raycasts, and a recon-rifle projectile simulation with travel time, gravity, and configurable wind acceleration. The mission includes intel collection, extraction, pause, restart, and a HUD.

An isolated enemy AI prototype now exists in `enemy.tscn` / `enemy_ai.gd`. It has idle, patrol, investigate, engage, and dead states; perception checks; a stimulus hook; health/damage; and detection/attack signals. It is not yet integrated into the main mission.

## Controls

WASD move; mouse aim; left click fire; right click toggle zoom; R reload; E collect/extract; Escape pause/resume; left click also resumes; N restart. Reload and movement freeze while paused. The first click that resumes does not fire.

## Validation

See [docs/VALIDATION.md](docs/VALIDATION.md) and [docs/ENEMY_AI.md](docs/ENEMY_AI.md). The existing mission smoke suite contains 28 checks. A separate enemy AI smoke script covers scene loading, initial state, stimulus investigation, damage, and elimination. Neither script has been run in Godot as part of this change. No passing engine run or Windows launch is claimed. A successful export is not a visual playtest.

## Current limitations

This is an unfinished prototype, not a finished commercial release. The environment is procedural blockout geometry; the mission still uses stationary block targets. The enemy prototype is isolated and uses direct steering; it has no navigation-mesh pathfinding, cover behavior, squad coordination, or player-damage implementation. There are no production character models/animations, cinematic takedowns, final weapon handling animations, finished audio, save/load or campaign checkpoints, or production art. The scope is currently a field-of-view/overlay prototype, not a finished optic. Ammunition exhaustion does not end the intel mission; restarting resets supplies.

See [docs/ROADMAP.md](docs/ROADMAP.md) for the staged development plan and acceptance criteria.
