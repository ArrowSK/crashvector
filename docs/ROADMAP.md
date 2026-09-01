# Roadmap

## M0 — Physics skeleton — complete

- Godot project bootstrap.
- 240 Hz fixed physics tick.
- Rigid test vehicle and barrier.
- Telemetry, energy, and momentum diagnostics.
- Headless CI baseline.

## M1 — Structural proof — complete

- Lumped structural nodes.
- Axial beams with stiffness and damping.
- Plastic yield, permanent deformation, and fracture.
- Structural debug renderer.
- Energy-balance diagnostics.

## M2 — Generic compact hatchback — complete

- 28-node passenger-car architecture.
- Rear crush, safety cell, front transition, and front crush zones.
- Whole-vehicle translation/rotation extraction.
- Procedural deformable body shell.
- Four wheel anchors and detachable bumper proof.

## M3 — Passenger-car classes and heavy truck — complete

- Generic B-segment small hatchback preset.
- Generic C-segment compact-car preset.
- Generic D-segment midsize-car preset.
- 32-node generic heavy truck with 18 / 32 / 40 t development presets.
- Rear underride structure and simplified tractor/trailer regions.
- Coupled dynamic-pair node-contact solver.
- Rear-impact reference scenario with 50 / 90 / 140 km/h car speeds.

## M4 — Scenario editor — complete

- Desktop editor replaces keyboard-driven scenario configuration.
- Primary passenger car plus target palette.
- Target palette includes passenger car, heavy truck, rigid wall, concrete barrier, pole, and tree.
- **Car-vs-car rear-end and near head-on scenarios.**
- Independent B / C / D passenger-car classes, masses, speeds, positions, and headings for both cars.
- Heavy-truck mass, speed, position, and heading inspector.
- Direct 3D move and rotate interaction.
- Contact friction, restitution, duration, solver-substep, and structure-debug controls.
- Static-target structural contact layer.
- Preflight validation, including rejection of unsupported broadside car-vs-car layouts.
- Human-readable `.crashvector.json` save/load.
- Pause, reset, and camera framing controls.

## M5 — Analysis and replay

- Recorded replay state independent of live physics.
- Timeline scrubbing and slow motion.
- Crash-pulse and deformation graphs.
- Delta-v and intrusion-oriented educational metrics.
- Velocity, momentum, energy, and structural-state overlays.
- Event markers for first contact, peak loading, structural failure, separation, and rest.

## M6 — Comparison

- Parameter sweeps such as 50 / 90 / 140 km/h.
- Synchronized comparison playback.
- Side-by-side metrics.
- Same-scene vehicle-class comparisons.

## M7 — Video export

- Offline fixed-frame rendering.
- Camera presets.
- 1080p+ export pipeline.
- Educational overlays and result cards.

## M8 — Calibration

- Documented reference-test datasets.
- Defined validated ranges and extrapolation labels.
- Regression thresholds tied to published reference conditions.
