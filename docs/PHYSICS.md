# Physics Notes

CrashVector is an educational simulator. Numerical outputs must be labelled according to the confidence of the underlying model and must not be presented as certified accident reconstruction, manufacturer crash performance, biomechanics or injury prediction.

The current `main` source is implemented through M22. The full current regression stack has executed successfully, and the verified public package is `0.9.0-beta.2`.

## Passenger-car presets

CrashVector uses generic A-, B-, C-, D-, J- and M-segment passenger-car presets. The classes vary representative mass, structural dimensions, mass distribution and stiffness scaling. These parameters are development assumptions, not manufacturer data, CAD-derived structures or homologation models.

Multiple passenger-car instances can exist in one scenario. Class identity remains generic even when the Kenney presentation layer supplies visually distinct bodies.

## Current production world motion

Since M12, supported production whole-object motion is not integrated by the historical deformable point-mass graph. Godot `RigidBody3D` is authoritative for mass, inertia, translation, rotation, gravity and world collision on the current production path.

For passenger cars, the M11 refined 44-node structural graph remains local to the rigid chassis and supplies permanent deformation/crush state. M13 extends local failure rearward through firewall/cowl intrusion, floor/rocker and A-pillar/roof deformation, passenger-cell shortening and rear-body buckling. M17 adds bounded direct rear deformation. M18 adds bounded left/right lateral protected-cell deformation. M19 adds observation/diagnostic coverage without taking collision authority away from Godot.

The passenger-car rigid collision volume ends around the protected cell/subframe rather than occupying the crushable nose. Front-crush travel is observed by one centre ray plus two M19 lateral rays. The deepest valid non-ground observation drives the existing crush path; those rays are sensors, not collision shapes and not separate force generators.

Passenger cars use four force-producing raycast suspension contacts. Heavy/other targets use their own production rigid bodies and support structures. Continuous collision detection remains enabled for production rigid bodies.

## Historical reduced-order solvers

`VehiclePairSimulation`, `VehiclePairContact`, `VehicleStaticSimulation` and the historical synchronous `ComparisonRunner` remain for regression continuity.

They are not silently substituted for the M12–M22 production world-motion path. Since M17, Visual Compare and Comparison Lab execute each requested variant through an isolated current production scene/`World3D` and consume the resulting production `ReplayRecording` and analysis state.

A result produced only by the historical reduced-order path must not be presented as current production physics.

## Passenger-car longitudinal deformation

### Front and staged failure

The M12 front structure has finite crush travel. M13 propagates severe residual collision demand through:

`front crush → firewall/cowl → floor/rocker + A-pillar/roof → passenger-cell shortening → rear-body buckle`

Stage activation uses collision demand and measured front-zone exhaustion rather than a simple speed threshold. The protected-cell collision face retreats during severe collapse so later shortening corresponds to physical collision geometry rather than a mesh-only effect.

The established generic B-class regression values remain historical project guards:

- 50 km/h rigid wall: about 105.0 kJ demand, 0.536 m front crush, effectively zero firewall/cabin/rear collapse;
- 200 km/h rigid wall: about 1,739.2 kJ demand, 0.945 m front-zone crush, 0.300 m firewall intrusion, 0.820 m passenger-cell collapse, 0.231 m rear buckle and 1.948 m combined longitudinal collapse.

These are CrashVector regression measurements, not predictions for a production car.

### Reciprocal rear impacts

M17 removes the assumption that the UI “primary” actor is always the striker. Supported dynamic impacts are classified from position, heading and velocity.

Passenger-car direct rear deformation and heavy-target longitudinal deformation retain both reduced-mass relative-velocity demand and contact-impulse-derived demand:

`E_impulse = J² / (2μ)`

where `J` is measured contact impulse and `μ` is reduced mass.

This avoids suppressing legitimate deformation merely because Godot has already resolved much of the relative velocity before the local-deformation layer observes the state.

## M18 passenger-car side impacts

M18 adds a generic bounded lateral-deformation envelope for passenger-car pairs.

A reported contact sample is considered lateral only when it lies near a protected-cell side face and within the protected-cell longitudinal span. Collider-centre/relative-motion checks prevent ordinary longitudinal contact with a wide actor from being misclassified as broadside.

Lateral collision demand again uses the larger of reduced-mass lateral relative-velocity energy and `J²/(2μ)` reconstructed from real contact impulse.

The phenomenological side relation is:

`E = F0*x + 0.5*k*x²`

with generic class/mass scaling and a bounded intrusion envelope. Struck-side structural nodes move inward/downward and the physical side collision face retreats with commanded intrusion.

The accepted M18 perpendicular regression uses a stationary C-segment car and a B-segment striker at 55 km/h / -90° and historically records approximately:

