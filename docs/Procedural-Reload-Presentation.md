# Procedural Weapon Reload Presentation

The first-person viewmodel now uses a staged reload pose driven by the weapon rig's existing reload timer.

## Animation phases

- **Early:** the weapon and camera presentation dip while the magazine begins to lower.
- **Middle:** the magazine remains clearly lowered and the weapon holds a brief reload posture.
- **Late:** the magazine rises back into its seated position and the weapon settles; a sidearm slide receives a short release movement.
- **Idle:** the pose returns to the normal hip/aim position without leaving residual transforms.

The transitions use a smooth interpolation curve and are derived from each weapon profile's configured reload duration, so different reload timings remain supported.

## Automated coverage

The viewmodel suite checks the magazine drop, mid-reload weapon dip, final magazine seating and return to a neutral weapon transform.

## Limitations

This is a procedural presentation layer, not authored animation. The hands do not yet grip or manipulate the magazine, there is no detached magazine prop or floor collision, rifle bolt/charging-handle motion is not authored, and there are no separate reload clips for sprint, prone or tactical reload variants. Production arm/weapon meshes and authored animation clips remain a later content task.
