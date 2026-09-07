# M19 — Contact fidelity and external validation foundation

M19 starts the post-M18 work by making production contact behaviour observable and by fixing one narrowly identified contact-measurement blind spot without introducing another world-motion solver.

Godot `RigidBody3D` remains authoritative for vehicle translation, rotation, collision impulses and contact resolution. M12-M18 collision bodies, suspension, rear/side classifiers and generic deformation-capacity curves remain intact.

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

The X/Z spread product is not physical contact-patch area. The diagnostic has the explicit scope marker `diagnostic_only_no_solver_feedback`; manifold values do not feed back into Godot impulses or deformation demand.

The production M19 layer stores these diagnostics in replay context and vehicle metrics. `CrashAnalysis` aggregates the maximum primary/target manifold diagnostics over the recording. The existing analysis summary adds a concise contact-manifold line when real non-ground contacts were observed.

## Offset/oblique front-crush coverage

The M12 front-crush measurement originally used one centre-line `RayCast3D`. That is adequate for centred wall and vehicle impacts, but it has an obvious geometric blind spot: a real Godot contact can overlap only one side of the passenger-car nose while the centre ray passes beside the other actor.

M19 keeps the original centre ray as the public compatibility handle and adds two symmetric lateral rays at the same longitudinal mount. The deepest valid non-ground ray measurement drives the existing front-crush measurement path.

This is deliberately a narrow change:

- the rays are sensors, not collision shapes;
- they create no impulses and do not replace the rigid-body contact manifold;
- the existing M16.2 collision-energy limit still caps crush against light or narrow targets;
- the existing single central crush-resistance force is unchanged, so adding measurement rays does not multiply resistance force;
- centred impacts still use the same centre-line geometry and existing deformation-capacity curves;
- the front probe set remains class-scaled and symmetric.

The change is intended to prevent a false `zero front crush` result when an offset/oblique impact already produced genuine rigid-body contact. It is not a claim that the resulting crush magnitude is externally correlated.

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
- all four generic contact-observation scenarios pass production preflight while remaining explicitly non-protocol replicas;
- a production passenger car exposes the original centre front-crush ray plus two symmetric lateral rays on one longitudinal mount;
- a production perpendicular passenger-car impact produces real chassis manifold diagnostics;
- replay frames preserve those diagnostics;
- `CrashAnalysis` retains the primary manifold summary.

The dedicated M19 test is part of consolidated CI. The manual package smoke gate already runs `runtime_presentation_stability.gd` and `m18_side_impacts.gd`; those tests also exercise the cheap M19 helper/catalog checks and the current production scene's replay/analysis manifold path, so no additional expensive four-case package-smoke run is required.

## Offset/oblique observation matrix

`ContactFidelityScenarioCatalog` defines four generic CrashVector observation cases:

- aligned head-on passenger cars;
- generic offset head-on passenger cars;
- generic 15-degree oblique passenger-car pair;
- perpendicular passenger-car impact.

These are deliberately not described as replicas of the stored NHTSA/IIHS protocols. They exist to compare the current production contact manifold as alignment changes while holding the architecture constant.

`tests/m19_contact_matrix.gd` runs the four cases through the real production scene and writes `build/m19_contact_fidelity/contact_matrix.json`. The manual Presentation visual review workflow runs this matrix alongside the rendered acceptance frames and uploads the JSON in the same review artifact. This keeps the expensive multi-case observation pass manual rather than adding four more production simulations to every normal CI push.

The diagnostic report includes reported contact-point count, local spread, maximum per-step projected X/Z spread, peak reported-step impulse, primary/target front/rear/side crush, maximum vertical motion and basic analysis metrics. It also treats a completed aligned/offset/oblique case with real contact but no measurable front-crush response as a contact-coverage failure. These are internal architecture checks, not external validation corridors.

## Current validation status and next production step

The source changes above were committed with `[skip ci]` while hosted Actions capacity was constrained. Therefore the new three-ray layout, M19 regression and four-case matrix are code-reviewed/static changes until Godot executes them. They must not be described as runtime-validated yet.

The next M19 decision remains evidence-dependent: run the manual matrix, inspect whether aligned, offset, oblique and broadside cases produce finite, plausible and distinct manifold behaviour, and only then consider any further collision/contact-geometry or deformation-classification change. A solver change should be traceable to an observed failure mode rather than introduced merely to improve appearance.

Public protocol geometry is not by itself a correlation corridor. Additional measured vehicle-response data or suitable licensed/public crash-test datasets are required before CrashVector can strengthen evidence claims for offset/oblique production behaviour.
