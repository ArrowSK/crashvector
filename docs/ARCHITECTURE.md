# Architecture

## Current source and release split

CrashVector separates structural mechanics, Godot world motion, target-specific deformation, scenario data, replay/analysis, comparison/export, evidence, presentation and desktop distribution.

The current `main` source is implemented through M22. The full current regression stack, visual/contact review and native package gates have run successfully; the current verified public package is `0.9.0-beta.2`.

The governing production rule since M12 is unchanged: **Godot rigid bodies own whole-object world motion; CrashVector structural graphs own local deformation/presentation state.** Historical reduced-order solvers remain only where explicitly retained for regression continuity and do not secretly replace the current production trajectory.

## Production scene inheritance

`app/main.tscn` loads `src/demo/crash_demo_m22.gd`.

The current top-level source chain is:

```text
crash_demo_m22.gd
  ↓
crash_demo_m21.gd
  ↓
crash_demo_m20.gd
  ↓
crash_demo_m19.gd
  ↓
crash_demo_presentation.gd
  ↓
crash_demo_m17.gd
  ↓
M16/M15/M14/M13/M12/... inherited layers
```

M18 passenger-car side-impact behaviour is implemented in the production passenger-car/contact compatibility components used by the M17+ scene rather than as a competing root-scene script. `M17CompactHatchback` carries both M17 rear-impact state and the M18 bounded lateral state.

Each post-M18 layer is intentionally narrow:

- M19 adds contact diagnostics and front-probe observation coverage;
- M20 swaps in target-specific heavy-truck/lorry/motorcycle deformation implementations;
- M21 swaps the heavy truck to separate tractor/trailer rigid bodies with a fifth-wheel joint;
- M22 adds the cyclist/moving-pedestrian road-user layer and current desktop routing.

## Structural layer

- `StructuralNode` — lumped structural state: position, velocity, mass/force and pin state.
- `StructuralBeam` — axial response, damping, plastic flow, permanent deformation and fracture.
- `StructuralModel` — structural-graph integration and energy/deformation diagnostics.
- `StructuralSnapshot` — replay-safe capture/restore of structural state.

Whole-model translation/yaw helpers remain for historical reduced-order paths and editor transforms, but they do not own current production vehicle world motion.

## Passenger-car layer

- `PassengerCarCatalog` defines generic A/B/C/D/J/M representative classes, not production vehicles.
- The M11 production passenger-car structure uses the refined 44-node local graph.
- `CompactHatchback` remains the compatibility runtime wrapper.
- `VehicleRigidChassis` owns production passenger-car mass, inertia, translation, rotation, gravity, CCD and collision response.
- Passenger cars use four force-producing suspension rays.
- M13 extends local failure beyond the finite front crush zone into firewall/cowl, floor/rocker, A-pillar/roof, passenger-cell and rear-body stages.
- M17 adds bounded direct rear deformation from real contact demand.
- M18 adds independent negative-Z/positive-Z bounded lateral protected-cell deformation and retreats the impacted physical side face.
- M19 keeps Godot collision response authoritative while recording non-ground contact-manifold diagnostics and using three front-crush observation rays instead of only the historical centre ray.

A second passenger car uses the same production architecture for rear-end, near-head-on and M18 broadside/T-bone layouts.

## Passenger-car presentation

The visible passenger-car body is presentation-only and never defines mass, stiffness or collision geometry.

`KenneyVehicleSkin3D` uses six distinct Kenney Car Kit 3.1 body assets for the six generic passenger classes. The neutral visual no longer globally stretches the source mesh onto the deformation cage. At installation it captures:

- the source mesh and source bounds;
- a neutral CrashVector structural-section sample set;
- one uniform source-to-target scale;
- neutral placement relative to the vehicle reference transform.

At zero deformation the source Kenney silhouette therefore keeps its proportions, apart from axis conversion, uniform scale, placement and paint. During deformation, the presentation adapter adds the displacement between the live structural cage and the captured neutral cage to the pristine source point.

