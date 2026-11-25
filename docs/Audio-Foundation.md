# Audio foundation

The AudioDirector autoload centralizes positional sound-event playback and the SFX preference. It currently generates small mono PCM cues at runtime so the project has audible placeholders without committing unlicensed recordings or large binary packs.

## Events

- rifle_report
- suppressed_report
- sidearm_report
- reload_click
- impact
- footstep
- enemy_report
- radio_static

Player weapon firing selects a report based on weapon family and suppressor state. Enemy firing emits a separate positional hostile report. Reload initiation, bullet impacts and stance-aware player footsteps trigger their own cues. The event API supports world-space positions, volume offsets and pitch variation.

## Important limitations

These are procedural placeholder effects, not realistic recordings. They do not yet model distance-layered weapon tails, outdoor reflections, occlusion, indoor reverb zones, material-specific impacts, enemy voice acting, ambience beds, adaptive music, or mix ducking. The radio-static event is available for future wiring but is not yet triggered by gameplay. Footsteps currently use a generic procedural cue; per-surface sound variation is not implemented. A dedicated Music/SFX bus layout is also still outstanding; current playback follows the master output and SFX preference.

Replace the generated cues with licensed or original WAV/OGG assets once the final sound palette is selected. Record the source and licence in assets/LICENSES.md before adding any third-party sound.

## Validation

The tests/audio.gd suite checks event generation, sample format, mute behaviour, positional voice creation and safe handling of unknown event names. The CI workflow runs this suite alongside the existing game tests and Windows export.
