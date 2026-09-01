# Physics Notes

CrashVector is an educational simulator. Numerical outputs must be labelled according to the confidence of the underlying model and must not be presented as certified accident reconstruction or occupant-injury prediction.

## Reference quantities

For mass `m` and velocity vector `v`:

- translational kinetic energy: `0.5 * m * |v|^2`;
- linear momentum: `m * v`;
- km/h to m/s: divide by `3.6`.

The regression reference uses a 1,150 kg body at 140 km/h:

- 38.8888889 m/s;
- 869,598.765 J kinetic energy;
- 44,722.222 kg·m/s momentum magnitude.

## Structural response

The node/beam solver is a lumped-mass educational model. Each beam has:

- axial stiffness;
- axial damping;
- elastic strain;
- yield strain;
- plastic rest-length evolution;
- maximum plastic strain;
- fracture strain.

This provides progressive permanent crush and member failure without claiming continuum finite-element fidelity.

## M2 structural zones

The generic hatchback separates structure into deliberately different development profiles:

- rear crush zone;
- passenger safety cell;
- front transition zone;
- front crush zone.

The safety-cell beam stiffness is intentionally higher and its allowable plastic deformation lower than the front crush zone. This encodes the design principle that sacrificial structures should absorb deformation before the passenger compartment, but the numerical values are not sourced from any production vehicle.

## Global versus internal motion

Because the structural graph is the authoritative state, M2 extracts global vehicle motion from the nodes rather than adding a second independent rigid-body trajectory.

Whole-vehicle linear velocity is the mass-weighted average nodal velocity. Approximate angular velocity is derived from nodal angular momentum about the centre of mass using a scalar inertia approximation. The remaining nodal kinetic energy after translation and approximate rotation is reported as internal/deformation motion.

This decomposition is diagnostic. It is not a six-degree-of-freedom rigid-body replacement and will be refined as the vehicle model develops.

## Energy bookkeeping

The solver tracks:

- current nodal kinetic energy;
- elastic beam energy;
- accumulated plastic work;
- accumulated damping loss;
- fracture energy at member failure;
- rigid-barrier contact dissipation.

The energy-balance diagnostic compares those tracked terms against the captured initial energy. It is primarily a regression/debugging signal. Large residuals indicate numerical or accounting problems even if the animation appears plausible.

## Exterior and wheel physics boundary

The M2 procedural body shell follows structural nodes but does not itself contribute mass or stiffness. The M2 wheel/suspension system is also a visual attachment approximation and does not yet provide tyre forces or suspension reaction forces to the structure.

Those limitations must remain visible in documentation and in any interpretation of M2 results.
