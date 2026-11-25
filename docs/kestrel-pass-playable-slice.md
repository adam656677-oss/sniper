# Kestrel Pass — playable campaign slice

Kestrel Pass is now a selectable single-player mission. It turns the existing design brief into a compact playable blockout that exercises the campaign objective flow.

## Mission flow

1. Insert in the south gully at dawn.
2. Move toward the depot and eliminate the named commander.
3. Recover the ledger at the office marker after the commander objective unlocks it.
4. Reach the north saddle extraction zone.

## Optional and secondary objectives

- Disable the radio mast by interacting at its base before lockdown.
- Stay undetected.
- Use suppressed weapons only.
- Eliminate the commander from beyond 500 m.

## Level blockout

The scene includes two raised approach areas with access ramps, a walled depot, office/workshop/storage buildings, fuel tanks, a radio mast, a road, tree clusters, eight guards and a named commander. Lockdown can add four reinforcements at the north gate. The level uses the existing perception, squad alert, weapon, ballistics, mission-log, checkpoint and results systems.

## Current limitations

This is a compact graybox/visual blockout, not the final 1 km² mountain environment. The ridge and pine shelf are raised simple meshes, not sculpted terrain; trees, buildings and tanks are procedural placeholders. The culvert route and abandoned north-gate truck are present as static blockout geometry. Detailed terrain, truck animation, radio junction-box destruction, a fully dressed office interior, authored cinematics, ambient/weapon audio and final landscape art remain outstanding. The radio mast is disabled through close interaction in this slice, not by shooting its junction box.

The commander and guards use the procedural humanoid placeholder rig from the enemy-character pass.

## Test

`tests/kestrel_mission.gd` verifies mission selection, the nine-enemy roster, objective unlock order, radio interaction, ledger recovery and north-saddle extraction.