- 0.058 m lateral intrusion on the struck car;
- about 10 kJ generic side-contact demand;
- 0.305 m front deformation on the striking car;
- real non-ground Godot contacts on both actors.

Those are internal project regression values, not regulatory or manufacturer side-impact corridors.

## M19 contact fidelity and diagnostics

M19 makes the real Godot contact manifold observable without modifying solver impulses.

`ContactManifoldMetrics` summarizes non-ground samples from `PhysicsDirectBodyState3D`, including:

- simultaneous reported contact count;
- impulse-weighted local centroid/normal;
- XYZ spread;
- projected X/Z bounding-box spread product;
- reported per-step impulse;
- collider names.

The diagnostic scope is explicitly `diagnostic_only_no_solver_feedback` (or the articulated-pair equivalent for M21). The X/Z spread product is not physical contact-patch area and must not be interpreted as such.

M19 also stores public contact-load-case references. The extra NHTSA/IIHS offset/oblique entries are protocol-geometry-only where no source outcome corridor is stored. Geometry alone does not establish production correlation.

## M20 heavy and other-vehicle deformation

M20 extends generic broadside/oblique scope beyond passenger-car pairs for three target families while leaving Godot rigid bodies authoritative for world motion.

### Heavy truck

Real target-local contact demand is decomposed into longitudinal and lateral components. The inherited front/rear paths remain active and M20 adds independent bounded side deformation with collision-face retreat. Oblique contact can therefore command both longitudinal and lateral local deformation.

The generic truck side envelope is capped at approximately 0.52 m.

### Rigid lorry / box truck

`M20RigidLorry` adds bounded local deformation around the existing cargo-box/cab/frame/rear-guard architecture. Current generic caps are:

- rear 0.78 m;
- front 0.66 m;
- side 0.46 m.

### Riderless motorcycle

`M20Motorcycle` retains the riderless rigid-body trajectory/stability support and adds bounded frame/fork local deformation. Current generic caps are:

- rear 0.24 m;
- front 0.34 m;
- side 0.20 m.

There is no rider, steering controller, tyre-force model or injury inference.

These M20 values are phenomenological project limits, not measured crashworthiness corridors.

## M21 articulated heavy truck

M21 removes the previous one-rigid-body tractor/trailer simplification.

The heavy truck now uses separate trailer and tractor `RigidBody3D` assemblies. The configured target mass is preserved across the pair with a generic project mass split. The bodies exclude one another from collision response and are connected through a constrained `Generic6DOFJoint3D` fifth wheel.

The fifth-wheel model constrains linear separation and uses generic angular envelopes of approximately:

- yaw ±52°;
- pitch ±8°;
- roll ±6°.

Those are numerical/educational limits, not specifications for a real tractor/trailer.

M20 front/rear/side local deformation remains inherited. Contacts from trailer and tractor are consumed independently and mapped to the structure owned by the contacted rigid body. Replay/metrics add articulation yaw, peak articulation, fifth-wheel separation and combined contact diagnostics.

M21 does not add tyre-force modelling, load-securement behaviour, manufacturer mass distribution or forensic truck reconstruction.

## Vulnerable-road-user production path

Road-user targets remain contact/trajectory models rather than biomechanics models.

### M15 articulated pedestrian

The production pedestrian uses 11 rigid bodies connected by 10 bounded `Generic6DOFJoint3D` joints. Linear motion at those joints is constrained and angular motion uses conservative stability envelopes.

The historical accepted M15 regression recorded:

- 2.51 m/s final pedestrian COM speed;
- 13.97 m maximum COM travel;
- 105.2° maximum direct-joint motion;
- about 0.001 m maximum passenger-car vertical rise.

These are numerical stability/trajectory guards, not experimental biomechanics corridors.

### M15 riderless bicycle

The riderless bicycle uses a rigid frame plus two independently simulated wheel bodies joined at the hubs.

The historical accepted 60 km/h city-bicycle regression recorded:

- 3 rigid bodies / 2 hub joints;
- 9.21 m/s final target COM speed;
- 19.22 m maximum COM travel;
- 34.85 rad/s maximum wheel angular motion;
- about 0.001 m maximum passenger-car vertical rise.

The target remains riderless and keeps its near-longitudinal heading restriction.

## M22 cyclist

M22 adds a separate `cyclist` target instead of changing the meaning of `bicycle`.

The cyclist combines:

- one bicycle frame/root body;
- two bicycle wheel bodies;
- eleven generic rider bodies;
- two hub joints;
- ten bounded rider articulation joints;
- five temporary rider↔bicycle coupling joints at seat, hands and feet.

The scenario mass is combined rider+bicycle mass. The selected bicycle contributes its generic mass and validation preserves at least a 35 kg rider share.

Before contact the temporary coupling joints keep rider and bicycle associated. On first production-compatible vehicle contact those couplings are detached, after which rider and bicycle can follow independent trajectories. Self-collision inside the rider/bicycle assembly remains deliberately disabled; M22 does not claim a validated rider/bicycle high-energy contact solver.

