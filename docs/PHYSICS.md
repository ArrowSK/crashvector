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

## Energy bookkeeping

Future deformation work must explicitly track where pre-impact kinetic energy goes: remaining translation, rotation, structural deformation, frictional loss, suspension work, detached parts, and numerical loss. A solver that creates energy beyond tolerance is considered defective even when the animation looks plausible.

## Structural model boundary

M0 contains no crashworthiness model. The rigid test sled is only a dynamics and instrumentation baseline. M1 will add elastic response, plastic yield, permanent deformation, progressive weakening, and beam failure.
