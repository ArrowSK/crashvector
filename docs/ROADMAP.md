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
- Contact-friction, restitution, solver-substep, duration, and structural-debug controls.
- Static-target structural contact layer.
- Preflight validation, including rejection of unsupported broadside car-vs-car layouts.
- Human-readable `.crashvector.json` save/load.
- Pause, reset, and camera framing controls.

## M5 — Analysis and replay — complete

- 120 Hz recorded structural replay state independent of subsequent live physics.
- Timeline scrubbing and replay at 0.05x / 0.10x / 0.25x / 0.50x / 1.00x.
- Crash-pulse and front-crush deformation graphs.
- Primary and target delta-v metrics.
- Peak simulated longitudinal deceleration.
- Safety-cell deformation proxy for intrusion-oriented education.
- Kinetic-energy and broken-structural-member summaries.
- 3D velocity and momentum vectors plus the existing structural-state overlay.
- Event markers for first contact, peak loading, structural failure, separation, and rest when the event is actually observed in the recorded window.
- Replay regression tests verify snapshot restoration is independent of final live-physics state.

## M6 — Visual comparison — complete

- Offline deterministic 50 / 90 / 140 km/h parameter sweep.
- Offline B / C / D passenger-car class sweep.
- Three simultaneous 3D comparison lanes.
- Impact-synchronized playback by default, with scenario-time synchronization available.
- Shared comparison timeline and 0.05x / 0.10x / 0.25x / 0.50x / 1.00x playback.
- Per-lane live speed and crush labels.
- Side-by-side delta-v, peak deceleration, crush, safety-cell deformation, and kinetic-energy results.
- Visual kinetic-energy and deformation bars so the lesson works without reading a technical table first.
- Selectable presentation-only car paint for each comparison lane, with eight generic colors and visible swatches.
- Neutral silver target car in car-vs-car comparisons to keep the compared primary vehicles visually distinct.
- Optional structural X-ray view.
- Regression coverage for sweeps, replay independence, requested duration, kinetic-energy v² behaviour, paint palette, and runtime editor construction.

## M7 — Cinematic video export — complete

- Offline fixed-frame rendering from recorded replay state rather than live physics.
- 1080p, 1440p, and 4K output profiles at 30 or 60 fps.
- Auto cinematic, wide, tracking, impact close-up, and aftermath-orbit camera presets.
- Impact-centred 0.25x slow-motion retiming without changing the underlying simulation.
- Opening title card, live educational speed/crush overlay, watermark, and closing result card.
- Independent primary and target passenger-car paint selection for exported video.
- High-quality JPEG frame sequence rendered through a dedicated offscreen viewport.
- External FFmpeg H.264/MP4 encoding with fast-start output; no codec binary is bundled.
- Optional preservation of source frames and a machine-readable video metadata sidecar.
- Cancellation and progress reporting in the desktop editor.
- Regression coverage for deterministic retiming, fixed frame counts, camera poses, encoder arguments, export profiles, and runtime editor construction.

## M8 — Calibration and validation scope — complete

- Machine-readable NHTSA full-frontal rigid-barrier reference dataset from DOT HS 812 237 / laboratory test 7078.
- Published test conditions and observations kept separate from CrashVector-defined regression corridors.
- Deterministic 1,661 kg / 56.5 km/h generic D-segment reference run.
- Regression gates for crash-pulse duration, longitudinal delta-v, safety-cell structural proxy, and numerical energy balance.
- Scenario evidence labels: Reference-correlated, Near reference, Class-scaled, and Extrapolated.
- 90 / 140 km/h, car-vs-car, car-vs-truck, and other out-of-envelope scenarios remain explicitly extrapolated instead of inheriting a validation claim.
- In-app calibration panel can run the stored reference check and display metric/corridor results.
- Calibration documentation defines evidence boundaries and rules for adding future reference datasets.
- CI fails if the directly correlated reference leaves its stored engineering corridors.
