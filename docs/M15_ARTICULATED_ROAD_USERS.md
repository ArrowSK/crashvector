# M15 — Articulated pedestrian and bicycle dynamics

M15 upgrades the M14 vulnerable-road-user production path without changing the M12–M14 passenger-car rigid-body/crush architecture.

## Production model

`RoadUserRigidProxy3D` remains the compatibility API/root used by the production editor and replay layer, but vulnerable targets are no longer treated as one rigid mannequin.

For pedestrians, `RoadUserArticulatedProxy3D` builds an 11-body articulated rigid chain connected by 10 bounded `Generic6DOFJoint3D` constraints. The limits are conservative numerical stability envelopes; they are not human range-of-motion data and must not be described as biomechanical validation.

For riderless bicycles, the production proxy contains a rigid frame plus two independently simulated wheel bodies joined at the hubs. The bicycle remains riderless; M15 does not add cyclist coupling.

Road-user rigid segments use a dedicated collision channel. They collide with the road, while passenger-car/road-user impact coupling remains routed through the existing passenger-car front-crush probe. Any owned articulated body can be recognized as the probe contact target.

## Why Generic6DOFJoint3D

An earlier M15 implementation used `ConeTwistJoint3D` for pedestrian articulation. Under high-speed impact in Godot 4.4.1 that topology could inject excessive numerical energy and permit near-180-degree direct-joint folding. M15 therefore uses bounded `Generic6DOFJoint3D` constraints with linear motion locked and angular motion limited per joint.

This is a numerical-stability decision, not a claim that the configured limits reproduce a validated crash dummy or human body.

## Replay and metrics

Replay captures and restores the articulated part transforms and velocities rather than recording only the root body. Production metrics use the articulated target centre-of-mass state and record maximum direct-joint motion. Bicycle regression additionally tracks wheel angular motion.

## Validation

The dedicated M15 regression runs the actual Godot physics path and preserves M14 compatibility gates.

At the final 60 km/h reference regression:

- pedestrian: 11 bodies / 10 joints, 2.51 m/s final centre-of-mass speed, 13.97 m maximum centre-of-mass travel, 105.2° maximum direct-joint motion, 0.001 m maximum passenger-car vertical rise and no measured reverse launch;
- riderless city bicycle: 3 bodies / 2 hub joints, 9.21 m/s final centre-of-mass speed, 19.22 m maximum centre-of-mass travel, 34.85 rad/s maximum wheel angular motion and 0.001 m maximum passenger-car vertical rise.

The pedestrian regression also enforces a 22 m/s target-centre-of-mass speed sanity ceiling for the 60 km/h case so a joint instability cannot pass merely because the final pose looks plausible.

These values are project regression measurements for numerical stability and material trajectory. They are not experimental biomechanics corridors, injury thresholds or manufacturer/regulatory reference data.

## Scope boundary

M15 remains an educational contact/trajectory model. It does not calculate or claim:

- HIC, AIS or other injury measures;
- tissue, bone, organ or dummy-equivalent loading;
- survivability or medical outcome;
- validated pedestrian kinematics;
- bicycle rider dynamics;
- walking/running pedestrian motion.

Historical M8 calibration does not validate M15. See `docs/CALIBRATION.md` for the evidence boundary and `docs/M14_ROAD_USERS_OBSTACLES.md` for the M14 production foundation.
