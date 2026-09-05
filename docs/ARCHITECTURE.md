# Architecture

## Layering

CrashVector separates structural mechanics, object construction, contact resolution, scenario data, editor UI, replay/analysis, comparison/export, calibration evidence, desktop distribution and presentation. In the current M12–M16 production path, Godot rigid bodies own supported world motion while CrashVector structural graphs remain local deformation/presentation state. Historical reduced-order solvers are retained only where explicitly documented for regression or unavailable legacy workflows; presentation and distribution layers do not maintain a competing hidden production trajectory.

### Structural layer

- `StructuralNode` — lumped mass, position, velocity, accumulated force and pin state.
- `StructuralBeam` — axial spring/damper response, plastic flow, permanent deformation and fracture.
- `StructuralModel` — fixed-substep graph integration plus energy/contact diagnostics. Whole-model translation and yaw helpers remain available for historical reduced-order paths and editor transforms.
- `StructuralSnapshot` — captures and restores complete node/beam state for replay and offline rendering.

### Passenger-car layer

- `PassengerCarCatalog` defines generic A-, B-, C-, D-, J- and M-segment development presets without production-model branding.
- The M11 production passenger-car structure uses the refined 44-node local structural graph, including added engine-bay cross-sections, rather than the original 28-node whole-car production graph.
- `CompactHatchback` remains the common runtime wrapper for passenger-car presets and local deformation.
- `VehicleRigidChassis` is authoritative for supported M12–M16 passenger-car mass, inertia, translation, rotation, gravity, CCD and road/world collision.
- M13 extends local deformation past the front structure into firewall/cowl, floor/rocker, A-pillar/roof, passenger-cell and rear-body stages when collision demand justifies it.

A second passenger-car instance can be used for supported car-vs-car scenarios. The current production path does not substitute a hidden reduced-order point-mass trajectory for passenger-car world motion.

### Passenger-car presentation layer

M16 separates visible class identity from the physics representation.

- `VehicleVisualProfileCatalog` defines generic class-specific presentation profiles for A/B/C/D/J/M cars.
- `M16VehicleVisualRefined` reads the current deforming passenger-car structural state every frame and generates the visible body skin, glazing, trim, class details and wheels.
- The legacy `DeformableBodyShell` and `SimpleWheelRig` are hidden while the M16 skin is active; they are not repurposed as physics.
- SUV, MPV, midsize and smaller-car profiles can differ in roof height, windscreen/cabin offset, greenhouse extent, upper-body width, bonnet height, wheel package and lower cladding.

M16 presentation values do not change rigid collision geometry, mass, inertia, structural stiffness, beams, crush capacities, contact probes or solver configuration. They are not manufacturer CAD or homologation geometry.

### Heavy-vehicle and motorcycle layer

- `HeavyTruckBuilder` / `HeavyTruck` create the generic tractor/trailer structural approximation; the supported production heavy articulated truck uses rigid-body world motion, six suspension contacts and a physical rear underride contact face.
- `RigidLorryBuilder` / `RigidLorry` create the generic rigid-lorry / box-truck approximation.
- `MotorcycleBuilder` / `Motorcycle` create a generic riderless road-motorcycle approximation.

These are generic development models. Truck/lorry guard geometry and motorcycle structure are not manufacturer-specific or standards-certification models. Rigid lorry and motorcycle remain outside the current production rigid-body path and are not silently run through the historical solver.

### Road-user layer

`src/road_users/` contains deliberately limited vulnerable-road-user objects:

