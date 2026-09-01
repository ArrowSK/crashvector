# Architecture

## M0 baseline

The first milestone separated application concerns from physics metrics:

- `src/analysis/physics_metrics.gd` contains side-effect-free SI-unit calculations.
- `src/vehicles/impact_vehicle.gd` owns the original rigid test vehicle's state and initial conditions.
- `src/simulation/telemetry_recorder.gd` samples rigid-body physics state on fixed ticks for later replay/analysis work.
- `tests/m0_smoke.gd` preserves the reference conversions and scene-load regression.

The M0 rigid-body code remains in the repository as a global-dynamics baseline.

## M1 structural subsystem

M1 adds an independent deterministic structural proof-of-concept:

- `src/structural/structural_node.gd` — lumped point mass and integration state.
- `src/structural/structural_beam.gd` — axial elastic/damping response, plastic rest-length evolution, and fracture state.
- `src/structural/structural_model.gd` — fixed-substep graph advancement, rigid-plane contact, structural metrics, and energy bookkeeping.
- `src/structural/structural_sled_builder.gd` — development-only 20-node compact-hatchback-like frame with front-crush, transition, and cabin profiles.
- `src/structural/structural_sled.gd` — Godot debug visualisation of nodes and beams.
- `src/demo/crash_demo.gd` — M1 barrier-impact demonstration and live diagnostics.
- `tests/m1_structural.gd` — plasticity, fracture, impact, finite-state, and deterministic-state tests.

The structural solver intentionally uses no randomness. Identical inputs, Godot version, and solver settings must produce identical recorded state within documented floating-point tolerance.

## Hybrid vehicle direction

M1 intentionally runs the structural graph as a standalone deformable sled so that its numerical behaviour can be debugged without hiding errors behind rigid-body collision response.

The production direction remains hybrid:

1. Jolt/Godot rigid-body state provides global vehicle translation, rotation, world contacts, wheels, detached parts, and environmental collision.
2. The CrashVector structural graph resolves local crush, yielding, permanent deformation, and member failure.
3. Contact impulses and deformation state are exchanged between the global and structural representations.
4. A visual deformation layer maps structural displacement onto the rendered vehicle shell.
5. Replay records both global and structural state rather than rerunning the crash.

M2 begins this integration while building the first generic compact-hatchback architecture.

## Units

All internal calculations use SI units: metres, seconds, kilograms, newtons, joules, and radians. Conversion to km/h or other display units belongs at the UI/analysis boundary.

## Development rule

The primitive M0 box and the M1 wireframe sled are diagnostic assets. Neither is a production vehicle model and neither should be cosmetically polished in place of solver validation.
