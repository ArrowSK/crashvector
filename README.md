# CrashVector

**Open-source vehicle collision simulation for education and visualisation.**

CrashVector is being built to bridge the gap between simple game collisions and specialist crash-engineering software. The application now combines physically informed structural deformation, a desktop scenario editor, recorded replay and analysis, synchronized visual comparison, and cinematic video export.

> CrashVector is an educational physics visualisation tool. It is not a certified accident-reconstruction, vehicle-homologation, structural-engineering, manufacturer crash-performance, or occupant-injury prediction system.

## Current milestone: M7 — Cinematic Video Export

CrashVector can now turn a completed simulated crash into a presentation-ready offline-rendered video. Export uses the recorded structural replay rather than re-running live physics, so frame rate and graphics performance do not change the collision result.

Video export includes:

- 1080p, 1440p, and 4K output;
- 30 or 60 fps fixed-frame rendering;
- Auto Cinematic, Wide Overview, Vehicle Tracking, Impact Close-up, and Aftermath Orbit cameras;
- impact-centred 0.25× slow motion as a presentation retime;
- opening title card, live speed/crush overlay, educational watermark, and closing result card;
- independent paint selection for primary and target passenger cars;
- high-quality offscreen JPEG rendering followed by H.264 MP4 encoding through an external FFmpeg installation;
- export progress and cancellation;
- optional retained source frames;
- a `.crashvector-video.json` metadata sidecar documenting the scenario, export profile, key metrics, timing, and disclaimer.

FFmpeg is intentionally not bundled in the repository. CrashVector invokes a locally installed FFmpeg executable for MP4 encoding; see `docs/VIDEO_EXPORT.md` and `THIRD_PARTY_NOTICES.md`.

## Scenario editor

The editor provides a primary passenger car and impact targets for another passenger car, heavy truck, rigid wall, concrete barrier, pole, or tree. Passenger cars use generic B-, C-, and D-segment classes with editable mass, speed, position, and heading. The editor also exposes contact friction, restitution, solver substeps, simulation duration, structural debug view, direct 3D placement/rotation, and human-readable `.crashvector.json` save/load.

### Car vs car

Car-vs-car is a first-class scenario. Either vehicle can use any generic passenger-car class with independent mass, speed, position, and heading. Rear-end and near head-on car-vs-car layouts are supported. Broadside and strongly oblique car-vs-car contact remains intentionally blocked until a proper side-contact geometry model is implemented.

### Generic passenger-car classes

- **B-Segment Small Hatchback** — 1,150 kg default mass
- **C-Segment Compact Car** — 1,375 kg default mass
- **D-Segment Midsize Car** — 1,575 kg default mass

These are representative size classes only. CrashVector does not use production model names, manufacturer badges, proprietary CAD, or OEM-specific crash-performance claims.

## Replay, analysis, and visual comparison

Completed simulations are recorded at 120 Hz and can be scrubbed or replayed independently of live physics. Analysis includes primary/target delta-v, longitudinal crash pulse, peak simulated deceleration, front-crush history, safety-cell deformation proxy, kinetic energy, structural failures, and event markers.

Visual Compare can run deterministic 50 / 90 / 140 km/h or B / C / D class sweeps and present three synchronized 3D lanes at once. First impact can be aligned across all variants so deformation differences are visible immediately. Each comparison lane can use a different presentation-only car paint.

## Run locally

Install Godot 4.4.1 or newer, clone the repository, open `project.godot`, and run the project.

Typical workflow:

1. Configure the primary vehicle and impact target.
2. Press **Simulate**.
3. Review replay and crash analysis after the run completes.
4. Use **Visual Compare** for synchronized speed/class comparisons.
5. Use **Cinematic Video** to configure and render an MP4 from the recorded replay.
6. Use **Save** / **Open** for `.crashvector.json` scenarios.

## Development status

- **M0** — physics skeleton and telemetry — complete
- **M1** — deformable structural test sled — complete
- **M2** — generic compact hatchback architecture — complete
- **M3** — generic passenger-car classes and heavy-truck collision — complete
- **M4** — scenario editor, car-vs-car, static targets, and save/load — complete
- **M5** — analysis, replay, crash pulse, and overlays — complete
- **M6** — synchronized visual comparison — complete
- **M7** — cinematic offline video export — complete
- **M8** — calibration against documented reference tests

## Verification

CI imports and parses the complete Godot project, runs every M0–M7 regression suite, and instantiates the editor in headless runtime smoke tests. M7 adds deterministic cinematic timeline/frame-count tests, camera-pose checks, export-profile validation, FFmpeg argument validation, render/export object construction, and full editor construction.

CI intentionally does not perform a real 4K GPU render or invoke FFmpeg; those are runtime integration paths and are kept separate from deterministic headless logic tests.

## Licence

CrashVector source code is licensed under the Mozilla Public License 2.0. Third-party assets and dependencies may have their own licences and must be documented before distribution.
