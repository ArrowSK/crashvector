# Physics Notes

CrashVector is an educational simulator. Numerical outputs must be labelled according to the confidence of the underlying model and must not be presented as certified accident reconstruction, manufacturer crash performance, biomechanics, or injury prediction.

## Passenger-car presets

CrashVector uses generic A-, B-, C-, D-, J-, and M-segment passenger-car presets. The classes vary representative mass, structural dimensions, mass distribution, and stiffness scaling. These parameters are development assumptions, not manufacturer data, CAD-derived structures, or homologation models.

Multiple passenger-car instances can exist in one scenario. This remains intentionally class-based rather than production-model based.

## World transforms

The structural graph itself is transformed when an editor user moves or rotates a dynamic object. Heading is therefore not a cosmetic mesh rotation: node positions and velocities are yaw-rotated around the configured origin and initial energy is recaptured after the transform.

This lets the same generic structure represent supported rear-end and near head-on layouts without changing the underlying object definition.

## Dynamic paired contact

`VehiclePairSimulation` advances two structural models on one substep clock. For each configured structural-node pair, `VehiclePairContact`:

1. detects penetration along the scenario contact normal and verifies transverse proximity;
2. measures relative normal and tangent velocity;
3. computes a normal impulse from both nodal inverse masses and configured restitution;
4. applies equal-and-opposite normal velocity changes;
5. applies a Coulomb-limited tangent impulse from the configured contact-friction coefficient;
6. performs inverse-mass-weighted positional correction for residual penetration;
7. records kinetic-energy loss attributed to local contact.

Because contact impulses are applied equally and oppositely, pair-system linear momentum is conserved apart from floating-point/numerical tolerance. Structural beams then distribute the local response through each deformable graph.

This paired architecture is used for supported car-vs-car, car-vs-heavy-truck, car-vs-lorry, car-vs-motorcycle, car-vs-bicycle, and car-vs-pedestrian-proxy cases.

### Car vs car

For rear-end layouts, the primary car's lower front nodes contact the target car's lower rear nodes. For near head-on layouts, the target structural graph and initial velocity are rotated approximately 180 degrees and front nodes contact front nodes.

Broadside and strongly oblique car-vs-car layouts are deliberately rejected. The current paired-node contact representation does not provide a sufficiently meaningful side-impact surface, door contact patch, wheel/body interaction, or sliding multi-point manifold.

### Heavy truck and lorry

Heavy-vehicle rear-contact scenarios use the car's lower front structural nodes against low rear/guard nodes in the generic heavy-vehicle structure. This is a simplified rear-impact/underride-relevant representation. It does not claim compliance with a particular rear-guard standard or reproduce a specific vehicle design.

### Motorcycle and bicycle

The motorcycle is riderless and uses a generic frame/fork structural approximation. The bicycle is also riderless and uses a much lighter deformable frame/fork graph. Their current paired-node contact supports rear-end or near head-on orientation ranges, not validated broadside two-wheeler contact.

Motorcycle/bicycle structural deformation and trajectory are educational proxies only. No rider is inferred from the vehicle mass.

### Pedestrian proxy

The pedestrian is a lightweight articulated structural/contact proxy with configurable body preset and mass. Presets currently provide representative adult, child-sized, and tall-adult height/mass defaults.

The proxy begins in a supported standing stance. When vehicle contact occurs, the stance support releases; gravity and simple ground contact then affect the articulated structure. This is intended to make contact sequence, body motion, and post-impact trajectory visible.

It is not a validated anthropomorphic test device, multibody human model, tissue/bone model, or injury model. Joint forces, fracture probability, head-injury criteria, AIS, fatality probability, and medical outcomes must not be inferred from it. The current pedestrian starts stationary; walking/running motion is not yet modelled.

## Static-target contact

A separate fixed-target solver handles rigid wall, concrete barrier, pole, and tree scenarios.

Wall and barrier targets use oriented vertical planes with finite lateral/vertical bounds. Pole and tree targets use vertical cylindrical contact regions. When a node penetrates a static target, the solver applies normal restitution, Coulomb-limited tangent friction, positional correction, and contact-energy accounting.

Static targets are externally fixed and therefore do not exchange momentum with a second simulated dynamic body. This is appropriate for the current educational presets but must not be confused with a deformable roadside structure or an uprooting tree.

## Energy bookkeeping

For a dynamic-pair scenario, diagnostic accounting includes both structural models' kinetic, elastic, plastic, damping, fracture, and local contact terms plus pair-contact dissipation.

For a static-target scenario, fixed-target contact dissipation is included with the primary structural model's accounting.

The bookkeeping is a numerical diagnostic rather than a validated thermodynamic partition. Its purpose is to expose hidden energy creation, instability, and solver regressions.

## Speed comparison

Comparison workflows clone a normal scenario and independently re-run each requested speed/type variant. They do not scale or interpolate a single crash result.

Primary-car speed can be set from 0 to 300 km/h, including close comparisons such as 130 vs 140 km/h. At equal mass, translational kinetic energy follows `E = 0.5 m v²`, so the 140 km/h case begins with about 16% more kinetic energy than the 130 km/h case. CI checks the expected velocity-squared relationship.

First-impact synchronization is presentation-only: each lane is simulated independently before its replay clock is shifted for visual comparison.

## M8 correlation boundary

M8 adds the first external structural-correlation reference rather than changing the basic node/beam equations. The directly correlated condition is intentionally narrow: a generic D-segment midsize passenger car at approximately 56 km/h in a full-frontal rigid-wall impact, using the NHTSA DOT HS 812 237 / laboratory test 7078 condition as the evidence source.

The stored source-correlation observation and CrashVector regression guardrails are explicitly separated. Published pedal/foot-rest intrusion observations are not re-labelled as beam deformation because the measurement definitions differ.

Current evidence labels mean:

- `reference_correlated` — inside the narrow midsize rigid-wall mass/speed envelope;
- `near_reference` — same class/impact family but just outside the direct envelope;
- `class_scaled` — another generic passenger-car class produced by the same structural scaling rules without direct test correlation;
- `extrapolated` — other conditions, including high-speed cases, dynamic vehicle-pair impacts, lorry/motorcycle cases, and all road-user cases.

A `reference_correlated` label is not a safety rating, homologation result, occupant-injury prediction, or claim that the generic D-segment structure reproduces a specific production vehicle. See `docs/CALIBRATION.md` for source and corridor definitions.

## M0 reference quantities

The original regression remains unchanged: a 1,150 kg body at 140 km/h has 38.8888889 m/s speed, 869,598.765 J translational kinetic energy, and 44,722.222 kg·m/s momentum magnitude.
