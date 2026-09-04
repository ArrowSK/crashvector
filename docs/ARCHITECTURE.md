# Architecture

## Layering

CrashVector separates structural mechanics, object construction, contact resolution, scenario data, editor UI, replay/analysis, comparison/export, calibration evidence, desktop distribution, and the M10 presentation shell. The physical state lives in structural graphs; presentation and distribution layers read or package those layers rather than maintaining a competing hidden trajectory or implementation.

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

### Editor layer

`src/demo/crash_demo.gd` remains the M4 scenario-editor base. Later milestone scripts extend it rather than replacing working layers:

- `crash_demo_m5.gd` adds replay and analysis;
- `crash_demo_m6.gd` adds visual comparison;
- `crash_demo_m7.gd` adds cinematic export;
- `crash_demo_m8.gd` adds expanded vehicle targets, custom-speed comparison, calibration-scope visibility, and the reference check;
- `crash_demo_extended.gd` adds bicycle/pedestrian target handling and Comparison Lab while preserving the M8 lorry/motorcycle members;
- `crash_demo_m9.gd` adds only the desktop Updates UI and delegates discovery/download/verification to a dedicated update service;
- `crash_demo_m10.gd` adds the responsive Scenario/Compare shell, inspector, replay drawer, technical environment and presentation controls while continuing to call the inherited M0–M9 services;
- `crash_demo_m10_release.gd` is the final compatibility shell that keeps the M7–M9 modal CanvasLayers in their original ownership hierarchy and suppresses only their obsolete fixed-position launch controls.

`app/main.tscn` runs the M10 release shell. M10 does not replace an already-attached script at runtime and does not reparent the proven updater/export/calibration/Comparison Lab service trees. The editor still rebuilds a clean physical preview before every run, avoiding continuation from partially deformed state after parameter edits.

### M10 presentation layer

M10 deliberately changes what the user sees without introducing a second simulation representation.

- The Scenario workspace owns the compact scenario selector, camera shortcuts and tabbed inspector.
- The Compare workspace gives synchronized comparison output the available desktop width rather than stacking it under scenario controls.
- Replay and analysis occupy a collapsible bottom drawer whose expanded geometry reduces the viewport instead of covering it.
- Vehicle and target visuals remain children of the existing structural runtime wrappers. Passenger-car paint, glazing, lamps and trim, plus rebuilt heavy-vehicle/motorcycle/bicycle/static-target meshes, are presentation-only surfaces driven by the same model transforms and deformation anchors used before M10.
- The technical road, markings, sky and lighting are visual context only. They do not define collision planes or modify contact parameters.
- The first-run B-class versus rigid-wall 50 km/h scenario is a UI default, not a new calibration claim.

Responsive-layout regression covers 1280×720, 1440×900, 1920×1080 and 2560×1440 and explicitly rejects sidebar, toolbar, viewport and replay-drawer overlap. A separate editor smoke gate checks the new workspace hierarchy and preservation of the existing M8/M9 service nodes.

### Update service layer

`src/update/` is independent of simulation state.

- `SemanticVersion` parses and compares the canonical application version, including prerelease identifiers.
- `CrashVectorUpdateService` discovers official GitHub Releases, validates `update-manifest.json`, selects the package for the current OS, downloads it, verifies SHA-256, and hands only a verified installer to the operating system.
- Update preferences are stored under `user://`; no update state is embedded into scenario or physics data.
- The service never mutates or overwrites the executable that is currently running. macOS opens the verified DMG; Windows starts the verified Setup executable; CrashVector exits only after a successful handoff.

Network or verification failure therefore cannot modify the installed application. Stable users are not silently moved to prereleases; a prerelease install may move to a later prerelease or the eventual stable release.

### Desktop distribution layer

M9 packaging is generated from repository sources rather than manually maintained native projects, and M10 reuses the same distribution architecture with the canonical version advanced to `0.2.0-beta.1`.

- `project.godot` contains the one canonical CrashVector Semantic Version.
- `tools/prepare_packaging.py` derives Godot export presets and native numeric version resources from that version.
- `tools/render_icon.gd` and `tools/generate_icon_containers.py` derive platform-native multi-resolution icon containers from the existing SVG branding master without changing the artwork.
- macOS CI produces and verifies a Universal 2 `CrashVector.app`, signs it, builds a DMG containing the application plus an Applications shortcut, and supports Developer ID/notarization when credentials exist.
- Windows CI produces the x64 application, applies/validates product metadata and icon resources, builds an Inno Setup installer, and performs a real install/uninstall validation; Authenticode hooks are present for later certificate use.
- `tools/build_update_manifest.py` creates the release manifest from the two already-validated packages.

Core CI, M10 visual/UX validation, macOS packaging and Windows packaging are independent acceptance checks. Release automation verifies the package checksum sidecars again and will not replace assets for an already-published version. `docs/DISTRIBUTION.md` describes the operational flow.

### Architecture hardening

Production code must use normal inheritance, composition, services and signals. Runtime implementation replacement through `set_script(...)`, `take_over_path(...)`, direct script-property reassignment or equivalent mechanisms is prohibited. Core CI and the M10 validation workflow scan `src/` and `app/` for those patterns so a future change cannot quietly reintroduce them.

## Determinism

Identical scenario inputs, engine version, and solver configuration are expected to produce identical state within regression tolerance. CI covers structural determinism, paired-contact momentum conservation, static contact, scenario serialisation invariants, replay independence, comparison timing, export planning, M8 reference correlation, road-user construction/trajectory behaviour, type × speed comparison matrices, M9 version/update logic, complete-editor startup, and M10 responsive presentation invariants.

## Units

Internal calculations use SI units: metres, seconds, kilograms, newtons, joules, and radians. The editor displays km/h where useful but converts at the UI/physics boundary.

## Scope boundary

CrashVector is an educational scenario-building and visualisation application. Most scenarios are not experimentally validated. A/B/C/D/J/M cars are generic representative classes; heavy vehicles and motorcycles are simplified structural graphs; bicycle and pedestrian modes are contact/trajectory proxies; broadside/complex oblique contact awaits a richer geometry system; and occupant/rider biomechanics and injury prediction remain outside the model.

M8 makes that modelling boundary explicit in the UI and exported metadata. M9 changes distribution and update mechanics only. M10 changes layout, interaction and visible scene presentation only; it does not broaden the validation claim or alter the physical model.
