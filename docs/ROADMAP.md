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

- Generic passenger-car presets cover A, B, C, D, J and M classes.
- All passenger-car presets remain class-scaled versions of the shared 28-node architecture, not manufacturer models.
- 32-node generic heavy articulated truck with 18 / 32 / 40 t development presets.
- 24-node generic rigid lorry / box-truck target.
- 16-node generic riderless motorcycle target.
- Rear underride / rear-guard structural approximations where applicable.
- Coupled dynamic-pair node-contact solver.

## M4 — Scenario editor — complete

- Desktop editor replaces keyboard-driven configuration.
- Primary passenger car plus target palette.
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
- Primary and target delta-v metrics where meaningful.
- Peak simulated longitudinal deceleration.
- Safety-cell deformation proxy.
- Kinetic-energy and broken-structural-member summaries.
- 3D velocity and momentum vectors.
- Event markers for observed contact/loading/failure/separation/rest events.

## M6 — Visual comparison — complete

- Deterministic user-defined two- or three-speed sweeps from 0–300 km/h.
- Convenience defaults remain 50 / 90 / 140 km/h.
- Explicit support for close comparisons such as 130 vs 140 km/h.
- B / C / D core class sweep retained as a convenient three-lane class comparison.
- Impact-synchronized or scenario-time playback.
- Shared comparison timeline and slow-motion replay speeds.
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

## M8 — Calibration, broader scenario library, and validation scope — complete

- Machine-readable NHTSA DOT HS 812 237 / laboratory test 7078 reference.
- Full-frontal rigid-wall reference condition at 1,661 kg and 56.5 km/h.
- Published approximately 120 ms crash-pulse observation stored as source-correlation evidence.
- Delta-v, safety-cell proxy and energy-balance thresholds explicitly separated as CrashVector numerical regression guardrails rather than NHTSA measurements.
- Rebound-aware delta-v sanity range documented instead of forcing the solver into an unsupported external corridor.
- Evidence labels: Reference-correlated, Near reference, Class-scaled and Extrapolated.
- High-speed, dynamic-pair, heavy-vehicle, motorcycle and road-user modes remain explicitly extrapolated.
- In-app calibration check and video-export evidence metadata.
- Easy target defaults so users can select an object and simulate without mandatory mass entry.
- Riderless bicycle presets: city bicycle, road bicycle and e-bike, with editable mass.
- Pedestrian body presets: default adult, child-sized and tall adult, with editable mass and articulated contact/trajectory proxy behaviour.
- Comparison Lab supports up to three vehicle classes, target types, or road-user presets crossed with up to three arbitrary primary-car speeds, for up to nine independently simulated comparison lanes in one run.
- Exact close-speed comparison remains supported, including 130 vs 140 km/h.
- Road-user replay, analysis presentation and cinematic rendering retain explicit contact/trajectory-only disclaimers.
- Full MPL-2.0 license text is included in the repository.
- CI regression covers the complete M0–M8 suite, road-user construction/trajectory behaviour, scenario serialization, editor runtime, comparison matrices, calibration scope and the 130/140 km/h `v²` energy relationship.

## M9 — Desktop productization and update lifecycle — complete

- First packaged application version: `0.1.0-beta.1`.
- High-resolution application branding from the supplied CrashVector artwork; native Windows multi-size ICO generated from the high-resolution project/macOS source icon.
- macOS Universal 2 DMG package produced on a native macOS GitHub runner.
- macOS app is ad-hoc signed and verified before DMG creation; future Developer-ID signing/notarization can replace this without changing the package contract.
- Windows x64 Godot export packaged with Inno Setup.
- Windows package registers with the normal Apps & Features uninstall system and creates Start-menu shortcuts.
- Built-in updater checks official GitHub Releases with semantic-version ordering.
- Prerelease builds may follow newer prereleases; stable builds do not silently opt into beta releases.
- Update download is user-controlled and verified against a matching SHA-256 sidecar before installer handoff.
- macOS update handoff opens the verified DMG; Windows handoff launches the verified Setup executable; CrashVector then exits.
- CrashVector does not rewrite its installed executable in place.
- User update preferences persist in the normal `user://` application-data directory.
- Runtime monkey patching is explicitly prohibited: production code uses inheritance, composition, services and signals; CI rejects runtime `set_script(...)` or Resource path takeover.
- M9 update/version tests and editor runtime smoke test are part of the main CI gate.
- Separate desktop-package CI builds both platforms on pull requests before release publication.
- A `main` build publishes the versioned GitHub prerelease only after both platform packages succeed and checksums verify.

## Beyond M9

Further accuracy work should add additional independent public/licensed crash references before narrowing or extending validation claims. Side-impact geometry, richer contact manifolds, suspension/tyre behaviour, articulated truck fifth-wheel dynamics, cyclist coupling, moving pedestrians and additional structural/biomechanical references remain future simulation milestones.

Distribution hardening can proceed independently: Apple Developer-ID signing/notarization and Windows Authenticode signing can be added when credentials are available without changing the updater or user-facing install flow.
