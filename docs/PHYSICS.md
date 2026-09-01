# Physics Notes

CrashVector is an educational simulator. Numerical outputs must be labelled according to the confidence of the underlying model and must not be presented as certified accident reconstruction or occupant-injury prediction.

## M0 reference quantities

For mass `m` and velocity vector `v`:

- translational kinetic energy: `0.5 * m * |v|^2`;
- linear momentum: `m * v`;
- km/h to m/s: divide by `3.6`.

The M0 regression case uses a 1,150 kg test body at 140 km/h:

- 38.8888889 m/s;
- 869,598.765 J kinetic energy;
- 44,722.222 kg·m/s momentum magnitude.

## M1 structural model

M1 uses a lightweight lumped-mass axial node/beam model. It is not a finite-element model and it does not represent sheet-metal shell elements, welds, adhesives, detailed joints, or material-rate effects.

Each structural node stores mass, position, velocity, and accumulated force. Each beam stores:

- original and current rest length;
- axial stiffness;
- axial damping;
- yield strain;
- maximum allowed plastic strain;
- break strain;
- plastic-flow rate;
- accumulated plastic, damping, and fracture-energy diagnostics.

For an intact beam, the solver calculates spring force from extension relative to the current rest length and damping force from relative axial velocity. When total engineering strain exceeds the yield threshold, the rest length moves gradually toward the deformed length, bounded by the configured maximum plastic strain. This produces permanent deformation after load removal. A beam is marked broken when absolute total strain reaches its configured break threshold.

The development sled uses three stiffness profiles: a relatively soft front crush segment, an intermediate transition segment, and a substantially stiffer cabin segment. These are development parameters, not measurements of any production vehicle.

## Integration and stability

The structural graph advances at Godot's 240 Hz physics rate with four internal solver substeps by default. The explicit semi-implicit integration scheme is intentionally simple and deterministic. Stiffness, damping, node mass, and substep count must be treated together when assessing numerical stability.

M1 barrier contact is handled directly by the structural solver as a rigid longitudinal plane. This isolates deformation behaviour for development. Coupling the structural graph to the global rigid-body vehicle representation is part of the later vehicle-integration work.

## Energy bookkeeping

M1 records:

- current translational kinetic energy of structural nodes;
- elastic strain energy stored in intact beams;
- accumulated plastic work;
- accumulated damping dissipation;
- elastic energy released into the fracture bucket when a beam fails;
- kinetic energy removed by rigid barrier contact.

`energy_balance_relative_error()` reports the difference between initial mechanical energy and the sum of the tracked buckets. It is a **numerical diagnostic**, not a validated physical energy partition. Plastic and fracture terms are deliberately approximate at this stage and will require calibration before quantitative interpretation.

A solver that develops non-finite state or creates unbounded energy is considered defective even if the animation appears plausible.

## Validation boundary

M1 proves that the implementation can produce elastic loading, permanent deformation, failure, contact, deterministic replay state, and auditable energy bookkeeping. It does **not** establish crashworthiness accuracy for a real car. Vehicle-level calibration is deferred until the generic hatchback architecture and deformation mapping exist.
