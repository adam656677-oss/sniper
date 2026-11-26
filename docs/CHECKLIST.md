# Echo Ridge master checklist

The ordered production checklist for taking Echo Ridge from the current broken prototype to a shippable single-player sniper game. Phases are sequential gates: do not start a phase until the previous phase's **exit gate** is met. Within a phase, items are ordered by dependency.

Each item has a **verify** note. `test` means a headless `SceneTree` script in `tests/` that CI runs. `playtest` means a human on Windows. `review` means a documentation or code review in the pull request.

Legend: `[ ]` not started, `[~]` in progress, `[x]` done and verified. Update this file in the same pull request as the work.

Game flow and architecture diagrams: `docs/GAME-FLOW.md`. Design reference: `docs/superpowers/specs/2026-11-15-echo-ridge-design.md`. Current state: `docs/STATUS.md`. Tools and access: `docs/TOOLING.md`.

---

## Phase 0: Repair and stabilise (the build must be green before anything else)

- [x] 0.1 Fix `scope_overlay.gd` parse error: `var hit := ...` becomes `var hit: Dictionary = ...`. Verify: import log has no `SCRIPT ERROR`.
- [x] 0.2 Resolve the duplicate members. Remove `paused`, `reload_remaining`, `cooldown`, `reserve`, `start_reload`, `can_fire`, `perform_shot` and the pause/reload handling from `main.gd`, restoring it to the world-building base, **or** complete 0.5 directly. Verify: `scripts/validate.sh` import step passes.
- [x] 0.3 Fix CI false positive in all three workflows: fail only on `SCRIPT ERROR:` and `FAIL:`, not every `ERROR:` (the headless dummy renderer prints `Parameter "m" is null` for `BoxMesh`). Verify: a green "Validate and build" run on the pull request.
- [x] 0.4 Consolidate the two test APIs. All suites drive `WeaponRig` and the `GameState` autoload. Verify: smoke and focus suites both pass against one script.
- [x] 0.5 Flatten the inheritance chain. Replace `main.gd` > `gameplay.gd` > `weapons.gd` > `projectile_gameplay.gd` with: `Mission` root script, `Player` scene, `Weapon` scene, `WeaponProfile` resource, `Projectile` system, `GameState` autoload. HUD built from `Control` nodes, no string replacement. Verify: every existing test passes unchanged in intent; test files may be edited only for node paths.
- [x] 0.6 Convert the code-built world into `levels/test_range.tscn` (ground, cover, targets, terminal, extraction). Verify: smoke test "Three test targets spawn" passes from the scene.
- [x] 0.7 Replace raw keycodes with `InputMap` actions (`move_*`, `fire`, `aim`, `reload`, `interact`, `pause`, `restart`, `weapon_1..3`). Verify: tests use `Input.action_press` or synthesised action events.
- [x] 0.8 Rename real product names in `LOADOUT` to fictional ones. Verify: review.
- [x] 0.9 Evaluate upgrading to the current Godot 4.x stable. (4.7 stable: all suites pass unchanged; CI repinned.) Run the full suite and a Windows export on the candidate version in a branch. Adopt only if green; update the CI pin. Verify: CI green on the new pin.
- [ ] 0.10 Enable branch protection on `main` requiring "Validate and build" **(owner)**. Verify: a push to `main` without a pull request is rejected.
- [x] 0.11 Update `README.md` and `docs/VALIDATION.md` to describe the real suite and controls. Verify: review.
- [ ] 0.12 Download the Windows build from CI and launch it on a Windows machine. Verify: playtest; record the result in `docs/VALIDATION.md`.

**Exit gate:** CI green on `main`, a Windows build artefact exists, one human has launched it and played the test range.

---

## Phase 1: Core sniper feel (the shot)

