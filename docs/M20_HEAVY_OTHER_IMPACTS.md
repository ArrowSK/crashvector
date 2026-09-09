# M20 — Heavy and other-vehicle deformation

M20 closes part of the target-specific gap left after M18. It allows the existing heavy articulated truck, rigid lorry / box truck and riderless motorcycle production targets to participate in broadside and oblique layouts while preserving CrashVector's current world-motion architecture.

This milestone is a **generic educational deformation model**, not manufacturer-specific crashworthiness, finite-element analysis, homologation, injury prediction or regulatory correlation.

## Architecture preserved

M20 does not introduce another collision solver.

- Godot `RigidBody3D` remains authoritative for target mass, inertia, translation, rotation, gravity and collision impulses.
- The existing M12-M19 passenger-car implementation is unchanged.
- The heavy articulated truck remains one rigid world assembly in M20. Tractor/trailer fifth-wheel articulation is still deferred to M21.
- Existing suspension, road contact, replay, comparison, analysis, presentation and contact-manifold diagnostics are inherited.
- Local target deformation is driven only after real non-ground Godot contact is reported.

## Heavy articulated truck

`M20HeavyTruck` extends the existing M17 heavy-truck target.

M17 front/rear collapse is retained. M20 decomposes real relative motion and reported contact impulse into target-local longitudinal and lateral components. Longitudinal demand continues to drive the established front/rear paths; lateral demand can additionally drive a bounded side path. An oblique contact can therefore load both directions without classifying the whole collision as purely frontal or purely broadside.

The side response:

- stores negative-Z and positive-Z demand separately;
- records the approximate longitudinal contact location;
- moves nearby target structural nodes inward/downward with longitudinal falloff;
- retreats the impacted side of the trailer, tractor and frame collision volumes rather than leaving an invisible undeformed side wall;
- is capped at a generic 0.52 m local side-deformation envelope.

The truck is still one rigid tractor/trailer world body. Side deformation does not imply fifth-wheel rotation or trailer articulation.

## Rigid lorry / box truck

`M20RigidLorry` upgrades the M17 target from a rigid presentation/reference structure to bounded local front, rear and side deformation around its existing Godot chassis.

The model keeps the existing cargo-box, cab, frame and rear-guard collision architecture. Real target-local longitudinal/lateral contact demand drives generic deformation of the structural reference nodes. Corresponding collision faces retreat with that deformation.

Current generic caps are:

- rear: 0.78 m;
- front: 0.66 m;
- side: 0.46 m.

These are CrashVector phenomenological limits, not measured lorry corridors.

## Riderless motorcycle

`M20Motorcycle` retains the existing riderless Godot rigid-body trajectory and four-ray stability support. It adds a bounded local response for the frame/fork reference model after real contact.

Current generic caps are:

- rear: 0.24 m;
- front: 0.34 m;
- side: 0.20 m.

The frame collision volume follows bounded local shortening/lateral retreat, and front/rear wheel collision centres can move with longitudinal frame collapse. No rider, steering controller, tyre-force model, rider coupling or injury inference is introduced.

## Scenario scope

`ScenarioConfig` now permits arbitrary heading deltas for:

- passenger cars;
- heavy articulated trucks;
- rigid lorries / box trucks;
- riderless motorcycles.

Riderless bicycle broadside contact remains blocked. Pedestrians still start stationary. M20 does not silently broaden those scopes.

## Regression

`tests/m20_heavy_other_impacts.gd` is intended to cover:

- broadside preflight for truck, lorry and motorcycle;
- continued blocking of bicycle broadside layouts;
- real Godot non-ground contact in broadside truck, lorry and motorcycle cases;
- bounded target side deformation and physical side-face retreat;
- finite chassis motion without artificial vertical launch;
- contact-linked primary passenger-car response;
- a representative generic oblique heavy-truck case in which lateral and longitudinal target deformation can coexist.

The test is included in consolidated M0-M20 CI. It is deliberately a production-architecture regression rather than an external correlation test.

## Validation status

The M20 implementation has passed its dedicated regression together with the inherited M12-M19 suite, the full M0–M22 gate and native package validation. Its generic modelling boundaries remain unchanged.

No release should strengthen evidence claims for heavy/lorry/motorcycle side impacts on the basis of this implementation alone. M19's stored public protocol geometry does not provide outcome corridors for these target classes.

## Next milestone

M21 should address the architectural limitation explicitly left in M17 and M20: the heavy articulated truck is still one rigid tractor/trailer assembly. The next step is a real tractor/trailer two-body model connected through a constrained fifth-wheel joint, with articulation tested independently of local crash deformation.
