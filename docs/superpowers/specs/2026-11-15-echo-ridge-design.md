# Echo Ridge design document

Status: **draft for approval**. Written 2026-11-15 from the repository audit in `docs/STATUS.md` and the owner's brief: "an AAA single-player sniper game". Everything under *Owner decisions* came from the owner. Everything under *Proposed* is the author's call and is open to correction.

## Intent

A first-person, single-player, mission-based sniper game in the tradition of long-range marksman titles: the player infiltrates a large open area, uses a scope with realistic bullet drop and wind, chooses when and from where to take each shot, and deals with the consequences of a miss. The fantasy is patience, precision and consequence, not run-and-gun.

## Owner decisions (from the brief)

- Single player only.
- Sniper rifle is the core weapon; sidearms exist to support it.
- Quality bar is "AAA". Interpreted below as a *AAA-feel vertical slice* first, then content scale-up. See Constraints.
- Platform: Windows PC first (the existing export preset and CI already target this).

## Proposed (author's calls, open to correction)

- **Working title stays "Echo Ridge".**
- **Setting**: fictional mountainous border region, present day, fictional factions. Avoids real-world conflicts and real unit names. Weapon names become fictional (the repo currently names real commercial products; see anti-goals).
- **Tone**: grounded and quiet. Weight on stealth, observation and the single shot.
- **Core loop**: *Recon* (binoculars, mark targets, read wind) → *Position* (move, prone, set up) → *Shot* (breath hold, drop and wind compensation, slow-motion kill cam on long shots) → *Consequence* (alert states, relocation, extraction).
- **Vertical slice target**: one 1 km² mission with four to six marked targets, one enemy archetype with full perception and alert behaviour, one rifle with one scope, one sidearm, day lighting, full HUD, menus, save, audio and polish. This is the unit of "done" for Phase 4 in the checklist, and the thing to show people.

## Goals

1. A shot that feels earned: drop, wind, breath, range-finding and target lead all matter and are readable in the scope.
2. Enemies that behave believably at range: patrol, notice, investigate, alert, search, flank, flee.
3. Missions that reward observation and position over reflexes.
4. Production quality presentation: real models, animation, sound, lighting and effects, not primitives.
5. Stable 60 fps at 1080p on a mid-range GPU from the last four years.
6. Shippable: installer, settings, save, controller support, accessibility basics.

## Non-goals

- Multiplayer, co-op, leaderboards, online services.
- Console or mobile ports (keep the door open, do not build for it).
- Procedural or open-world scale. Missions are hand-built arenas.
- A full modding SDK.

## Anti-goals (would make it a failure even if it technically works)

- Shipping with primitive-box art or placeholder audio.
- A scope that is a field-of-view change rather than a rendered optic.
- Enemies that do not react to being shot at.
- Using real manufacturer and product names for weapons without a licence. The current `LOADOUT` table names two real commercial shotguns; rename before any public build.
- Another red CI run merged to `main`.

## Constraints

- **Team**: one owner plus AI coding sessions. "AAA" therefore means AAA *standards* applied to a small scope, not AAA head-count. The checklist scales content only after the vertical slice is polished.
- **Engine**: Godot 4.3 stable is pinned by CI and all existing code. Staying on Godot 4 is the recommendation (below). Upgrading the minor version is a checklist item with its own test gate, not an assumption.
- **Assets**: no art team. Plan on CC0 and purchased asset packs (Poly Haven, Kenney, Quaternius, Sketchfab CC-BY, Synty style packs) plus Blender for kitbashing, with a documented licence ledger. Purchased packs need owner budget approval.
- **Verification**: anything that cannot be checked by a headless test or a CI export must be checked by a human playtest on Windows. The repository has never had one. The owner is the playtester until that changes.
- **Repository hygiene**: pull requests only, CI must be green to merge.

## Approaches considered

### A. Rebuild on Unreal Engine 5

Industry default for AAA shooters; Nanite, Lumen, MetaHuman, Marketplace animation sets. Trades: discards all existing code and tests, C++ or Blueprint retooling, 20 GB plus toolchain that this CI and the cloud dev sessions cannot run headlessly, 5 percent royalty above 1 M USD revenue. Rejected: the owner's existing investment is in Godot, and the automation that lets AI sessions verify their own work does not exist for Unreal here.

### B. Rebuild on Unity 6 (HDRP)

Strong asset store, good animation tooling, C#. Trades: same discard-everything cost as A, licensing uncertainty history, HDRP is heavy for a solo project. Rejected for the same reason as A.

### C. Stay on Godot 4, restructure the prototype (recommended)

Keep the engine, the CI, the test harness and the ballistics work. Flatten the inheritance chain into scene-based composition: `Player`, `Weapon`, `Projectile`, `Enemy`, `Mission` scenes with scripts that expose one API the tests drive. Use the Forward+ renderer with SDFGI or VoxelGI, volumetric fog and TAA for the AAA look. Godot's weaknesses (no built-in animation retargeting as polished as Unreal's, weaker terrain tooling) are covered by Blender and the Terrain3D add-on. Chosen because it preserves the only verified assets the project has (ballistics, tests, CI) and because every step can be checked headlessly by the same automation that found the current breakage.

## Architecture (the parts decided here)

- **Scenes, not code-built nodes.** Each gameplay entity is a `.tscn` with its script. `main.gd` becomes a thin `Mission` root that loads a level scene.
- **One game-state autoload** (`GameState`): pause, mission phase, alert level, save data. No more per-layer `paused` flags.
- **Weapon as a resource plus a scene.** `WeaponProfile` (`Resource`) holds tuning (capacity, reload, interval, spread, muzzle velocity, zero range). `Weapon` scene holds model, animation player, muzzle, sounds. The gunsmith module produces a `WeaponProfile` from a base profile plus parts.
- **Ballistics stays a pure static module** (`ballistics.gd` already is). Add drag model and wind as velocity, not acceleration. All projectile integration tests keep passing.
- **Enemy AI as a state machine over a perception component.** Perception (vision cone, distance falloff, light level, sound events) feeds a per-enemy state: `Patrol`, `Suspicious`, `Investigate`, `Alert`, `Search`, `Flee`. A squad-level `AlertCoordinator` escalates the mission alert level.
- **Rendering**: Forward+ renderer. Compatibility renderer is kept only as a low-spec fallback if it costs nothing; otherwise dropped.
- **Input via `InputMap` actions**, never raw keycodes, so remapping and controller support are free.
- **Tests**: keep headless `SceneTree` scripts. Each new system ships with one. CI matches `SCRIPT ERROR:` and `FAIL:` only.

## Left to the builder

Level layout, enemy placement, exact tuning numbers, choice of specific asset packs within the licence rules, shader details, UI typography, and the order of Phase 5 content missions.

## Open questions for the owner

Ordered by how much the answer changes the plan.

1. **Scope and timeline.** The checklist assumes a vertical slice first and then scale-up. Is there a date or event this needs to be ready for?
2. **Budget for assets.** Zero (CC0 only), a few hundred dollars (asset packs), or more (commissioned art and audio)? This decides Phase 3 almost entirely.
3. **Realism level.** Sim-leaning (full drag model, mil-dot ranging, no kill cam) or arcade-leaning (readable drop indicator, kill cam, generous breath hold)? The proposal is arcade-leaning with a realism toggle.
4. **Weapon names.** Confirm fictional names are acceptable. The existing real product names are a licensing risk.
5. **Playtesting.** Who will run Windows builds and when? Until someone does, "it works" means "headless tests pass".