- [~] 1.1 (SubViewport scope camera, 4x to 12x magnification, textured reticle disc and scaled holdover marks done; scope mesh, parallax, eye-box vignette and chromatic edge need art and a playtest) Rendered scope. A `SubViewport` rendering the scoped view through a scope mesh, with parallax, eye-box vignette, chromatic edge and reticle as a texture. Variable zoom (e.g. 4x to 12x). Verify: playtest; test asserts scope camera FOV range and that reticle scene instantiates.
- [x] 1.2 Ballistics v2 in `ballistics.gd`: drag (G1 or G7 coefficient), muzzle velocity per profile, wind as a velocity vector affecting relative airflow, zeroing distance. Verify: test with reference trajectories (drop at 300 m, 600 m, 1000 m within tolerance).
- [x] 1.3 Breath hold and sway: stamina-driven hold, sway amplitude based on stance and heart rate. Verify: test sway amplitude ranges by stance; playtest feel.
- [x] 1.4 Stances: stand, crouch, prone. Prone with bipod reduces sway further. Verify: test collider heights and sway multipliers.
- [x] 1.5 Range-finding and wind reading: laser range finder (or mil-dot estimation on realism setting), wind indicator on HUD and in scope. (Wind sock props deferred to Phase 3 environment kit.) Verify: test range readout against known distance; playtest readability.
- [x] 1.6 Scope zero adjustment (elevation turret in 100 m steps) and holdover marks. Verify: test that zeroing to N metres gives zero drop at N.
- [x] 1.7 Hit model: hitboxes (head, torso, limbs) on a target scene with damage multipliers. Verify: test headshot kills, limb hit does not.
- [x] 1.8 Bullet time / kill cam for shots over a distance threshold, skippable, optional in settings. Verify: playtest; test that it triggers only above threshold.
- [~] 1.9 (tracers, hit marker, capped bullet holes, dust/chip, metal sparks, wood splinters and earth/stone dust are implemented; ricochet direction/audio, authored decals and optional blood toggle remain) Impact feedback: material-aware projectile response, readable hit confirmation and optional gore setting. Verify: Windows visual/audio playtest.
- [x] 1.10 Sidearm: suppressed pistol with hitscan, for close range. Shotguns removed or kept as a mission-specific pickup. Verify: weapons test updated.
- [~] 1.11 Weapon animation: procedural idle/aim sway, recoil, firing cycle and staged reload pose now include a separate tumbling magazine prop, weapon dip, magazine seating and slide release; authored idle, aim in/out, bolt cycle, sprint, hand animation and production clips remain. Verify: Windows playtest; test animation timing and required authored clips.
- [~] 1.12 (recoil kick and recovery, head bob off when aiming or with reduced motion; sprint FOV and landing dip pending sprint) Camera: head bob, recoil kick and recovery, FOV change on sprint, landing dip. Verify: playtest.
- [x] 1.13 Target range level: a 1000 m shooting range with distance markers, steel plates that ring and fall, wind variation. This is the tuning playground. Verify: playtest.

**Exit gate:** A playtester can hit a plate at 600 m using the scope, wind and drop cues without being told the numbers, and says the shot feels good.

---

## Phase 2: Enemies and stealth

- [~] 2.1 (hit zones, navigation, death handling and a procedural humanoid visual rig are implemented; production skeletal mesh, authored rig, ragdoll physics and animation clips remain) Enemy scene: production humanoid model, skeleton, hitboxes from 1.7, ragdoll on death, `NavigationAgent3D`. Verify: test spawn, navigation to a point, death ragdoll activates.
- [x] 2.2 Perception component: vision cone with distance falloff, occlusion raycasts to multiple body points, light-level factor, hearing with sound events (gunshot radius by weapon and suppressor, footsteps by stance and surface). Verify: test detection times at distances, in cover, in shadow.
- [x] 2.3 Behaviour state machine: Patrol, Suspicious, Investigate, Alert, Search, Flee, Dead. Timeouts and de-escalation. Verify: test transitions for scripted stimuli.
- [x] 2.4 Squad coordination: `AlertCoordinator` shares last known position, escalates mission alert level (Calm, Suspicious, Alert, Lockdown), spawns reinforcement patrol on Lockdown. Verify: test escalation rules.
- [x] 2.5 Enemy combat: return fire with inaccuracy that improves while the player stays still; suppression of player (screen effect); flanking move toward last known position. Verify: test accuracy curve; playtest.
- [x] 2.6 Body awareness: enemies discover bodies and escalate; player can move bodies. Verify: test body discovery escalates.
- [~] 2.7 Enemy animations: procedural idle/walk posing and a short directional stagger/recoil on non-lethal hits are implemented and tested. Authored idle, walk/run, aim/fire clips, hit-zone-specific reactions, alert gestures, multiple death variants and ragdoll remain. Verify: Windows playtest; validate hit reaction timing and readable silhouettes.
- [x] 2.8 Player stealth tools: binoculars with target tagging, noise meter, stone distraction. (Outline-through-walls visual comes with Phase 3.) Verify: test tagging persists, noise meter responds.
- [x] 2.9 Player damage, health regeneration or medkits, death and checkpoint reload. Verify: test damage and respawn.
- [x] 2.10 Difficulty settings affecting perception rates, enemy accuracy, HUD assists. Verify: test that difficulty scales the numbers.

**Exit gate:** In the test range with ten enemies, a playtester can complete a stealth clear and a loud clear, and enemies behave believably in both.

---

## Phase 3: World, art and audio (the AAA look)