- `RoadUserCatalog` owns pedestrian and bicycle presets and their default mass/height values.
- `BicycleBuilder` / `Bicycle` create the riderless bicycle structural/presentation representation.
- `PedestrianBuilder` / `Pedestrian` create the historical structural/presentation representation.
- M14 introduced `RoadUserRigidProxy3D`, a real Godot `RigidBody3D` production wrapper with gravity, CCD, friction, collision geometry and post-impact world motion.
- M15 keeps that API/root for compatibility but upgrades production vulnerable targets to articulated multi-body motion.
- `RoadUserArticulatedProxy3D` builds the production pedestrian as an 11-body rigid chain connected by 10 bounded `Generic6DOFJoint3D` constraints.
- Riderless bicycles use a rigid frame plus two independently simulated wheel bodies connected at the hubs.
- Road-user rigid segments use a dedicated collision channel: they collide with the road, while passenger-car/vulnerable-target coupling remains routed through the existing passenger-car front-crush probe.
- `owns_collider()` lets the production path recognise any articulated target body rather than only the root collider.
- Replay serialises/restores articulated part transforms and velocities.

The M15 Generic6DOF joint limits are numerical stability envelopes. They are not validated human range-of-motion data. The pedestrian is not a crash dummy, tissue/bone model or injury predictor. The bicycle is riderless; a future cyclist should couple a separately modelled human body to a bicycle rather than combine their masses into one object.

### Historical reduced-order pair layer

- `VehiclePairContact` resolves paired node contacts using equal-and-opposite normal and Coulomb-limited tangent impulses.
- `VehiclePairSimulation` advances two structural models on one substep clock.
- The pair normal is scenario-defined, so heading-aware rear-end and near head-on layouts share deterministic historical contact logic.

This infrastructure remains in the repository for legacy regressions and the historical comparison runner. It is not the authoritative M12–M16 production world-motion path and is not used to bypass the production block on rigid lorry or motorcycle.

Broadside and strongly oblique contact still needs richer body-surface geometry and is rejected where the current production contact representation is not meaningful.

### Static and yielding target layer

`StaticObstacle3D` owns the wall/barrier/pole/tree target hierarchy used by the production scene.

- Wall and concrete barrier use real `StaticBody3D` collision geometry and remain non-yielding.
- Pole and tree use a `RigidBody3D` collision/visual hierarchy that begins frozen and effectively anchored.
- M14 `apply_collision_demand()` releases pole/tree targets into normal rigid-body motion when generic phenomenological yielding demand is exceeded, so visible and collision geometry move together after failure.
- Pole/tree yielding does not redefine wall/barrier behaviour or the M13 passenger-car staged-collapse model.

The generic pole/tree capacities are educational project parameters, not claims about a specific lamp post, utility pole, tree species, trunk diameter, soil or foundation.

### Scenario layer

- `ScenarioConfig` is the in-memory source of truth for target type, vehicle/body/bicycle preset, masses, speeds, positions, headings, contact parameters, duration and solver settings.
- `ScenarioConfig.apply_target_defaults()` gives targets sensible ready-to-run defaults so users are not forced to enter mass values before their first simulation.
- `ScenarioStore` serialises/deserialises human-readable `.crashvector.json` files.
- Preflight validation belongs in `ScenarioConfig`, not scattered across UI callbacks, so editor runs, saved scenarios, replay, comparison and batch workflows share constraints.

### Replay and analysis layer

- `ReplayRecorder` captures production state at 120 Hz.
- `ReplayRecording` stores frames and event markers independently of subsequent live simulation.
- `StructuralSnapshot` restores complete local structural state for deterministic scrubbing and offline presentation.
- Passenger-car replay stores rigid-chassis world state plus local structural deformation.
- M15 road-user replay stores articulated part transforms/velocities so playback does not collapse the target back into a single root-body approximation.
- `CrashAnalysis` derives delta-v, crash pulse, deformation histories, peak simulated deceleration, structural failures and event markers where those quantities are meaningful for the selected object type.

Road-user output remains contact/trajectory-only; it does not expose injury metrics.

### Comparison layer

- `ComparisonRunner` and `ComparisonLane3D` retain the historical deterministic batch-comparison implementation and regression coverage.
- Quick Visual Compare and Comparison Lab remain unavailable in the current desktop production path because the historical synchronous runner has not yet been ported to the M12–M16 rigid-body world architecture.
- The application does not present a reduced-order comparison result as current production physics merely to keep the UI feature enabled.

