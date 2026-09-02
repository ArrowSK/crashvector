# CrashVector

**Open-source vehicle collision simulation for education and visualisation.**

CrashVector bridges the gap between simple game collisions and specialist crash-engineering software. It combines physically informed structural deformation, a desktop scenario editor, recorded replay and analysis, synchronized visual comparison, cinematic video export, and an explicit calibration/evidence scope.

> CrashVector is an educational physics visualisation tool. It is not a certified accident-reconstruction, vehicle-homologation, structural-engineering, manufacturer crash-performance, rider/occupant-injury prediction, or safety-rating system.

## Current milestone: M8 — Calibration, validation scope, and expanded scenarios

M8 adds a machine-readable external structural reference and makes the evidence boundary visible in the application instead of allowing every simulated scenario to look equally validated.

The first direct correlation reference uses the NHTSA NCAP full-frontal rigid-barrier condition documented in **DOT HS 812 237**, laboratory test **7078**. CrashVector runs a generic D-segment midsize development vehicle at the documented **1,661 kg** test mass and **56.5 km/h** impact speed.

The published approximately **120 ms crash pulse** is kept separate from CrashVector-only numerical guardrails. Delta-v, safety-cell beam deformation and energy-balance thresholds are explicitly labelled project regressions rather than NHTSA measurements. This matters because the simplified model can rebound from the wall, increasing computed delta-v beyond impact speed.

The editor labels scenarios as **Reference-correlated**, **Near reference**, **Class-scaled**, or **Extrapolated**. High-speed runs, non-reference classes, vehicle-to-vehicle impacts, lorry/motorcycle scenarios, and non-reference targets therefore do not inherit a validation claim from the 56 km/h wall test.

## Scenario editor

The primary vehicle remains a generic passenger car with editable class, mass, speed, position and heading. Available passenger-car classes are:

- **A-Segment City Car** — 950 kg default mass
- **B-Segment Small Hatchback** — 1,150 kg
- **C-Segment Compact Car** — 1,375 kg
- **D-Segment Midsize Car** — 1,575 kg
- **J-Segment SUV / Crossover** — 1,850 kg
- **M-Segment MPV / Minivan** — 2,050 kg

All six use the common class-scaled CrashVector passenger-car architecture. They are representative development classes, not production vehicles or manufacturer crash-performance models.

Impact targets now include another passenger car, a heavy articulated truck, a **rigid lorry / box truck**, a **riderless motorcycle**, a **full-frontal rigid wall**, concrete barrier, pole and tree. The wall is a normal selectable target, so a car-vs-wall crash can be simulated, replayed, analysed, compared and exported like other supported scenarios.

The motorcycle model intentionally contains no rider. It can illustrate vehicle mass, speed, momentum and structural interaction, but does not model rider trajectory, helmet performance or injury.

Car-vs-car supports rear-end and near head-on layouts. Broadside and strongly oblique vehicle contact remains intentionally blocked until the geometric contact layer is suitable for side structures.

## Custom speed comparison

Speed comparison is not limited to presets. **Visual Compare** accepts any two or three distinct primary-car speeds from **0–300 km/h**. The initial values remain 50 / 90 / 140 km/h for convenience, but they are editable.

For example, set the first two fields to **130** and **140 km/h** and disable **Use third**. CrashVector runs both scenarios independently, aligns first impact, then shows the two recorded structural states side by side with delta-v, peak simulated deceleration, front crush, safety-cell proxy and initial kinetic energy.

This is especially useful for small speed differences because kinetic energy scales with the square of speed. At the same mass, 140 km/h carries about **16.0% more kinetic energy** than 130 km/h even though the speed is only about 7.7% higher.

Custom speed comparison works with the rigid-wall target as well as the supported dynamic and static targets. High-speed comparisons remain explicitly labelled **Extrapolated** unless a future reference dataset supports them.

## Replay, analysis, and video

Completed simulations are recorded at 120 Hz and can be scrubbed or replayed independently of live physics. Analysis includes primary/target delta-v, longitudinal crash pulse, peak simulated deceleration, front-crush history, safety-cell deformation proxy, kinetic energy, structural failures and event markers.

Visual comparison can be impact-synchronized or synchronized by scenario time. Each passenger-car lane can use a different presentation-only paint colour.

**Cinematic Video** renders from recorded replay state rather than re-running physics. It supports 1080p, 1440p and 4K at 30/60 fps, cinematic camera presets, impact slow motion, educational overlays/result cards, car colours and external FFmpeg H.264 MP4 encoding. FFmpeg is intentionally not bundled; see `docs/VIDEO_EXPORT.md`.

## Run locally

Install Godot 4.4.1 or newer, clone the repository, open `project.godot`, and run the project.

Typical workflow:

1. Choose a passenger-car class and set its mass/speed if desired.
2. Choose an impact target, including **Rigid Wall (full-frontal)** when you want a wall crash.
3. Press **Simulate** and review replay/analysis.
4. Open **Visual Compare**, enter two or three speeds such as 130 / 140, and run the synchronized comparison.
5. Use **Cinematic Video** to export a recorded result.
6. Open **Calibration** to inspect the evidence label or run the built-in reference check.
7. Use **Save** / **Open** for `.crashvector.json` scenarios.

## Development status

- **M0** — physics skeleton and telemetry — complete
- **M1** — deformable structural test sled — complete
- **M2** — generic compact hatchback architecture — complete
- **M3** — passenger-car classes and heavy articulated truck — complete
- **M4** — scenario editor, car-vs-car, static targets and save/load — complete
- **M5** — analysis, replay, crash pulse and overlays — complete
- **M6** — synchronized visual comparison — complete
- **M7** — cinematic offline video export — complete
- **M8** — documented reference correlation, explicit validation scope, A/J/M classes, lorry, riderless motorcycle, rigid-wall workflow and user-defined speed comparison — complete

## Verification

CI imports and parses the complete Godot project and runs every M0–M8 regression suite plus runtime editor smoke tests. M8 verifies the NHTSA reference metadata, source-vs-project calibration separation, expanded class/target construction, and a deterministic **130 vs 140 km/h rigid-wall comparison** including the expected kinetic-energy `v²` relationship.

CI intentionally does not perform a real 4K GPU render or invoke FFmpeg; those remain runtime integration paths separate from deterministic headless tests.

## Licence

CrashVector source code is licensed under the Mozilla Public License 2.0. Third-party assets and dependencies may have their own licences and must be documented before distribution.