The one-shot vulnerable-target transfer remains closing-speed based and bounded. It is a stability-oriented educational coupling, not a biomechanical force calculation.

Cyclist initial speed may be configured from 0–80 km/h and generic broadside/oblique heading layouts are allowed.

## M22 moving pedestrian

The articulated pedestrian may now start with 0–20 km/h translation along the configured heading. Every articulated body begins with the same translational velocity.

This is not a walking or running simulation. CrashVector does not model gait cycle, foot placement, propulsion, balance, ground-reaction control or evasive movement.

## Vulnerable-road-user evidence boundary

Pedestrian, riderless-bicycle and cyclist output is trajectory/contact visualisation only. CrashVector does not calculate HIC, AIS, survivability, fracture probability, tissue loading, dummy-equivalent measures or medical outcome.

M15/M22 joint limits, coupling locations, release logic and impulse sharing are numerical/model assumptions, not validated human biomechanical data.

## Static and yielding targets

Wall and concrete barrier remain fixed collision targets.

Generic pole/tree targets begin effectively anchored and can be released into normal rigid-body motion when project collision-demand thresholds are exceeded. Current generic thresholds remain approximately:

- pole yielding around 70 kJ; generic failure flag around 480 kJ;
- tree yielding around 240 kJ; generic failure flag around 1.65 MJ.

These are educational parameters, not claims about a particular pole, tree, soil, roots or foundation.

## Replay and metrics

Production replay is recorded at 120 Hz and stores enough state to reproduce historical presentation without re-running the crash.

Depending on target/model, replay can include:

- passenger-car rigid transform/velocity and structural snapshot;
- M17 rear crush state;
- M18 left/right lateral state;
- M19 contact-manifold diagnostics;
- M20 target-specific deformation;
- M21 articulated truck state;
- articulated road-user part transforms/velocities;
- M22 cyclist coupling-release state.

The analysis layer exposes only quantities meaningful for the selected model. Road-user modes remain trajectory/contact only.

## Energy bookkeeping

CrashVector energy accounting is a numerical diagnostic rather than a validated thermodynamic partition. It is used to expose hidden energy creation, instability and regression.

Historical structural solvers retain elastic/plastic/damping/fracture/contact bookkeeping. Current rigid-body production paths use measured contact demand and bounded local deformation state. M15/M22 add road-user stability guards. M17–M21 retain real contact-impulse information where post-solve relative speed alone would understate collision demand.

These quantities must not be interpreted as an experimentally validated energy partition for a real vehicle, person, bicycle or roadside object.

## Comparison

Each current production comparison variant is simulated independently in an isolated production scene. Results are then synchronized for replay; CrashVector does not scale or interpolate one crash to manufacture another speed/class result.

The historical `ComparisonRunner` remains for regression continuity only.

At equal mass the familiar initial-condition relation still applies: `E = 0.5 m v²`. For example, 140 km/h carries about 16% more translational kinetic energy than 130 km/h.

## M8 correlation boundary

The historical M8 directly correlated condition remains intentionally narrow: generic D-segment midsize passenger car, approximately 56 km/h, full-frontal rigid wall, limited mass range around NHTSA DOT HS 812 237 / laboratory test 7078.

Evidence labels remain:

- `reference_correlated`;
- `near_reference`;
- `class_scaled`;
- `extrapolated`.

The M8 runner is a separate historical reduced-order correlation/regression path. It does **not** validate the M12–M22 production architecture, including rigid-body world motion, staged collapse, road-user articulation, reciprocal impacts, passenger-car side impacts, M19 contact diagnostics, M20 heavy/other deformation, M21 fifth-wheel articulation or M22 cyclist/moving-pedestrian behaviour.

M19 protocol-geometry references also do not create outcome correlation corridors merely because a test geometry is public.

## Validation scope by milestone

The current consolidated test inventory retains historical M0–M18 regression plus dedicated source gates for:

- M19 contact-manifold helper/reference/probe/replay diagnostics;
- M20 truck/lorry/motorcycle broadside/oblique deformation;
- M21 articulated heavy-truck topology/contact/articulation/replay;
- M22 cyclist topology/mass/coupling/replay and moving-pedestrian initial motion.

The manual visual-review workflow separately renders presentation acceptance frames and the four-case M19 contact-observation matrix.

Because hosted Actions capacity is currently exhausted, M19–M22 have not yet been executed by Godot in CI. Until that changes, they must be described as implemented source behaviour, not as passed runtime validation or released support.

## M0 reference quantities

The original regression remains unchanged: a 1,150 kg body at 140 km/h has 38.8888889 m/s speed, 869,598.765 J translational kinetic energy and 44,722.222 kg·m/s momentum magnitude.
