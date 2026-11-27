# Echo Ridge: project status

Audited 2026-11-26 against main commit `40263797cb949a53caece57684a0747a49c083f2`.

## Headline

Echo Ridge has a green Godot 4.7 development build pipeline and a growing single-player foundation. The main branch now includes the first integrated story-mode layer: a persistent campaign, an opening narrative sequence, radio/subtitle dialogue, evidence collection and chapter progression through the three existing mission scenes.

This is still an in-development prototype—not a finished game or a complete cinematic campaign. The opening is currently a text-and-dialogue presentation, not a playable 3D home/ambush sequence. Production character/weapon art, authored animation, recorded audio, finished environments, later campaign missions, the final boss and human Windows playtesting remain major work.

## Latest verified main-branch automation

For merge commit `40263797cb949a53caece57684a0747a49c083f2`:

| Workflow | Run | Result |
|---|---:|---|
| Validate and build | [45856882903](https://github.com/adam656677-oss/sniper/actions/runs/45856882903) | Success |
| Projectile regression tests | [45856882935](https://github.com/adam656677-oss/sniper/actions/runs/45856882935) | Success |
| Windows runtime smoke test | [45856885061](https://github.com/adam656677-oss/sniper/actions/runs/45856885061) | Success |

The validation workflow also exported a Windows development build and uploaded screenshots. These results confirm automated checks and a Windows runtime smoke test; they do not replace a human playing the game on a Windows PC.

## Implemented foundation

- Godot 4.7 project structure and Windows export workflow.
- First-person movement, scoped rifle handling, ballistic projectiles, wind, drag, zeroing, range finding, stances and breath sway.
- Sidearm, weapon profiles, staged procedural reload presentation, casing ejection, muzzle smoke and material-aware projectile impact effects.
- Enemy perception, patrol/suspicious/investigate/alert/search/flee/dead state machine, squad alert coordination, return fire, body discovery, lockdown and reinforcement foundations.
- Procedural enemy visual rig, directional hit stagger and death presentation foundations. These are not authored production animations or a final character rig.
- Mission objectives, triggers, extraction, checkpoints, save/load, results, settings, gunsmith and mission selection foundations.
- Kestrel Pass terrain shader and procedural ridge dressing foundations; the full 1 km² production terrain and authored environment kit remain.
- Positional audio event foundation with procedural cues; recorded weapon layers, foley, ambience, voice performance and final mix remain.
- Story campaign save state, New Story / Continue Story, a skippable nine-beat prologue presentation, reusable subtitle/radio overlay, mission radio beats, Black Ledger evidence screen and chapter progression across the currently existing Kestrel Pass, Echo Ridge recon and Compound scenes.

## Story direction and implementation

The original revenge/corporate-noir story is documented in:
- `docs/design/story-bible.md`: characters, factions, conspiracy, campaign arc, finale and production principles.
- `docs/design/campaign-outline.md`: prologue and eight-mission campaign map.
- `docs/design/mission-01-kestrel-pass.md`: Kestrel Pass mission design.

The story follows Elias Vance after Asterion Continuity's Varn Accord strike team attacks his home, kills his wife Lena Vale and frames him. Lena's Black Ledger evidence points to the NIGHTGLASS program and ultimately to Asterion director Silas Vey. The final confrontation is intended to be earned through the campaign, with the player deciding what happens to the evidence afterward.

The prologue opens with a short text presentation that sets up the evening, then hands off to a playable blockout: the home with three story discoveries, the front-door breach, and a stealth escape across the yard past two flashlight-sweeping Accord operatives (cover, crouch, an exposure meter, spotted-and-reset). Lena's loss and the framing are narrated over black after the escape, and the Kestrel Pass briefing acknowledges whether Elias was seen. It uses primitive geometry; the on-screen raid, authored characters, animation, voice and a human difficulty playtest remain. Later missions, the complete Rusk/Vey boss encounters and ending presentation are not implemented yet.

## Major remaining production gates

1. **Human Windows playtest:** download and launch the CI build; record controls, stability and playability in `docs/VALIDATION.md`.
2. **Playable story vertical slice:** replace the prologue blockout (home, breach and yard escape) with production art, the on-screen raid and animation; playtest the escape difficulty; finish the story handoff into Kestrel Pass.
3. **Core sniper feel:** visual/audio review of scope, impacts, weapon handling, camera and enemy reactions.
4. **World and art:** production terrain, environment kit, player/weapon models, character variants, authored animations, VFX and recorded audio.
5. **Campaign content:** build and playtest the remaining missions, including the final High Cairn boss encounter.
6. **Release readiness:** performance, accessibility, licensing, external QA, signing and release packaging.

## Checklist discipline

`docs/CHECKLIST.md` is the authoritative production checklist. An item stays open or in progress until its stated verification is complete. CI success alone does not complete a task that requires a human Windows playtest, visual review, performance capture or owner action.
