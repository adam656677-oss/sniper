# Validation and development builds

The workflow pins Godot 4.3 stable for repeatability, not as a claim that it is the latest engine. It downloads the editor and export templates from the official Godot release repository.

On pushes, pull requests, or manual dispatch, it imports the project, checks logs for engine/script errors, runs 16 mission smoke checks, and exports a Windows x86-64 development build only after validation succeeds. Logs are retained for failed runs where available. Builds are unsigned and are not public releases.

## Local validation
Install Godot 4.3 and its export templates, then run from the project directory:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/smoke.gd
mkdir -p builds/windows
godot --headless --path . --export-debug "Windows Desktop" builds/windows/EchoRidge.exe
```

## Downloading a successful build
In the repository's Actions tab, open a successful Validate and build run and download EchoRidge-Windows-development. Extract the complete archive and keep the EXE and PCK together. Do not infer success merely because these workflow files exist.

## Coverage and limits
Tests cover scene creation, player/camera initialization, targets, starting ammunition, floor collision, intel proximity, extraction requirements, development refill, and completion HUD. They do not verify shooting, aim accuracy, graphical appearance, audio, Windows launch behavior, performance, or enemy AI. A Linux headless export is not a Windows playtest.

These files have not yet executed in Godot at authoring time. GitHub Actions must run before any engine-test or build success can be reported. Actions availability and repository workflow permissions may affect execution. No credentials or paid services are required by the workflow; GitHub runner usage remains subject to the account's quotas and billing settings.
