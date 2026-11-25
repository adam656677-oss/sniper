# Muzzle Smoke Presentation

The first-person weapon viewmodel now emits a short-lived smoke wisp after each shot.

## Behaviour

- Unsuppressed weapons emit a compact, short-lived smoke puff.
- Suppressed weapons emit a denser and longer-lived wisp to give the muzzle a distinct signature.
- Smoke is attached to the current muzzle position in the viewmodel.
- Active smoke instances are capped at three and automatically cleaned up after their particle lifetime.
- Weapon model rebuilds clear any remaining smoke nodes.

## Validation

The viewmodel test checks the unsuppressed puff, the suppressed sidearm's larger/longer effect, and cleanup after the effect lifetime.

## Limitations

This is a procedural particle effect, not a physically simulated gas plume or a recorded muzzle blast. Smoke does not drift with wind, obscure optics, accumulate in rooms or use different materials for every weapon. Windows visual review is still needed to tune visibility and performance.
