<p align="center">
  <img src="assets/branding/crashvector-icon.webp" alt="CrashVector — educational 3D crash simulation" width="180">
</p>

<h1 align="center">CrashVector</h1>

<p align="center">
  <strong>Build a crash. Change the speed. Compare the outcome.</strong>
</p>

<p align="center">
  Educational 3D collision simulation with deformable generic vehicles, road users, replay, analysis, comparison and cinematic export.
</p>

<p align="center">
  <a href="https://github.com/ArrowSK/crashvector/releases/download/v0.1.0-beta.1/CrashVector-0.1.0-beta.1-macOS-universal.dmg"><img alt="Download CrashVector for macOS" src="https://img.shields.io/badge/Download-macOS%20Beta-111827?style=for-the-badge&logo=apple&logoColor=white"></a>
  <a href="https://github.com/ArrowSK/crashvector/releases/download/v0.1.0-beta.1/CrashVector-0.1.0-beta.1-Windows-x64-Setup.exe"><img alt="Download CrashVector for Windows" src="https://img.shields.io/badge/Download-Windows%20Beta-2563eb?style=for-the-badge&logo=windows&logoColor=white"></a>
</p>

<p align="center">
  <sub><strong>v0.1.0-beta.1.</strong> macOS Universal 2 · Windows x64 · normal system install/uninstall · built-in update checker.</sub>
</p>

<p align="center">
  <img alt="M9 complete" src="https://img.shields.io/badge/milestone-M9%20complete-ff4d1f">
  <img alt="Version 0.1.0 beta 1" src="https://img.shields.io/badge/version-0.1.0--beta.1-6c7a89">
  <img alt="Godot 4.4.1" src="https://img.shields.io/badge/Godot-4.4.1-478cbf">
  <img alt="MPL 2.0" src="https://img.shields.io/badge/license-MPL--2.0-6c7a89">
  <a href="https://github.com/ArrowSK/crashvector/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/ArrowSK/crashvector/actions/workflows/ci.yml/badge.svg?branch=main"></a>
  <a href="https://github.com/ArrowSK/crashvector/actions/workflows/desktop-packages.yml"><img alt="Desktop packages" src="https://github.com/ArrowSK/crashvector/actions/workflows/desktop-packages.yml/badge.svg?branch=main"></a>
</p>

CrashVector is an open-source desktop crash-simulation sandbox for people who want to **see what speed, mass and impact configuration change** without turning the exercise into specialist engineering software.

Set up a vehicle and target, press **Simulate**, scrub the recorded crash, compare alternatives side by side, and optionally export a cinematic video. The physics is intentionally visible and measurable, while the claims remain conservative.

> **Scope:** CrashVector is an educational physics visualisation tool. It is **not** certified accident reconstruction, homologation, manufacturer crash-performance prediction, biomechanics, medical/injury prediction or a safety-rating system.

## Install

### macOS

Download the DMG, open it, and drag **CrashVector** to **Applications**. Uninstall by moving CrashVector from Applications to the Trash.

The first beta is ad-hoc signed rather than Apple Developer-ID signed/notarized. If macOS blocks the first launch, use **System Settings → Privacy & Security → Open Anyway**. Normal installation, updating and removal do **not** require Terminal.

### Windows

Download and run the Setup executable. CrashVector installs under Program Files, gets a Start-menu entry, and appears in **Settings → Apps → Installed apps**, where it can be uninstalled normally.

The first beta is not Authenticode-signed, so SmartScreen may show an unknown-publisher warning.

See **[Installation](docs/INSTALLATION.md)** for the short platform-specific guide.

## The normal workflow

For a first run, you should not need to understand the solver or enter every parameter.

```text
choose vehicle + target
          ↓
     set speed
   (defaults exist)
          ↓
       Simulate
          ↓
 replay · analysis · compare
          ↓
  optional cinematic video
```

A typical scenario is simply:

1. choose a passenger-car class;
2. choose the impact target — CrashVector fills in a sensible default preset and mass;
3. change speed, colour or advanced values only when you want to;
4. press **Simulate**;
5. inspect replay, open **Visual Compare / Comparison Lab**, or export a video.

Mass is editable, but it is never mandatory setup work.

