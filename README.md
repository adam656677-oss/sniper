# Echo Ridge

Single-player first-person action prototype for Godot 4.3. Import `project.godot` and press F5.

## Implemented in source

Procedural 3D test environment, player collision and first-person movement, mouse aiming, scoped sensitivity and zoom, three fictional weapon profiles, ammunition and timed reload handling, shotgun pellet raycasts, and a recon-rifle projectile simulation with travel time, gravity, and configurable wind acceleration. The mission includes intel collection, extraction, pause, restart, and a HUD. Shooting and projectile updates are processed through the gameplay/physics update paths.

## Controls

WASD move; mouse aim; left click fire; right click toggle zoom; R reload; E collect/extract; Escape pause/resume; left click also resumes; N restart. Reload and movement freeze while paused. The first click that resumes does not fire.

## Validation

See [docs/VALIDATION.md](docs/VALIDATION.md). The smoke suite currently contains 28 checks covering scene/player setup, mission flow, timed reload, finite reserve, pause behavior, cooldown gating, and completion restrictions. No passing engine run or Windows launch is claimed until the workflow or a local Godot 4.3 run confirms it. A successful export is not a visual playtest.

## Current limitations

This is an unfinished prototype, not a finished commercial release. The environment is procedural blockout geometry; targets are stationary blocks and there is no enemy AI yet. There are no production character models/animations, cinematic takedowns, final weapon handling animations, finished audio, save/load or campaign checkpoints, advanced navigation, or production art. The scope is currently a field-of-view/overlay prototype, not a finished optic. Ammunition exhaustion does not end the intel mission; restarting resets supplies.

See [docs/ROADMAP.md](docs/ROADMAP.md) for the staged development plan and acceptance criteria.
