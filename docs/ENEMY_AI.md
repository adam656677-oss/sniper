# Enemy AI foundation

The first enemy prototype is deliberately isolated from the existing mission controller.

## Files

- `enemy_ai.gd`: reusable `CharacterBody3D` enemy brain and health.
- `enemy.tscn`: primitive placeholder enemy scene.
- `tests/enemy_ai_smoke.gd`: headless checks for scene loading, initial state, sound investigation, damage, and elimination.

## Current behavior

The enemy supports idle, waypoint patrol, investigate, engage, and dead states. It searches for a node in the exported `target_group` (default: `player`), checks range, field of view, and raycast line of sight, and emits signals when it first detects a target or reaches an attack interval. Gunshots and other gameplay systems can call `investigate_position_at(world_position)` to provide a noise stimulus. Damage is applied through `receive_damage(amount, source_position)`.

Movement currently steers directly toward patrol points, stimuli, or a visible target. This is a foundation, not finished navigation: it does not yet pathfind around obstacles, use cover, coordinate squads, or apply damage to the player. The attack signal is a hook for a later combat system.

## Validation

With Godot 4.3 installed, run:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/enemy_ai_smoke.gd
```

The new test script has not been run by the GitHub connector. Confirm its result in Godot or CI before treating the implementation as validated.