When this layer is ported, first-impact synchronization must remain presentation-only; each lane should still be simulated independently before playback timing is aligned.

### Cinematic export layer

M7 cinematic export maps recorded replay time into fixed output frames, camera plans, overlays, title/result cards and optional external FFmpeg MP4 encoding. The exporter does not re-run the collision.

Export metadata records scenario, analysis summary, presentation profile, timing, disclaimer and M8 calibration-scope label. Road-user exports retain explicit contact/trajectory-only scope wording.

### Calibration layer

M8 deliberately keeps evidence data outside the vehicle builder so a reference test cannot silently become a production-model preset.

- `CalibrationReference` loads machine-readable external reference metadata from `calibration/references/`.
- `CalibrationMetrics` maps a recorded CrashVector run into the limited structural metrics used by the current reference.
- `CalibrationRunner` executes the deterministic stored reference scenario and compares it with explicitly separated source-correlation and project-regression corridors.
- `CalibrationScope` classifies arbitrary editor scenarios as `reference_correlated`, `near_reference`, `class_scaled` or `extrapolated`.
- `docs/CALIBRATION.md` explains which numbers are published observations and which are CrashVector engineering thresholds.

The first directly correlated envelope remains intentionally narrow: generic D-segment midsize passenger car, full-frontal rigid wall, approximately 56 km/h and a limited mass range around the NHTSA reference condition. Passing that historical reference does not propagate a validation claim to M12–M16 rigid-body physics, high-speed demonstrations, vehicle-pair collisions, road users or class-specific M16 presentation.

The M14 evidence-scope fix changes presentation stacking only: the existing calibration/evidence CanvasLayer is raised above the desktop CanvasLayer so the existing modal and **Close** callback remain usable.

### Editor and production-scene layer

`src/demo/crash_demo.gd` remains the M4 scenario-editor base. Later milestone scripts extend it rather than replacing working layers:

- `crash_demo_m5.gd` adds replay and analysis;
- `crash_demo_m6.gd` adds visual comparison;
- `crash_demo_m7.gd` adds cinematic export;
- `crash_demo_m8.gd` adds expanded vehicle targets, custom-speed comparison, calibration-scope visibility and the reference check;
- `crash_demo_extended.gd` adds bicycle/pedestrian target handling and Comparison Lab while preserving the M8 lorry/motorcycle members;
- `crash_demo_m9.gd` adds the desktop Updates UI and delegates discovery/download/verification to a dedicated update service;
- `crash_demo_m10.gd` adds the original responsive Scenario/Compare shell and presentation controls;
- `crash_demo_m10_release.gd` retains M7–M9 service CanvasLayers in their inherited ownership hierarchy;
- M11–M13 add the refined crush, rigid-chassis and progressive whole-body failure production layers;
- `crash_demo_m14.gd` adds the M14 vulnerable-target/yielding-target production bridge and rigid road-user replay handling;
- `crash_demo_m15.gd` upgrades the road-user implementation to `RoadUserArticulatedProxy3D`, configures isolated vulnerable-target collision channels and retains the M14 production contract;
- `crash_demo_m16.gd` builds the task-focused desktop hierarchy and M16 presentation layer on top of M15;
- `crash_demo_m16_release.gd` preserves stable M10 shell identifiers/geometry contracts and attaches the refined production passenger-car skin.

`app/main.tscn` runs `crash_demo_m16_release.gd`. The M16 production scene therefore includes M15 articulated road-user physics underneath the M16 desktop/presentation layer.

### M16 desktop interaction layer

M16 gives each major region one job:

- Scenario builder: scenario name, primary vehicle, target and impact speed;
- 3D viewport: crash scene plus camera/display tools;
- Properties: selected-object fields, with solver/contact controls behind Advanced setup;
- Playback dock: timeline, replay speed, analysis and video export;
- command/secondary menus: file, calibration/evidence, updates and About.