- [ ] 3.1 Asset licence ledger `assets/LICENSES.md` and Git LFS enabled **(owner)**. Verify: review; a model commits through LFS.
- [ ] 3.2 Switch to the Forward+ renderer; configure SDFGI or VoxelGI, volumetric fog, SSAO, SSR, TAA, physical light units, ACES tonemap. Verify: playtest at target hardware for 60 fps at 1080p; test that project settings match.
- [~] 3.3 Terrain: Kestrel Pass has a procedural multi-scale earth/rock ground shader plus a deterministic mesh-only ridge dressing pass for pine silhouettes, boulders and scrub. The playable mission remains a compact flat blockout. Terrain3D, a 1 km² heightmap, true texture splat maps, grass and distance-culling detail meshes remain. Verify: Windows visual review and playtest frame-time budget.
- [~] 3.4 Environment kit: existing blockout buildings, walls, road, fuel tanks, radio mast and low-poly pine clusters are supplemented by deterministic ridge pines, boulders and scrub; decorative dressing has no collision and does not alter navigation. Production rocks, authored trees with wind sway/LODs, detailed buildings, props and vehicles remain. Verify: Windows visual review; review of ledger; playtest.
- [x] 3.5 (dawn, noon, dusk and night presets with sky, sun, ambient, haze and shadows; cloud shadows pending art) Lighting and atmosphere: sun angle and sky per mission, time of day presets (dawn, noon, dusk, night), fog layers, cloud shadows. Verify: playtest.
- [~] 3.6 (clear, windy, rain and dust presets driving gusting ballistic wind, haze, enemy sight and hearing; rain and dust particles pending art) Weather: wind strength and direction tied to ballistics, rain and dust storms as visibility modifiers. Verify: test weather affects wind vector; playtest.
- [ ] 3.7 Player and weapon models: first-person arms, rifle with scope and bipod, pistol, binoculars. Verify: playtest.
- [ ] 3.8 Characters: at least two enemy variants (patrol, officer) with material variation. Verify: playtest.
- [~] 3.9 VFX: muzzle flash, tracer, dust/chip impacts, capped bullet holes, hit marker, metal sparks, wood splinters, earth/stone dust, first-person brass casing ejection and short muzzle-smoke wisps (with a denser suppressed-weapon signature) are implemented. Production decals, world-space debris/physics, optional blood, movement dust, distant explosions and final authored VFX remain. Verify: Windows visual playtest.
- [~] 3.10 Audio: procedural positional event foundation added for player rifle, suppressed, sidearm, reload, impact, stance-aware footsteps and enemy weapon reports; gameplay events are wired and automated PCM/playback tests added. Recorded weapon layers, reflections, surface-specific footsteps, foley, ambience beds, enemy voice barks, dynamic music and a dedicated mix bus with ducking remain. Verify: test bus layout; Windows audio-device playtest.
- [ ] 3.11 Performance pass: occlusion culling, LOD distances, texture streaming budgets, shadow cascade tuning, GPU profile under 16 ms. Verify: automated frame-time capture in a scripted fly-through.

**Exit gate:** A 60-second capture of the mission looks like a current-generation game to someone who has not seen the project.

---

## Phase 4: Vertical slice mission and game shell

- [x] 4.1 Mission 1 design doc (docs/design/mission-01-kestrel-pass.md): objectives, map, enemy placement, routes, three approaches. Verify: review.
- [x] 4.2 Mission framework: objectives (primary, secondary, optional), mission phases, triggers, scripted events, failure conditions, extraction. Verify: test objective completion and failure.
- [ ] 4.3 Build Mission 1 on the terrain from 3.3. Verify: playtest start to finish.
- [x] 4.4 Checkpoints and save/load: serialise mission state, player state, enemy states, with versioned save format. Verify: test save, restart, load round trip.
- [~] 4.5 Main menu, pause menu, mission select, results screen (score, accuracy, longest shot, stealth rating). Shared tactical theme, cinematic shader backdrop, title hierarchy, mission-button styling, and pause/results panels added; Windows visual review and final art remain. Verify: test navigation; playtest.
- [x] 4.6 (subtitles toggle stored but has nothing to caption until audio exists) Settings: video (resolution, window mode, vsync, quality presets, FOV), audio (buses), controls (remap, sensitivity, invert), gameplay (realism toggles, kill cam, assists), accessibility (subtitles, colour-blind reticle, hold or toggle aim, reduced motion). Persist to user settings file. Verify: test persistence.
- [~] 4.7 (bindings for every action, right-stick look, trigger hold-to-aim, bumper weapon cycle; on-screen glyphs, aim assist and a real controller playtest pending) Controller support with glyphs and aim assist option. Verify: playtest with a controller.
- [x] 4.8 Gunsmith workbench: wire `gunsmith.gd` to `WeaponProfile`, workbench UI between missions, per-weapon saved configuration. Verify: existing gunsmith tests plus save round trip.
- [~] 4.9 (seven guided steps on the 1000 m range: aim, ring 100 m, range, zero, ring 300 m, breath, holdover; needs a playtest with someone new) Tutorial: the target range from 1.13 as a guided first mission. Verify: playtest with someone new.
- [x] 4.10 Localisation hooks: all strings through `tr()`, CSV with English. Verify: test that no user-facing literal strings remain in scripts (lint script).
- [x] 4.11 Crash and error handling: engine log written to user://logs (five rotating files), corrupt, incomplete and wrong-version saves rejected with a reason. Verify: test corrupt save fallback.

