# M12 — Hybrid rigid-body physics correction

M12 is a corrective physics milestone prompted by visibly implausible post-impact motion in the M11 production desktop path. In particular, the M11 reduced-order structural graph could rebound away from a rigid wall and could generate excessive vertical motion because the same point-mass/beam graph was responsible for both permanent crush and whole-vehicle world motion.

M12 separates those responsibilities.

## Production architecture

For M12-supported desktop scenarios, Godot `RigidBody3D` is the authoritative whole-vehicle dynamics model. It owns:

- vehicle mass and inertia;
- world translation and rotation;
- 9.80665 m/s² gravity;
- continuous collision detection;
- collision response against real `StaticBody3D` targets and other rigid vehicle bodies;
- road support and chassis pitch/vertical response.

The M11 44-node passenger-car structure remains, but it is no longer the world-motion solver. Stations through the firewall/safety cell are anchored to the rigid chassis. The engine-bay and nose sections remain deformable and drive the visible body shell.

## Road support

Passenger cars use four raycast suspension contacts at the axle stations. Heavy articulated trucks use six suspension contacts across the trailer/tractor support stations. These are force-producing road contacts rather than the pre-M12 visual wheel clamp or hard wheel spheres.

The visible wheel meshes remain presentation geometry. Ground support comes from the suspension forces applied to the real rigid chassis.

## Front crush coupling

The passenger-car rigid collision volume ends at the protected-cell/subframe region rather than filling the undeformed nose. A forward collision-distance probe measures the remaining space between the protected structure and the opposing collider.

The production crush travel is therefore derived from:

`undeformed nose length - measured obstacle distance`

That travel drives a reduced-order progressive crash-box/front-rail resistance curve on the real `RigidBody3D`. The same travel is mapped across the M11 engine-bay structural stations so the visible shell shortens progressively instead of allowing an invisible rigid nose to contact first.

The coupling is phenomenological. It is not a finite-element vehicle model and does not claim manufacturer-specific crash performance.

## Static targets

Rigid wall, concrete barrier, pole and tree targets now include actual Godot static collision bodies matching their simplified presentation geometry. The old `VehicleStaticSimulation` remains in the repository for historical regression/calibration but is not stepped by the M12 production desktop path for these targets.

## Dynamic vehicle targets

Passenger-car and heavy articulated-truck scenarios use Godot rigid bodies for world motion. The truck includes a physical rear underride contact face and raycast suspension, preventing the passenger-car safety cell from numerically climbing an exposed low chassis rail.

## Explicitly unported paths

M12 does not silently fall back to the old world-motion solver. Rigid lorry, motorcycle, bicycle and pedestrian production simulation are temporarily blocked until those targets are ported to the rigid-body architecture.

For the same reason, Visual Compare and Comparison Lab are temporarily unavailable in the M12 corrective beta. Their historical synchronous `ComparisonRunner` remains available to legacy regression tests, but it is not presented as M12 production physics. A later milestone can restore these features using scene-based rigid-body recording.

The M8 calibration runner also remains a historical reduced-order correlation test. It is intentionally separate from the M12 production-world model and must not be interpreted as a validation of the new rigid-body/crush coupling.

## M12 regression gates

The dedicated M12 gate uses actual Godot physics frames and checks human-visible failure modes directly.

The centred 50 km/h generic B-class rigid-wall test fails if:

- reverse speed exceeds 0.90 m/s;
- retreat after first contact exceeds 0.25 m;
- vertical chassis rise exceeds 0.10 m;
- vertical speed exceeds 1.0 m/s;
- chassis pitch exceeds 6 degrees;
- front crush is below 0.25 m or above 0.85 m.

The 90 km/h generic B-class versus 18-tonne truck test additionally fails excessive passenger-car or truck vertical motion and requires substantial passenger-car crush.

A stationary-road test verifies that the rigid chassis remains supported by suspension rather than falling through or oscillating on the road.

These are project regression guardrails intended to catch visibly impossible behavior. They are not regulatory or manufacturer acceptance limits.

## Compatibility

Scenario files remain `.crashvector.json` and the M10 Scenario/Replay shell remains the desktop UI. M0–M11 reduced-order components remain in the repository for deterministic historical tests, calibration and future porting work. M12 changes which physics path is authoritative for supported production scenarios; it does not rewrite old scenario data.