The established M10 shell-region node names remain stable so historical responsive-layout tests still protect non-overlap and minimum viewport size. M16 adds its own regression for task-focused controls, class-specific vehicle visual differences and M15 preservation through the real production scene.

### Update service layer

`src/update/` is independent of simulation state.

- `SemanticVersion` parses and compares the canonical application version, including prerelease identifiers.
- `CrashVectorUpdateService` discovers official GitHub Releases, validates `update-manifest.json`, selects the package for the current OS, downloads it, verifies SHA-256 and hands only a verified installer to the operating system.
- Update preferences are stored under `user://`; no update state is embedded into scenario or physics data.
- The service never mutates or overwrites the executable that is currently running. macOS opens the verified DMG; Windows starts the verified Setup executable; CrashVector exits only after a successful handoff.

Network or verification failure therefore cannot modify the installed application. Stable users are not silently moved to prereleases; a prerelease install may move to a later prerelease or the eventual stable release.

### Desktop distribution layer

M9 packaging is generated from repository sources rather than manually maintained native projects, and later milestones reuse the same distribution architecture. The current canonical prerelease is `0.7.0-beta.1`.

- `project.godot` contains the one canonical CrashVector Semantic Version.
- `tools/prepare_packaging.py` derives Godot export presets and native numeric version resources from that version.
- `tools/render_icon.gd` and `tools/generate_icon_containers.py` derive platform-native multi-resolution icon containers from the SVG branding master.
- macOS CI produces and verifies a Universal 2 `CrashVector.app`, signs it, builds a DMG containing the application plus an Applications shortcut and supports Developer ID/notarization when credentials exist.
- Windows CI produces the x64 application, applies/validates product metadata and icon resources, builds an Inno Setup installer and performs a real install/uninstall validation; Authenticode hooks are present when signing credentials exist.
- `tools/build_update_manifest.py` creates the release manifest from the two already-validated packages.

Core CI, dedicated M10–M16 validation, macOS packaging and Windows packaging are release gates for the current M16 line. Release automation verifies package checksum sidecars again and refuses to replace an already-published version.

### Architecture hardening

Production code must use normal inheritance, composition, services and signals. Runtime implementation replacement through `set_script(...)`, `take_over_path(...)`, direct script-property reassignment or equivalent mechanisms is prohibited. Core CI and dedicated validation workflows scan `src/` and `app/` for those patterns so a future change cannot quietly reintroduce them.

## Determinism and regression strategy

Identical scenario inputs, engine version and solver configuration are expected to produce identical state within regression tolerance. CI covers structural determinism, historical paired-contact momentum conservation, scenario serialisation invariants, replay independence, M8 reference correlation, M9 version/update logic, M10 responsive presentation invariants, M11/M12/M13 passenger-car crush and rigid-body stability, M14 vulnerable-target/yielding-target production behaviour, M15 articulated road-user stability and M16 production UI/presentation integration.

The release pipeline additionally proves that the canonical source builds into a macOS Universal 2 DMG and Windows x64 installer before publication.

## Units

Internal calculations use SI units: metres, seconds, kilograms, newtons, joules and radians. The editor displays km/h where useful but converts at the UI/physics boundary.

## Scope boundary

CrashVector is an educational scenario-building and visualisation application. Most scenarios are not experimentally validated. A/B/C/D/J/M cars are generic representative classes; heavy vehicles and motorcycles are simplified models; pedestrian and bicycle modes are contact/trajectory proxies; broadside/complex oblique contact awaits a richer geometry system; and occupant/rider biomechanics and injury prediction remain outside the model.

M8 makes that modelling boundary explicit in the UI and exported metadata. M9 changes distribution/update mechanics only. M10 changes layout and scene presentation. M11–M13 refine passenger-car crush and authoritative rigid-body world motion. M14 adds rigid vulnerable-target trajectories and generic yielding pole/tree behaviour. M15 adds bounded articulated vulnerable-target dynamics without biomechanical validation. M16 changes desktop interaction and class-specific presentation without altering the M12–M15 physics/evidence scope.
