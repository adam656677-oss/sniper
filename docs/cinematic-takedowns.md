# Cinematic takedown foundation

Press **F** when close behind an unaware guard to perform a silent takedown.

## Eligibility

- The target must be alive and within 2.2 metres.
- The player must be behind the target.
- The target cannot already be in the alert or flee state.
- Carrying a body prevents starting a takedown.

## Sequence

- Switches from the first-person camera to a short third-person camera move.
- Freezes player and enemy physics while the cinematic plays.
- Silently eliminates the target partway through the sequence.
- Records the kill through the existing mission statistics signal.
- Restores the first-person camera, HUD, viewmodel and prior physics-processing states.
- Escape cancels the sequence before the elimination moment.

## Production-art note

This is a working camera/gameplay foundation. It currently uses the enemy's procedural death collapse rather than a bespoke synchronized grab/strike animation. Final motion-captured takedown animations, character contact poses, sound design, blood/impact effects and camera polish remain outstanding.
