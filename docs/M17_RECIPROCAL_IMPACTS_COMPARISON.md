# M17 — Reciprocal impacts, production comparison and long proving road

M17 completes the production-integration work that remained after M16.2 while preserving the M12–M16 rigid-body architecture and the finalized M15/M16 presentation and road-user layers.

## Production comparison

Visual Compare and Comparison Lab no longer execute the historical reduced-order `ComparisonRunner` as if it were current production physics.

Each requested comparison variant is executed independently in an isolated `SubViewport` / `World3D` using the current production scene and Godot `RigidBody3D` world-motion path. The resulting production `ReplayRecording` and analysis report are then displayed in synchronized comparison lanes.

This applies to custom-speed comparison, class comparison and Comparison Lab. First-impact synchronization remains presentation-only: each lane is simulated independently before playback timing is aligned.

## Reciprocal impact direction

Supported dynamic targets may start ahead of or behind the passenger car. Which actor strikes which follows position, heading and velocity rather than the UI words “primary” and “target”.

This allows scenarios such as a faster heavy truck approaching a passenger car from behind. Static fixtures still have to start ahead of the passenger car.

M17 remains intentionally near-collinear for dynamic vehicle-pair validation. Broadside passenger-car contact is added separately in M18.

## Passenger-car rear deformation

Passenger cars gain a bounded direct rear-impact deformation path driven by real Godot contact demand. The established M12/M13 front-crush and staged whole-body failure paths remain intact.

Collision demand preserves both reduced-mass relative-velocity energy and the real Godot contact impulse reconstructed as `J² / (2μ)`. Retaining the impulse term is important because post-solve relative velocity can materially understate a real contact after Godot has already changed both actors' velocities.

## Heavy articulated truck

The heavy articulated truck gains bounded local front and rear collapse. Its rigid collision faces retreat with the commanded collapse so the physical contact geometry follows the local deformation rather than leaving a full-size invisible rigid surface.

The truck remains one rigid world assembly. M17 does not introduce a tractor/fifth-wheel/trailer articulation model.

## Rigid lorry and motorcycle production routing

Generic rigid lorry / box-truck and riderless motorcycle targets are ported from the earlier blocked state to Godot `RigidBody3D` production world motion.

Their existing structural graphs remain rigid presentation/reference structures in M17. This milestone does not claim a detailed crush model for either target family and does not silently fall back to the historical reduced-order production solver.

## Long proving road

The production collision road is extended to approximately 4 km × 20 m, with presentation ground and editor position ranges widened to match. This provides substantial margin for high-speed scenarios around the working area instead of allowing normal 200 km/h runs to leave the original short road.

## Replay and compatibility

Comparison replay restores recorded rigid transforms and current presentation state, including articulated pedestrian/bicycle replay where applicable. Existing M12–M16 replay, analysis, calibration/evidence and cinematic-export layers remain inherited rather than replaced.

## Evidence boundaries

CrashVector remains an educational contact, trajectory and generic-deformation simulator. M17 does not claim:

- manufacturer-specific crash stiffness or collapse behaviour;
- detailed rigid-lorry or motorcycle crush;
- articulated fifth-wheel/trailer dynamics;
- certified accident reconstruction;
- homologation or safety-rating equivalence;
- occupant biomechanics, injury or survivability prediction.

M8 calibration remains a separate historical reduced-order correlation path and does not validate the M12–M17 production rigid-body/deformation stack.

## Regression gate

`tests/m17_production_integration.gd` covers the production integration points introduced by M17, including:

- a heavy truck striking a passenger car from behind;
- material deformation on both relevant actors;
- rigid-lorry and motorcycle production `RigidBody3D` routing;
- the approximately 4 km proving road;
- a real two-variant production Comparison run rather than the historical reduced-order comparison path.

The final M17 PR head `bb870532373aa9baf419d8bb86510393392a2470` passed M10 through M17 dedicated validation, canonical Core CI, macOS Universal 2 packaging, Windows export and Windows x64 installer packaging before merge.

M18 subsequently reran the M17 production-integration gate on top of its passenger-car broadside changes, and the merged M18 `main` commit `77fae8d6058724c54de1e9003020fccfddaa63b7` passed the M17 dedicated check again.
