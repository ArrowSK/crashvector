<p align="center">
  <img src="assets/branding/crashvector-icon.svg" alt="CrashVector — educational 3D crash simulation" width="170">
</p>

<h1 align="center">CrashVector</h1>

<p align="center">
  <strong>Build a crash. Change the speed. Inspect the outcome.</strong>
</p>

<p align="center">
  Educational 3D collision simulation with generic deformable vehicles, replay, analysis and cinematic export.
</p>

<p align="center">
  <img alt="M13 progressive failure" src="https://img.shields.io/badge/milestone-M13%20progressive%20failure-ff4d1f?style=for-the-badge">
  <a href="https://github.com/ArrowSK/crashvector/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/ArrowSK/crashvector/actions/workflows/ci.yml/badge.svg?branch=main"></a>
</p>

<p align="center">
  <a href="https://github.com/ArrowSK/crashvector/releases/download/v0.5.0-beta.1/CrashVector-0.5.0-beta.1-macOS-universal.dmg"><img alt="Download CrashVector for macOS" src="https://img.shields.io/badge/Download-macOS%20Universal%202-111111?style=for-the-badge&logo=apple"></a>
  <a href="https://github.com/ArrowSK/crashvector/releases/download/v0.5.0-beta.1/CrashVector-0.5.0-beta.1-Windows-x64-Setup.exe"><img alt="Download CrashVector for Windows" src="https://img.shields.io/badge/Download-Windows%20x64-0078D4?style=for-the-badge&logo=windows11"></a>
</p>

<p align="center">
  <a href="https://github.com/ArrowSK/crashvector/releases/tag/v0.5.0-beta.1">Release notes & checksums</a>
  ·
  <a href="docs/DISTRIBUTION.md">Installation & updates</a>
</p>

<p align="center">
  <img alt="Godot 4.4.1+" src="https://img.shields.io/badge/Godot-4.4.1%2B-478cbf">
  <img alt="MPL 2.0" src="https://img.shields.io/badge/license-MPL--2.0-6c7a89">
  <img alt="Generic models" src="https://img.shields.io/badge/models-generic%20classes-19b5a5">
  <img alt="Educational simulation" src="https://img.shields.io/badge/scope-educational-19b5a5">
</p>

CrashVector is an open-source desktop crash-simulation sandbox for people who want to **see what speed, mass and impact configuration change** without turning the exercise into specialist engineering software.

The M12/M13 production architecture deliberately separates whole-vehicle motion from permanent crush. For supported production scenarios, Godot `RigidBody3D` owns mass, inertia, translation, rotation, gravity, continuous collision detection and road/world collision. CrashVector's structural graph is local deformation relative to that rigid chassis. M13 extends the local failure model past the front rails so sufficiently severe frontal impacts can propagate through the firewall, floor/rockers, A-pillars/roof, passenger cell and eventually the rear body instead of stopping at an artificial one-metre crush boundary.

> **Current state:** **M13 is the current corrective desktop beta, 0.5.0-beta.1.** The production rigid-body path supports passenger-car impacts with rigid wall, concrete barrier, pole, tree, another passenger car and the heavy articulated truck. Passenger cars use four force-producing suspension contacts; the truck uses six and a physical rear underride contact face. The responsive M10 UI, replay, analysis, cinematic export, native installers, updater and scenario-file format remain in place.

> **Important boundary:** rigid lorry, motorcycle, bicycle and pedestrian production simulation are temporarily blocked until those targets are ported to the same rigid-body world architecture. Visual Compare and Comparison Lab are also temporarily unavailable because their historical batch runner still uses the reduced-order world solver. CrashVector will not silently substitute that old solver for a current production result.

> **Scope:** CrashVector is an educational physics visualisation tool. It is **not** certified accident reconstruction, homologation, manufacturer crash-performance prediction, biomechanics, medical/injury prediction or a safety-rating system.

## Download and install

No Git, Godot, Python, Terminal or PowerShell is required for the packaged desktop beta.

