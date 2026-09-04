# Architecture

## Layering

CrashVector separates structural mechanics, object construction, contact resolution, scenario data, editor UI, replay/analysis, comparison/export, calibration evidence, desktop distribution, and the M10 presentation shell. In the current M12–M14 production path, Godot rigid bodies own supported world motion while CrashVector structural graphs remain local deformation/presentation state. Historical reduced-order solvers are retained only where explicitly documented for regression or unavailable legacy workflows; presentation and distribution layers do not maintain a competing hidden production trajectory.

### Structural layer

- `StructuralNode` — lumped mass, position, velocity, accumulated force, and pin state.
- `StructuralBeam` — axial spring/damper response, plastic flow, permanent deformation, and fracture.
- `StructuralModel` — fixed-substep graph integration plus energy/contact diagnostics. Whole-model translation and yaw rotation helpers remain available for the historical reduced-order paths and editor transforms.
- `StructuralSnapshot` — captures and restores complete node/beam state for replay and offline rendering.

### Passenger-car layer

- `PassengerCarCatalog` defines generic A-, B-, C-, D-, J-, and M-segment development presets without production-model branding.
- The M11 production passenger-car structure uses the refined 44-node local structural graph, including the added engine-bay cross-sections, rather than the original 28-node whole-car production graph.
- `CompactHatchback` remains the common visual/runtime wrapper for passenger-car presets, local deformation and presentation paint.
- `VehicleRigidChassis` is authoritative for supported M12–M14 passenger-car mass, inertia, translation, rotation, gravity, CCD and road/world collision.
- `DeformableBodyShell`, wheel/presentation components and `StructuralDebugRenderer` map the local structural state into the visible car while global motion follows the rigid chassis.

A second passenger-car instance can be used for supported car-vs-car scenarios. The current production path does not substitute a hidden truck or reduced-order point-mass trajectory for passenger-car world motion.

### Heavy-vehicle and motorcycle layer

- `HeavyTruckBuilder` / `HeavyTruck` create the generic tractor/trailer structural approximation; the supported production heavy articulated truck uses rigid-body world motion, six suspension contacts and a physical rear underride contact face.
- `RigidLorryBuilder` / `RigidLorry` create the generic rigid-lorry / box-truck approximation.
- `MotorcycleBuilder` / `Motorcycle` create a generic riderless road-motorcycle approximation.

These are generic development models. Truck/lorry guard geometry and motorcycle structure are not manufacturer-specific or standards-certification models. Rigid lorry and motorcycle remain outside the current production rigid-body path and are not silently run through the historical solver.

### Road-user layer

`src/road_users/` contains deliberately limited non-car objects:

- `RoadUserCatalog` owns the easy-to-use pedestrian and bicycle presets and their default mass/height values.
- `BicycleBuilder` / `Bicycle` create the existing riderless bicycle structural/presentation proxy.
- `PedestrianBuilder` / `Pedestrian` create the existing articulated structural/presentation proxy.
- M14 adds `RoadUserRigidProxy3D`, a real Godot `RigidBody3D` wrapper with gravity, CCD, friction, collision geometry and post-impact translation/rotation. In production, the existing `Bicycle` or `Pedestrian` object is a presentation/contact child of this rigid body rather than the authoritative world-motion object.
- On meaningful passenger-car nose contact, the road-user proxy receives the reduced-mass contact impulse used for its trajectory/tumble response while the passenger car keeps its existing phenomenological nose-resistance path.

The pedestrian is not a validated dummy, tissue/bone model, or injury predictor. The bicycle is riderless; a future cyclist should couple a separately modelled human body to a bicycle rather than combine their masses into one object.

### Historical reduced-order pair layer

- `VehiclePairContact` resolves paired node contacts using equal-and-opposite normal and Coulomb-limited tangent impulses.
- `VehiclePairSimulation` advances two structural models on one substep clock.
- The pair normal is scenario-defined, so heading-aware rear-end and near head-on layouts share deterministic historical contact logic.

This infrastructure remains in the repository for legacy regressions and the historical comparison runner. It is not the authoritative M12–M14 whole-world production-motion path for pedestrian/bicycle targets, and it is not used to bypass the production block on rigid lorry or motorcycle. Supported current road-user production scenarios route through `RoadUserRigidProxy3D`.

Broadside and strongly oblique contact still needs richer body-surface geometry and is rejected where the current production contact representation is not meaningful.

### Static and yielding target layer

`StaticObstacle3D` owns the current wall/barrier/pole/tree target hierarchy used by the production scene.

