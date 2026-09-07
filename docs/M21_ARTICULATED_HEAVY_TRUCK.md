# M21 — Articulated heavy truck

M21 removes the largest architectural simplification left in the M17-M20 heavy-truck target: the tractor and trailer no longer share one rigid world body.

The M21 truck is still a generic educational target. It is not a manufacturer model, multibody tyre model, load-securement model, homologation calculation or forensic reconstruction tool.

## Two-body world model

`M21HeavyTruck` extends the M20 deformation target but splits world motion into two real Godot `RigidBody3D` assemblies:

- the trailer body retains the trailer collision volume, rear underride face, trailer frame and trailer suspension contacts;
- the tractor body owns the cab/tractor collision volume, tractor frame and tractor suspension contacts;
- the configured target mass is preserved across the two bodies using a generic 68/32 trailer/tractor mass split;
- the two bodies exclude one another from collision response and are connected through a constrained `Generic6DOFJoint3D` fifth wheel.

The fifth-wheel anchor is located at the established tractor/trailer transition. Linear motion at the anchor is constrained. Generic angular envelopes allow approximately ±52° yaw, ±8° pitch and ±6° roll. Those values are numerical/educational limits, not measured articulation specifications for a particular truck.

## Existing deformation preserved

M21 does not replace the M20 crash-deformation logic.

Real Godot contacts are consumed independently from the trailer and tractor rigid bodies. Contact demand is projected into each body's current longitudinal/lateral frame. The existing generic M20 front, rear and side deformation envelopes remain in force, but structural nodes and collision faces are now moved relative to the body that actually owns that part of the truck.

This matters during oblique and broadside events: the trailer can rotate relative to the tractor while local side deformation is still represented at the contacted structure.

## Presentation and replay

`M21HeavyTruckVisual` keeps the established M16.2/M17/M20 truck materials and silhouette but gives the tractor its own presentation transform.

Trailer and tractor presentation transforms are reconstructed from the recorded structural nodes rather than copied from the live final rigid bodies. As a result, replay can show historical articulation instead of leaving the tractor at the completed-run pose while the structural replay is rewound.

The inherited one-piece chassis presentation is split visually into trailer and tractor frame sections so no rigid visual bar bridges the fifth wheel.

## Metrics and diagnostics

M21 adds:

- current tractor/trailer articulation yaw;
- peak articulation yaw over the run;
- fifth-wheel anchor separation as a numerical joint diagnostic;
- combined target contact-manifold diagnostics that retain trailer and tractor sub-diagnostics while preserving the explicit diagnostic-only evidence scope.

Combined linear velocity, momentum and translational kinetic energy use both rigid bodies rather than reporting only the trailer body.

Replay context stores articulation and the combined target contact diagnostics alongside the inherited M19-M20 fields.

## Regression coverage

`tests/m21_articulated_truck.gd` defines an off-centre rear-quarter broadside passenger-car impact intended to verify:

- production routing to `M21HeavyTruck`;
- separate trailer and tractor `RigidBody3D` instances;
- preservation of configured total mass;
- presence of the constrained fifth-wheel joint;
- real non-ground Godot contact;
- measurable but bounded tractor/trailer yaw articulation;
- bounded fifth-wheel anchor separation;
- finite body motion without an artificial vertical launch;
- M21 articulated presentation routing;
- replay preservation of articulation/contact diagnostic context.

The existing M20 broadside/oblique production regression still runs through `main`, so it also exercises the M21 truck while preserving M20 deformation compatibility. Package smoke additionally constructs the two-body truck and articulated presentation through `runtime_presentation_stability.gd`.

## Validation status

M21 was implemented while GitHub-hosted Actions capacity was constrained and commits therefore use `[skip ci]`. Until Godot successfully imports the project and executes the M12-M21 regression stack, M21 must be treated as **implemented but runtime-unvalidated**.

No external accident-reconstruction or regulatory correlation claim follows from adding fifth-wheel articulation. The joint limits, mass split, suspension split and local deformation parameters remain generic CrashVector assumptions.

## Next milestone

The next planned road-user step is M22: cyclist/rider coupling and moving pedestrians. That work should preserve the current pedestrian/bicycle contact/trajectory evidence boundary unless suitable biomechanical validation data is introduced separately.
