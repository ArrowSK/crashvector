# Physics Notes

CrashVector is an educational simulator. Numerical outputs must be labelled according to the confidence of the underlying model and must not be presented as certified accident reconstruction or occupant-injury prediction.

## Passenger-car presets

M3 introduces generic B-, C- and D-segment passenger-car presets. The classes vary representative mass, structural length/width scaling and stiffness scaling. These parameters are development assumptions, not manufacturer data and not homologation models.

## Coupled car/truck contact

The M3 coupled-contact solver uses paired structural nodes at the car front and truck rear underride structure. For an active contact pair it:

1. detects normal penetration and verifies transverse proximity;
2. measures relative closing speed along the contact normal;
3. computes an impulse from the two nodal inverse masses and configured restitution;
4. applies equal-and-opposite velocity changes;
5. performs mass-weighted positional correction for residual penetration;
6. records kinetic-energy loss attributed to contact.

Because the impulse applied to the two nodes is equal and opposite, system linear momentum is conserved apart from floating-point tolerance. The structural beams then transmit those local changes through each vehicle.

## Energy bookkeeping

For a coupled scenario the diagnostic accounting is the sum of:

- car kinetic and elastic energy;
- truck kinetic and elastic energy;
- plastic work;
- damping loss;
- fracture energy;
- any per-model barrier-contact loss;
- car/truck pair-contact dissipation.

The current bookkeeping remains a diagnostic rather than a validated thermodynamic partition. It is intended to expose numerical defects and make hidden energy creation visible.

## Underride model

The first M3 truck scenario deliberately contacts the car's lower front structural nodes against the truck's low rear guard nodes. This is a simplified geometric representation of a rear-underride interaction. It does not claim compliance with any specific guard standard or reproduce a particular truck design.

## M0 reference quantities

The original regression remains unchanged: a 1,150 kg body at 140 km/h has 38.8888889 m/s speed, 869,598.765 J translational kinetic energy and 44,722.222 kg·m/s momentum magnitude.
