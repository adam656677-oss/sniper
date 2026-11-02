# Echo Ridge

Single-player computer sniper-game prototype for Godot 4.3. Import project.godot and press F5.

## Implemented in source
Procedural 3D test environment, player collision and first-person movement, mouse aiming, reduced scoped sensitivity, zoom, hitscan target shooting, one-second shot cooldown, five-round magazine, 20 reserve rounds, two-second reload, intel collection, extraction, pause and restart. Shooting queries are processed in the physics update.

## Controls
WASD move; mouse aim; left click fire; right click toggle zoom; R reload; E collect/extract; Escape pause/resume; left click also resumes; N restart. Reload and movement freeze while paused. The first click that resumes does not fire.

## Validation
See docs/VALIDATION.md. The existing workflow imports the project, runs tests/smoke.gd, and attempts a Windows development export. The smoke suite now contains 28 checks including timed reload, finite reserve, pause, cooldown gating and completed-mission firing restrictions. No passing engine run or Windows launch is claimed here. A successful export is not a visual playtest.

## Limitations
Unfinished prototype, not a AAA release. Targets are stationary blocks without enemy AI. No projectile travel, bullet drop, wind, reload/bolt animation, sound, save/load, advanced navigation or production art. Scope is a field-of-view change, not a finished optic. Ammunition exhaustion does not end the intel mission; restart resets supplies. Validation documentation's older 16-check description refers to the initial suite; current checks are in tests/smoke.gd.