## What CrashVector can do today

| Area | What you get |
| --- | --- |
| Scenario editor | Visual setup for vehicle class, target, mass, speed, position, heading, contact parameters and presentation |
| Passenger cars | Generic A / B / C / D / J / M classes with representative default masses |
| Heavy vehicles | Articulated heavy truck and rigid lorry / box-truck development models |
| Road users | Riderless motorcycle, riderless bicycle presets and an articulated pedestrian contact/trajectory proxy |
| Static targets | Full-frontal rigid wall, concrete barrier, pole and tree |
| Car vs car | Rear-end and near head-on layouts with independent class, mass and speed |
| Replay & analysis | 120 Hz recorded replay, timeline scrubbing, Δv, crash pulse, peak simulated deceleration, crush and structural diagnostics |
| Comparison | Exact user-entered speeds plus multi-type / multi-speed Comparison Lab |
| Presentation | Car colours, structure/X-ray view, visual lanes, analysis overlays and cinematic cameras |
| Video export | 1080p / 1440p / 4K offline replay rendering at 30/60 fps with external FFmpeg H.264 encoding |
| Calibration | Evidence labels plus a narrow NHTSA full-frontal rigid-wall structural-correlation reference |
| Desktop lifecycle | macOS DMG, Windows installer and verified in-app update download/handoff |

## Vehicle and target library

CrashVector uses **generic classes rather than production models**. There are no manufacturer badges, proprietary CAD files or claims that a class reproduces a particular real car.

| Class | Representative type | Default mass |
| --- | --- | ---: |
| A | City car | 950 kg |
| B | Small hatchback | 1,150 kg |
| C | Compact car | 1,375 kg |
| D | Midsize car | 1,575 kg |
| J | SUV / crossover | 1,850 kg |
| M | MPV / minivan | 2,050 kg |

The default mass is only a starting point. You can override it directly.

Targets include another passenger car, heavy articulated truck, rigid lorry / box truck, riderless motorcycle, riderless bicycle, pedestrian proxy, rigid wall, concrete barrier, pole and tree.

Useful defaults include a **12,000 kg rigid lorry** and **220 kg riderless motorcycle**.

### Pedestrian presets

| Body preset | Default mass | Height |
| --- | ---: | ---: |
| Adult — default | 75 kg | 1.75 m |
| Child-sized | 32 kg | 1.35 m |
| Tall adult | 90 kg | 1.90 m |

The pedestrian is an articulated **contact/trajectory proxy**, not a crash-test dummy, bone/tissue model, AIS estimator, fatality predictor or medical model.

### Bicycle presets

| Bicycle preset | Default mass |
| --- | ---: |
| City bicycle — default | 16 kg |
| Road bicycle | 9 kg |
| E-bike | 24 kg |

The bicycle is riderless. A future cyclist model should couple a separately modelled human to the bicycle rather than hiding rider mass inside the bicycle.

## Speed comparison is a first-class feature

**Visual Compare** accepts any two or three distinct primary-car speeds from **0–300 km/h**. The familiar 50 / 90 / 140 km/h values are only defaults.

If the question is:

> What actually changes between **130 km/h** and **140 km/h**?

enter **130** and **140**, disable the third lane, and run exactly those two simulations. At equal mass, 140 km/h starts with about **16% more translational kinetic energy** than 130 km/h because kinetic energy scales with velocity squared.

### Comparison Lab

Comparison Lab crosses:

- up to **three classes, target types or road-user presets**;
- with up to **three arbitrary speeds**;
- for up to **nine independently simulated crashes in one batch**.

Playback can be synchronized to **first impact** so visual differences are immediately apparent, or to normal scenario time.

```text
A / C / J cars × 50 / 90 / 140 km/h
Rigid wall / lorry / passenger car × 100 / 130 / 140 km/h
Adult pedestrian / city bicycle / e-bike × 30 / 40 / 50 km/h
```

Presentation colours are separate from physics.

## Replay, analysis and cinematic export

CrashVector records completed simulations at **120 Hz**, so replay and presentation do not need to re-run the collision.

