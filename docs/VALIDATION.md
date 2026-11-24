# Validation and development builds

The workflow pins Godot 4.3 stable for repeatability, not as a claim that it is the latest engine. It downloads the editor and export templates from the official Godot release repository.

On pushes, pull requests, or manual dispatch, the workflow imports the project, checks logs for engine/script errors, runs the 28 checks in `tests/smoke.gd`, and attempts a Windows x86-64 development export only after validation succeeds. Logs are retained for failed runs where available. Builds are unsigned and are not public releases. The workflow definition is not proof that a run has passed.

## Local validation

Install Godot 4.3 and its export templates, then run from the project directory:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/smoke.gd
mkdir -p builds/windows
godot --headless --path . --export-debug "Windows Desktop" builds/windows/EchoRidge.exe
```

## Downloading a successful build

In the repository's Actions tab, open a successful Validate and build run and download `EchoRidge-Windows-development`. Extract the complete archive and keep the EXE and PCK together. Do not infer success merely because these workflow files exist.

## Coverage and limits

The smoke suite covers scene creation, player/camera initialization, targets, starting ammunition, floor collision, intel proximity, extraction requirements, reload timing and reserve accounting, pause behavior, cooldown gating, and completion HUD/restrictions. It does not verify enemy AI, graphical appearance, audio, Windows launch behavior, performance, or the feel of the combat. A Linux headless export is not a Windows playtest.

At the time this document was updated, no new Godot engine run or Windows launch had been performed as part of this documentation change. GitHub Actions must complete successfully before engine-test or build success can be reported. Actions availability and repository workflow permissions may affect execution. No credentials or paid services are required by the workflow; GitHub runner usage remains subject to the account's quotas and billing settings.
