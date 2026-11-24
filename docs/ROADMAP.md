# Echo Ridge — Development Roadmap

## Product direction

Build a polished, gritty, single-player tactical action game for Windows PC in Godot 4.3. The core camera is first-person; selected close-quarters takedowns may transition into authored third-person cinematics. Favor believable pacing, readable combat, strong sound, and deliberate level design over feature count.

Use free tools and assets by default. Do not add paid dependencies or assets without approval. Keep the project runnable at each milestone and preserve working systems unless a replacement is verified.

## Current repository baseline

The project is a Godot 4.3 prototype with a procedural test environment and a first-person player/camera. Existing source includes:
- Mouse-look, movement, zoom/scope overlay, pause, restart, and HUD.
- Three fictional weapon profiles, reload/ammunition handling, and shotgun pellet raycasts.
- Recon-rifle projectile travel with gravity and configurable wind acceleration in `ballistics.gd`.
- Intel collection and extraction objectives.
- A headless smoke-test script and a GitHub Actions validation/build workflow.

Known limitations:
- The environment is primitive procedural blockout geometry.
- The three targets are static test objects; there is no enemy character or enemy AI.
- No production character animation, takedown system, final audio, campaign save/checkpoints, or finished art direction.
- Scope is currently a field-of-view/overlay prototype, not a finished optic.
- Existing smoke tests do not establish visual quality, Windows runtime behavior, or gameplay feel. A successful export is not a substitute for playtesting.

## Milestones

### 0 — Stabilize the prototype
- Keep Godot 4.3 as the pinned baseline until an intentional engine upgrade is tested.
- Reconcile documentation with the actual scripts and CI workflow.
- Run the headless import and smoke suite; fix errors before adding dependent systems.
- Verify a Windows development export and record what was actually tested.

**Exit criteria:** clean import, passing smoke tests, reproducible Windows development build, and documentation that matches the repository.

### 1 — Enemy foundation
- Add a modular enemy character scene with health, damage response, and clear state ownership.
- Implement a small state machine: idle, patrol, investigate, alert, engage, and dead.
- Add player visibility checks with range, field-of-view, and line-of-sight obstruction.
- Add a simple sound/noise stimulus interface so gunshots and player actions can attract enemies.
- Begin with deterministic waypoint patrol and simple movement; introduce NavigationAgent3D only with a tested navigation mesh.
- Add tests for state transitions, detection boundaries, damage, and death.

**Exit criteria:** one enemy can patrol, detect the player fairly, investigate a stimulus, engage, take damage, and die without breaking the existing mission.

### 2 — Combat encounter vertical slice
- Add one compact encounter with cover, sightlines, readable entry routes, and a clear objective.
- Give enemies distinct telegraphs and reaction windows; avoid unfair instant detection or perfect accuracy.
- Add hit feedback, impact effects, muzzle flashes, and temporary placeholder audio using free assets or original effects.
- Tune weapon handling and enemy health together; keep all weapon tuning explicitly game-oriented.

**Exit criteria:** a complete encounter is playable, understandable, and repeatable.

### 3 — Close-quarters action and takedowns
- Build a contextual takedown system with range, facing, target-state, and obstruction checks.
- Use a controlled third-person camera transition and authored animation only during the takedown.
- Add interruption rules, invulnerability timing where appropriate, and clear return to first-person control.
- Make takedowns optional and avoid forcing them into every encounter.

**Exit criteria:** takedowns are reliable, readable, and do not trap the player or break camera/input state.

### 4 — Campaign vertical slice
- Create one complete mission: briefing, insertion, infiltration, objective, escalating encounter, extraction, and debrief.
- Add checkpoints and persistent mission state only after restart/load behavior is tested.
- Use mission scripting/data rather than hard-coding every objective into the player controller.
- Establish a consistent narrative tone and environmental storytelling.

**Exit criteria:** one polished mission can be completed from start to finish and replayed.

### 5 — Presentation and content
- Replace blockout assets with optimized, legally usable environment and character assets.
- Establish lighting, materials, post-processing, animation, weapon handling, UI, and sound standards.
- Profile frame time, memory, and load behavior on representative Windows hardware.
- Add accessibility options for sensitivity, subtitles, FOV, and key bindings.

**Exit criteria:** visual/audio presentation is cohesive, performant, and supports the gameplay rather than obscuring it.

### 6 — Windows release readiness
- Add settings, save management, error handling, credits, and a clean first-run experience.
- Test packaged builds on a clean Windows environment.
- Verify asset licenses, third-party notices, and distribution permissions.
- Produce versioned builds and release notes; do not label a development export as a release.

**Exit criteria:** reproducible packaged build, verified playthrough, documented controls, and no known release-blocking defects.

## Engineering rules

1. Inspect existing architecture before changing it.
2. Prefer small, reviewable commits on feature branches.
3. Keep gameplay systems modular; avoid growing the inherited script chain further.
4. Add a test or explicit manual validation checklist for each meaningful feature.
5. Run Godot import, smoke tests, and export checks after relevant changes.
6. Report exactly what was run and what remains unverified.
7. Never claim a feature, test, or Windows build works without evidence.
8. Ask before introducing paid tools, assets, services, or licensing obligations.

## Immediate next task

Complete milestone 0 validation, then implement milestone 1 as an isolated enemy scene and state machine. Do not replace the current test mission until the enemy can be tested in isolation and then integrated behind a controlled feature change.
