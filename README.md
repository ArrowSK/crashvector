# CrashVector

**Open-source vehicle collision simulation for education and visualisation.**

CrashVector is being built to bridge the gap between simple game collisions and specialist crash-engineering software. The long-term target is a user-friendly 3D application with physically informed vehicle deformation, replay, analysis, scenario comparison, and video export.

> CrashVector is an educational physics visualisation tool. It is not a certified accident-reconstruction, vehicle-homologation, structural-engineering, or occupant-injury prediction system.

## Current milestone: M2 — Generic Compact Hatchback

M2 turns the M1 structural proof into the first complete generic vehicle architecture.

The current demo includes:

- a 28-node, zone-based compact-hatchback structural graph;
- separate rear crush, passenger safety-cell, front transition, and front crush zones;
- a deliberately stiffer passenger cell than the sacrificial front/rear structures;
- mass distribution across seven longitudinal stations;
- extraction of whole-vehicle translation, approximate rigid rotation, and internal deformation motion from the nodal solution;
- a live procedural exterior body shell whose vertices follow the deforming structure;
- four wheel/suspension visual anchors following the live structural nodes;
- a detachable front bumper for severe front-structure damage;
- live structural debug rendering and zone colouring;
- 50 / 90 / 140 km/h barrier-impact demonstrations;
- regression tests for vehicle architecture, global kinematics, barrier deformation, finite state, and determinism.

The M2 hatchback remains a **generic development vehicle, not a calibrated real make/model**. Geometry, stiffness, yield, and fracture parameters are engineering-development values used to establish the architecture. They must not be interpreted as Ford Fiesta, Volkswagen Polo, Renault Clio, or any other production vehicle data.

## Reference scenario

For a 1,150 kg body at 140 km/h:

- speed: 38.8889 m/s;
- kinetic energy: 869.60 kJ;
- momentum magnitude: 44,722.22 kg·m/s.

These M0 reference values remain covered by regression tests.

## Run locally

Install Godot 4.4.1 or newer, clone the repository, open `project.godot`, and run the project.

Controls:

- `1` — 50 km/h
- `2` — 90 km/h
- `3` — 140 km/h
- `D` — toggle structural debug view
- `R` — reset the current speed

Structural colours: green identifies the passenger safety cell, cyan ordinary crush structure, yellow near-yield loading, orange permanent deformation, and red failed members.

Headless tests:

```bash
godot --headless --path . --script res://tests/m0_smoke.gd
godot --headless --path . --script res://tests/m1_structural.gd
godot --headless --path . --script res://tests/m2_hatchback.gd
```

## Architecture direction

CrashVector currently uses a deterministic lumped-mass structural graph as the source of truth for the prototype vehicle.

1. `StructuralNode` stores point mass, position, velocity, and accumulated force.
2. `StructuralBeam` calculates axial spring/damper response, plastic flow, and fracture.
3. `StructuralModel` advances the graph and maintains energy/contact diagnostics.
4. `CompactHatchbackBuilder` defines the generic vehicle geometry, mass distribution, and structural zones.
5. `VehicleKinematics` separates global translation/approximate rotation from internal deformation motion.
6. `DeformableBodyShell` maps the live structural nodes into a visible hatchback-shaped surface.
7. `SimpleWheelRig` supplies the current wheel/suspension visual approximation.
8. `CompactHatchback` composes those systems into the M2 vehicle.

The current wheel system and exterior shell are deliberately lightweight visual/architectural layers. Detailed tyre forces, suspension dynamics, production-quality body panels, glass, doors, and underbody geometry are later work.

## Roadmap

- **M0** — physics skeleton and telemetry — complete
- **M1** — deformable structural test sled — complete
- **M2** — generic compact hatchback architecture — complete
- **M3** — heavy truck and car-vs-truck scenarios
- **M4** — scenario editor and usable desktop UI
- **M5** — analysis, replay, crash pulse, and overlays
- **M6** — synchronized scenario comparison
- **M7** — offline video export and cinematic cameras
- **M8** — calibration against documented reference tests

## Licence

CrashVector source code is licensed under the Mozilla Public License 2.0. Third-party assets and dependencies may have their own licences and must be documented before distribution.
