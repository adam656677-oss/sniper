# Echo Ridge — game flow and system architecture

This document is the map of how the game is intended to work from launch to mission completion. The master production tracker is **[CHECKLIST.md](CHECKLIST.md)**; this file explains the systems and the paths between them.

> **Status note (26 November 2026):** The diagrams describe the current architecture and intended finished-game flow. Some systems are already implemented, some are procedural foundations, and some remain roadmap work. A diagram is not proof that a feature is complete. Use the checklist's `[x]` / `[~]` / `[ ]` status and each item's verification requirement as the source of truth.

## 1. Whole-game flow

```mermaid
flowchart TD
    BOOT([Launch Echo Ridge]) --> ENGINE[Godot loads project and autoload services]
    ENGINE --> MENU[Main menu]
    MENU --> CONTINUE{Continue available?}
    CONTINUE -->|Yes| RESUME[Load checkpoint through SaveSystem]
    CONTINUE -->|No| SELECT[Mission catalog]
    MENU --> SELECT
    SELECT --> WORKBENCH[Optional gunsmith and loadout preparation]
    WORKBENCH --> BRIEF[Mission briefing and objectives]
    BRIEF --> LOAD[Load selected mission scene]
    RESUME --> LOAD
    LOAD --> INIT[Mission root builds level, player, weapon rig, enemies and HUD]
    INIT --> PLAY[First-person gameplay loop]
    PLAY --> PAUSE{Pause requested?}
    PAUSE -->|Yes| PAUSED[Pause menu / settings / resume]
    PAUSED --> PLAY
    PLAY --> CHECK{Mission state}
    CHECK -->|Objective update| PLAY
    CHECK -->|Checkpoint| SAVE[SaveSystem writes versioned checkpoint]
    SAVE --> PLAY
    CHECK -->|Primary objective complete and extraction reached| RESULTS[Results screen and score]
    CHECK -->|Player death or mission failure| FAIL[Failure / retry / checkpoint reload]
    FAIL --> PLAY
    RESULTS --> RECORDS[Progression records, unlocks and achievements]
    RECORDS --> NEXT{More campaign missions?}
    NEXT -->|Yes| SELECT
    NEXT -->|No| COMPLETE([Campaign complete])
    RESULTS --> MENU
```

## 2. Runtime architecture — which system owns what

```mermaid
flowchart TB
    subgraph APP["Application and persistent services"]
      MENU["Main Menu / Mission Catalog / Settings"]
      GS["GameState<br/>pause, failure, completion, difficulty"]
      SET["Settings<br/>input, video, audio, accessibility"]
      SAVE["SaveSystem<br/>versioned saves and checkpoints"]
      LOADOUT["Loadout<br/>weapon parts and configurations"]
      PROG["Progression<br/>records, unlocks, achievements"]
      AUDIO["AudioDirector<br/>positional gameplay sound events"]
      STORY["StoryCampaign<br/>chapter state, evidence, dialogue flags"]
      DIALOGUE["StoryDialogue<br/>subtitles and radio overlay"]
    end

    subgraph MISSION["Mission scene — mission.gd"]
      LEVEL["Level implementation<br/>terrain, cover, props, weather, navigation"]
      PLAYER["Player scene<br/>movement, camera, stance, health, interaction"]
      WEAPON["WeaponRig + WeaponProfile<br/>ammo, fire, reload, selection"]
      BALLISTICS["Ballistics / Projectile system<br/>drag, gravity, wind, zero, collision"]
      ENEMY["Enemy + Perception<br/>sensing, state machine, navigation, combat"]
      ALERT["AlertCoordinator<br/>shared contact, alert level, reinforcements"]
      OBJECTIVES["MissionLog + TriggerZones<br/>primary, secondary, optional, extraction"]
      HUD["HUD / Scope / Binoculars<br/>feedback and mission information"]
      FX["Shot feedback<br/>tracers, impacts, holes, casing, smoke"]
      TAKEDOWN["Takedown / Kill camera<br/>cinematic presentation"]
    end

    MENU --> MISSION
    GS <--> MISSION
    SET --> PLAYER
    SET --> WEAPON
    SET --> HUD
    SAVE <--> MISSION
    LOADOUT --> WEAPON
    PROG <--> MISSION
    STORY <--> MENU
    STORY <--> MISSION
    STORY --> DIALOGUE
    AUDIO <--> PLAYER
    AUDIO <--> WEAPON
    AUDIO <--> ENEMY
    PLAYER <--> WEAPON
    WEAPON --> BALLISTICS
    BALLISTICS --> FX
    BALLISTICS --> ENEMY
    ENEMY <--> ALERT
    ENEMY <--> LEVEL
    PLAYER <--> LEVEL
    PLAYER --> OBJECTIVES
    ENEMY --> OBJECTIVES
    LEVEL --> OBJECTIVES
    OBJECTIVES --> HUD
    PLAYER --> HUD
    WEAPON --> HUD
    WEAPON --> TAKEDOWN
    ENEMY --> TAKEDOWN
```

