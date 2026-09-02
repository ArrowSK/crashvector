# CrashVector

**Open-source vehicle collision simulation for education and visualisation.**

CrashVector bridges the gap between simple game collisions and specialist crash-engineering software. The application combines physically informed structural deformation, a desktop scenario editor, recorded replay and analysis, synchronized visual comparison, cinematic video export, and an explicit calibration/evidence scope.

> CrashVector is an educational physics visualisation tool. It is not a certified accident-reconstruction, vehicle-homologation, structural-engineering, manufacturer crash-performance, or occupant-injury prediction system.

## Current milestone: M8 — Calibration and Validation Scope

M8 adds a machine-readable external structural reference and makes the evidence boundary visible in the application instead of allowing every simulated scenario to look equally validated.

The first direct correlation reference uses the NHTSA NCAP full-frontal rigid-barrier condition documented in **DOT HS 812 237**, laboratory test **7078**. CrashVector runs a generic D-segment midsize development vehicle at the documented **1,661 kg** test mass and **56.5 km/h** impact speed and checks crash-pulse duration, longitudinal delta-v, a clearly labelled safety-cell structural proxy, and numerical energy balance against stored project corridors.

The editor now labels each scenario as:

- **Reference-correlated** — inside the narrow current midsize rigid-wall envelope;
- **Near reference** — similar but outside the directly correlated mass/speed corridor;
- **Class-scaled** — B/C class scaling without a direct published correlation test;
- **Extrapolated** — outside the current evidence envelope.

That last category deliberately includes the 90 / 140 km/h demonstrations, car-vs-car, car-vs-truck, and other targets. A successful 56 km/h rigid-wall correlation does not silently validate those scenarios.

The **Calibration** panel can run the stored reference check in-app and shows the actual metric values and pass/fail corridors. Published brake-pedal and foot-rest intrusion measurements are retained as source observations, but CrashVector does not pretend its beam-deformation proxy is the same measurement. See `docs/CALIBRATION.md`.

## Scenario editor

The editor provides a primary passenger car and impact targets for another passenger car, heavy truck, rigid wall, concrete barrier, pole, or tree. Passenger cars use generic B-, C-, and D-segment classes with editable mass, speed, position, heading, and presentation color. The editor also exposes contact friction, restitution, solver substeps, simulation duration, structural debug view, direct 3D placement/rotation, and human-readable `.crashvector.json` save/load.

### Car vs car

Car-vs-car is a first-class scenario. Either vehicle can use any generic passenger-car class with independent mass, speed, position, and heading. Rear-end and near head-on car-vs-car layouts are supported. Broadside and strongly oblique car-vs-car contact remains intentionally blocked until a proper side-contact geometry model is implemented.

### Generic passenger-car classes

- **B-Segment Small Hatchback** — 1,150 kg default mass
- **C-Segment Compact Car** — 1,375 kg default mass
- **D-Segment Midsize Car** — 1,575 kg default mass

These are representative size classes only. CrashVector does not use production model names, manufacturer badges, proprietary CAD, or OEM-specific crash-performance claims.

## Replay, analysis, comparison, and video

Completed simulations are recorded at 120 Hz and can be scrubbed or replayed independently of live physics. Analysis includes primary/target delta-v, longitudinal crash pulse, peak simulated deceleration, front-crush history, safety-cell deformation proxy, kinetic energy, structural failures, and event markers.

**Visual Compare** can run deterministic 50 / 90 / 140 km/h or B / C / D class sweeps and present three synchronized 3D lanes at once. First impact can be aligned across all variants so deformation differences are immediately visible. Each comparison lane can use a different presentation-only car paint.

**Cinematic Video** renders from recorded replay state rather than re-running physics. It supports 1080p, 1440p, and 4K at 30/60 fps, cinematic camera presets, impact slow motion, educational overlays/result cards, independent car colors, and external FFmpeg H.264 MP4 encoding. FFmpeg is intentionally not bundled; see `docs/VIDEO_EXPORT.md`.

## Run locally

Install Godot 4.4.1 or newer, clone the repository, open `project.godot`, and run the project.

Typical workflow:

1. Configure the primary vehicle and impact target.
2. Check the visible calibration-scope label for the scenario.
3. Press **Simulate**.
4. Review replay and crash analysis after the run completes.
5. Use **Visual Compare** for synchronized speed/class comparisons.
6. Use **Cinematic Video** to configure and render an MP4 from the recorded replay.
7. Open **Calibration** to inspect the evidence boundary or run the built-in reference check.
8. Use **Save** / **Open** for `.crashvector.json` scenarios.

## Development status

- **M0** — physics skeleton and telemetry — complete
- **M1** — deformable structural test sled — complete
- **M2** — generic compact hatchback architecture — complete
- **M3** — generic passenger-car classes and heavy-truck collision — complete
- **M4** — scenario editor, car-vs-car, static targets, and save/load — complete
- **M5** — analysis, replay, crash pulse, and overlays — complete
- **M6** — synchronized visual comparison — complete
- **M7** — cinematic offline video export — complete
- **M8** — documented reference correlation and explicit validation scope — complete

## Verification

CI imports and parses the complete Godot project and runs every M0–M8 regression suite plus runtime editor smoke tests. M8 adds source-metadata checks, evidence-scope classification tests, and a deterministic NHTSA reference run that fails CI if the directly correlated result leaves its stored project corridors.

CI intentionally does not perform a real 4K GPU render or invoke FFmpeg; those remain runtime integration paths and are kept separate from deterministic headless logic tests.

## Licence

CrashVector source code is licensed under the Mozilla Public License 2.0. Third-party assets and dependencies may have their own licences and must be documented before distribution.
