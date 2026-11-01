# Modular gunsmith foundation

Status: isolated calculation module, not yet connected to gameplay or CI. Tests are authored, not reported as executed. No visual workbench or component meshes are included. Existing missions remain unchanged.

`gunsmith.gd` calculates effective stats from an unchanged base profile plus one installed part per slot. Recalculate from the base, never from a previously upgraded profile. Invalid combinations return an empty dictionary. The module does not read or write ammunition.

Prototype slots: optic, spring, stock. All values are fictional game balancing, not real modification specifications. Lightweight springs trade faster cycling for increased spread; stock choices trade reload timing against spread. Precision optics and reflex optics set different camera fields of view. Families include placeholders for future AR-style and L115-style weapons, which are NOT playable additions in this commit.

Run from the project root with Godot 4.3:

```sh
godot --headless --path . --script res://tests/gunsmith.gd
```

Next steps: connect computed profiles to firing/reload/aim logic; add a paused workbench with stock/upgraded/custom options; add per-weapon saved configurations; create separate component meshes and animated exploded/assembled views. Add ammunition migration rules before introducing capacity-changing parts.