### Persistent services

| Service | Responsibility |
|---|---|
| `GameState` | Shared mission state: pause, completion/failure, difficulty and mission-level flags |
| `Settings` | Saved user preferences, controls, sensitivity, video/audio and accessibility options |
| `SaveSystem` | Versioned save data, checkpoints, quick save/load and validation of corrupt or incompatible files |
| `Loadout` | Installed weapon parts and per-weapon configurations |
| `Progression` | Mission records, best score/time/shot distance, unlocks and achievements |
| `AudioDirector` | Positional gameplay sound events and SFX preference handling |
| `StoryCampaign` | Saved story chapter, unlocks, evidence, seen dialogue, flags and ending decision |
| `StoryDialogue` | Shared subtitle/radio overlay that presents lines requested by the story campaign |

### Mission scene ownership

The mission root coordinates the active level and game systems. The level owns the physical world and level-specific setup. The player owns movement and first-person interaction. The weapon rig owns the current weapon's firing/reload state. The ballistics system owns projectile travel and hit resolution. Enemies own their individual perception and behaviour; the alert coordinator shares information between them. The mission log owns objective state and completion rules. UI reads and presents state; it should not become the owner of gameplay rules.

## 3. Player and weapon loop — from input to impact

```mermaid
flowchart TD
    INPUT[InputMap: mouse, keyboard or controller] --> ACTION{Player action}
    ACTION --> MOVE[Move / crouch / prone / sprint]
    ACTION --> AIM[Aim / scope / range / wind]
    ACTION --> FIRE[Fire current weapon]
    ACTION --> RELOAD[Reload]
    ACTION --> INTERACT[Interact / tag / use stealth tool]
    MOVE --> PLAYER[Player controller and camera]
    AIM --> PLAYER
    INTERACT --> PLAYER
    PLAYER --> STEALTH[Stance, speed, visibility and noise]
    FIRE --> PROFILE[WeaponProfile: fire mode, ammo, muzzle velocity, suppression]
    PROFILE --> VALID{Can fire?}
    VALID -->|No| HUD[HUD feedback]
    VALID -->|Yes| SHOT[Create shot and consume ammunition]
    SHOT --> TYPE{Weapon type}
    TYPE -->|Projectile rifle| BALLISTICS[Ballistics: velocity, gravity, drag, wind and zero]
    TYPE -->|Hitscan sidearm| RAY[Hitscan ray / hit zones]
    BALLISTICS --> COLLISION[Collision and hit-zone resolution]
    RAY --> COLLISION
    COLLISION --> RESULT{What was hit?}
    RESULT -->|Enemy / target| DAMAGE[Apply hit-zone damage and kill logic]
    RESULT -->|World surface| SURFACE[Resolve material: metal, wood, earth or stone]
    DAMAGE --> ENEMY[Enemy state / target state update]
    SURFACE --> IMPACT[Material-specific particle impact and optional decal]
    SHOT --> PRESENT[Recoil, muzzle flash, casing and smoke]
    SHOT --> SOUND[AudioDirector: weapon report]
    COLLISION --> MARK[Hit marker / bullet camera when eligible]
    DAMAGE --> MARK
    ENEMY --> MISSION[Mission objectives and statistics update]
    IMPACT --> MISSION
    PRESENT --> HUD
    SOUND --> HUD
    MARK --> HUD
    RELOAD --> AMMO[Transfer reserve ammunition and animate reload]
    AMMO --> HUD
```

The intended shot chain is: **input → weapon validation → ammunition consumption → projectile or hitscan → collision → hit-zone/material response → mission statistics/objectives → player feedback**. A weapon profile supplies the weapon-specific values; the ballistics system should not contain UI rules.

## 4. Enemy perception and response

