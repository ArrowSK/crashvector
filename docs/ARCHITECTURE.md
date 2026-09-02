# Architecture

## Layering

CrashVector separates structural mechanics, vehicle construction, contact resolution, scenario data, editor UI, replay/analysis, comparison/export, and calibration evidence.

### Structural layer

- `StructuralNode` — lumped mass, position, velocity, and accumulated force.
- `StructuralBeam` — axial spring/damper response, plastic flow, and fracture.
- `StructuralModel` — fixed-substep graph integration plus energy/contact diagnostics. Whole-model translation and yaw rotation helpers apply editor transforms directly to physical state rather than only to visuals.

### Passenger-car layer

- `PassengerCarCatalog` defines generic B-, C-, and D-segment development presets without production-model branding.
- `PassengerCarBuilder` scales the shared 28-node architecture by dimensions, mass, and stiffness.
- `CompactHatchback` can instantiate any catalog preset, heading, and presentation paint.
- `DeformableBodyShell`, `SimpleWheelRig`, and `StructuralDebugRenderer` map structural state into the visible car.

A second `CompactHatchback` instance is used for car-vs-car scenarios. There is no hidden rigid proxy or truck substitution.

### Heavy-truck layer

- `HeavyTruckBuilder` creates the 32-node tractor/trailer structural approximation.
- `HeavyTruck` owns truck visuals and supports an initial world heading.

### Dynamic-pair collision layer

- `VehiclePairContact` resolves paired node contacts using equal-and-opposite normal and Coulomb-limited tangent impulses.
- `VehiclePairSimulation` advances any two structural models on one substep clock. It is used for both car-vs-truck and car-vs-car scenarios.
- The pair normal is scenario-defined, so heading-aware rear-end and near head-on car-vs-car layouts can share the same deterministic contact implementation.

Passenger-car pair contact is deliberately limited to rear-end or near head-on layouts. Side-impact contact needs richer body-surface geometry and is not approximated by pretending the existing front/rear node pairs are valid side structures.

### Static-target collision layer

- `VehicleStaticContact` resolves structural-node contact with a fixed wall, barrier, pole, or tree.
- `VehicleStaticSimulation` advances the deformable car and applies static contact after each substep.
- `StaticObstacle3D` renders the editor-visible target geometry from the same scenario transform used by the contact layer.

### Scenario layer

- `ScenarioConfig` is the in-memory source of truth for object types, generic vehicle classes, masses, speeds, world positions, headings, contact parameters, duration, and solver settings.
- `ScenarioStore` serialises/deserialises human-readable `.crashvector.json` files.
- Preflight validation belongs in `ScenarioConfig`, not scattered across UI callbacks, so saved scenarios and batch runs share the same constraints.

### Replay and analysis layer

- `ReplayRecorder` captures structural state at 120 Hz.
- `ReplayRecording` stores frames and event markers independently of subsequent live simulation.
- `StructuralSnapshot` restores complete structural state for deterministic scrubbing and offline presentation.
- `CrashAnalysis` derives delta-v, crash pulse, deformation histories, peak deceleration, structural failures, and event markers.

### Comparison and export layer

- `ComparisonRunner` performs deterministic offline parameter sweeps.
- `ComparisonLane3D` presents independently recorded variants in synchronized 3D lanes.
- M7 cinematic export maps recorded replay time into fixed output frames, camera plans, overlays, title/result cards, and optional external FFmpeg MP4 encoding.
- Export metadata records the scenario, analysis summary, presentation profile, timing, disclaimer, and M8 calibration-scope label.

### Calibration layer

M8 deliberately keeps evidence data outside the vehicle builder so a reference test cannot silently become a production-model preset.

- `CalibrationReference` loads machine-readable external reference metadata from `calibration/references/`.
- `CalibrationMetrics` maps a recorded CrashVector run into the limited structural metrics used by the current reference.
- `CalibrationRunner` executes the deterministic stored reference scenario and compares it with project-defined corridors.
- `CalibrationScope` classifies arbitrary editor scenarios as `reference_correlated`, `near_reference`, `class_scaled`, or `extrapolated`.
- `docs/CALIBRATION.md` explains which numbers are published observations and which are CrashVector engineering thresholds.

The first directly correlated envelope is intentionally narrow: generic D-segment midsize passenger car, full-frontal rigid wall, approximately 56 km/h, and a limited mass range around the NHTSA reference condition. Passing that reference does not propagate a validation claim to the 90/140 km/h demonstrations, vehicle-pair collisions, or other target types.

### Editor layer

`src/demo/crash_demo.gd` remains the M4 scenario-editor base. Later milestone scripts extend it rather than replacing working layers:

- `crash_demo_m5.gd` adds replay and analysis;
- `crash_demo_m6.gd` adds visual comparison;
- `crash_demo_m7.gd` adds cinematic export;
- `crash_demo_m8.gd` adds calibration-scope visibility and the reference check.

The editor rebuilds a clean physical preview before every run. This avoids continuing from partially deformed state after parameter edits.

## Determinism

Identical scenario inputs, engine version, and solver configuration are expected to produce identical state within regression tolerance. CI covers structural determinism, paired-contact momentum conservation, static contact, scenario serialisation invariants, replay independence, comparison timing, export planning, and the M8 reference-correlation gate.

## Units

Internal calculations use SI units: metres, seconds, kilograms, newtons, joules, and radians. The editor displays km/h where useful but converts at the UI/physics boundary.

## Scope boundary

CrashVector is usable as an educational scenario-building and visualisation application, but most scenarios are not experimentally validated. The B/C/D cars remain generic representative classes, the heavy truck remains a simplified tractor/trailer graph, broadside/complex oblique contact awaits a richer geometry system, and occupant/restraint biomechanics are outside the current model.

M8 makes that boundary explicit in the UI rather than weakening it.
