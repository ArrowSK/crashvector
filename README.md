# CrashVector

**Open-source vehicle collision simulation for education and visualisation.**

CrashVector is being built to bridge the gap between simple game collisions and specialist crash-engineering software. The long-term target is a user-friendly 3D application with physically informed vehicle deformation, replay, analysis, scenario comparison, and video export.

> CrashVector is an educational physics visualisation tool. It is not a certified accident-reconstruction, vehicle-homologation, structural-engineering, or occupant-injury prediction system.

## Current milestone: M4 — Scenario Editor

M4 replaces the keyboard-driven development demo with the first usable desktop scenario editor.

The editor now provides:

- a primary passenger-car object;
- impact targets for **another passenger car**, heavy truck, rigid wall, concrete barrier, pole, or tree;
- generic B-, C-, and D-segment passenger-car classes with editable mass and speed;
- editable truck mass and speed;
- position and heading controls in the inspector;
- direct left-drag placement and right-drag rotation in the 3D view;
- contact-friction, restitution, solver-substep, duration, and structural-debug controls;
- preflight validation before simulation;
- New / Open / Save / Simulate / Pause / Reset / Frame actions;
- human-readable `.crashvector.json` scenario files.

### Car vs car

Car-vs-car is a first-class M4 scenario, not a special case hidden behind the truck model. Either vehicle can use any of the three generic passenger-car classes and have its own mass, speed, position, and heading.

M4 supports:

- rear-end car-vs-car impacts when both vehicles have similar headings;
- near head-on car-vs-car impacts by rotating the target car approximately 180 degrees;
- independent B / C / D class combinations.

Broadside and strongly oblique car-vs-car contact is intentionally rejected by preflight for now because the current paired-node contact model does not yet provide a trustworthy side-impact contact surface. That belongs in a later contact-geometry upgrade rather than being faked.

### Generic passenger-car classes

The application currently ships:

- **B-Segment Small Hatchback** — 1,150 kg default mass;
- **C-Segment Compact Car** — 1,375 kg default mass;
- **D-Segment Midsize Car** — 1,575 kg default mass.

These correspond to general size classes only. CrashVector does not use production model names, manufacturer badges, proprietary CAD, or OEM-specific crash-performance claims.

### Heavy truck

The M3 generic heavy-truck model remains available with its 32-node tractor/trailer structural approximation and editable total mass. The M4 editor exposes truck position, heading, mass, and speed directly rather than through development keyboard shortcuts.

### Static targets

M4 also adds editor-selectable rigid wall, concrete barrier, pole, and tree targets. These use a deterministic static-contact layer that resolves vehicle-node contact, friction, restitution, penetration correction, and contact-energy diagnostics.

## Run locally

Install Godot 4.4.1 or newer, clone the repository, open `project.godot`, and run the project.

Typical workflow:

1. Select the primary passenger car and choose its class, mass, speed, position, and heading.
2. Choose an impact target from the left panel. Selecting **Passenger Car** creates a true car-vs-car scenario.
3. Configure the target in the right inspector or move/rotate it directly in the 3D view.
4. Press **Simulate**. Preflight blocks layouts the current contact model does not support safely.
5. Use **Reset** to return to the editable starting state.
6. Use **Save** to write a `.crashvector.json` scenario and **Open** to load it again.

## Development status

- **M0** — physics skeleton and telemetry — complete
- **M1** — deformable structural test sled — complete
- **M2** — generic compact hatchback architecture — complete
- **M3** — generic passenger-car classes and heavy-truck collision — complete
- **M4** — scenario editor, car-vs-car, static targets, and save/load — complete
- **M5** — analysis, replay, crash pulse, and overlays
- **M6** — synchronized scenario comparison
- **M7** — offline video export and cinematic cameras
- **M8** — calibration against documented reference tests

## Verification

CI imports the complete Godot project and runs the M0, M1, M2, M3, and M4 headless suites. M4 adds regression coverage for scenario JSON round trips, filesystem save/load, preflight rules, heading transforms, static-wall contact, rear-end car-vs-car impacts, head-on car-vs-car impacts, deformation, momentum conservation, and finite numerical state.

## Licence

CrashVector source code is licensed under the Mozilla Public License 2.0. Third-party assets and dependencies may have their own licences and must be documented before distribution.