This preserves the distinction:

- **physics/structure** determines rigid motion and deformation magnitude;
- **Kenney geometry** determines the undamaged visible shape;
- **presentation adapter** transfers deformation displacement between them.

Wheel presentation remains separate from the structural/collision model.

## Contact and diagnostics layer

`VehicleRigidChassis` receives the real contact samples reported by Godot. M19 summarizes non-ground samples through `ContactManifoldMetrics` and records latest/peak manifold diagnostics including:

- simultaneous reported contact-point count;
- local centroid/normal and XYZ spread;
- projected X/Z bounding-box spread product;
- reported per-step impulse;
- collider names.

These fields have an explicit diagnostic-only scope and never feed back into Godot collision impulses.

The passenger-car front-crush observation path keeps the original centre `RayCast3D` and adds two symmetric lateral rays. The deepest valid non-ground observation drives the existing front-crush measurement. The rays are sensors, not collision shapes, and do not multiply the crush-resistance force.

## Heavy articulated truck

M20 and M21 build on the original generic heavy-truck structure without replacing Godot world motion.

### M20 deformation

M20 decomposes real target-local contact demand into longitudinal and lateral components. The generic truck can receive bounded front/rear/side local deformation, and the affected collision face retreats with the local deformation state.

### M21 articulation

`M21HeavyTruck` splits the world model into two real rigid assemblies:

- trailer rigid body — trailer collision volume, rear underride face, trailer frame and trailer suspension;
- tractor rigid body — cab/tractor collision volume, tractor frame and tractor suspension.

Configured target mass is preserved across both bodies using a generic project mass split. The bodies exclude one another from collision response and are joined through a constrained `Generic6DOFJoint3D` fifth wheel. Linear separation at the joint is constrained and yaw/pitch/roll use bounded generic numerical envelopes.

The existing M20 deformation paths remain inherited. Contact samples from trailer and tractor are consumed independently, then mapped to the structural region owned by the contacted body.

`M21HeavyTruckVisual` gives tractor and trailer separate presentation transforms. Replay reconstructs historical articulation from recorded state instead of leaving the tractor at the live final pose.

M21 adds articulation yaw, peak articulation yaw, fifth-wheel separation and combined trailer/tractor contact diagnostics to current metrics/replay context.

The fifth-wheel geometry, joint limits, mass split, suspension split and deformation parameters are generic educational assumptions, not a specific truck specification.

## Rigid lorry and riderless motorcycle

M17 first moved these targets onto production Godot rigid-body world motion. M20 adds bounded target-specific deformation without introducing another world solver.

### Rigid lorry / box truck

`M20RigidLorry` keeps the generic cargo-box/cab/frame/rear-guard architecture and adds contact-driven bounded front/rear/side local deformation plus corresponding collision-face retreat.

### Riderless motorcycle

`M20Motorcycle` keeps the riderless rigid-body trajectory and stability support while adding bounded frame/fork front/rear/side deformation and limited collision-geometry adjustment.

There is still no rider, steering controller, tyre-force model, manufacturer geometry or crashworthiness correlation for the motorcycle target.

## Road-user layer

`src/road_users/` deliberately remains a trajectory/contact model rather than a biomechanics package.

### M15 preserved targets

- pedestrians use an 11-body articulated rigid chain with 10 bounded `Generic6DOFJoint3D` joints;
- riderless bicycles use a rigid frame plus two wheel rigid bodies connected at the hubs;
- road-user parts collide with the road through their dedicated collision channel;
- passenger-car/vulnerable-target coupling stays routed through the passenger-car front-probe path;
- replay stores/restores articulated transforms and velocities.

M15 joint limits are numerical stability envelopes, not human biomechanical range-of-motion data.

### M22 cyclist

`M22RoadUserProxy3D` adds a separate `cyclist` target without changing the meaning of the old `bicycle` target.

The cyclist combines:

- one existing bicycle frame/root body;
- two bicycle wheel bodies;
- eleven generic rider bodies;
- two hub joints;
- ten bounded rider articulation joints;
- five temporary rider↔bicycle coupling joints at seat, hands and feet.