| Platform | Download | Install |
| --- | --- | --- |
| macOS — Apple Silicon + Intel | **[Download macOS Universal 2 DMG](https://github.com/ArrowSK/crashvector/releases/download/v0.5.0-beta.1/CrashVector-0.5.0-beta.1-macOS-universal.dmg)** | Open the DMG, then drag **CrashVector.app** onto the **Applications** shortcut. Launch it from Applications. |
| Windows 10/11 x64 | **[Download Windows x64 Setup](https://github.com/ArrowSK/crashvector/releases/download/v0.5.0-beta.1/CrashVector-0.5.0-beta.1-Windows-x64-Setup.exe)** | Run Setup and follow the graphical installer. CrashVector installs under Program Files and appears in the Start menu and Installed apps. |

The matching SHA-256 checksum files and `update-manifest.json` are on the **[0.5.0-beta.1 release page](https://github.com/ArrowSK/crashvector/releases/tag/v0.5.0-beta.1)**.

This beta is ad-hoc signed on macOS and unsigned on Windows when paid signing credentials are not configured, so Gatekeeper or SmartScreen may warn about an unknown developer/publisher. Use only the files attached to the official `ArrowSK/crashvector` release.

**GitHub Packages is not used for the desktop installers.** CrashVector's distributable DMG and Setup EXE are GitHub Release assets.

To uninstall on macOS, quit CrashVector and move it from Applications to Trash. On Windows, use **Settings → Apps → Installed apps → CrashVector → Uninstall**.

CrashVector includes **Updates → Check for updates**. It can optionally check once per day; an update is downloaded and SHA-256 verified first, and installation is explicitly handed to the normal operating-system installer.

See **[Desktop distribution and updates](docs/DISTRIBUTION.md)** for detailed installation, removal, update, checksum and signing information.

## The normal M13 workflow

For the ready-to-run default you do not need to understand the solver or enter every parameter.

```text
choose passenger-car class + supported target
                    ↓
                 set speed
              (defaults exist)
                    ↓
                 Simulate
                    ↓
              replay · analysis
                    ↓
         optional cinematic video
```

A typical scenario is simply:

1. choose a passenger-car class;
2. choose a supported target — rigid wall, barrier, pole, tree, passenger car or heavy articulated truck;
3. change the speed, colour or advanced values only if you want to;
4. press **Simulate**;
5. inspect the replay/analysis or export a video.

Mass is editable, but it is never mandatory setup work.

## What CrashVector can do in M13

| Area | What you get |
| --- | --- |
| Scenario editor | Responsive desktop setup for vehicle class, supported target, mass, speed, position, heading, contact parameters and presentation |
| Passenger cars | Generic A / B / C / D / J / M classes with representative default masses and a refined 44-node local structural model |
| Whole-vehicle dynamics | Godot `RigidBody3D`, real gravity, CCD and raycast suspension for the supported production path |
| Progressive structural failure | Front crush followed, when demand is sufficient, by firewall/cowl intrusion, floor/rocker and A-pillar/roof deformation, passenger-cell shortening and rear-body buckling |
| Heavy articulated truck | Rigid-body world motion, six suspension contacts and physical rear underride face |
| Static targets | Rigid wall, concrete barrier, pole and tree with actual `StaticBody3D` collision geometry |
| Car vs car | Rear-end and near head-on layouts using rigid-body world motion for the passenger cars |
| Replay & analysis | 120 Hz recorded replay, timeline scrubbing, rigid-body velocity/momentum plus front and whole-body structural diagnostics |
| Comparison | Temporarily unavailable; the old batch runner is not used for production results |
| Other dynamic targets | Rigid lorry, motorcycle, bicycle and pedestrian remain editable/library models but production simulation is temporarily blocked pending rigid-body port |
| Presentation | Generic vehicle/target silhouettes, car colours, structure/X-ray view, technical road/lighting environment, overlays and cinematic cameras |
| Video export | 1080p / 1440p / 4K offline replay rendering at 30/60 fps with external FFmpeg H.264 encoding |
| Calibration | Historical M8 evidence labels/reference check retained separately from current production-world validation |
| Desktop distribution | macOS Universal 2 DMG and Windows x64 Setup installer with checksums and update support |

## Passenger-car classes

CrashVector uses **generic classes rather than production models**. There are no manufacturer badges, proprietary CAD files or claims that a class reproduces a particular real car.

| Class | Representative type | Default mass |
| --- | --- | ---: |
| A | City car | 950 kg |
| B | Small hatchback | 1,150 kg |
| C | Compact car | 1,375 kg |
| D | Midsize car | 1,575 kg |
| J | SUV / crossover | 1,850 kg |
| M | MPV / minivan | 2,050 kg |

The default mass is only a starting point. You can override it directly in the scenario.

## M12 rigid-body correction

The pre-M12 production model let the deformable structural node graph control both permanent crush and the entire car's world motion. That was the source of visibly wrong rebound/jump behaviour that scalar regression checks did not catch.

M12 changed the supported path to:

```text
Godot rigid-body world motion
        +
real gravity / CCD / road suspension
        +
real rigid target contact
        ↓
measured available structural-crush distance
        ↓
progressive resistance on the rigid chassis
        +
local structural deformation
```

The dedicated M12 regression uses actual Godot physics frames and directly rejects the human-visible failures that triggered that milestone. Its 50 km/h wall and 90 km/h car-versus-truck cases remain active regression gates in M13.

## M13 progressive whole-body failure

M12 still had one severe-impact discontinuity: once the engineered nose had used roughly its available travel, the protected cell behind it was effectively an indestructible rigid boundary. At extreme impact energy that meant the front could disappear while the firewall, roof and cabin remained implausibly unchanged.

M13 keeps the stable M12 rigid-body motion but lets structural failure propagate rearward when both collision demand and front-zone exhaustion justify it. Stage selection uses normal collision energy, relative closing speed/reduced mass for dynamic targets, and actual measured front-crush travel. It is not a simple `speed > X` animation.

The protected-cell collision face also retreats as catastrophic local collapse develops. This gives severe firewall/cabin shortening real additional travel against the obstacle instead of deforming only the visible mesh inside an unchanged invisible box.

The generic B-class release regression deliberately compares two very different wall impacts:

- **50 km/h:** about 105.0 kJ demand, 0.536 m front crush and effectively zero firewall/cabin/rear collapse.
- **200 km/h:** about 1,739.2 kJ demand, 0.945 m front-zone crush, 0.300 m firewall intrusion, 0.820 m passenger-cell collapse, 0.231 m rear-body buckle and 1.948 m combined longitudinal collapse. The same run records only about 0.015 m/s maximum reverse speed, 0.005 m chassis vertical rise and 0.89° pitch.

Those values are **generic project regression measurements**, not predictions for any production car. The acceptance goal is the progression itself: moderate crashes preserve the protected cell, while extreme residual demand no longer vanishes at the end of the nose.

See [M13 progressive whole-body failure](docs/M13_PROGRESSIVE_FAILURE.md) and [M12 hybrid physics](docs/M12_HYBRID_PHYSICS.md).

## Temporarily unported models and comparison

CrashVector still contains the historical rigid-lorry, motorcycle, bicycle and pedestrian structural/library models because old scenarios and deterministic regression data remain useful. They are **not run as current production physics** until their world-motion/contact path is ported to rigid bodies.

The same rule applies to Visual Compare and Comparison Lab. Their historical synchronous runner is retained for old regression coverage, but the desktop beta explicitly refuses to execute it as if it were the current production solver.

This is intentional: an unavailable result is preferable to a visually polished result produced by a physics path already known to be unsuitable for whole-vehicle motion.

## Replay, analysis and visual presentation

CrashVector records the completed supported simulation at **120 Hz**, so replay and presentation do not need to re-run the collision.

You can:

- scrub backward and forward through the crash;
- replay at 0.05× / 0.10× / 0.25× / 0.50× / 1×;
- inspect rigid-body speed/momentum and front/firewall/cabin/rear structural diagnostics;
- expand the Analysis drawer without covering the 3D viewport;
- toggle velocity / momentum / structure overlays;
- choose different passenger-car paint colours.

The visible passenger-car shell follows the local structural stations while global movement follows the rigid chassis.

## Cinematic video export

**Cinematic Video** renders from the recorded replay rather than recalculating physics during export.

Available presentation features include:

- 1080p, 1440p and 4K;
- 30 or 60 fps;
- Auto Cinematic, Wide, Tracking, Impact Close-up and Aftermath Orbit cameras;
- impact-centred slow motion;
- title card, live overlays, watermark and result card;
- independent passenger-car colours where applicable;
- optional retained source frames;
- machine-readable `.crashvector-video.json` metadata.

CrashVector calls an **external FFmpeg installation** for H.264 MP4 encoding. FFmpeg is not bundled with the repository. See [Video export](docs/VIDEO_EXPORT.md).

## Calibration and evidence labels

CrashVector deliberately separates **a convincing visual** from **a validated engineering claim**.

The historical M8 reduced-order reference uses the NHTSA NCAP full-frontal rigid-wall condition documented in **DOT HS 812 237 / laboratory test 7078**, with the documented **1,661 kg** test mass and **56.5 km/h** impact condition.

The application retains the labels:

- **Reference-correlated**
- **Near reference**
- **Class-scaled**
- **Extrapolated**

The M8 calibration runner remains a historical regression/correlation path. It does **not** validate the M12/M13 rigid-body and staged-collapse coupling, and current regression numbers are not manufacturer or regulatory corridors.

See [Calibration and validation scope](docs/CALIBRATION.md), [M12 hybrid physics](docs/M12_HYBRID_PHYSICS.md) and [M13 progressive failure](docs/M13_PROGRESSIVE_FAILURE.md).

## Known modelling boundaries

CrashVector intentionally rejects or blocks scenarios instead of making a visually plausible but unsupported claim.

- Current production rigid-body coverage includes wall, barrier, pole, tree, passenger-car and heavy-articulated-truck targets.
- Rigid lorry, motorcycle, bicycle and pedestrian production simulation is temporarily blocked pending rigid-body port.
- Visual Compare and Comparison Lab are temporarily blocked pending a scene-based rigid-body recorder.
- Generic vehicle classes are not production-car crash models.
- M13 staged collapse is a phenomenological reduced-order model, not finite-element structural analysis or manufacturer body-in-white data.
- Static target geometry is simplified.
- CI validates deterministic logic, editor runtime and engine-physics regression paths, but does not perform a real 4K GPU render or invoke the machine's FFmpeg binary.

For deeper assumptions, see [M13 progressive failure](docs/M13_PROGRESSIVE_FAILURE.md), [M12 hybrid physics](docs/M12_HYBRID_PHYSICS.md) and [Physics notes](docs/PHYSICS.md).

## Run from source

Requirements:

- **Godot 4.4.1 or newer**
- Git

```bash
git clone https://github.com/ArrowSK/crashvector.git
cd crashvector
godot --editor --path .
```

Or open `project.godot` directly in Godot and run the project.

## Documentation

| Guide | What it is for |
| --- | --- |
| [Roadmap](docs/ROADMAP.md) | Implementation history and next physics ports |
| [Architecture](docs/ARCHITECTURE.md) | Structural, simulation, replay, export, calibration, distribution and presentation layers |
| [M13 progressive failure](docs/M13_PROGRESSIVE_FAILURE.md) | Whole-body staged failure, collision-demand model, severe-impact coupling and limitations |
| [M12 hybrid physics](docs/M12_HYBRID_PHYSICS.md) | Rigid-body world-motion architecture, road/contact coupling and coverage boundaries |
| [M11 crush dynamics](docs/M11_CRUSH_DYNAMICS.md) | Refined 44-node structure and historical reduced-order M11 dynamics |
| [Physics notes](docs/PHYSICS.md) | Contact, energy accounting, structural assumptions and modelling boundaries |
| [Calibration](docs/CALIBRATION.md) | Reference source, evidence labels and historical regression corridors |
| [Scenario format](docs/SCENARIO_FORMAT.md) | Human-readable `.crashvector.json` save/load format |
| [Video export](docs/VIDEO_EXPORT.md) | Offline rendering, camera modes, FFmpeg boundary and metadata |
| [Desktop distribution and updates](docs/DISTRIBUTION.md) | Installation, updater, packaging, signing and release architecture |

## Development status

**M13 is the current progressive-failure release milestone.** Canonical Core CI retains the complete historical M0–M12 regression suite and its hybrid-physics script now also contains the M13 200 km/h whole-body-failure gate. A dedicated M13 workflow independently runs the 50 km/h preservation and 200 km/h severe-failure cases. Independent packaging gates build the macOS Universal 2 DMG and Windows x64 installer, including a real Windows Program Files install/uninstall lifecycle.

`v0.5.0-beta.1` is the M13 corrective packaged prerelease. Release automation verifies both package checksum sidecars, generates `update-manifest.json`, and refuses to replace an already-published release under the same version.

The next physics work is to port rigid lorry, motorcycle, bicycle/pedestrian contact and the comparison recorder to the rigid-body world architecture, then add additional independent public/licensed references before extending validation claims.

## Licence

CrashVector source code is licensed under the **Mozilla Public License 2.0 (MPL-2.0)**. See [LICENSE](LICENSE).

Third-party components and externally installed tools may carry their own licences; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