You can scrub backward/forward, replay at 0.05× through 1×, inspect Δv/crash pulse/simulated deceleration/crush, toggle velocity/momentum/structure overlays, choose car colours, and compare several recorded crashes in synchronized 3D lanes.

**Cinematic Video** renders from recorded replay state rather than recalculating physics. It supports 1080p, 1440p and 4K; 30/60 fps; tracking/impact/aftermath cameras; impact slow motion; title/results overlays; and machine-readable metadata.

CrashVector calls an **external FFmpeg installation** for H.264 MP4 encoding. FFmpeg is not bundled. See [Video export](docs/VIDEO_EXPORT.md).

## Built-in updates

Open **Updates** inside CrashVector.

The updater:

1. checks official CrashVector GitHub Releases;
2. tells you when a newer compatible version exists;
3. downloads nothing until you choose **Download**;
4. downloads the platform installer and its SHA-256 sidecar;
5. verifies the package locally;
6. opens the normal DMG/Windows installer and quits CrashVector.

CrashVector does **not** rewrite its own installed executable and does not inject replacement scripts at runtime. See [Update architecture](docs/UPDATES.md).

Prerelease builds receive newer prereleases and stable versions. Stable builds do not silently opt into beta updates.

## Calibration and evidence labels

CrashVector deliberately separates **a convincing visual** from **a validated engineering claim**.

The first direct structural-correlation reference is the NHTSA NCAP full-frontal rigid-wall condition documented in **DOT HS 812 237 / laboratory test 7078**, using the documented **1,661 kg** test mass and **56.5 km/h** impact condition.

The application labels scenarios as **Reference-correlated**, **Near reference**, **Class-scaled**, or **Extrapolated**. High-speed demonstrations, most vehicle-pair scenarios and road-user impacts remain extrapolated.

See [Calibration and validation scope](docs/CALIBRATION.md).

## Known modelling boundaries

CrashVector intentionally rejects some scenarios instead of making a visually plausible but unsupported claim.

- Broadside and strongly oblique car-vs-car contact are not yet supported by the current front/rear paired-contact geometry.
- Road-user output is trajectory/contact visualisation, not injury prediction.
- Generic vehicle classes are not production-car crash models.
- Static wall/barrier/pole/tree models are simplified fixed targets.
- CI validates deterministic logic and editor runtime paths, but does not perform a real 4K GPU video encode.

For deeper assumptions, see [Physics notes](docs/PHYSICS.md).

## Run from source

Packaged users do not need Godot or Git.

For development:

```bash
git clone https://github.com/ArrowSK/crashvector.git
cd crashvector
godot --editor --path .
```

Use **Godot 4.4.1** for the reproducible development/export baseline.

## Documentation

| Guide | What it is for |
| --- | --- |
| [Installation](docs/INSTALLATION.md) | macOS/Windows installation and uninstall |
| [Updates](docs/UPDATES.md) | In-app update flow, channels and trust boundary |
| [Desktop packaging](docs/DESKTOP_PACKAGING.md) | DMG/Windows build and release architecture |
| [Roadmap](docs/ROADMAP.md) | M0–M9 implementation history and future accuracy work |
| [Architecture](docs/ARCHITECTURE.md) | Structural, simulation, UI, update and distribution layers |
| [Physics notes](docs/PHYSICS.md) | Contact, energy accounting and modelling boundaries |
| [Calibration](docs/CALIBRATION.md) | Reference source, evidence labels and regression corridors |
| [Scenario format](docs/SCENARIO_FORMAT.md) | Human-readable `.crashvector.json` save/load format |
| [Video export](docs/VIDEO_EXPORT.md) | Offline rendering, camera modes, FFmpeg boundary and metadata |

## Development status

**M0 through M9 are complete.** CI imports/parses the Godot project and runs every milestone regression/runtime suite, the road-user and comparison-matrix gates, update/version tests, the M9 editor smoke test, and a no-runtime-monkey-patching check.

A separate desktop-package workflow builds both installable platforms on pull requests. On `main`, a release is published only after both packages succeed and their checksums verify.

## Licence

CrashVector source code is licensed under the **Mozilla Public License 2.0 (MPL-2.0)**. See [LICENSE](LICENSE).

Third-party components and externally installed tools may carry their own licences; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