The configured cyclist mass is combined rider+bicycle mass. The selected bicycle contributes its generic mass and the validator preserves at least a 35 kg rider share. On first production-compatible contact the temporary coupling joints are detached so rider and bicycle can follow independent post-impact trajectories.

Self-collision within the rider/bicycle assembly remains deliberately disabled after release. This avoids claiming an unvalidated high-energy rider/bicycle contact solver.

### Moving pedestrian

M22 permits 0–20 km/h initial pedestrian translation along the target heading. Every articulated pedestrian body starts with the same translational velocity. There is no gait, foot-placement, propulsion or balance controller.

## Scenario layer

`ScenarioConfig` is the in-memory source of truth for target type, presets, mass, speed, position, heading, contact parameters, duration and solver settings. `ScenarioStore` serializes/deserializes `.crashvector.json`.

Current dynamic targets include passenger car, heavy truck, rigid lorry, motorcycle, riderless bicycle, cyclist and pedestrian.

Preflight scope is intentionally target-specific:

- passenger-car pairs support arbitrary relative headings through M18;
- heavy truck, rigid lorry and riderless motorcycle support M20 broadside/oblique layouts;
- riderless bicycle retains its rear-end / near-head-on heading restriction;
- cyclist supports generic broadside/oblique rider+bicycle trajectory scenarios;
- pedestrian initial translation is capped at 20 km/h;
- static fixtures remain subject to the static-ahead preflight rule.

M21 does not change the saved identifier `heavy_truck`; existing scenarios route to the newer articulated implementation without a format migration. M22 introduces a new `cyclist` identifier rather than changing old `bicycle` semantics.

## Historical reduced-order solvers

`VehiclePairContact`, `VehiclePairSimulation`, `VehicleStaticSimulation` and `ComparisonRunner` remain for historical regression continuity.

They are not authoritative M12–M22 production world motion. Since M17, current Visual Compare and Comparison Lab run each requested variant through an isolated production scene/`World3D` and consume the resulting real production replay/analysis state.

A result produced only by the historical reduced-order runner must not be presented as current production physics.

## Static and yielding targets

`StaticObstacle3D` owns wall/barrier/pole/tree production targets.

- rigid wall and concrete barrier remain non-yielding collision targets;
- pole/tree begin effectively anchored and can be released into normal rigid-body motion when generic phenomenological collision demand exceeds project thresholds;
- visible and collision geometry move together after yielding.

These capacities are generic educational parameters, not claims about a particular pole, tree, soil or foundation.

## Replay and analysis

`ReplayRecorder` records production state at 120 Hz. `ReplayRecording` stores frames/markers independently of later live simulation.

Current replay can include:

- passenger-car rigid transform/velocity and local structural state;
- M17 rear-deformation state;
- M18 left/right lateral-deformation state;
- M19 contact-manifold diagnostics;
- M20 target-specific deformation state;
- M21 articulated truck state and combined contact diagnostics;
- articulated road-user part transforms/velocities;
- M22 cyclist coupling-release state.

`CrashAnalysis` derives only metrics that are meaningful for the selected model. Road-user output remains trajectory/contact-only and exposes no injury metrics.

## Comparison

M17 production comparison executes each variant in an isolated `SubViewport`/`World3D` using the current production scene. The resulting `ReplayRecording` and analysis report are replayed in synchronized lanes.

This applies to main speed/class Compare and Comparison Lab target-type matrices. Later M19–M22 target implementations are therefore inherited automatically by comparison when the resulting `ScenarioConfig` is valid.

## Cinematic export

M7 cinematic export renders from recorded replay state and does not re-run the collision. It supports fixed output profiles, replay retiming, camera plans, overlays and external FFmpeg H.264/MP4 encoding.

Export metadata carries scenario/analysis/evidence information. Vulnerable-road-user exports retain contact/trajectory-only scope wording.

## Calibration and evidence

