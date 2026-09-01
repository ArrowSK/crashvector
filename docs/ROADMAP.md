# Roadmap

## M0 — Physics skeleton — complete

- Godot project bootstrap.
- 240 Hz fixed physics tick.
- Configurable rigid test vehicle.
- Rigid road/barrier scene.
- Telemetry recorder.
- Kinetic-energy and momentum diagnostics.
- Headless smoke tests and CI.

## M1 — Structural proof — complete

- Structural node type.
- Beam connectivity and rest length.
- Elastic response and damping.
- Plastic yield and permanent deformation.
- Failure thresholds and broken-beam state.
- Structural debug renderer.
- Energy-balance diagnostics.

## M2 — Generic compact hatchback — complete

- Seven-station / 28-node hatchback structure.
- Separate rear crush, passenger safety-cell, front transition, and front crush zones.
- Non-uniform mass distribution.
- Global translation and approximate rigid-rotation extraction from nodal motion.
- Procedural exterior shell driven by structural node positions.
- Four wheel/suspension visual anchors.
- Detachable front bumper proof.
- Zone-specific diagnostics and M2 regression tests.

M2 remains a generic development vehicle. It is not calibrated to a Ford Fiesta or any other production model.

## M3 — Heavy truck and car-vs-truck

- Generic tractor/trailer structure.
- Configurable gross mass presets.
- Truck collision geometry and underride-relevant structure.
- Moving and stationary truck scenarios.
- Compact-hatchback versus heavy-truck reference cases.
- Validate momentum transfer and energy accounting across large mass ratios.

## M4 — Scenario editor

- Usable desktop scene editor.
- Vehicle and obstacle placement.
- Speed, mass, heading, and surface controls.
- Scenario save/load format.

## M5 — Analysis and replay

- Recorded replay state.
- Timeline and slow motion.
- Delta-v, crash pulse, crush, and intrusion-oriented diagnostics.
- Educational overlays.

## M6 — Comparison

- Synchronized 50 / 90 / 140 km/h comparisons.
- Side-by-side metrics and replay.

## M7 — Video export

- Offline rendering.
- Cinematic cameras.
- 1080p+ presentation output.

## M8 — Calibration and validation ranges

- Documented reference-test sources.
- Calibrated generic vehicle presets.
- Explicit validated/extrapolated ranges and uncertainty labels.
