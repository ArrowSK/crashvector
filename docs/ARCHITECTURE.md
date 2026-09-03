# Architecture

## Layering

CrashVector separates structural mechanics, object construction, contact resolution, scenario data, editor UI, replay/analysis, comparison/export, calibration evidence, and desktop lifecycle/distribution. The physical state lives in structural graphs; presentation layers read those graphs rather than maintaining a competing hidden trajectory.

### Structural layer

- `StructuralNode` — lumped mass, position, velocity, accumulated force, and pin state.
- `StructuralBeam` — axial spring/damper response, plastic flow, permanent deformation, and fracture.
- `StructuralModel` — fixed-substep graph integration plus energy/contact diagnostics. Whole-model translation and yaw rotation helpers apply editor transforms directly to physical state rather than only to visuals.
- `StructuralSnapshot` — captures and restores complete node/beam state for replay and offline rendering.

### Passenger-car layer

- `PassengerCarCatalog` defines generic A-, B-, C-, D-, J-, and M-segment development presets without production-model branding.
- `PassengerCarBuilder` scales the shared 28-node architecture by dimensions, mass distribution, and stiffness assumptions.
- `CompactHatchback` is the common visual/runtime wrapper for any passenger-car preset, heading, and presentation paint.
- `DeformableBodyShell`, `SimpleWheelRig`, and `StructuralDebugRenderer` map structural state into the visible car.

A second `CompactHatchback` instance is used for car-vs-car scenarios. There is no hidden rigid proxy or truck substitution.

### Heavy-vehicle and motorcycle layer

- `HeavyTruckBuilder` / `HeavyTruck` create the generic 32-node tractor/trailer structural approximation.
- `RigidLorryBuilder` / `RigidLorry` create the generic 24-node rigid-lorry / box-truck approximation.
- `MotorcycleBuilder` / `Motorcycle` create a generic riderless 16-node road-motorcycle approximation.

These are generic development models. Truck/lorry guard geometry and motorcycle structure are not manufacturer-specific or standards-certification models.

### Road-user layer

`src/road_users/` contains deliberately limited non-car objects:

- `RoadUserCatalog` owns the easy-to-use pedestrian and bicycle presets and their default mass/height values.
- `BicycleBuilder` / `Bicycle` create a deformable riderless bicycle frame/fork proxy.
- `PedestrianBuilder` / `Pedestrian` create a lightweight articulated structural/contact proxy. The pedestrian starts in a supported stance, releases after impact, then uses gravity and simple ground contact for post-impact trajectory.

The pedestrian is not a validated dummy, tissue/bone model, or injury predictor. The bicycle is riderless; a future cyclist should couple a separately modelled human body to a bicycle rather than combine their masses into one object.

### Dynamic-pair collision layer

- `VehiclePairContact` resolves paired node contacts using equal-and-opposite normal and Coulomb-limited tangent impulses.
- `VehiclePairSimulation` advances two structural models on one substep clock.
- The pair normal is scenario-defined, so heading-aware rear-end and near head-on layouts can share deterministic contact logic.

The same pair infrastructure is used for supported car-vs-car, car-vs-truck, car-vs-lorry, car-vs-motorcycle, car-vs-bicycle, and car-vs-pedestrian-proxy scenarios. Contact-node sets differ by object type.

Passenger-car, motorcycle, and bicycle contact is deliberately limited to rear-end or near head-on layouts. Broadside and strongly oblique contact needs richer body-surface geometry and is rejected rather than approximated with unsuitable front/rear node pairs.

### Static-target collision layer

- `VehicleStaticContact` resolves structural-node contact with a fixed wall, barrier, pole, or tree.
- `VehicleStaticSimulation` advances the deformable primary car and applies static contact after each substep.
- `StaticObstacle3D` renders the same target transform used by the contact layer.

Static targets are externally fixed. They do not exchange momentum with a second dynamic body.

### Scenario layer

- `ScenarioConfig` is the in-memory source of truth for target type, vehicle/body/bicycle preset, masses, speeds, positions, headings, contact parameters, duration, and solver settings.
- `ScenarioConfig.apply_target_defaults()` gives every target a sensible ready-to-run default so users are not forced to enter mass values before their first simulation.
- `ScenarioStore` serialises/deserialises human-readable `.crashvector.json` files.
- Preflight validation belongs in `ScenarioConfig`, not scattered across UI callbacks, so editor runs, saved scenarios, replay, comparison, and batch workflows share the same constraints.

### Replay and analysis layer

- `ReplayRecorder` captures structural state at 120 Hz.
- `ReplayRecording` stores frames and event markers independently of subsequent live simulation.
- `StructuralSnapshot` restores complete structural state for deterministic scrubbing and offline presentation.
- `CrashAnalysis` derives delta-v, crash pulse, deformation histories, peak simulated deceleration, structural failures, and event markers where those quantities are meaningful for the selected object type.

### Comparison layer

- `ComparisonRunner` performs deterministic offline variants from cloned `ScenarioConfig` instances.
- `ComparisonLane3D` presents independently recorded variants on synchronized 3D lanes.
- Quick Visual Compare retains two/three arbitrary speed comparison and the B/C/D convenience class sweep.
- Comparison Lab can vary up to three classes/target types/road-user presets across up to three arbitrary primary-car speeds, producing up to nine independently simulated lanes in one batch.

