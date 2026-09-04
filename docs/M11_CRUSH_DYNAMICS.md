# M11 — Crush Dynamics Rebuild

M11 replaces CrashVector's production collision-response path while preserving the M0–M10 scenario, replay, comparison, calibration, export, updater and desktop-distribution layers.

## Why M11 exists

The pre-M11 static and vehicle-pair contact solvers used instantaneous velocity impulses followed by aggressive penetration correction. That could remove impact energy at the contact boundary before the deformable front structure had time to carry the load, allowing a vehicle to pivot around one or two contact nodes instead of progressively collapsing.

## Structural changes

The historical `CompactHatchbackBuilder` remains available as the M2 regression fixture. Production passenger cars built by `PassengerCarBuilder` now retain the seven historical reference stations at their original indices and add four engine-bay cross-sections, for 44 structural nodes total.

The refined front structure distinguishes bumper/nose structure, crash boxes, front rails, upper rails, subframe/cross-members and the firewall transition. Front members use progressive post-yield force curves rather than one purely linear axial spring law. Three-node bending constraints add angular stiffness, damping, plastic fold angle and fracture behaviour. The passenger cell receives substantially stronger bending constraints than the crush zone.

## Contact changes

`VehicleStaticContact` and `VehiclePairContact` are compliant force contacts. Penetration creates a normal spring force plus limited damping; tangential friction is force-limited. Contact forces are applied after structural forces are assembled and before nodes are integrated for the same solver substep.

Normal production contact no longer zeroes/reverses a node's velocity in one operation and no longer applies large penetration teleports. A very small emergency position correction exists only for deep numerical penetration.

Vehicle-pair simulation expands historical two-node contact seeds to the complete structural impact face and then greedily matches simultaneous transverse contact points. Equal and opposite forces preserve pair momentum without the old impulse pivot.

## Acceptance tests

`tests/m11_crush_dynamics.gd` explicitly checks properties that earlier scalar regressions did not:

- 44-node production passenger-car architecture and bending constraints;
- bumper, crash-box, rail, subframe and firewall-transition components;
- contact remains compliant after the first substep rather than instantaneously stopping a node;
- substantial engine-bay shortening in a centred 50 km/h wall impact;
- bounded passenger-cell reference-span change;
- left/right crush symmetry and near-zero yaw for symmetric input;
- measurable permanent fold angle and plastic work;
- multi-point expansion for car/truck contact;
- pair linear-momentum conservation;
- finite, bounded high-speed 140 km/h wall behaviour.

M11 does not turn CrashVector into a certified crash-reconstruction or production-vehicle FE model. The refined structure is still a generic reduced-order educational model, and evidence labels remain authoritative.
