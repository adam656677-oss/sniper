# Modular gunsmith foundation

Status: connected. The Loadout autoload persists installed parts per family and the rifle chosen for the primary slot to user://loadout.cfg, and applies the parts to each WeaponProfile when a mission builds its weapon rig; the main menu Workbench screen edits them. No visual workbench models or component meshes are included.

`gunsmith.gd` calculates effective stats from an unchanged base profile plus one installed part per slot. Recalculate from the base, never from a previously upgraded profile. Invalid combinations (unknown part or family, wrong slot, a family the part does not fit, or a base profile missing a stat the part changes) return an empty dictionary. The module does not read or write ammunition.

Slots: optic, spring, stock. All values are fictional game balancing, not real modification specifications. Lightweight springs trade faster cycling for increased spread; stock choices trade reload timing against spread; the match barrel tightens spread and extends range. Families are `recon`, `sidearm`, `auto_shotgun`, `pump_shotgun`, `carbine` and `heavy_rifle`; `carbine` is a placeholder with no playable weapon yet. `WeaponProfile.to_stats()` produces the base dictionary this module expects.

## Optics

An optic sets the aimed camera view (`fov`) and, for projectile rifles, the scope: magnification range and step of the rendered scope view (`zoom_min`, `zoom_max`, `zoom_step`) and the holdover reticle, a mark every `reticle_step` metres beyond the zero out to `reticle_max` (never past the rifle's maximum range). Profiles default to the standard 4x to 12x scope with a mark every 100 m to 1000 m. Optics change only these optical stats, never ballistics or handling.

| Part | Fits | Aimed view | Magnification | Reticle | Trade-off |
|---|---|---|---|---|---|
| Precision scope | rifles | 18° | 4x to 12x (profile default) | every 100 m to 1000 m | Balanced |
| Thicket close-range scope | rifles | 32° | 2x to 8x in 2x steps | every 50 m to 600 m | Wide view and fine holds for close and middle distance; tops out at 8x and 600 m |
| Farwatch long-range scope | rifles | 14° | 6x to 24x in 3x steps | every 100 m to 1500 m | Reaches the heavy rifle's distances; narrow view, cannot go below 6x, and the higher power shows sway more |
| Reflex sight | every family | 60° | profile default | profile default | Wide aimed view |

The mission's `ScopeView` takes the range from the active projectile rifle's profile (`bind_weapon`, `configure`) and starts at the optic's lowest power; switching to a handgun leaves the rifle's optic and zoom in place. The scope camera clips everything within 2.5 m so the first-person viewmodel never appears in the magnified picture. `scope_overlay.gd` draws the reticle from the profile's spacing and reach.

## Rifles

The workbench chooses which rifle chassis occupies the primary slot (`Loadout.RIFLES`, keyed by gunsmith family; `Loadout.select_rifle`). Each chassis keeps its own installed parts. `WeaponRig` loads the chosen rifle into slot 0 in place of the default; the three handguns keep slots 1 to 3, so input bindings and saves are unchanged.

| Rifle | Family | Muzzle velocity | Drag | Damage | Magazine | Cycle | Reload | Max range | Recoil |
|---|---|---|---|---|---|---|---|---|---|
| Ridgeline recon rifle (default) | `recon` | 820 m/s | 0.0004 | 90 | 5 + 20 | 0.9 s | 2.2 s | 1200 m | 3.0° |
| Talus heavy rifle | `heavy_rifle` | 880 m/s | 0.00024 | 150 | 3 + 12 | 1.6 s | 3.4 s | 1800 m | 5.5° |

Zeroed at 100 m in still air, the Talus needs 6.8 m of holdover at 1000 m against the Ridgeline's 9.0 m, and drifts 0.37 m against 0.70 m in a 4 m/s crosswind at 800 m. It trades magazine size, cycling, reload and recoil for that reach and stopping power.

## Persistence

`user://loadout.cfg` holds a `[selection]` section with `rifle = "<family>"` and one section per family with `slot = "<part id>"`. Configs written before the rifle choice existed have no `[selection]` section and load with the recon rifle; an unknown or non-rifle stored choice also falls back to the recon rifle, and invalid parts are dropped.

Run from the project root with Godot 4.7:

```sh
godot --headless --path . --script res://tests/gunsmith.gd
godot --headless --path . --script res://tests/loadout.gd
```

Next steps: component meshes and animated exploded/assembled views; a playable carbine; ammunition migration rules before introducing capacity-changing parts; thermal and night optics are reserved for a later mission's mechanic.