```mermaid
stateDiagram-v2
    [*] --> Patrol
    Patrol --> Suspicious: sound, glimpse or disturbance
    Suspicious --> Patrol: stimulus expires / no evidence
    Suspicious --> Investigate: confidence threshold reached
    Investigate --> Alert: player confirmed or attacked
    Investigate --> Search: trail lost
    Alert --> Search: last known position lost
    Search --> Alert: player reacquired
    Search --> Patrol: search timeout
    Alert --> Flee: morale / mission rule
    Patrol --> Dead: lethal hit
    Suspicious --> Dead: lethal hit
    Investigate --> Dead: lethal hit
    Alert --> Dead: lethal hit
    Search --> Dead: lethal hit
    Flee --> Dead: lethal hit
    Dead --> [*]
```

Enemy perception combines sight, distance, occlusion, stance/light exposure and hearing. Gunshots, footsteps and distractions are stimuli. Each enemy changes its own state; the alert coordinator shares last-known player information, changes the overall alert level and can trigger reinforcements. Body discovery is another world stimulus. The finished game still needs authored animations, varied characters, convincing hit reactions and ragdoll/death presentation.

## 5. Mission lifecycle and objective rules

```mermaid
flowchart TD
    START([Mission starts]) --> BRIEF[Load briefing, map and objective definitions]
    BRIEF --> INSERT[Spawn player and initialize world]
    INSERT --> ACTIVE[Mission active]
    ACTIVE --> PRIMARY{Primary objective state}
    ACTIVE --> SECONDARY[Track secondary and optional objectives]
    ACTIVE --> CHECKPOINT[Save checkpoint at approved milestones]
    SECONDARY --> ACTIVE
    CHECKPOINT --> ACTIVE
    PRIMARY -->|Incomplete| ACTIVE
    PRIMARY -->|Failed| FAILED[Mission failed]
    PRIMARY -->|Complete| EXFIL[Enable / reach extraction]
    EXFIL --> EXTRACT{Player reaches extraction and interacts?}
    EXTRACT -->|No| ACTIVE
    EXTRACT -->|Yes| COMPLETE[Mission complete]
    FAILED --> RETRY[Retry or reload checkpoint]
    RETRY --> INSERT
    COMPLETE --> SCORE[Calculate score, accuracy, stealth and shot records]
    SCORE --> SAVE[Persist progression and unlocks]
    SAVE --> RESULTS[Show results and next mission option]
```

Mission content should be data-driven where practical: objective definitions, trigger zones, enemy placements, mission phases and extraction rules belong to the mission/level, not hard-coded into generic UI. Optional objectives should never block primary completion unless explicitly designed to do so.

## 6. Build, test and release pipeline

```mermaid
flowchart TD
    CHANGE[Developer change] --> BRANCH[Feature or documentation branch]
    BRANCH --> TEST[Run scripts/validate.sh]
    TEST --> PASS{All import and headless suites pass?}
    PASS -->|No| FIX[Fix regression; do not merge]
    FIX --> TEST
    PASS -->|Yes| EXPORT[Export Windows x86-64 development build]
    EXPORT --> RUNTIME[Windows runtime smoke test]
    RUNTIME --> SCREEN[Capture screenshots / inspect artifacts]
    SCREEN --> REVIEW[Review diff, checklist and licence impact]
    REVIEW --> HUMAN{Human Windows playtest required?}
    HUMAN -->|Yes| PLAY[Launch and play on Windows; record result]
    HUMAN -->|No| MERGE[Merge after required checks and review]
    PLAY --> ACCEPT{Playtest passes?}
    ACCEPT -->|No| FIX
    ACCEPT -->|Yes| MERGE
    MERGE --> MAIN[Update main and checklist status]
    MAIN --> RELEASE[Release candidate: full QA, performance, accessibility and legal review]
    RELEASE --> TAG[Version tag triggers release workflow]
    TAG --> INSTALLER[Windows release artifact / installer]
    INSTALLER --> SIGN[Code signing and clean-machine install test]
    SIGN --> PUBLISH[Publish build, notes, specs and known issues]
```

The automated Windows runtime smoke test is not a substitute for a human playtest. A green CI run does not prove that controls feel good, graphics look finished, sound works on a user's device, performance meets the target, or a full campaign can be completed.

## 7. Where to find the implementation