- Wall and concrete barrier use real `StaticBody3D` collision geometry and remain non-yielding.
- Pole and tree use a `RigidBody3D` collision/visual hierarchy that begins frozen and effectively anchored.
- M14 `apply_collision_demand()` releases pole/tree targets into normal rigid-body motion when generic phenomenological yielding demand is exceeded, so visible and collision geometry move together after failure.
- Pole/tree yielding does not redefine wall/barrier behaviour or the M13 passenger-car staged-collapse model.

The generic pole/tree capacities are educational project parameters, not claims about a specific lamp post, utility pole, tree species, trunk diameter, soil or foundation.

### Scenario layer

- `ScenarioConfig` is the in-memory source of truth for target type, vehicle/body/bicycle preset, masses, speeds, positions, headings, contact parameters, duration, and solver settings.
- `ScenarioConfig.apply_target_defaults()` gives every target a sensible ready-to-run default so users are not forced to enter mass values before their first simulation.
- `ScenarioStore` serialises/deserialises human-readable `.crashvector.json` files.
- Preflight validation belongs in `ScenarioConfig`, not scattered across UI callbacks, so editor runs, saved scenarios, replay, comparison, and batch workflows share the same constraints.

### Replay and analysis layer

- `ReplayRecorder` captures simulation state at 120 Hz.
- `ReplayRecording` stores frames and event markers independently of subsequent live simulation.
- `StructuralSnapshot` restores complete local structural state for deterministic scrubbing and offline presentation.
- Current production replay also records rigid-body visual state for supported passenger-car and M14 road-user trajectories so replay does not fall back to historical world-motion reconstruction.
- `CrashAnalysis` derives delta-v, crash pulse, deformation histories, peak simulated deceleration, structural failures, and event markers where those quantities are meaningful for the selected object type.

### Comparison layer

- `ComparisonRunner` and `ComparisonLane3D` retain the historical deterministic batch-comparison implementation and its regression coverage.
- Quick Visual Compare and Comparison Lab remain unavailable in the current desktop production path because the historical synchronous runner has not yet been ported to the M12–M14 rigid-body world architecture.
- The application does not present a reduced-order comparison result as current production physics merely to keep the UI feature enabled.

When this layer is ported, first-impact synchronization must remain presentation-only; each lane should still be simulated independently before playback timing is aligned.

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

The M14 evidence-scope fix changes only presentation stacking: the existing calibration/evidence CanvasLayer is raised above the M10 desktop UI so the existing modal and **Close** callback remain usable. It does not broaden the calibration claim.

### Editor layer

`src/demo/crash_demo.gd` remains the M4 scenario-editor base. Later milestone scripts extend it rather than replacing working layers:

- `crash_demo_m5.gd` adds replay and analysis;
- `crash_demo_m6.gd` adds visual comparison;
- `crash_demo_m7.gd` adds cinematic export;
- `crash_demo_m8.gd` adds expanded vehicle targets, custom-speed comparison, calibration-scope visibility, and the reference check;
- `crash_demo_extended.gd` adds bicycle/pedestrian target handling and Comparison Lab while preserving the M8 lorry/motorcycle members;
- `crash_demo_m9.gd` adds only the desktop Updates UI and delegates discovery/download/verification to a dedicated update service;
- `crash_demo_m10.gd` adds the responsive Scenario/Compare shell, inspector, replay drawer, technical environment and presentation controls while continuing to call the inherited M0–M9 services;
- `crash_demo_m10_release.gd` is the M10 compatibility shell that keeps the M7–M9 service CanvasLayers in their inherited ownership hierarchy and suppresses only obsolete fixed-position launch controls;
- M11–M13 add the refined crush, rigid-chassis and progressive whole-body failure production layers;
- `crash_demo_m14.gd` extends M13, replaces the legacy road-user world-motion object with `RoadUserRigidProxy3D` for bicycle/pedestrian targets, forwards pole/tree collision demand to `StaticObstacle3D`, and records/restores the road-user rigid-body replay state.

`app/main.tscn` runs `crash_demo_m14.gd`. The M14 layer preserves the inherited M10 UI and M12/M13 passenger-car architecture rather than redesigning them.

### M10 presentation layer

M10 deliberately changes what the user sees without introducing a second simulation representation.

