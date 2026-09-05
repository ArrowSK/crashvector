# Physics Notes

CrashVector is an educational simulator. Numerical outputs must be labelled according to the confidence of the underlying model and must not be presented as certified accident reconstruction, manufacturer crash performance, biomechanics or injury prediction.

## Passenger-car presets

CrashVector uses generic A-, B-, C-, D-, J- and M-segment passenger-car presets. The classes vary representative mass, structural dimensions, mass distribution and stiffness scaling. These parameters are development assumptions, not manufacturer data, CAD-derived structures or homologation models.

Multiple passenger-car instances can exist in one scenario. This remains intentionally class-based rather than production-model based.

M16 adds class-specific **presentation** profiles, but those profiles do not change the physics parameters described here.

## Current production world motion

Since M12, supported production whole-object motion is not integrated by the historical deformable point-mass graph. Godot `RigidBody3D` is authoritative for mass, inertia, translation, rotation, gravity and world collision on the current supported production path.

For passenger cars, the M11 refined 44-node structural graph remains local to the rigid chassis and supplies permanent deformation/crush state. M13 extends that local failure rearward through firewall/cowl intrusion, floor/rocker and A-pillar/roof deformation, passenger-cell shortening and rear-body buckling when collision demand and front-zone exhaustion justify it.

The passenger-car rigid collision volume ends around the protected cell/subframe rather than occupying the crushable nose. A forward probe measures available front-crush travel, drives the phenomenological resistance force and provides the production contact route used by M14/M15 vulnerable road-user targets.

Passenger cars use four force-producing raycast suspension contacts. The supported heavy articulated truck uses six suspension contacts plus a physical rear underride contact face. Continuous collision detection is enabled for production rigid bodies.

## Historical reduced-order pair solver

`VehiclePairSimulation` and `VehiclePairContact` remain in the repository for historical regression and legacy batch/comparison coverage. They advance structural models on a shared substep clock and apply equal-and-opposite contact response at paired structural points.

That solver is not silently substituted for the current M12–M16 production world-motion path. In particular, rigid lorry and motorcycle production simulation remain blocked until their world motion/contact is ported to the rigid-body architecture, and Visual Compare / Comparison Lab remain unavailable because their historical synchronous runner has not yet been ported.

The historical pair solver remains useful for regression continuity, but a result produced only by that path is not presented as current production physics.

## Car vs car and heavy truck

Supported current passenger-car scenarios use the rigid-body production path for world motion. Car-vs-car remains limited to supported rear-end and near head-on layouts; broadside and strongly oblique contact still need richer body-surface geometry and a more complete contact manifold.

The supported heavy articulated truck also uses the rigid-body world path. Its rear underride geometry is a generic educational approximation and does not claim compliance with a particular rear-guard standard or reproduce a specific production vehicle.

## M14 vulnerable-road-user production bridge

M14 introduced `RoadUserRigidProxy3D`, a real Godot `RigidBody3D` wrapper for pedestrian and riderless-bicycle targets. It owns vulnerable-target mass, gravity, CCD, collision geometry, friction and post-impact world motion.

The passenger-car front probe uses relative closing speed and reduced mass to derive a target-side contact impulse while the passenger car continues to receive its existing phenomenological front-crush resistance. The vulnerable-target proxy therefore does not add a second competing passenger-car motion solver.

M14 also established production replay/metric plumbing for road-user trajectories and the dedicated road-user/road collision channel later retained by M15.

## M15 articulated pedestrian dynamics

M15 keeps `RoadUserRigidProxy3D` as the compatibility API/root but replaces the pedestrian's one-rigid-body approximation with `RoadUserArticulatedProxy3D`.

The production pedestrian contains 11 rigid bodies connected by 10 bounded `Generic6DOFJoint3D` constraints. Linear motion at the joints is locked; angular motion is limited by conservative joint-specific envelopes.

An earlier M15 prototype used `ConeTwistJoint3D`, but high-speed Godot 4.4.1 testing exposed severe numerical energy injection and near-180-degree direct-joint folding. The final Generic6DOF topology was selected because it remained bounded under the release regression.

The configured angular limits are **not** measured human range-of-motion data. They are numerical stability envelopes only.

