# Enemy character presentation

This pass replaces the visible blockout cubes with an original procedural humanoid presentation while retaining the existing collision and hit-zone nodes.

## Included

- Humanoid silhouette with helmet, uniform, plate carrier, pouches, gloves and boots.
- Separate head, torso, arms, forearms, thighs and calves for readable proportions.
- A fictional compact weapon silhouette that appears when the enemy enters an alert/search combat posture.
- Procedural walk cycle driven by horizontal movement.
- Combat-ready arm pose and a simple visual collapse on death.
- Regression checks for visual rig creation, preserved hit zones and state-driven posing.

## AI and combat

The existing enemy state machine remains authoritative: patrol, suspicious, investigate, alert, search, flee and dead. It continues to use perception, line-of-sight, sound, squad contact sharing, flanking movement, return fire, health and hit-zone damage. The visual rig only reads that state; it does not create a second AI or change weapon damage.

## Art-production note

This is an original procedural placeholder character, not a photorealistic scanned human, rigged production character, motion-captured animation or final uniform/weapon asset. It provides a more human-readable silhouette and animation hook without introducing unlicensed third-party art. Final character meshes, facial/cloth detail, hand-authored animation, ragdoll physics and combat audio remain future production work.

## Validation

Run `scripts/validate.sh --export` with Godot 4.7. The `tests/enemy_visual.gd` suite checks the rig, hit-zone preservation and state-driven movement/pose changes.
