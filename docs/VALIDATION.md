# Validation and development builds

The project targets Godot 4.3 stable for repeatability. Do not treat the existence of a workflow or test script as proof that validation has passed.

## Local validation

Install Godot 4.3 and its export templates, then run from the project directory:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/smoke.gd
godot --headless --path . --script res://tests/enemy_ai_smoke.gd
mkdir -p builds/windows
godot --headless --path . --export-debug "Windows Desktop" builds/windows/EchoRidge.exe
```

Run the import step first so Godot registers the `EchoRidgeEnemy` global class used by the isolated enemy test.

## Existing mission smoke suite

`tests/smoke.gd` covers scene creation, player/camera initialization, targets, starting ammunition, floor collision, intel proximity, extraction requirements, reload timing and reserve accounting, pause behavior, cooldown gating, and completion HUD/restrictions.

## Enemy AI smoke suite

`tests/enemy_ai_smoke.gd` checks that the enemy scene loads, starts in the expected state, accepts an investigation stimulus, takes damage, enters the dead state, and is removed from the scene.

The enemy test is a foundation test, not proof of full enemy gameplay. It does not yet validate waypoint navigation, perception/occlusion in a complete encounter, cover selection, player damage, animation, or combat balance.

## Windows build and playtest

A successful export is not a Windows playtest. Launch the packaged build on Windows, verify the EXE and PCK work together, complete the mission, and record any errors or performance issues before calling the build verified. Do not label a development export as a release.

No Godot engine run, smoke-test pass, or Windows launch is claimed for the current branch until those steps have actually completed. No paid services or assets are required for these tests.
