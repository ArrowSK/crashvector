# M18 — Passenger-car side impacts

M18 adds the first production broadside vehicle-pair path to CrashVector while preserving the M12–M17 rigid-body world-motion architecture.

## Production scope

Passenger-car vs passenger-car scenarios may use arbitrary relative headings, including perpendicular T-bone layouts. Godot `RigidBody3D` remains authoritative for mass, inertia, translation, rotation, gravity, suspension and contact response. M18 does not restore or introduce a custom whole-vehicle solver.

The existing longitudinal deformation paths remain unchanged:

- M12/M13 front crush and staged whole-body failure;
- M17 direct rear-impact crush;
- real rigid-body contact and replay from the production scene.

M18 adds a bounded local lateral-deformation envelope to the existing `M17CompactHatchback` compatibility class. Keeping the production class/API stable avoids replacing the M16/M17 presentation, replay or editor layers solely to add a new contact direction.

## Side-contact classification

The Godot contact point is evaluated in the struck car's local chassis frame. A sample is treated as lateral only when it lies near a protected-cell side face and within the longitudinal span of that cell. This prevents an ordinary bumper-corner contact from being interpreted as full cabin-side intrusion.

For a lateral sample, the collision demand uses the greater of:

1. reduced-mass energy from lateral relative velocity; and
2. `J² / (2μ)` reconstructed from the real Godot contact impulse.

The impulse term is retained because the direct-body callback observes contact after the physics solver has already changed the actors' velocities; relying on post-solve relative speed alone can substantially understate a real impact.

## Generic lateral deformation envelope

The side-crush relation is phenomenological:

`E = F0*x + 0.5*k*x²`

with class/mass scaling applied to the generic resistance terms. Commanded lateral intrusion is bounded to a fraction of the class-scaled vehicle width. The struck-side structural nodes move inward, with additional upper-structure drop to provide a visible door/B-pillar/roof-rail response rather than a uniform body translation.

The protected-cell `CollisionShape3D` retreats on the struck side as intrusion grows. This keeps physical contact geometry consistent with the local deformation instead of leaving a full-width invisible rigid box behind the damaged presentation.

## Replay and metrics

Replay visual state stores independent negative-Z and positive-Z lateral collision energy and intrusion values. The normal production metrics panel reports lateral intrusion when side-impact state is present. Structural snapshots continue to carry the actual deformed node positions used by the M16 presentation skin.

## Deliberate limits

M18 broadside support applies only to passenger-car pairs. Validation continues to reject broadside heavy-truck, rigid-lorry, motorcycle and bicycle layouts until those target families have appropriate lateral/contact models.

M18 does not claim:

- manufacturer-specific body-in-white stiffness or geometry;
- regulatory side-impact correlation;
- pole-side-impact certification;
- occupant compartment injury criteria;
- HIC, AIS, chest deflection or survivability;
- curtain-airbag, restraint or dummy modelling.

The side stiffness, intrusion and regression thresholds are generic CrashVector educational parameters. M8 calibration does not validate the M12–M18 rigid-body/deformation stack.

## Regression gate

`tests/m18_side_impacts.gd` verifies that:

- a 90-degree passenger-car pair passes preflight;
- a 90-degree heavy-truck case remains rejected;
- a perpendicular passenger-car production run produces real Godot contact on both actors;
- the struck passenger car develops material but bounded lateral intrusion;
- the striking passenger car still uses the existing front-crush path;
- the struck car's physical lateral collision face retreats;
- rigid-body state remains finite and vertical launch remains bounded;
- replay state contains lateral-deformation data.

The dedicated M18 workflow also executes the full M17 production-integration regression before the new side-impact gate.