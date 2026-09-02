<p align="center">
  <img src="assets/branding/crashvector-icon.jpg" alt="CrashVector — educational 3D crash simulation" width="170">
</p>

<h1 align="center">CrashVector</h1>

<p align="center">
  <strong>Build a crash. Change the speed. Compare the outcome.</strong>
</p>

<p align="center">
  Educational 3D collision simulation with deformable generic vehicles, road users, replay, analysis and cinematic export.
</p>

<p align="center">
  <img alt="M8 complete" src="https://img.shields.io/badge/milestone-M8%20complete-ff4d1f?style=for-the-badge">
  <a href="https://github.com/ArrowSK/crashvector/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/ArrowSK/crashvector/actions/workflows/ci.yml/badge.svg?branch=main"></a>
</p>

<p align="center">
  <img alt="Godot 4.4.1+" src="https://img.shields.io/badge/Godot-4.4.1%2B-478cbf">
  <img alt="MPL 2.0" src="https://img.shields.io/badge/license-MPL--2.0-6c7a89">
  <img alt="Generic models" src="https://img.shields.io/badge/models-generic%20classes-19b5a5">
  <img alt="Educational simulation" src="https://img.shields.io/badge/scope-educational-19b5a5">
</p>

CrashVector is an open-source desktop crash-simulation sandbox for people who want to **see what speed, mass and impact configuration change** without turning the exercise into specialist engineering software.

Set up a vehicle and target, press **Simulate**, scrub the recorded crash, compare alternatives side by side, and export a cinematic video. The physics is intentionally visible and measurable, but the claims stay conservative.

> **Current state:** **M8 is complete on `main`**, including the full vehicle/road-user library, arbitrary speed comparison, Comparison Lab and the first evidence-labelled calibration reference. CrashVector currently runs from source in **Godot 4.4.1+**; a packaged desktop release has not been published yet.

> **Scope:** CrashVector is an educational physics visualisation tool. It is **not** certified accident reconstruction, homologation, manufacturer crash-performance prediction, biomechanics, medical/injury prediction or a safety-rating system.

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
3. change the speed, colour or advanced values only if you want to;
4. press **Simulate**;
5. inspect the replay, open **Visual Compare / Comparison Lab**, or export a video.

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

## Vehicle and target library

### Passenger-car classes

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

### Other targets

The same editor can target:

- another passenger car;
- a heavy articulated truck;
- a rigid lorry / box truck;
- a riderless motorcycle;
- a riderless bicycle;
- a pedestrian proxy;
- a rigid wall;
- a concrete barrier;
- a pole;
- a tree.

Useful defaults include a **12,000 kg rigid lorry**, **220 kg riderless motorcycle**, and the road-user presets below.

## Speed comparison is a first-class feature

CrashVector does not force you into a few demonstration speeds.

**Visual Compare** accepts any two or three distinct primary-car speeds from **0–300 km/h**. The familiar 50 / 90 / 140 km/h values are just defaults.

So if the question is:

> What actually changes between **130 km/h** and **140 km/h**?

enter **130** and **140**, disable the third lane, and run exactly those two simulations. At equal mass, 140 km/h starts with about **16% more translational kinetic energy** than 130 km/h because kinetic energy scales with velocity squared.

### Comparison Lab

For broader comparisons, **Comparison Lab** crosses:

- up to **three classes, target types or road-user presets**;
- with up to **three arbitrary speeds**;
- for up to **nine independently simulated crashes in one batch**.

Playback can be synchronized to **first impact** so the visual difference is immediately obvious, or to normal scenario time when that is more useful.

Examples:

```text
A / C / J cars × 50 / 90 / 140 km/h
Rigid wall / lorry / passenger car × 100 / 130 / 140 km/h
Adult pedestrian / city bicycle / e-bike × 30 / 40 / 50 km/h
```

Presentation colours are deliberately separate from physics.

## Pedestrian and bicycle models

The road-user models are intentionally useful without pretending to be something they are not.

### Pedestrian

