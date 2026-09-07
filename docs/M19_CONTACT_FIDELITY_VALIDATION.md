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

## Regression and smoke gates

`tests/m19_contact_fidelity.gd` is intended to verify:

- ground contacts are excluded from manifold diagnostics;
- reported contact count, impulse and spread are summarized consistently;
- the four evidence references load and preserve their distinct evidence roles;
- protocol-only references do not invent source outcome corridors;
- a production perpendicular passenger-car impact produces real chassis manifold diagnostics;
- replay frames preserve those diagnostics;
- `CrashAnalysis` retains the primary manifold summary.

The dedicated M19 test is part of consolidated CI. The manual package smoke gate already runs `runtime_presentation_stability.gd` and `m18_side_impacts.gd`; those tests now also verify the cheap M19 helper/catalog checks and the current production scene's replay/analysis manifold path, so no additional package-smoke production run is required.

## Offset/oblique observation matrix

`ContactFidelityScenarioCatalog` defines four generic CrashVector observation cases:

- aligned head-on passenger cars;
- generic offset head-on passenger cars;
- generic 15-degree oblique passenger-car pair;
- perpendicular passenger-car impact.

These are deliberately not described as replicas of the stored NHTSA/IIHS protocols. They exist to compare the current production contact manifold as alignment changes while holding the architecture constant.

`tests/m19_contact_matrix.gd` runs the four cases through the real production scene and writes `build/m19_contact_fidelity/contact_matrix.json`. The manual Presentation visual review workflow runs this matrix alongside the rendered acceptance frames and uploads the JSON in the same review artifact. This keeps the expensive multi-case observation pass manual rather than adding four more production simulations to every normal CI push.

The diagnostic report includes reported contact-point count, local spread, peak reported-step impulse, primary/target front/rear/side crush and basic analysis metrics. It remains observation data only; no threshold is presented as an external validation corridor.

## Next production step

The next M19 increment is evidence-dependent: run the manual matrix, inspect whether aligned, offset, oblique and broadside cases produce plausible and distinct manifold behaviour, and only then make the smallest justified change to collision/contact geometry or deformation classification. A solver change should be traceable to an observed failure mode rather than introduced merely to improve appearance.

Public protocol geometry is not by itself a correlation corridor. Additional measured vehicle-response data or suitable licensed/public crash-test datasets are required before CrashVector can strengthen evidence claims for offset/oblique production behaviour.
