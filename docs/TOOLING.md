# Tooling, assets and access

What is needed to complete Echo Ridge, grouped by who provides it. Items marked **(owner)** need an action or a decision from the owner; everything else can be done by an engineering session.

## Software (free unless noted)

| Tool | Purpose | Notes |
|---|---|---|
| Godot 4.7 stable + export templates | Engine, editor, headless tests, Windows export | Pinned by CI; repinned from 4.3 after checklist item 0.9 |
| Blender 4.x | Kitbashing models, rigging, animation retargeting, LOD generation | Export glTF 2.0 into `assets/models/` |
| Terrain3D (Godot add-on, MIT) | Heightmap terrain, texture painting, LOD | Needed for the 1 km² mission |
| Git LFS | Store binary assets (models, textures, audio) in the repository | **(owner)** enable LFS on the GitHub repository; default quota is 1 GB storage and 1 GB bandwidth per month, buy a data pack if exceeded |
| Audacity or Reaper | Audio editing, loudness normalisation | |
| Rclone or similar | Mirror purchased asset packs that cannot be committed | Only if licences forbid redistribution in a public repo |
| GitHub Actions | CI validation and Windows export (already configured) | **(owner)** check the account's Actions minutes; Windows runners cost 2x Linux minutes |

## Asset sources and licences

Every asset that enters the repository gets a line in `assets/LICENSES.md` (path, source, licence, attribution text). This is checklist item 3.1.

| Source | Licence | Good for |
|---|---|---|
| Poly Haven | CC0 | HDRIs, PBR textures, props |
| Kenney.nl | CC0 | UI, icons, placeholder props |
| Quaternius | CC0 | Characters, weapons, nature |
| Sketchfab (filter CC0 / CC-BY) | Per asset | Weapons, vehicles, buildings |
| Mixamo | Adobe terms, free for games | Humanoid animation clips |
| Freesound (filter CC0) | Per asset | Foley, ambience |
| Sonniss GDC bundles | Royalty free | Weapon and impact sound libraries |
| Synty, Dekogon, or similar packs **(owner budget)** | Commercial | Coherent environment sets, biggest single visual upgrade available |

## Decisions and access needed from the owner

1. **Approve or amend** `docs/superpowers/specs/2026-11-15-echo-ridge-design.md`, in particular the five open questions at the end.
2. **Branch protection on `main`** requiring the "Validate and build" check. Settings → Branches → Add rule. This stops the pattern that broke the build.
3. **Git LFS** enabled on the repository before any model, texture or audio is committed.
4. **Asset budget** (zero, modest, commissioned).
5. **A Windows machine and a time slot** for playtesting each milestone build, or a named person who will do it.
6. **Admin access offered**: nothing beyond the GitHub repository is required right now. The engineering sessions can download Godot themselves. If a paid asset pack, a Steam partner account, or a code-signing certificate becomes relevant (Phase 6), those will be requested at that point.

## Local setup for an engineer

```bash
# Linux
curl -L -o godot.zip https://github.com/godotengine/godot-builds/releases/download/4.7-stable/Godot_v4.7-stable_linux.x86_64.zip
unzip godot.zip && chmod +x Godot_v4.7-stable_linux.x86_64
export GODOT=$PWD/Godot_v4.7-stable_linux.x86_64
```

```bash
# Validate the project (import + every test suite)
scripts/validate.sh
```

```bash
# Also export the Windows debug build (needs export templates installed)
scripts/validate.sh --export
```

## Definition of done for any task

- A headless test exists for the behaviour, or the task is explicitly marked "visual, needs playtest".
- `scripts/validate.sh` passes locally.
- Pull request opened; "Validate and build" is green; README or docs updated if behaviour changed.
- No real manufacturer or product names added.
