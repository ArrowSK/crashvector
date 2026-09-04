# M14 — Vulnerable road users and yielding narrow obstacles

M14 closes two production gaps reported during testing of the M13 desktop beta: bicycle/pedestrian targets were still intentionally blocked from the M12/M13 rigid-body production path, and pole/tree targets were represented as perfectly rigid `StaticBody3D` cylinders at every impact severity.

## Vulnerable road-user targets

Pedestrian and riderless-bicycle targets now use `RoadUserRigidProxy3D`, a real Godot `RigidBody3D` wrapper with gravity, CCD, friction, collision geometry and post-impact translation/rotation. The existing generic `Pedestrian` and `Bicycle` structural objects remain as presentation/contact proxies inside that rigid body; they are not promoted to biomechanical or injury models.

The passenger car remains on the M12/M13 `VehicleRigidChassis` path. Its front distance probe can detect the vulnerable target before the protected-cell collision volume reaches it. On first meaningful closing contact, the target receives a reduced-mass impulse and is released into normal Godot rigid-body trajectory/tumble motion. The car continues to receive its existing phenomenological nose-crush resistance, avoiding the old behaviour where a 16–75 kg target acted like a rigid wall until the safety cell arrived.

Pedestrian output remains explicitly a contact/trajectory visualisation. CrashVector does not calculate injury, survivability, HIC, AIS, tissue loading or dummy-equivalent metrics. The bicycle target remains riderless.

## Pole and tree yielding

Wall and concrete-barrier targets remain rigid. Pole and tree targets retain stable Godot static collision contact, but their full visual and collision hierarchy can now rotate permanently about the ground attachment when collision demand exceeds generic yielding thresholds.

The current project parameters are phenomenological educational values:

- generic pole: yielding begins around 70 kJ and progresses toward a large permanent bend around 420 kJ;
- generic tree: yielding begins around 240 kJ and progresses toward a large permanent bend around 1.55 MJ;
- sufficiently larger demand can mark base/foundation failure and increase the permanent rotation further.

These values are not claims about a particular lamp post, utility pole, tree species, trunk diameter, soil condition or foundation design. They exist to remove the visibly false assumption that every narrow target remains perfectly vertical under arbitrarily severe impact.

## Release gates

M14 adds engine-physics regression cases for:

- a passenger car striking a stationary adult pedestrian proxy and producing material target trajectory;
- a passenger car striking a stationary riderless city-bicycle proxy and producing material target trajectory;
- a 200 km/h generic B-class car striking the generic pole and producing substantial permanent pole rotation;
- a 200 km/h generic B-class car striking the generic tree and producing substantial permanent tree rotation;
- wall and concrete barrier remaining non-yielding under the new obstacle API;
- passenger-car vertical/rebound stability remaining bounded in those scenarios.

The M10–M13 physics, UI and packaging regressions remain mandatory. M14 does not change the M13 passenger-car whole-body failure model.