M8 deliberately separates evidence data from current production model construction.

- `CalibrationReference` stores external reference metadata;
- `CalibrationMetrics` maps the historical stored run into limited correlation quantities;
- `CalibrationRunner` executes the deterministic historical reduced-order reference path;
- `CalibrationScope` exposes the labels `reference_correlated`, `near_reference`, `class_scaled` and `extrapolated`.

M19 adds a separate external-reference catalog for contact-fidelity work. The additional NHTSA/IIHS offset/oblique entries are protocol-geometry-only unless source outcome corridors are explicitly available; their geometry must not be mistaken for validation of CrashVector output.

The M8 correlation reference does **not** validate the M12–M22 production architecture, including current rigid-body motion, staged collapse, road-user trajectories, reciprocal impact, side impact, M19 contact diagnostics, M20 heavy/other deformation, M21 articulation or M22 cyclist/moving-pedestrian behaviour.

## Desktop interaction and presentation

The established M16 desktop layout remains the current user shell:

- Scenario builder;
- central 3D viewport;
- contextual Properties;
- Playback/analysis dock;
- secondary file/update/calibration/export functions.

M19–M22 extend data/targets through that existing shell rather than redesigning it. Cyclist appears in the existing Impact target selector, and the Target tab exposes cyclist archetype/combined mass/speed and pedestrian initial speed.

Presentation-only environment/camera/selection work remains separated from physics and collision geometry.

## Update and distribution layer

`src/update/` remains independent from simulation state. The updater discovers official GitHub Releases, validates `update-manifest.json`, downloads the correct package, verifies SHA-256 and hands only a verified installer to the operating system.

Packaging is generated from repository sources:

- macOS Universal 2 application + DMG;
- Windows x64 application + Inno Setup installer;
- optional Developer ID/notarization and Authenticode paths when credentials are configured;
- checksum sidecars and generated update manifest.

The current public packaged version is `0.9.0-beta.2`, matching the M22 source and updater discovery.

`.github/workflows/package-release.yml` now requires M21 and M22 production regressions in both publishable validation levels. `validation=none` can build diagnostic artifacts but cannot publish a release.

## Architecture hardening

Production code uses normal inheritance, composition, services and signals. Runtime implementation replacement through `set_script(...)`, `take_over_path(...)`, direct script reassignment or equivalent patterns is prohibited and scanned by `tools/check_no_monkey_patching.sh`.

## Determinism and validation strategy

Regression tests are architecture/numerical preservation gates, not manufacturer or regulatory correlation.

The consolidated suite now enumerates M0–M22 and includes dedicated current-source checks for:

- M18 passenger-car side impacts;
- M19 contact diagnostics/front-probe layout;
- M20 heavy/lorry/motorcycle deformation;
- M21 articulated heavy truck;
- M22 cyclist and moving pedestrian.

The manual visual-review workflow separately renders presentation acceptance frames and the M19 contact-observation matrix. Release packaging separately proves native macOS/Windows build/install structure.

Because Actions capacity is currently exhausted, M19–M22 have not yet received their required Godot runtime execution. Until that happens, documentation must describe them as implemented source, not validated release capability.

## Units

Internal calculations use SI units: metres, seconds, kilograms, newtons, joules and radians. The editor displays km/h where useful and converts at the UI/physics boundary.

## Scope boundary

CrashVector is an educational scenario-building and visualisation application. Generic vehicle classes, target deformation limits, articulated joint envelopes and road-user coupling are project models rather than production-vehicle or human validation data.

CrashVector does not provide certified reconstruction, homologation, manufacturer crashworthiness prediction, occupant/rider biomechanics, medical/injury prediction or safety ratings.

M19 contact-manifold spread is diagnostic reported-contact geometry, not physical contact-patch area. M20 heavy/other deformation, M21 fifth-wheel articulation and M22 cyclist/moving-pedestrian behaviour remain generic educational extensions. No evidence claim should be strengthened until suitable external outcome data exists and the corresponding production source has also passed its runtime gates.
