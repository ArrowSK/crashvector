# Physics Notes

CrashVector is an educational simulator. Numerical outputs must be labelled according to the confidence of the underlying model and must not be presented as certified accident reconstruction or occupant-injury prediction.

## Passenger-car presets

CrashVector currently uses generic B-, C-, and D-segment passenger-car presets. The classes vary representative mass, structural length/width scaling, and stiffness scaling. These parameters are development assumptions, not manufacturer data and not homologation models.

M4 allows two independent passenger-car instances in the same scenario. This is intentionally class-based rather than production-model based.

## World transforms

The structural graph itself is transformed when an editor user moves or rotates a vehicle. Heading is therefore not a cosmetic mesh rotation: node positions and velocities are yaw-rotated around the configured vehicle origin and initial energy is recaptured after the transform.

This lets the same structural model represent rear-end and near head-on layouts without changing the underlying car definition.

## Dynamic vehicle-pair contact

`VehiclePairSimulation` is used for both car-vs-truck and car-vs-car impacts. For each configured structural-node pair, `VehiclePairContact`:

1. detects penetration along the scenario contact normal and verifies transverse proximity;
2. measures relative normal and tangent velocity;
3. computes a normal impulse from the two nodal inverse masses and configured restitution;
4. applies equal-and-opposite normal velocity changes;
5. applies a Coulomb-limited tangent impulse using the configured contact-friction coefficient;
6. performs inverse-mass-weighted positional correction for residual penetration;
7. records kinetic-energy loss attributed to contact.

Because every contact impulse is applied equally and oppositely to the two nodes, system linear momentum is conserved apart from floating-point tolerance. The structural beams then distribute the local contact response through both deformable vehicles.

### Car vs car

For rear-end layouts, the primary car's lower front nodes contact the target car's lower rear nodes.

For near head-on layouts, the primary front nodes contact the target front nodes after the target structural graph and velocity have been rotated by approximately 180 degrees.

M4 deliberately rejects broadside and strongly oblique car-vs-car layouts. The current paired-node contact representation does not yet provide a sufficiently meaningful side-impact surface, door structure contact patch, wheel-to-body contact, or sliding multi-point manifold. Side-impact support should arrive with a richer geometric contact layer, not by stretching the front/rear approximation beyond its intended range.

## Car vs heavy truck

The heavy-truck reference scenario contacts the car's lower front structural nodes against the truck's low rear-underride nodes. This is a simplified geometric representation of a rear-underride interaction. It does not claim compliance with any specific guard standard or reproduce a particular truck design.

## Static-target contact

M4 adds a separate fixed-target contact solver for wall, concrete barrier, pole, and tree scenarios.

Wall and barrier targets use oriented vertical planes with finite lateral and vertical bounds. Pole and tree targets use vertical cylindrical contact regions. When a node penetrates a static target, the solver applies normal restitution, Coulomb-limited tangent friction, positional correction, and contact-energy accounting.

Static targets are externally fixed in M4. They therefore do not exchange momentum with a second simulated rigid body. This is appropriate for the current educational wall/barrier/pole/tree presets but should not be confused with modelling a deformable roadside structure or uprooting tree.

## Energy bookkeeping

For a dynamic-pair scenario, the diagnostic accounting is the sum of both structural models' kinetic, elastic, plastic, damping, fracture, and local contact terms plus pair-contact dissipation.

For a static-target scenario, fixed-target contact dissipation is added to the passenger-car structural model's accounting.

The bookkeeping remains a numerical diagnostic rather than a validated thermodynamic partition. Its purpose is to expose hidden energy creation, instability, and solver regressions.

## M8 correlation boundary

M8 adds the first external structural-correlation reference rather than changing the basic node/beam equations. The directly correlated condition is intentionally narrow: a generic D-segment midsize passenger car at approximately 56 km/h in a full-frontal rigid-wall impact, using the NHTSA DOT HS 812 237 / test 7078 condition as the evidence source.

The M8 regression compares the CrashVector result against project corridors for pulse duration, longitudinal delta-v, the safety-cell beam-deformation proxy, and energy-balance error. Published pedal/foot-rest intrusion values are preserved as source observations but are not re-labelled as beam deformation because the measurement definitions are different.

The current evidence labels therefore mean:

- `reference_correlated`: inside the narrow midsize rigid-wall mass/speed envelope;
- `near_reference`: same class/impact family but just outside the direct envelope;
- `class_scaled`: a generic B/C class is produced by the same structural scaling rules, without direct test correlation;
- `extrapolated`: all other conditions, including 90/140 km/h and dynamic vehicle-pair impacts.

A `reference_correlated` label is not a safety rating, homologation result, occupant-injury prediction, or claim that the generic D-segment structure reproduces a specific production vehicle. See `docs/CALIBRATION.md` for the source and corridor definitions.

## M0 reference quantities

The original regression remains unchanged: a 1,150 kg body at 140 km/h has 38.8888889 m/s speed, 869,598.765 J translational kinetic energy and 44,722.222 kg·m/s momentum magnitude.
