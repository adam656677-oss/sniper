# Surface-Specific Bullet Impact Effects

Bullet impacts now choose a lightweight particle response based on the struck surface.

## Surface types

- **Metal:** short, bright, emissive-looking spark fragments with a fast falloff.
- **Wood:** warm-coloured splinters with a moderate outward burst.
- **Earth:** a wider, softer brown dust puff.
- **Stone (fallback):** the existing neutral dust-and-chip response.

## Surface identification

The mission resolves a surface from explicit `impact_surface` metadata first, then optional groups (`surface_metal`, `surface_wood`, `surface_earth`), then common environment names such as fuel tanks, trucks, crates, ground and roads. Unrecognised objects safely fall back to stone.

## Automated coverage

The feedback suite checks surface classification and the expected distinct particle response for metal, wood and earth.

## Limitations

These are procedural particles, not recorded high-fidelity material sounds or authored decal textures. There are no ricochet direction calculations, material-specific bullet penetration, persistent scorch marks, glass breakage or surface-specific audio recordings yet.