- The Scenario workspace owns the compact scenario selector, camera shortcuts and tabbed inspector.
- The Compare workspace remains part of the inherited shell even though production comparison execution is temporarily unavailable pending rigid-body porting.
- Replay and analysis occupy a collapsible bottom drawer whose expanded geometry reduces the viewport instead of covering it.
- Vehicle and target visuals remain presentation surfaces driven by the current runtime objects: local structural deformation for deformable proxies and Godot rigid-body transforms for supported world motion.
- The technical road, markings, sky and lighting are visual context only. They do not define collision planes or modify contact parameters.
- The first-run B-class versus rigid-wall 50 km/h scenario is a UI default, not a new calibration claim.

Responsive-layout regression covers 1280×720, 1440×900, 1920×1080 and 2560×1440 and explicitly rejects sidebar, toolbar, viewport and replay-drawer overlap. M14 adds a production open/close regression for the evidence-scope modal without replacing the M10 shell.

### Update service layer

`src/update/` is independent of simulation state.

- `SemanticVersion` parses and compares the canonical application version, including prerelease identifiers.
- `CrashVectorUpdateService` discovers official GitHub Releases, validates `update-manifest.json`, selects the package for the current OS, downloads it, verifies SHA-256, and hands only a verified installer to the operating system.
- Update preferences are stored under `user://`; no update state is embedded into scenario or physics data.
- The service never mutates or overwrites the executable that is currently running. macOS opens the verified DMG; Windows starts the verified Setup executable; CrashVector exits only after a successful handoff.

Network or verification failure therefore cannot modify the installed application. Stable users are not silently moved to prereleases; a prerelease install may move to a later prerelease or the eventual stable release.

### Desktop distribution layer

M9 packaging is generated from repository sources rather than manually maintained native projects, and later milestones continue to reuse the same distribution architecture. The current canonical prerelease is `0.6.0-beta.1`.

- `project.godot` contains the one canonical CrashVector Semantic Version.
- `tools/prepare_packaging.py` derives Godot export presets and native numeric version resources from that version.
- `tools/render_icon.gd` and `tools/generate_icon_containers.py` derive platform-native multi-resolution icon containers from the existing SVG branding master without changing the artwork.
- macOS CI produces and verifies a Universal 2 `CrashVector.app`, signs it, builds a DMG containing the application plus an Applications shortcut, and supports Developer ID/notarization when credentials exist.
- Windows CI produces the x64 application, applies/validates product metadata and icon resources, builds an Inno Setup installer, and performs a real install/uninstall validation; Authenticode hooks are present for later certificate use.
- `tools/build_update_manifest.py` creates the release manifest from the two already-validated packages.

Core CI, dedicated M10–M14 validation, macOS packaging and Windows packaging are release gates for the current M14 line. Release automation verifies package checksum sidecars again and skips publication when the canonical version already has an existing release, so a documentation-only follow-up does not replace published `0.6.0-beta.1` assets. `docs/DISTRIBUTION.md` describes the operational flow.

### Architecture hardening

Production code must use normal inheritance, composition, services and signals. Runtime implementation replacement through `set_script(...)`, `take_over_path(...)`, direct script-property reassignment or equivalent mechanisms is prohibited. Core CI and dedicated validation workflows scan `src/` and `app/` for those patterns so a future change cannot quietly reintroduce them.

## Determinism

Identical scenario inputs, engine version, and solver configuration are expected to produce identical state within regression tolerance. CI covers structural determinism, historical paired-contact momentum conservation, scenario serialisation invariants, replay independence, M8 reference correlation, M9 version/update logic, complete-editor startup, M10 responsive presentation invariants, M11/M12/M13 passenger-car crush and rigid-body stability, and M14 road-user/yielding-obstacle production routing and behaviour.

## Units

Internal calculations use SI units: metres, seconds, kilograms, newtons, joules, and radians. The editor displays km/h where useful but converts at the UI/physics boundary.

## Scope boundary

CrashVector is an educational scenario-building and visualisation application. Most scenarios are not experimentally validated. A/B/C/D/J/M cars are generic representative classes; heavy vehicles and motorcycles are simplified models; bicycle and pedestrian modes are contact/trajectory proxies; broadside/complex oblique contact awaits a richer geometry system; and occupant/rider biomechanics and injury prediction remain outside the model.

M8 makes that modelling boundary explicit in the UI and exported metadata. M9 changes distribution and update mechanics only. M10 changes layout, interaction and visible scene presentation only. M11–M13 refine passenger-car crush and authoritative rigid-body world motion. M14 adds rigid-body road-user contact/trajectory proxies and generic yielding pole/tree behaviour without broadening any validation claim.
