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

## M3 — Generic vehicle classes and heavy vehicles — complete

- Generic passenger-car presets now cover A, B, C, D, J and M classes.
- All passenger-car presets remain class-scaled versions of the shared 28-node architecture, not manufacturer models.
- 32-node generic heavy articulated truck with 18 / 32 / 40 t development presets.
- 24-node generic rigid lorry / box-truck target.
- 16-node generic riderless motorcycle target.
- Rear underride / rear-guard structural approximations where applicable.
- Coupled dynamic-pair node-contact solver.

## M4 — Scenario editor — complete

- Desktop editor replaces keyboard-driven configuration.
- Primary passenger car plus target palette.
- Target palette includes passenger car, heavy articulated truck, rigid lorry, riderless motorcycle, rigid wall, concrete barrier, pole and tree.
- Car-vs-car rear-end and near head-on scenarios.
- Editable masses, speeds, positions and headings for dynamic vehicles.
- Direct 3D move and rotate interaction.
- Contact friction, restitution, duration, solver-substep and structure-debug controls.
- Static-target structural contact layer, including selectable full-frontal rigid-wall crashes.
- Preflight validation, including rejection of unsupported broadside vehicle layouts.
- Human-readable `.crashvector.json` save/load.

## M5 — Analysis and replay — complete

- 120 Hz recorded structural replay state independent of subsequent live physics.
- Timeline scrubbing and replay at 0.05x / 0.10x / 0.25x / 0.50x / 1.00x.
- Crash-pulse and front-crush deformation graphs.
- Primary and target delta-v metrics.
- Peak simulated longitudinal deceleration.
- Safety-cell deformation proxy.
- Kinetic-energy and broken-structural-member summaries.
- 3D velocity and momentum vectors.
- Event markers for observed contact/loading/failure/separation/rest events.

## M6 — Visual comparison — complete

- Deterministic user-defined two- or three-speed sweeps from 0–300 km/h.
- Convenience defaults remain 50 / 90 / 140 km/h.
- Explicit support for close comparisons such as 130 vs 140 km/h.
- B / C / D core class sweep retained as the default three-lane class comparison.
- Impact-synchronized or scenario-time playback.
- Shared comparison timeline and 0.05x / 0.10x / 0.25x / 0.50x / 1.00x playback.
- Per-lane live speed and crush labels.
- Side-by-side delta-v, peak deceleration, crush, safety-cell deformation and kinetic-energy results.
- Visual kinetic-energy/deformation bars and presentation-only car paint.
- Optional structural X-ray view.

## M7 — Cinematic video export — complete

- Offline fixed-frame rendering from recorded replay state rather than live physics.
- 1080p, 1440p and 4K output profiles at 30 or 60 fps.
- Auto cinematic, wide, tracking, impact close-up and aftermath-orbit cameras.
- Impact-centred slow-motion retiming without changing the simulation.
- Opening title card, educational overlays, watermark and result card.
- External FFmpeg H.264/MP4 encoding; no codec binary bundled.
- Optional retained source frames and machine-readable metadata sidecar.
- Cancellation and progress reporting.

## M8 — Calibration and validation scope — complete

- Machine-readable NHTSA DOT HS 812 237 / laboratory test 7078 reference.
- Full-frontal rigid-wall reference condition at 1,661 kg and 56.5 km/h.
- Published approximately 120 ms crash-pulse observation stored as source-correlation evidence.
- Delta-v, safety-cell proxy and energy-balance thresholds explicitly separated as CrashVector numerical regression guardrails rather than NHTSA measurements.
- Rebound-aware delta-v sanity range documented instead of forcing the solver into an unsupported external corridor.
- Evidence labels: Reference-correlated, Near reference, Class-scaled and Extrapolated.
- High-speed, lorry, motorcycle and non-reference collision modes remain explicitly extrapolated.
- In-app calibration check and video-export evidence metadata.
- CI regression for calibration metadata, source/project separation, expanded vehicle construction and a 130 vs 140 km/h rigid-wall comparison with the expected kinetic-energy `v²` relationship.

## Beyond M8

Further accuracy work should add additional independent public/licensed reference tests before narrowing or extending any validation claim. Side-impact geometry, richer contact manifolds, suspension/tyre behaviour and additional structural references should be developed as new explicit milestones rather than being implied by M8 completion.