| Area | Main files |
|---|---|
| Project entry and menu | `project.godot`, `scenes/ui/main_menu.tscn`, `scenes/ui/main_menu.gd` |
| Mission coordinator | `mission.gd`, `main.tscn`, `kestrel_mission.tscn`, `compound_mission.tscn` |
| Player | `scenes/player/player.tscn`, `scenes/player/player.gd`, `scenes/player/stealth_kit.gd` |
| Weapons and scope | `scenes/weapons/`, `ballistics.gd`, `scope_overlay.gd` |
| Enemies | `scenes/enemies/enemy.gd`, `perception.gd`, `alert_coordinator.gd`, `enemy_visual.gd` |
| Levels and atmosphere | `scenes/levels/` |
| Objectives | `scenes/missions/mission_log.gd`, `trigger_zone.gd` |
| Feedback and takedowns | `scenes/fx/shot_feedback.gd`, `scenes/killcam.gd`, `scenes/takedown_controller.gd` |
| UI | `scenes/ui/` |
| Persistent services | `autoload/` |
| Automated tests | `tests/`, run by `scripts/validate.sh` |
| CI and Windows export | `.github/workflows/build.yml`, `projectiles.yml`, `windows-runtime.yml`, `release.yml` |

## 8. How the master checklist is maintained

The authoritative task list is **[CHECKLIST.md](CHECKLIST.md)**.

- `[ ]` = not complete.
- `[~]` = partially implemented or awaiting required verification.
- `[x]` = implemented **and** its stated verification passed.
- Every feature PR must identify the checklist item(s) it changes.
- Update the checklist in the same PR as the implementation.
- Do not mark a Windows visual/audio/playtest item complete based only on headless tests or a successful export.
- Owner-only tasks (accounts, certificates, branch protection, store setup, legal approvals and physical Windows testing) remain open until the owner completes them.
- Each phase has an exit gate. Do not call the game complete until the release exit gate in the master checklist is satisfied.

For validation commands, test coverage and playtest recording, see [VALIDATION.md](VALIDATION.md). For the full production sequence and outstanding work, see [CHECKLIST.md](CHECKLIST.md).

## 9. Story mode flow — prologue to campaign progression

```mermaid
flowchart TD
    MENU[Main menu] --> NEW[New Story]
    MENU --> CONTINUE[Continue Story]
    NEW --> RESET[StoryCampaign creates a fresh campaign save]
    RESET --> PROLOGUE[The Last Quiet Night prologue]
    CONTINUE --> ROUTE[Resolve active chapter from campaign save]
    ROUTE --> PROLOGUE
    ROUTE --> KESTREL[Kestrel Pass]
    ROUTE --> ECHO[Echo Ridge recon]
    ROUTE --> COMPOUND[The Compound]
    PROLOGUE --> BEATS[Skippable narrative beats and saved position]
    BEATS --> COMPLETE_PROLOGUE[Complete prologue]
    COMPLETE_PROLOGUE --> KESTREL
    KESTREL --> RADIO[StoryDialogue radio/subtitle beats]
    RADIO --> OBJECTIVES[Mission objectives and player choices]
    OBJECTIVES --> EVIDENCE[Recover Black Ledger fragments]
    EVIDENCE --> DOSSIER[Evidence dossier]
    DOSSIER --> RESULT[Results screen records chapter completion]
    RESULT --> UNLOCK[StoryCampaign unlocks next chapter]
    UNLOCK --> CONTINUE_RESULT[Continue Story]
    CONTINUE_RESULT --> ECHO
    ECHO --> RESULT
    COMPOUND --> RESULT
    UNLOCK --> FUTURE[Later chapters remain locked / in development until playable]
```

### Story ownership and save boundaries

- `StoryCampaign` owns narrative progress and saves to `user://campaign/story.json`. It is separate from `SaveSystem` mission checkpoints and `Progression` score records.
- `StoryDialogue` is a presentation layer. It receives speaker/line events; it does not decide whether a chapter or evidence item is unlocked.
- Mission objective events can request one-time dialogue and add evidence. Replayed scenes do not repeat already-seen one-time story lines.
- The prologue stores its current beat so Continue Story resumes the sequence.
- The current story path connects the prologue to Kestrel Pass, Echo Ridge recon and The Compound. Later campaign chapters are intentionally not selectable until their playable scenes exist.
- The current prologue is a text-and-dialogue cinematic presentation. A fully playable 3D home/ambush sequence, authored cinematics, voice acting and the final boss/ending presentation remain production work.