A comparison never changes the underlying physics merely to line up the visuals. First-impact synchronization changes replay timing only; each lane was simulated independently before playback.

### Cinematic export layer

M7 cinematic export maps recorded replay time into fixed output frames, camera plans, overlays, title/result cards, and optional external FFmpeg MP4 encoding. The exporter does not re-run the collision.

Export metadata records the scenario, analysis summary, presentation profile, timing, disclaimer, and M8 calibration-scope label. Road-user exports retain explicit contact/trajectory-only scope wording.

### Calibration layer

M8 deliberately keeps evidence data outside the vehicle builder so a reference test cannot silently become a production-model preset.

- `CalibrationReference` loads machine-readable external reference metadata from `calibration/references/`.
- `CalibrationMetrics` maps a recorded CrashVector run into the limited structural metrics used by the current reference.
- `CalibrationRunner` executes the deterministic stored reference scenario and compares it with explicitly separated source-correlation and project-regression corridors.
- `CalibrationScope` classifies arbitrary editor scenarios as `reference_correlated`, `near_reference`, `class_scaled`, or `extrapolated`.
- `docs/CALIBRATION.md` explains which numbers are published observations and which are CrashVector engineering thresholds.

The first directly correlated envelope is intentionally narrow: generic D-segment midsize passenger car, full-frontal rigid wall, approximately 56 km/h, and a limited mass range around the NHTSA reference condition. Passing that reference does not propagate a validation claim to high-speed demonstrations, vehicle-pair collisions, road users, or other target types.

### Desktop lifecycle and update layer

M9 keeps application lifecycle concerns out of the physics/editor layers.

- `AppMetadata` owns the packaged application version, GitHub release endpoint and platform package naming contract.
- `VersionUtil` performs semantic-version ordering including prerelease identifiers.
- `UpdateAssetSelector` selects a compatible release asset and matching SHA-256 sidecar without performing network I/O.
- `UpdateSettings` stores the automatic-check preference and last-check timestamp in `user://settings.cfg`.
- `UpdateService` owns HTTP requests, package download, SHA-256 verification and system-installer handoff.
- `crash_demo_m9.gd` adds the Updates panel and connects it to `UpdateService`.

An update is not a live code patch. CrashVector downloads a complete platform installer, verifies it, opens the normal system installer, and exits. The installed application is never rewritten while it is running.

Prerelease builds may follow later prerelease/stable releases. Stable builds do not silently opt into prereleases.

### Distribution layer

`export_presets.cfg` defines reproducible Godot 4.4.1 macOS Universal and Windows x64 exports.

- `.github/workflows/desktop-packages.yml` builds both package families on pull requests.
- macOS is exported on a native macOS runner, ad-hoc signed, verified, and packed into a DMG with an Applications shortcut.
- Windows is exported on a Windows runner, executable resources are branded with the native icon/metadata, and Inno Setup creates a standard installer/uninstaller.
- Both packages get SHA-256 sidecars.
- A `main` publication job verifies sidecars before creating the immutable versioned GitHub prerelease.

Platform code signing/notarization is an identity layer that can be strengthened later without changing the package/update contract.

### Editor layer

`src/demo/crash_demo.gd` remains the M4 scenario-editor base. Later milestone scripts extend it rather than replacing working layers:

- `crash_demo_m5.gd` adds replay and analysis;
- `crash_demo_m6.gd` adds visual comparison;
- `crash_demo_m7.gd` adds cinematic export;
- `crash_demo_m8.gd` adds expanded vehicle targets, custom-speed comparison, calibration-scope visibility, and the reference check;
- `crash_demo_extended.gd` adds bicycle/pedestrian target handling and Comparison Lab while preserving the M8 lorry/motorcycle members;
- `crash_demo_m9.gd` adds desktop lifecycle/update UI without changing collision physics.

`app/main.tscn` runs the M9 editor layer. The editor rebuilds a clean physical preview before every run, avoiding continuation from partially deformed state after parameter edits.

## No runtime monkey patching

CrashVector uses normal GDScript inheritance, composition, explicit services and signals. Production code must not replace the script attached to a live object or take over a Resource path to alter behavior after load.

CI scans `src/` and fails on runtime `set_script(...)` or `take_over_path(...)` patterns. This protects the packaged application from hidden mutation paths and keeps the updater completely separate from application code loading.

## Determinism

Identical scenario inputs, engine version, and solver configuration are expected to produce identical state within regression tolerance. CI covers structural determinism, paired-contact momentum conservation, static contact, scenario serialisation invariants, replay independence, comparison timing, export planning, M8 reference correlation, road-user construction/trajectory behaviour, type × speed comparison matrices, M9 version/update selection, and main-scene runtime construction.

## Units

Internal calculations use SI units: metres, seconds, kilograms, newtons, joules, and radians. The editor displays km/h where useful but converts at the UI/physics boundary.

## Scope boundary

CrashVector is an educational scenario-building and visualisation application. Most scenarios are not experimentally validated. A/B/C/D/J/M cars are generic representative classes; heavy vehicles and motorcycles are simplified structural graphs; bicycle and pedestrian modes are contact/trajectory proxies; broadside/complex oblique contact awaits a richer geometry system; and occupant/rider biomechanics and injury prediction remain outside the model.

M8 makes the evidence boundary explicit. M9 changes distribution and lifecycle only; it does not broaden the simulation validation claim.
