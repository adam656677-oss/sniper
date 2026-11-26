# Echo Ridge: project status

Audited 2026-11-26 against main commit `06934a750b611322ebd7c01fcc1e7d1e9e9628a8`.

## Headline

Echo Ridge has moved beyond the original broken prototype. The main branch has a growing Godot 4.7 single-player foundation, mission and enemy systems, a 1000 m shooting range, a Kestrel Pass blockout, a shared UI shell, procedural visual/audio effects and automated Windows build/runtime validation.

This is still an in-development prototype—not a finished game and not yet a complete cinematic story campaign. Production character/weapon art, authored animation, recorded audio, finished environments, full mission content and human Windows playtesting remain major work.

## Latest verified main-branch automation

For commit `06934a750b611322ebd7c01fcc1e7d1e9e9628a8`:

| Workflow | Run | Result |
|---|---:|---|
| Validate and build | 45738500837 | Success |
| Projectile regression tests | 45738500832 | Success |
| Windows runtime smoke test | 45738691418 | Success |

These results confirm automated checks and a Windows runtime smoke test on the listed commit. They do not replace a human playing the game on a Windows PC.

## Implemented foundation

- Godot 4.7 project structure and Windows export workflow.
- First-person movement, scoped rifle handling, ballistic projectiles, wind, drag, zeroing, range finding, stances and breath sway.
- Sidearm, weapon profiles, staged procedural reload presentation, casing ejection, muzzle smoke and material-aware projectile impact effects.
- Enemy perception, patrol/suspicious/investigate/alert/search/flee/dead state machine, squad alert coordination, return fire, body discovery, lockdown and reinforcement foundations.
- Procedural enemy visual rig, directional hit stagger and death presentation foundations. These are not authored production animations or a final character rig.
- Mission objectives, triggers, extraction, checkpoints, save/load, results, settings, gunsmith and mission selection foundations.
- Kestrel Pass terrain shader and procedural ridge dressing foundations; the full 1 km² production terrain and authored environment kit remain outstanding.
- Positional audio event foundation with procedural cues; recorded weapon layers, foley, ambience, voice performance and final mix remain outstanding.

## Narrative direction

The new campaign direction is documented in:
- `docs/design/story-bible.md`: protagonist, tragedy, corporation, cast, campaign arc, finale and story-system production plan.
- `docs/design/campaign-outline.md`: prologue and eight-mission campaign map.
- `docs/design/mission-01-kestrel-pass.md`: current Kestrel Pass mission design, to be revised for the new story.

The story is a narrative blueprint only. The prologue, cinematic sequences, dialogue/subtitles, evidence viewer, story flags, boss fight and ending choice are not yet implemented.

## Major remaining production gates

1. **Human Windows playtest:** download and launch the CI build; record controls, stability and playability in `docs/VALIDATION.md`.
2. **Core sniper feel:** visual/audio review of scope, impacts, weapon handling, camera and enemy reactions.
3. **World and art:** production terrain, environment kit, player/weapon models, character variants, authored animations, VFX and recorded audio.
4. **Story vertical slice:** playable prologue and Kestrel Pass with character introduction, attack, briefing, reactive radio and evidence progression.
5. **Campaign content:** build and playtest the remaining missions, including the final High Cairn boss encounter.
6. **Release readiness:** performance, accessibility, licensing, external QA, signing and release packaging.

## Checklist discipline

`docs/CHECKLIST.md` is the authoritative production checklist. An item stays open or in progress until its stated verification is complete. CI success alone does not complete a task that requires a human Windows playtest, visual review, performance capture or owner action.
