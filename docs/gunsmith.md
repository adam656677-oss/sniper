# Modular gunsmith foundation

Status: connected. The Loadout autoload persists installed parts per family to user://loadout.cfg and applies them to each WeaponProfile when a mission builds its weapon rig; the main menu Workbench screen edits them. Tests are authored, not reported as executed. No visual workbench or component meshes are included. Existing missions remain unchanged.

`gunsmith.gd` calculates effective stats from an unchanged base profile plus one installed part per slot. Recalculate from the base, never from a previously upgraded profile. Invalid combinations return an empty dictionary. The module does not read or write ammunition.

Prototype slots: optic, spring, stock. All values are fictional game balancing, not real modification specifications. Lightweight springs trade faster cycling for increased spread; stock choices trade reload timing against spread. Precision optics and reflex optics set different camera fields of view. Families are `recon`, `auto_shotgun`, `pump_shotgun`, `carbine` and `heavy_rifle`; the last two are placeholders with no playable weapon yet. `WeaponProfile.to_stats()` produces the base dictionary this module expects.

Run from the project root with Godot 4.7:

```sh
godot --headless --path . --script res://tests/gunsmith.gd
```

Next steps: connect computed profiles to firing/reload/aim logic; add a paused workbench with stock/upgraded/custom options; add per-weapon saved configurations; create separate component meshes and animated exploded/assembled views. Add ammunition migration rules before introducing capacity-changing parts.
