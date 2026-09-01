# CrashVector

**Open-source vehicle collision simulation for education and visualisation.**

CrashVector is being built to bridge the gap between simple game collisions and specialist crash-engineering software. The long-term target is a user-friendly 3D application with physically informed vehicle deformation, replay, analysis, scenario comparison, and video export.

> CrashVector is an educational physics visualisation tool. It is not a certified accident-reconstruction, vehicle-homologation, structural-engineering, or occupant-injury prediction system.

## Current milestone: M3 — Passenger Car vs Heavy Truck

M3 turns the M2 compact-hatchback proof into a small generic vehicle family and adds the first coupled car/truck collision scenario.

### Generic passenger-car classes

The application now ships three development presets:

- **B-Segment Small Hatchback** — 1,150 kg default mass;
- **C-Segment Compact Car** — 1,375 kg default mass;
- **D-Segment Midsize Car** — 1,575 kg default mass.

These are representative vehicle classes, not replicas of production vehicles. Their geometry and structural parameters are deliberately generic and must not be interpreted as manufacturer-specific crash predictions.

All three presets retain the M2 28-node zone architecture, with scaled dimensions, mass and structural stiffness while preserving separate rear-crush, safety-cell, transition and front-crush regions.

### Heavy truck

M3 adds a generic heavy truck combination with:

- 32 structural nodes;
- configurable 18 t / 32 t / 40 t total mass presets;
- trailer and tractor structural regions;
- a distinct rear underride-guard structure;
- a simplified fifth-wheel connection region;
- six visual wheel anchors;
- configurable 0 / 50 / 80 km/h initial truck speed.

The truck is intentionally generic. The current tractor/trailer connection is a structural approximation rather than a full articulated multibody joint.

### Coupled collision physics

`VehiclePairSimulation` advances both deformable structures on the same substep clock. `VehiclePairContact` exchanges equal-and-opposite contact impulses between paired structural contact nodes, preserving linear momentum within numerical tolerance while recording contact dissipation and penetration diagnostics.

The first reference scenario is a passenger car striking the rear underride structure of the heavy truck.

## Run locally

Install Godot 4.4.1 or newer, clone the repository, open `project.godot`, and run the project.

Controls:

- `1` — car at 50 km/h
- `2` — car at 90 km/h
- `3` — car at 140 km/h
- `V` — cycle B / C / D passenger-car classes
- `M` — cycle truck mass: 18 / 32 / 40 t
- `K` — cycle truck speed: 0 / 50 / 80 km/h
- `D` — toggle structural debug views
- `R` — reset the current scenario

The diagnostics panel shows vehicle masses and speeds, closing speed, car kinetic energy, front-crush and safety-cell deformation, truck rear-guard deformation, pair-contact count, peak node penetration, momentum-balance error and energy-balance error.

## Development status

- **M0** — physics skeleton and telemetry — complete
- **M1** — deformable structural test sled — complete
- **M2** — generic compact hatchback architecture — complete
- **M3** — generic passenger-car classes and heavy-truck collision — complete
- **M4** — scenario editor and usable desktop UI
- **M5** — analysis, replay, crash pulse, and overlays
- **M6** — synchronized scenario comparison
- **M7** — offline video export and cinematic cameras
- **M8** — calibration against documented reference tests

## Verification

CI imports the complete Godot project and runs the M0, M1, M2 and M3 headless regression suites. M3 adds checks for the three generic passenger-car presets, heavy-truck architecture, coupled-contact momentum conservation, rear-impact deformation and finite numerical state.

## Licence

CrashVector source code is licensed under the Mozilla Public License 2.0. Third-party assets and dependencies may have their own licences and must be documented before distribution.
