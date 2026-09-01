# Architecture

## M0

The first milestone intentionally separates application concerns from physics metrics:

- `src/analysis/physics_metrics.gd` contains side-effect-free SI-unit calculations.
- `src/vehicles/impact_vehicle.gd` owns the test vehicle's rigid-body state and initial conditions.
- `src/simulation/telemetry_recorder.gd` samples physics state on fixed ticks for later replay/analysis work.
- `src/demo/crash_demo.gd` assembles the temporary road, barrier, vehicle, camera, lighting, and diagnostic UI.
- `tests/m0_smoke.gd` provides headless regression checks.

The demo geometry is intentionally primitive and must not become the basis for production vehicle assets.

## Planned structural solver

M1 adds a lightweight node/beam graph alongside the rigid-body representation. The rigid body remains responsible for global translation and rotation while the structural solver represents local crush, plastic deformation, and failure.

The solver must remain deterministic for identical scenario inputs, engine version, and solver configuration within documented numerical tolerances.

## Units

All internal calculations use SI units: metres, seconds, kilograms, newtons, joules, and radians. Conversion to km/h or other display units belongs at the UI/analysis boundary.