**Exit gate:** A stranger can install the build, start a new game, play the tutorial and Mission 1 to the results screen, change settings, quit and resume from a checkpoint, with no instructions from the team.

---

## Phase 5: Content scale-up

- [x] 5.1 Campaign outline and story bible (docs/design/campaign-outline.md and docs/design/story-bible.md): original revenge/corporate-noir premise, protagonist, tragedy, principal cast, eight-mission arc and final boss/ending structure are defined. Verify: narrative review; story implementation is tracked separately.
- [~] 5.7 Story systems: persistent campaign progression, skippable narrative intro, first-person playable home blockout, three interactable story discoveries, Lena's data-key evidence, off-screen attack/blackout beat, escape objective, dialogue/radio overlay, Black Ledger dossier UI and chapter progression through the three existing mission scenes are implemented and headless-tested. The home uses primitive blockout geometry and a placeholder character silhouette; authored characters, animation, sound, full ambush/escape set piece, remaining campaign missions, integrated final boss and ending presentation remain. Verify: story campaign tests plus full Windows playthrough.
- [ ] 5.2 Missions 2 through N, each with a distinct biome or time of day and one new mechanic (night with thermal scope, moving vehicle target, protect an ally, timed extraction, sandstorm). One pull request per mission, each with a playtest. Verify: playtest each.
- [ ] 5.3 Additional rifles and scopes through the gunsmith (fictional names). Verify: gunsmith tests extended.
- [ ] 5.4 Enemy variety: snipers that counter the player, dogs, vehicles, drones. Verify: tests for each perception type.
- [~] 5.5 (local per-mission best score, fastest time and longest shot with a Records screen; dedicated long-shot challenges pending content) Challenge modes: range leaderboard (local), long-shot challenges. Verify: test scoring.
- [x] 5.6 Achievements framework (platform-agnostic, local). Verify: test unlock rules.

**Exit gate:** Full campaign playable start to finish by a playtester in one sitting without a blocking bug.

---

## Phase 6: Polish, QA and release

- [x] 6.1 Bug triage process (docs/TRIAGE.md, issue and pull request templates): issue labels, severity, weekly pass. Verify: review.
- [ ] 6.2 Full playtest rounds with at least five external testers, feedback captured and triaged. Verify: review.
- [ ] 6.3 Performance validation on minimum and recommended specs; document them. Verify: captures.
- [ ] 6.4 Accessibility review against the game accessibility guidelines basic tier. Verify: review.
- [~] 6.5 (release workflow on version tags, version and build stamp in the menu; PCK encryption decision pending owner) Release build: release export template, PCK encryption decision, version stamping, build number in main menu. Verify: CI produces a release artefact.
- [ ] 6.6 Code signing certificate **(owner)** and signed installer. Verify: SmartScreen does not warn on a clean Windows install.
- [ ] 6.7 Store presence **(owner decision)**: Steam partner account, store page, capsule art, trailer, achievements wiring if Steam. Verify: review.
- [ ] 6.8 Legal: licence ledger complete, third-party notices screen, privacy statement if any telemetry, age rating self-assessment. Verify: review.
- [ ] 6.9 Launch day checklist: tagged release, changelog, backup of build, known issues list. Verify: review.
- [ ] 6.10 Post-launch: crash log collection channel, patch cadence. Verify: review.

**Exit gate:** Signed release build on the store or download page, with documented specs and known issues.

---

## Current verified foundation (2026-11-25)

The main branch now includes the cinematic menu/UI pass, Kestrel Pass procedural terrain and ridge dressing foundations, positional audio event foundation, brass casing ejection, material-aware bullet impact particles, and muzzle-smoke presentation. These are procedural foundations, not final authored AAA assets. The latest completed work is reflected in the phase items above; never mark an item `[x]` solely because code exists or CI passes when its verify note requires a human Windows playtest, asset review, performance capture or release-owner action.

## Working agreements that keep the checklist honest

1. One pull request per checklist item or small group; the PR links the item and updates this file.
2. CI green is mandatory. Never merge red. Never widen the grep to hide an error.
3. Every system ships with a headless test. Visual items are marked `playtest` and the playtest result (date, machine, outcome) is recorded in `docs/VALIDATION.md`.
4. Fictional names for weapons, factions and places.
5. The design doc is updated when a decision changes, in the same PR.
