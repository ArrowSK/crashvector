# M11 — Crush Dynamics Rebuild

M11 replaces CrashVector's production collision-response path while preserving the M0–M10 scenario, replay, comparison, calibration, export, updater and desktop-distribution layers.

## Why M11 exists

The pre-M11 static and vehicle-pair contact solvers used instantaneous velocity impulses followed by aggressive penetration correction. That could remove impact energy at the contact boundary before the deformable front structure had time to carry the load, allowing a vehicle to pivot around one or two contact nodes instead of progressively collapsing.

## Structural changes

The historical `CompactHatchbackBuilder` remains available as the M2 regression fixture. Production passenger cars built by `PassengerCarBuilder` now retain the seven historical reference stations at their original indices and add four engine-bay cross-sections, for 44 structural nodes total.

The refined front structure distinguishes bumper/nose structure, crash boxes, front rails, upper rails, subframe/cross-members and the firewall transition. Front members use progressive post-yield force curves rather than one purely linear axial spring law. Three-node bending constraints add angular stiffness, damping, plastic fold angle and fracture behaviour. The passenger cell receives substantially stronger bending constraints than the crush zone, together with a longitudinal anti-inversion guard so a centred frontal load cannot numerically turn the protected-cell reference frame through 180 degrees.

Structural viscous damping is bounded by the local relative motion available during each explicit substep. Progressive beam strain energy is integrated from the actual nonlinear force/displacement curve rather than using the linear-spring `1/2 F x` shortcut after yield or hardening.

M11 production static-collision energy validation uses a work-conjugate structural ledger. The refined reduced-order model combines axial members, plastic rest-state changes, fracture, phenomenological fold constraints and the passenger-cell guard; their separate diagnostic energy estimates are useful individually but are not assumed to be mutually independent calorimetric channels. The regression balance therefore integrates the actual structural force work against actual node motion and independently accounts contact spring and contact-dissipation energy. This changes only the diagnostic balance calculation, not collision forces, deformation, replay or calibration corridors.

## Contact changes

`VehicleStaticContact` and `VehiclePairContact` are compliant force contacts. Penetration creates a normal spring force plus limited damping; tangential friction is force-limited. Contact damping follows the scenario restitution setting. Contact forces are applied after structural forces are assembled and before nodes are integrated for the same solver substep.

Normal production contact no longer zeroes/reverses a node's velocity in one operation and no longer applies large penetration teleports. A very small emergency position correction exists only for deep numerical penetration.

Vehicle-pair simulation expands historical two-node contact seeds to the complete structural impact face and then greedily matches simultaneous transverse contact points. Equal and opposite forces preserve pair momentum without the old impulse pivot.

## Solver convergence and M8 reference

The refined 44-node structure is materially stiffer than the historical production graph, so M11 expands the public scenario solver range to 1–64 structural substeps. The stored 56.5 km/h M8 reference uses the same public path at 64 substeps.

The reference mass, speed, contact settings, source-correlation evidence and project regression corridors are unchanged. In particular, the approximately 120 ms crash pulse remains the external NHTSA-linked observation; delta-v, safety-cell proxy and the energy-balance threshold remain CrashVector project regression guardrails rather than NHTSA acceptance criteria.

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

The existing M8 calibration regression remains mandatory and its corridors are not weakened for M11. M10 editor smoke also checks that the desktop solver control exposes the same 64-substep maximum accepted by `ScenarioConfig`.

M11 does not turn CrashVector into a certified crash-reconstruction or production-vehicle FE model. The refined structure is still a generic reduced-order educational model, and evidence labels remain authoritative.
