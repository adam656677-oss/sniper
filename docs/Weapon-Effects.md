# Weapon combat effects pass

This pass adds a short first-person brass casing animation to the existing procedural weapon viewmodel. Each shot spawns a small brass-colored cylinder that ejects to the right, arcs under gravity, spins, and cleans itself up after 0.95 seconds. A small cap prevents unbounded accumulation during rapid fire. The existing muzzle flash pulse, slide movement, recoil, tracer, dust impact and hit marker remain in place.

## Limits

The casing is a camera-local presentation effect, not a world-physics rigid body. It does not collide with floors, bounce, emit its own sound, or persist in the level. The weapon and arm geometry remain procedural placeholders rather than authored production models. Smoke, surface-specific impact materials, optional blood effects, footstep dust and distant explosions are still outstanding.

## Validation

The viewmodel test now checks casing creation and automatic cleanup. CI should run the complete test suite and Windows export. Human visual review is still required on Windows.