The passenger-car front probe may contact any owned articulated rigid body. The target-side impulse is distributed through the articulated target, while the road-user bodies physically collide with the road through an isolated collision channel.

At the final 60 km/h pedestrian regression the project records:

- 11 rigid bodies and 10 joints;
- 2.51 m/s final target centre-of-mass speed;
- 13.97 m maximum target centre-of-mass travel;
- 105.2° maximum direct-joint motion;
- 0.001 m maximum passenger-car vertical rise;
- no measured reverse launch;
- a hard 22 m/s target-centre-of-mass speed sanity ceiling for the test.

These are numerical stability/trajectory regressions, not experimental biomechanics corridors.

## M15 riderless-bicycle dynamics

The M15 riderless bicycle uses a rigid frame plus two independently simulated wheel bodies connected at the hubs. It remains a riderless target; no cyclist body is coupled to it.

The final 60 km/h riderless-city-bicycle regression records:

- 3 rigid bodies and 2 hub joints;
- 9.21 m/s final target centre-of-mass speed;
- 19.22 m maximum centre-of-mass travel;
- 34.85 rad/s maximum wheel angular motion;
- 0.001 m maximum passenger-car vertical rise.

The bicycle values are project regression measurements, not manufacturer bicycle data or cyclist-injury evidence.

## Vulnerable-road-user scope boundary

The current pedestrian presets provide representative adult, child-sized and tall-adult height/mass defaults. The pedestrian starts stationary; walking/running motion is not modelled. The bicycle remains riderless.

These objects are contact/trajectory visualisations only. CrashVector does not calculate injury, survivability, HIC, AIS, fracture probability, tissue loading, dummy-equivalent measures or medical outcomes.

## Static and yielding targets

`StaticObstacle3D` owns the current wall, concrete-barrier, pole and tree target hierarchy.

Wall and concrete barrier remain real `StaticBody3D` targets with fixed collision geometry.

Pole and tree are different in M14. Their collision and visual hierarchy begins as a frozen `RigidBody3D`, effectively behaving as an anchored fixture. CrashVector tracks generic collision demand and releases the target into normal rigid-body motion when the configured phenomenological yielding threshold is exceeded. Visible geometry and collision geometry therefore move together after yielding instead of leaving a permanently vertical rigid cylinder at arbitrary impact severity.

Current generic project thresholds are:

- pole yielding begins around 70 kJ; the generic failure flag is reached around 480 kJ;
- tree yielding begins around 240 kJ; the generic failure flag is reached around 1.65 MJ.

The released target receives only a fraction of residual collision energy as translational/rotational impulse so target failure does not become an artificial launch mechanism for the passenger car.

These values are educational project parameters. They are not claims about a particular lamp post, utility pole, tree species, trunk diameter, root system, soil, foundation or roadside installation.

## M13 progressive passenger-car failure

M13 removes the severe-impact discontinuity that existed after the original M12 rigid-body correction. The front crush zone has finite travel. Once that zone is materially exhausted, residual normal collision demand can activate later structural stages rather than disappearing at a fixed nose clamp.

The current progression is front crush → firewall/cowl intrusion → floor/rocker and A-pillar/roof deformation → passenger-cell shortening → rear-body buckling. Stage activation uses collision demand plus measured front-zone exhaustion, not a simple speed threshold.

For dynamic rigid targets, demand uses relative normal speed and reduced mass. The protected-cell collision face retreats as catastrophic firewall/cabin collapse develops, so later shortening produces real additional obstacle travel instead of being a mesh-only animation.

The M13 release regression preserves the distinction between moderate and extreme loading. The generic B-class reference runs recorded approximately:

- 50 km/h rigid wall: 105.0 kJ demand, 0.536 m front crush, effectively zero firewall/cabin/rear collapse;
- 200 km/h rigid wall: 1,739.2 kJ demand, 0.945 m front-zone crush, 0.300 m firewall intrusion, 0.820 m passenger-cell collapse, 0.231 m rear buckle and 1.948 m combined longitudinal collapse.

Those are CrashVector regression measurements for the generic project model, not predictions for a production car.

## Replay and metrics

