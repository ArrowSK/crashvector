# Roadmap

## M0 — Physics skeleton — complete

- Godot project bootstrap.
- 240 Hz fixed physics tick.
- Rigid test vehicle and barrier.
- Telemetry, energy and momentum diagnostics.
- Headless CI baseline.

## M1 — Structural proof — complete

- Lumped structural nodes.
- Axial beams with stiffness and damping.
- Plastic yield, permanent deformation and fracture.
- Structural debug renderer.
- Energy-balance diagnostics.

## M2 — Generic compact hatchback — complete

- 28-node passenger-car architecture.
- Rear crush, safety cell, front transition and front crush zones.
- Whole-vehicle translation/rotation extraction.
- Procedural deformable body shell.
- Four wheel anchors and detachable bumper proof.

## M3 — Passenger-car classes and heavy truck — complete

- Generic B-segment small hatchback preset.
- Generic C-segment compact-car preset.
- Generic D-segment midsize-car preset.
- 32-node generic heavy truck with 18 / 32 / 40 t mass presets.
- Rear underride structure and simplified tractor/trailer regions.
- Coupled car/truck node-contact solver.
- Equal-and-opposite impulse exchange and momentum diagnostic.
- 0 / 50 / 80 km/h truck-speed presets.
- Rear-impact reference scenario with 50 / 90 / 140 km/h car speeds.

## M4 — Scenario editor

- Replace keyboard-driven development scene with a usable desktop editor.
- Object palette for passenger cars, heavy truck, wall, barrier, pole and tree.
- Drag/rotate/place objects.
- Inspector for mass, speed, heading, friction and scenario parameters.
- Scenario save/load format.
- Preflight validation before simulation.

## M5 — Analysis and replay

- Recorded replay state.
- Timeline scrubbing and slow motion.
- Crash-pulse and deformation graphs.
- Delta-v and intrusion-oriented educational metrics.
- Velocity, momentum and structural-state overlays.

## M6 — Comparison

- Parameter sweeps such as 50 / 90 / 140 km/h.
- Synchronized comparison playback.
- Side-by-side metrics.

## M7 — Video export

- Offline fixed-frame rendering.
- Camera presets.
- 1080p+ export pipeline.
- Educational overlays and result cards.

## M8 — Calibration

- Documented reference-test datasets.
- Defined validated ranges and extrapolation labels.
- Regression thresholds tied to published reference conditions.
