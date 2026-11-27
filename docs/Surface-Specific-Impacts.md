# Surface-Specific Bullet Impact Effects

Bullet impacts choose a lightweight particle response based on the struck surface, and rifle rounds that graze a hard surface ricochet.

## Surface types

- **Metal:** short, bright, emissive-looking spark fragments with a fast falloff. Hard: can deflect a grazing round.
- **Wood:** warm-coloured splinters with a moderate outward burst.
- **Earth:** a wider, softer brown dust puff.
- **Stone (fallback):** the existing neutral dust-and-chip response. Hard: can deflect a grazing round.
- **Flesh (hostiles and target dummies):** the optional blood mist when the setting is on, otherwise the neutral stone dust. Never deflects a round.

## Surface identification

`scenes/fx/impact_surfaces.gd` resolves a surface from explicit `impact_surface` metadata first, then optional groups (`surface_metal`, `surface_wood`, `surface_earth`, `surface_flesh`), then hostiles and target dummies (flesh, matched by script class name), then common environment names such as fuel tanks, trucks, crates, ground and roads. Unrecognised objects safely fall back to stone. The mission's impact effects and the weapon rig's ricochet rule share this one classification.

## Ricochets

A simulated rifle projectile that strikes metal or stone at **15 degrees or less** (the angle between its path and the surface) ricochets instead of stopping:

- **Direction:** the mirror reflection of its path about the surface normal, turned by up to **4 degrees** of scatter. The scatter comes from `WeaponRig.ricochet_rng`, so seeding it repeats a ricochet exactly; `ricochet_scatter = 0` gives the bare reflection. Scatter never turns the round back into the surface.
- **Energy:** it keeps **60% of its speed**, so 36% of its energy, and any hit it then makes deals 36% of the weapon's damage (a ricochet into a head is still lethal, into a torso it wounds).
- **Range:** it flies on as a normal projectile (drag, gravity, wind, swept collision) for **100 m**, then drops out. It can hit a target or hostile on that path; the hit distance counts the whole path.
- **One bounce:** a deflected round that grazes another hard surface stops there.
- **What stops as before:** strikes steeper than 15 degrees, earth, wood, and anything that takes hits (hostiles, dummies, steel plates). A hit on a target always counts.
- **Feedback:** the strike shows the usual surface impact and hole, plus a tight fan of fast sparks and a brief bright streak along the new path. The tracer of a deflected round starts at the strike instead of reaching back through the surface. AudioDirector plays a procedural `ricochet` cue at the strike: a sharp tick and a tone gliding down from about 3.4 kHz to 0.9 kHz with a slight warble.
- **Guards:** the strike is reported as a noise with a 40 m radius (scaled by the weather's hearing factor). Guards within 10 m are alarmed and turn toward the strike; guards out to 40 m investigate it. This matters most for suppressed shots, whose report only carries 25 m.

Straight flight is untouched: the integration, range limit and kill-cam prediction are the same as before. The prediction stops at the first surface, so a round that would ricochet is never predicted to kill and never followed by the bullet camera. Hitscan sidearm rounds never ricochet.

The numbers are fictional gameplay tuning (`Ballistics.RICOCHET_*` and `WeaponRig.RICOCHET_*`), not ballistic data.

## Blood effects

`Gameplay > Blood effects` (`gameplay/blood_effects`, saved with the other settings) is **on by default**. When on, a hit on a hostile or target dummy throws a small dark-red mist back toward the shooter: ten billboarded motes, 1 to 3 cm, that drift and fade out within 0.4 seconds. There are no decals, pools, wounds or dismemberment, and nothing lingers. When off, the same hit shows the neutral stone dust puff. Steel plates and the environment never bleed. The hit marker is identical in both modes.

On by default because the story bible asks for grounded violence with consequences: a grey dust puff on a person reads like a sandbag. The mist is deliberately restrained, and the toggle is one click away for players who prefer it off. Content ratings consider what the game can show, so defaulting it off would not change the age rating self-assessment (checklist 6.8).

## Automated coverage

The feedback suite checks surface classification and the expected distinct particle response for metal, wood and earth. The impacts suite (`tests/impacts.gd`) checks the deflection maths (threshold, reflection, retention, seeded scatter), live grazing strikes on metal and stone deflecting and still hitting a target on the new path, the 100 m onward range, steep and soft strikes stopping, the ricochet sparks and whine, guards hearing a ricochet, the blood mist only with the setting on, the hit marker unchanged in both modes, and straight flight following the unchanged integration.

## Limitations

These are procedural particles and a procedural cue, not recorded high-fidelity material sounds or authored decal textures. There is no material-specific bullet penetration, fragmentation, persistent scorch marks, glass breakage, surface-specific impact recordings, ricochet off the ground (earth is soft) or ricochet for hitscan rounds. The look and sound still need a Windows visual and audio playtest.