Production replay is recorded at 120 Hz. For the current rigid-body path, replay stores rigid transform and rigid-body velocity state in addition to local structural snapshots.

M15 vulnerable-target replay additionally stores articulated part transforms and velocities, so playback does not reconstruct a multi-body pedestrian/bicycle as a single root body.

The analysis layer exposes only quantities meaningful for the selected model. Passenger-car metrics include rigid-body speed/momentum plus front and staged structural-failure measures. Vulnerable-road-user output remains contact/trajectory only.

## Energy bookkeeping

CrashVector energy accounting is a numerical diagnostic, not a validated thermodynamic partition. It is used to expose hidden energy creation, instability and regression.

The historical structural solvers retain their elastic/plastic/damping/fracture/contact bookkeeping. The current rigid-body production path additionally uses measured collision demand and local crush/failure state. M15 adds explicit target-centre-of-mass sanity gating to catch articulated-target instability.

These quantities must not be interpreted as an experimentally validated energy partition for a real vehicle, person, bicycle or roadside object.

## Comparison

The historical comparison workflows clone a scenario and independently run each requested speed/type variant. They do not scale or interpolate a single crash result, and their regression coverage remains useful.

However, Visual Compare and Comparison Lab are currently disabled in the desktop production path because their synchronous runner still depends on the historical reduced-order world solver. They will not be re-enabled until ported to the same rigid-body production architecture.

The familiar kinetic-energy relationship still holds for initial conditions: at equal mass, `E = 0.5 m v²`, so a 140 km/h case begins with about 16% more translational kinetic energy than a 130 km/h case.

## M8 correlation boundary

M8 adds the first external structural-correlation reference rather than validating the later production architecture. The directly correlated condition is intentionally narrow: a generic D-segment midsize passenger car at approximately 56 km/h in a full-frontal rigid-wall impact, using the NHTSA DOT HS 812 237 / laboratory test 7078 condition as the evidence source.

The stored source-correlation observation and CrashVector regression guardrails are explicitly separated. Current evidence labels mean:

- `reference_correlated` — inside the narrow midsize rigid-wall mass/speed envelope;
- `near_reference` — same class/impact family but just outside the direct envelope;
- `class_scaled` — another generic passenger-car class produced by the same structural scaling rules without direct test correlation;
- `extrapolated` — other conditions, including high-speed cases, dynamic vehicle-pair impacts, lorry/motorcycle cases and all road-user cases.

The M8 calibration runner remains a separate historical reduced-order correlation/regression path. It does not validate the M12–M16 rigid-body, staged-collapse, yielding-target, articulated-road-user or class-specific-presentation path.

A `reference_correlated` label is not a safety rating, homologation result, occupant-injury prediction or claim that the generic D-segment structure reproduces a specific production vehicle. See `docs/CALIBRATION.md` for source and corridor definitions.

## Validation scope by milestone

M14 dedicated engine-physics regression checks:

- passenger car versus stationary adult pedestrian proxy with material post-contact target trajectory;
- passenger car versus stationary riderless city-bicycle proxy with material post-contact target trajectory;
- severe generic pole and tree impacts producing permanent target motion;
- wall and concrete barrier remaining non-yielding;
- bounded passenger-car rebound/vertical behaviour;
- production routing through the real road-user proxy path.

M15 adds:

- articulated pedestrian body/joint topology;
- bounded direct-joint motion;
- target centre-of-mass speed/travel sanity;
- passenger-car vertical/rebound stability after articulated contact;
- independently simulated bicycle wheel motion;
- preservation of M14 compatibility behaviour.

M16 does not add or retune physics. Its production regression verifies that the actual M16 UI still routes pedestrian selection to the finalized M15 articulated target and that the class-specific vehicle visual layer remains presentation-only.

M14 also carries the evidence-scope UI regression that opens the Calibration / **Extrapolated** modal, verifies it is above the desktop UI, closes it through the existing **Close** control and verifies the normal UI remains intact. That test guards interaction/presentation only; it does not change physics or evidence scope.

## M0 reference quantities

The original regression remains unchanged: a 1,150 kg body at 140 km/h has 38.8888889 m/s speed, 869,598.765 J translational kinetic energy and 44,722.222 kg·m/s momentum magnitude.
