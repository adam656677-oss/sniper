# Kestrel Pass Environment Dressing

This pass adds deterministic, procedural visual dressing around the outer ridge and shelf of the Kestrel Pass blockout.

## Added

- 18 additional pine silhouettes with slight size, rotation and foliage-colour variation.
- 18 low-poly boulders with varied proportions and stone tones.
- 10 scrub clusters, each built from three small foliage meshes.
- A dedicated `EnvironmentDressing` scene node so the decorative pass is easy to inspect and replace later.

## Gameplay safety

All new dressing is mesh-only. It adds no collision objects, does not modify the navmesh footprint, and does not move mission objectives, guards, cover, extraction points or the existing playable routes. Placement is kept to the outer ridge/shelf and edge zones to preserve the depot sightlines.

The mission test checks that the dressing node contains at least 40 top-level objects and that no collision objects are introduced beneath it.

## Scope limitations

These are lightweight procedural silhouettes, not scanned or authored production assets. There is no wind animation, foliage translucency, terrain conforming, LOD system, GPU instancing, 1 km² heightmap or detailed photogrammetry. Windows visual review and performance profiling are still required before treating the environment as final.
