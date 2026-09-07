# M19 — Contact fidelity and external validation foundation

M19 starts the post-M18 work by making the production contact behaviour observable before changing it. The first M19 increment is deliberately diagnostic: it does not alter M12-M18 rigid-body motion, collision shapes, impulses, crush classification, deformation demand, suspension or replay state.

## Real Godot contact-manifold diagnostics

`VehicleRigidChassis` already receives the real contact samples reported by `PhysicsDirectBodyState3D`. M19 summarizes the non-ground contacts from each integration step through `ContactManifoldMetrics` and retains:

- number of simultaneous reported non-ground contact points;
- impulse-weighted local centroid and normal;
- local X/Y/Z spread of the reported points;
- diagnostic X/Z bounding-box spread product;
- total reported impulse for the integration step;
- collider names;
- the latest manifold and the peak-impulse manifold;
- maximum reported contact-point count and maximum local spread over the run.

The X/Z spread product is not physical contact-patch area. The diagnostic is observational only and has the explicit scope marker `diagnostic_only_no_solver_feedback`.

The production M19 layer stores these diagnostics in replay context and vehicle metrics. `CrashAnalysis` aggregates the maximum primary/target manifold diagnostics over the recording. The existing analysis summary adds a concise contact-manifold line when real non-ground contacts were observed.

## External validation reference catalog

M19 also separates useful public load-case evidence from claims that CrashVector currently reproduces the corresponding outcome.

The catalog contains four stored references:

1. the existing NHTSA full-frontal midsize reference used by the historical M8 reduced-order correlation path;
2. NHTSA research test 7441 — 90 km/h, 15-degree oblique, 35-percent overlap;
3. IIHS small overlap protocol — approximately 64.4 km/h, 25-percent overlap;
4. IIHS moderate overlap 2.0 protocol — approximately 64.4 km/h, 40-percent overlap.

The three offset/oblique references are `protocol_geometry_only`: they record public load-case geometry but contain no invented CrashVector outcome corridor. None of the four references currently claims validation of the M12-M19 production rigid-body stack. The historical M8 reference remains explicitly identified as a reduced-order correlation check.

## Regression gate

`tests/m19_contact_fidelity.gd` is intended to verify:

- ground contacts are excluded from manifold diagnostics;
- reported contact count, impulse and spread are summarized consistently;
- the four evidence references load and preserve their distinct evidence roles;
- protocol-only references do not invent source outcome corridors;
- a production perpendicular passenger-car impact produces real chassis manifold diagnostics;
- replay frames preserve those diagnostics;
- `CrashAnalysis` retains the primary manifold summary.

The test is added to consolidated CI. Runtime execution remains required before any change to offset/oblique contact response is justified.

## Next production step

The next M19 increment should compare full-frontal, offset-frontal, oblique and broadside production runs using the new manifold diagnostics. Only after those observations are available should CrashVector change collision/contact geometry or deformation classification. A change should be narrow and explainable from observed contact behaviour rather than introduced merely to make a screenshot look more plausible.

Public protocol geometry is not by itself a correlation corridor. Additional measured vehicle-response data or suitable licensed/public crash-test datasets are required before CrashVector can strengthen evidence claims for offset/oblique production behaviour.
