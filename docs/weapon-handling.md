# First-person weapon handling

This branch adds an original, code-built first-person viewmodel to the existing player camera.

## Included

- Distinct placeholder silhouettes for the recon rifle and sidearms.
- Simple forearm/sleeve geometry to establish weapon scale in first person.
- Aim/hip positioning, low-amplitude idle sway, movement bob and weapon-switch settling.
- Shot recoil, a short muzzle-flash pulse and a small reciprocating slide cue on handguns.
- Reload presentation driven by the existing timed reload state, including a separate magazine piece.
- A regression suite in `tests/viewmodel.gd`.

The viewmodel reads the active `WeaponProfile` and `WeaponRig` state. It does not duplicate ammunition, ballistics, damage or reload logic.

## Controls

- Mouse: aim and fire
- R: reload
- 1–4: select rifle or handgun
- Mouse wheel / configured next-weapon action: cycle weapons

## Art-production note

The meshes are deliberately original procedural placeholders made from primitive geometry. They prove the camera attachment and animation hooks without importing unlicensed models. They are not photorealistic weapon assets, skinned hands, motion-captured reloads, shell casings or production audio. Those remain a separate art/audio pass.

## Validation

Run `scripts/validate.sh --export` with the pinned Godot 4.7 build. The viewmodel suite checks attachment, weapon swaps, recoil, muzzle flash and reload-state presentation. The full project suite must pass before this branch is considered ready for Windows playtesting.
