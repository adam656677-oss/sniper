# Dropped Magazine Reload Effect

The first-person viewmodel now ejects a separate magazine prop during the reload sequence.

## Behaviour

- At roughly one quarter of the reload timeline, the magazine prop is duplicated at the weapon's current magazine transform.
- The duplicate moves away from the weapon, tumbles and falls under a lightweight presentation gravity curve.
- The magazine well is visually empty during the middle reload phase.
- The replacement magazine becomes visible again during the seating phase.
- Dropped props expire after 1.35 seconds and are capped at two active instances to prevent unbounded node growth.

## Validation

The viewmodel test checks the ejected prop, the temporarily empty magazine well, the replacement magazine, and cleanup after the fall.

## Limitations

This is a camera-local visual effect, not a world-space rigid body. The prop does not collide with the floor or persist in the level. The hands are not yet animated to remove or insert it, and there are no authored magazine variants, tactical reloads or retained-magazine logic. Those require proper weapon/hand animation and a world pickup/drop system.
