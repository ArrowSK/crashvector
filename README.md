# CrashVector

**Open-source vehicle collision simulation for education and visualisation.**

CrashVector bridges the gap between simple game collisions and specialist crash-engineering software. It combines physically informed structural deformation, an easy desktop scenario editor, recorded replay and analysis, synchronized visual comparison, cinematic video export, and an explicit calibration/evidence scope.

> CrashVector is an educational physics visualisation tool. It is not a certified accident-reconstruction, vehicle-homologation, structural-engineering, manufacturer crash-performance, biomechanical, or occupant-injury prediction system.

## Current milestone: M8 — Calibration, scenario library, and evidence scope

M8 keeps the validation claim deliberately narrow while making the simulator easier to explore. The editor now provides ready-to-run defaults for all supported vehicle and road-user types, so a user can select an object and press **Simulate** without entering a mass or other advanced values first. Mass, speed, position, heading, contact parameters, and selected presets remain editable when needed.

The first direct correlation reference uses the NHTSA NCAP full-frontal rigid-barrier condition documented in **DOT HS 812 237**, laboratory test **7078**. CrashVector runs a generic D-segment midsize development vehicle at the documented **1,661 kg** test mass and **56.5 km/h** impact speed and checks the published crash-pulse observation together with clearly separated CrashVector numerical/structural regression guardrails. See `docs/CALIBRATION.md`.

The editor labels scenarios as **Reference-correlated**, **Near reference**, **Class-scaled**, or **Extrapolated**. Road-user scenarios, dynamic vehicle-pair impacts, and high-speed demonstrations remain explicitly extrapolated; a successful lower-speed wall correlation does not silently validate them.

## Easy scenario setup

A typical first run is intentionally short:

1. Pick the primary passenger-car class.
2. Pick an impact target. CrashVector automatically supplies a useful default type and mass.
3. Optionally change speed, mass, position, heading, or presentation colour.
4. Press **Simulate**.
5. Scrub the recorded replay, inspect the crash analysis, or open a comparison/video workflow.

### Generic passenger-car classes

- **A-Segment City Car** — 950 kg default
- **B-Segment Small Hatchback** — 1,150 kg default
- **C-Segment Compact Car** — 1,375 kg default
- **D-Segment Midsize Car** — 1,575 kg default
- **J-Segment SUV / Crossover** — 1,850 kg default
- **M-Segment MPV / Minivan** — 2,050 kg default

These are representative development classes only. CrashVector does not use production model names, manufacturer badges, proprietary CAD, or OEM-specific crash-performance claims.

### Impact targets and defaults

The target palette includes another passenger car, an articulated heavy truck, a rigid lorry / box truck, a riderless motorcycle, a riderless bicycle, a pedestrian proxy, rigid wall, concrete barrier, pole, and tree.

Useful defaults include:

- **Rigid lorry / box truck** — 12,000 kg
- **Motorcycle** — 220 kg, riderless
- **City bicycle** — 16 kg; alternatives: 9 kg road bicycle and 24 kg e-bike
- **Adult pedestrian** — 75 kg and 1.75 m; alternatives: 32 kg child-sized and 90 kg tall-adult presets

The defaults are pre-filled, not mandatory data-entry fields. Changing a body/bicycle preset updates its default mass, but the mass can still be edited independently.

## Pedestrian and bicycle scope

The pedestrian is a lightweight articulated structural/contact proxy with feet supported before impact, stance release after vehicle contact, gravity, and simple ground contact. It is intended to make contact sequence and post-impact trajectory visible. It is **not** a dummy, bone/tissue model, injury model, or medical-outcome predictor.

The bicycle is a deformable riderless frame/fork proxy. A future cyclist model should couple a separately modelled rider to the bicycle rather than pretending that bicycle mass represents the person.

## Car vs car and other dynamic impacts

Car-vs-car remains a first-class scenario. Either passenger car can use any A/B/C/D/J/M class with independent mass, speed, position, and heading. Rear-end and near head-on layouts are supported. Broadside and strongly oblique car-vs-car contact remains intentionally blocked until a richer side-contact geometry model is implemented.

The same paired structural-contact architecture is used for the supported car-vs-truck, car-vs-lorry, car-vs-motorcycle, car-vs-bicycle, and car-vs-pedestrian proxy scenarios. The latter two remain trajectory/contact visualisations only.

## Visual comparison — including custom speeds

The original **Visual Compare** workflow remains available for quick synchronized comparisons. The **Comparison Lab** adds a more flexible batch workflow:

- choose up to **three vehicle classes, target types, or road-user presets**;
- choose up to **three arbitrary primary-car speeds** from 0–300 km/h;
- run the complete Cartesian combination in one batch — up to **nine independently simulated lanes**;
- synchronize playback to first impact or scenario time;
- compare Δv, peak simulated deceleration, front crush, energy, and the recorded 3D deformation/trajectory side by side.

The speed values are not restricted to presets. For example, set **130 km/h** and **140 km/h**, disable the third speed, and CrashVector will calculate and display exactly those two impacts. At equal mass the 140 km/h case begins with about 16% more translational kinetic energy than the 130 km/h case, which the regression suite checks using the expected velocity-squared relationship.

Comparison colours are presentation-only and never change the physics. Larger comparison matrices automatically cycle distinct car paints so the lanes remain visually distinguishable.

## Replay, analysis, and video

Completed simulations are recorded at 120 Hz and can be scrubbed or replayed independently of live physics. Analysis includes primary/target delta-v where meaningful, longitudinal crash pulse, peak simulated deceleration, front-crush history, safety-cell deformation proxy, kinetic energy, structural failures, and event markers.

**Cinematic Video** renders from recorded replay state rather than re-running physics. It supports 1080p, 1440p, and 4K at 30/60 fps, cinematic camera presets, impact slow motion, educational overlays/result cards, independent passenger-car colours, and external FFmpeg H.264 MP4 encoding. Pedestrian/bicycle exports retain the explicit contact/trajectory-only disclaimer. FFmpeg is intentionally not bundled; see `docs/VIDEO_EXPORT.md`.

## Run locally

Install Godot 4.4.1 or newer, clone the repository, open `project.godot`, and run the project.

## Development status

- **M0** — physics skeleton and telemetry — complete
- **M1** — deformable structural test sled — complete
- **M2** — generic compact hatchback architecture — complete
- **M3** — generic passenger-car classes and heavy-truck collision — complete
- **M4** — scenario editor, car-vs-car, static targets, and save/load — complete
- **M5** — analysis, replay, crash pulse, and overlays — complete
- **M6** — synchronized visual comparison — complete
- **M7** — cinematic offline video export — complete
- **M8** — documented reference correlation, broader generic scenario library, road-user proxies, arbitrary comparison matrix, and explicit validation scope — complete when the full M0–M8 + road-user CI gate passes

## Verification

CI imports and parses the complete Godot project and runs every M0–M8 regression suite plus runtime editor smoke tests. Additional road-user tests verify default presets, structural state, pedestrian stance release/contact trajectory, bicycle structure, scenario serialization, arbitrary type × speed matrices, and the 130/140 km/h kinetic-energy relationship.

CI intentionally does not perform a real 4K GPU render or invoke FFmpeg; those remain runtime integration paths and are kept separate from deterministic headless logic tests.

## Licence

CrashVector source code is licensed under the Mozilla Public License 2.0. Third-party assets and dependencies may have their own licences and must be documented before distribution.
