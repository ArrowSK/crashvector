# CrashVector

**Open-source vehicle collision simulation for education and visualisation.**

CrashVector is being built to bridge the gap between simple game collisions and specialist crash-engineering software. The long-term target is a user-friendly 3D application with physically informed vehicle deformation, replay, analysis, scenario comparison, and video export.

> CrashVector is an educational physics visualisation tool. It is not a certified accident-reconstruction, vehicle-homologation, structural-engineering, or occupant-injury prediction system.

## Current milestone: M1 — Structural Proof

The repository now contains a deterministic lightweight node/beam structural solver on top of the M0 physics and telemetry baseline.

M1 adds:

- point-mass structural nodes;
- axial beams with stiffness and damping;
- elastic response;
- plastic yield and permanent rest-length change;
- configurable failure strain and broken-beam state;
- structural energy bookkeeping for elastic storage, plastic work, damping, fracture, and barrier-contact loss;
- a 20-node compact-hatchback test sled with differentiated cabin, transition, and front-crush stiffness profiles;
- live structural debug rendering;
- 50 / 90 / 140 km/h selectable barrier-impact demonstrations;
- deterministic headless structural regression tests.

The M1 object is still a **structural test sled, not a calibrated vehicle model**. Its geometry and stiffness values are engineering-development parameters intended to prove the solver architecture. Vehicle-specific calibration begins much later.

## Reference scenario

For a 1,150 kg body at 140 km/h:

- speed: 38.8889 m/s;
- kinetic energy: 869.60 kJ;
- momentum magnitude: 44,722.22 kg·m/s.

These M0 reference values remain covered by regression tests.

## Run locally

Install Godot 4.4.1 or newer, clone the repository, open `project.godot`, and run the project.

The M1 scene launches the structural test sled at 50 km/h toward a rigid barrier.

Controls:

- `1` — 50 km/h
- `2` — 90 km/h
- `3` — 140 km/h
- `R` — reset the current speed

Beam colours in the debug view indicate structural state: cyan for ordinary elastic loading, yellow near yield, orange after permanent deformation, and red after failure.

Headless tests:

```bash
godot --headless --path . --script res://tests/m0_smoke.gd
godot --headless --path . --script res://tests/m1_structural.gd
```

## Architecture direction

CrashVector uses Godot for the application, rendering, and world simulation. The structural subsystem is intentionally separate and deterministic:

1. `StructuralNode` stores point mass, position, velocity, and accumulated force;
2. `StructuralBeam` calculates axial spring/damper response, plastic flow, and fracture;
3. `StructuralModel` advances the graph in fixed substeps and maintains energy/contact diagnostics;
4. `StructuralSledBuilder` creates the current development frame;
5. `StructuralSled` renders the graph for debugging.

M2 will turn this proof into a generic compact-hatchback architecture, add an explicit passenger safety cell and crush-zone layout, and begin coupling structural deformation to the visible vehicle body.

## Roadmap

- **M0** — physics skeleton and telemetry — complete
- **M1** — deformable structural test sled — complete
- **M2** — complete generic compact hatchback
- **M3** — heavy truck and car-vs-truck scenarios
- **M4** — scenario editor and usable desktop UI
- **M5** — analysis, replay, crash pulse, and overlays
- **M6** — synchronized scenario comparison
- **M7** — offline video export and cinematic cameras
- **M8** — calibration against documented reference tests

## Licence

CrashVector source code is licensed under the Mozilla Public License 2.0. Third-party assets and dependencies may have their own licences and must be documented before distribution.