The pedestrian is a lightweight articulated contact/trajectory proxy. It can show the sequence of impact, stance release, body motion, gravity and simple ground contact.

Presets:

| Body preset | Default mass | Height |
| --- | ---: | ---: |
| Adult — default | 75 kg | 1.75 m |
| Child-sized | 32 kg | 1.35 m |
| Tall adult | 90 kg | 1.90 m |

You may change the mass independently.

It is **not** a crash-test dummy, bone/tissue model, AIS estimator, fatality predictor or medical model.

### Bicycle

The bicycle is a deformable **riderless** frame/fork proxy.

| Bicycle preset | Default mass |
| --- | ---: |
| City bicycle — default | 16 kg |
| Road bicycle | 9 kg |
| E-bike | 24 kg |

A future cyclist model should couple a separately modelled human to the bicycle rather than hiding rider mass inside the bicycle itself.

## Replay, analysis and visual presentation

CrashVector records the completed simulation at **120 Hz**, so replay and presentation do not need to re-run the collision.

You can:

- scrub backward and forward through the crash;
- replay at 0.05× / 0.10× / 0.25× / 0.50× / 1×;
- inspect Δv, crash pulse, simulated deceleration, crush and structural failure;
- toggle velocity / momentum / structure overlays;
- choose different passenger-car paint colours;
- compare several recorded crashes in synchronized 3D lanes.

The visual shell follows the deforming structural model. The X-ray/structure view is there when you want to see what the visible body is responding to.

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

The first direct structural-correlation reference is the NHTSA NCAP full-frontal rigid-wall condition documented in **DOT HS 812 237 / laboratory test 7078**, using the documented **1,661 kg** test mass and **56.5 km/h** impact condition.

The application labels scenarios as:

- **Reference-correlated**
- **Near reference**
- **Class-scaled**
- **Extrapolated**

High-speed demonstrations, most vehicle-pair scenarios, motorcycle/bicycle/pedestrian impacts and other non-reference conditions remain explicitly extrapolated.

See [Calibration and validation scope](docs/CALIBRATION.md) for what is source-derived and what is only a CrashVector numerical regression guardrail.

## Known modelling boundaries

CrashVector intentionally rejects some scenarios instead of making a visually plausible but unsupported claim.

- Broadside and strongly oblique car-vs-car contact are not yet supported by the current front/rear paired-contact geometry.
- Road-user output is trajectory/contact visualisation, not injury prediction.
- Generic vehicle classes are not production-car crash models.
- Static wall/barrier/pole/tree models are simplified fixed targets.
- CI validates deterministic logic and editor runtime paths, but does not perform a real 4K GPU render or invoke the machine's FFmpeg binary.

For deeper physics assumptions, see [Physics notes](docs/PHYSICS.md).

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
| [Roadmap](docs/ROADMAP.md) | M0–M8 implementation history and the next accuracy work |
| [Architecture](docs/ARCHITECTURE.md) | Structural, simulation, replay, comparison, export and calibration layers |
| [Physics notes](docs/PHYSICS.md) | Contact, energy accounting, structural assumptions and modelling boundaries |
| [Calibration](docs/CALIBRATION.md) | Reference source, evidence labels and regression corridors |
| [Scenario format](docs/SCENARIO_FORMAT.md) | Human-readable `.crashvector.json` save/load format |
| [Video export](docs/VIDEO_EXPORT.md) | Offline rendering, camera modes, FFmpeg boundary and metadata |

## Development status

**M0 through M8 are complete.** The full CI gate imports/parses the Godot project and runs the milestone regression suites, editor runtime smoke tests, calibration checks, road-user tests and comparison-matrix tests.

The next accuracy work should add additional independent public/licensed crash references, richer side-impact contact geometry, tyre/suspension behaviour and other explicit validation milestones rather than silently extending the M8 evidence claim.

## Licence

CrashVector source code is licensed under the **Mozilla Public License 2.0 (MPL-2.0)**. See [LICENSE](LICENSE).

Third-party components and externally installed tools may carry their own licences; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
