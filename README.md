# CrashVector

**Open-source vehicle collision simulation for education and visualisation.**

CrashVector is being built to bridge the gap between simple game collisions and specialist crash-engineering software. The long-term target is a user-friendly 3D application with physically informed vehicle deformation, replay, analysis, scenario comparison, and video export.

> CrashVector is an educational physics visualisation tool. It is not a certified accident-reconstruction, vehicle-homologation, structural-engineering, or occupant-injury prediction system.

## Current milestone: M0 — Physics Skeleton

The repository now contains the first runnable Godot prototype:

- Godot 4.4 project configured for a 240 Hz physics tick;
- configurable rigid compact-hatchback test sled;
- rigid barrier and road surface;
- continuous collision detection;
- live mass, speed, kinetic-energy, and momentum telemetry;
- deterministic telemetry recorder;
- headless smoke tests for unit conversion and 140 km/h reference physics;
- GitHub Actions smoke-test workflow.

This milestone deliberately uses an ugly rigid test sled. Structural deformation begins in M1 only after the baseline motion and diagnostics are reliable.

## Reference scenario

For a 1,150 kg vehicle at 140 km/h:

- speed: 38.8889 m/s;
- kinetic energy: 869.60 kJ;
- momentum magnitude: 44,722.22 kg·m/s.

These values are asserted by the M0 smoke test and form an early regression reference.

## Run locally

Install Godot 4.4.1 or newer, clone the repository, open `project.godot`, and run the project.

The current scene launches a 1,150 kg test sled toward a rigid barrier at 50 km/h. Press `R` to reset the scenario.

For a headless smoke test:

```bash
godot --headless --path . --script res://tests/m0_smoke.gd
```

## Architecture direction

CrashVector uses Godot for the application, rendering, and world simulation. M0 establishes rigid-body motion and diagnostics. M1 will introduce the custom CrashVector structural solver: nodes, beams, elastic response, plastic deformation, and failure.

The eventual vehicle model remains a hybrid architecture:

1. global rigid-body dynamics;
2. lightweight internal node/beam structural graph;
3. deformation mapping to the visible vehicle mesh;
4. replay and analysis derived from recorded simulation state.

## Roadmap

- **M0** — physics skeleton and telemetry
- **M1** — deformable structural test sled
- **M2** — complete generic compact hatchback
- **M3** — heavy truck and car-vs-truck scenarios
- **M4** — scenario editor and usable desktop UI
- **M5** — analysis, replay, crash pulse, and overlays
- **M6** — synchronized scenario comparison
- **M7** — offline video export and cinematic cameras
- **M8** — calibration against documented reference tests

## Licence

CrashVector is intended to be released under the Mozilla Public License 2.0. Third-party assets and dependencies may have their own licences and must be documented before distribution.
