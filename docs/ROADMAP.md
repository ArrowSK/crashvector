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
- All passenger-car presets remain class-scaled versions of the shared historical architecture, not manufacturer models.
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

## M9 — Desktop distribution, updater and release hardening — complete

M9 is complete. The distribution layer was merged only after the real macOS and Windows package gates passed on the pull request, and the `v0.1.0-beta.1` prerelease was then published from a successful `main` run after package checksums were verified again.

- Canonical Semantic Version in `project.godot`; first public packaged version `0.1.0-beta.1`.
- Normal M9 inheritance over the existing M8/extended editor; no runtime script replacement.
- Built-in Updates UI with manual and optional once-daily checks against official CrashVector GitHub Releases.
- Prerelease-aware version comparison, release-note preview, deterministic platform package selection and SHA-256 verification before install handoff.
- macOS installer handoff opens the verified DMG; Windows handoff launches the verified Setup executable; the running application is never overwritten in place.
- Deterministic native icon containers generated from the existing high-resolution SVG branding master.
- macOS Universal 2 export and drag-to-Applications DMG pipeline, with `arm64`/`x86_64` architecture checks, signature verification and Developer ID/notarization hooks.
- Windows x64 export and Inno Setup pipeline, with executable metadata/icon checks, normal Program Files installation/uninstallation validation and Authenticode hooks.
- Core CI retains the complete M0–M8 regression/runtime suite and adds M9 updater/version tests, complete-editor smoke coverage and a prohibited-monkey-patching audit.
- Platform packaging is independently gated from Core CI.
- Release automation verifies both package checksum sidecars, generates `update-manifest.json`, and refuses to replace an already-published release under the same version.
- `v0.1.0-beta.1` was published with the Universal 2 DMG, Windows x64 Setup EXE, both SHA-256 sidecars and `update-manifest.json`.
- Installation, removal, update, signing limitations, packaging architecture, release process and version policy are documented in `docs/DISTRIBUTION.md`.

## M10 — Visual and UX rebuild — complete

M10 is complete. PR #13 was merged only after the dedicated editor/responsive-layout gate, complete M0–M9 regression suite, architecture audit, macOS Universal 2 package gate and real Windows install/uninstall package validation were green. The `v0.2.0-beta.1` prerelease was then published from the successful `main` merge run after both package checksums were re-verified and the update manifest was generated.

- New responsive desktop shell with compact Scenario and dedicated Compare workspaces.
- Vehicle, Target, Physics and Appearance inspector tabs replace the crowded fixed-position control stack.
- Replay/analysis lives in a collapsible bottom drawer instead of covering the 3D scene; inherited M5 analysis content remains intact inside a bounded scroll viewport at the supported desktop floor.
- Updates, Calibration, Video and Comparison Lab are launched from the new shell while their proven M7–M9 service CanvasLayers stay in their original ownership hierarchy.
- First-run ready scenario is a generic B-class passenger car against a rigid wall at 50 km/h.
- Technical road surface, lane markings, lighting and environment framing improve depth and scale without changing contact geometry.
- Passenger-car presentation now separates body paint, glazing, lamps, trim and class-scaled proportions while remaining driven by the same deformable structural anchors.
- Heavy articulated truck, rigid lorry, motorcycle and bicycle presentation is rebuilt around recognisable generic silhouettes while retaining their existing structural graphs.
- Static targets use clearer material/shape presentation for wall, barrier, pole and tree without changing solver behaviour.
- Pedestrian presentation remains an articulated contact/trajectory proxy and does not imply biomechanical or injury validation.
- M10 has dedicated editor and responsive-layout regression tests across 1280×720, 1440×900, 1920×1080 and 2560×1440, including explicit sidebar/top-bar/replay overlap checks and expanded-analysis drawer coverage.
- Existing M0–M9 regression, no-monkey-patching audit and macOS/Windows packaging gates remained mandatory through merge and release.
- Canonical packaged prerelease `0.2.0-beta.1` is published with the Universal 2 DMG, Windows x64 Setup EXE, both SHA-256 sidecars and `update-manifest.json`.

## M11 — Crush dynamics rebuild — complete

M11 replaced the production collision-response path that produced the post-M10 pivot/inversion failure while preserving the M0–M10 scenario, replay, comparison, calibration, export, updater and presentation layers.

- Production passenger cars retain the seven historical reference stations and add four engine-bay cross-sections, increasing the production structural graph from 28 to 44 nodes.
- Front structure distinguishes bumper/nose, crash boxes, front rails, upper rails, subframe/cross-members and firewall-transition members.
- Progressive post-yield axial force curves and plastic three-node bending/fold constraints replace the earlier front-structure response that could collapse around one or two contact nodes.
- Stronger protected-cell angular constraints and a longitudinal anti-inversion guard prevent the passenger-cell reference frame from numerically turning through 180 degrees in symmetric frontal loading.
- Static wall/barrier/pole/tree collision response is compliant and force-based inside structural substeps rather than an instantaneous stop plus large penetration correction.
- Vehicle-pair contact expands historical two-node seeds to the full impact face, performs multi-point matching and applies equal-and-opposite compliant forces.
- Contact damping follows configured restitution and both contact and structural damping are bounded so one explicit substep cannot remove more local relative motion than is available.
- Solver substeps are supported from 1 through 64. The M8 stored 56.5 km/h historical correlation reference uses 64 substeps for convergence of the refined M11 reduced-order structure; its evidence/regression corridors are unchanged.
- Dedicated M11 regression covers compliant contact, material front shortening, passenger-cell preservation, left/right symmetry, centred-impact yaw, permanent fold angle, multi-point pair contact, momentum conservation and finite 140 km/h wall behaviour.
- M10 editor smoke additionally verifies that the desktop Physics control exposes the same 64-substep ceiling as `ScenarioConfig`.
- Canonical packaged prerelease `0.3.0-beta.1` was published after the M11 gates passed.

## M12 — Hybrid rigid-body physics correction — complete

M12 corrected the more fundamental problem exposed by real use of M11: the deformable point-mass graph was still responsible for whole-vehicle world motion. That allowed visibly implausible rebound and vertical motion even when scalar crush/yaw regression checks passed.

- Godot `RigidBody3D` is authoritative for supported production vehicle mass, inertia, translation, rotation, gravity and collision response.
- Continuous collision detection is enabled for the production vehicle bodies.
- Passenger cars use four force-producing raycast suspension contacts; the heavy articulated truck uses six. Visual wheel meshes no longer masquerade as the road-support model.
- Rigid wall, concrete barrier, pole and tree targets have real `StaticBody3D` collision shapes.
- The M11 44-node passenger-car structure is retained as a local deformable structure anchored to the rigid chassis instead of moving the entire vehicle through custom node integration.
- The passenger-car rigid collision volume ends at the protected cell/subframe. A forward distance probe measures available nose-crush travel and drives both a progressive resistance force on the rigid body and visible/local crush geometry.
- The heavy articulated truck includes a physical rear underride collision face and raycast suspension so the passenger car cannot numerically climb an exposed low chassis rail.
- Dedicated M12 engine-physics regression directly checks 50 km/h rigid-wall rebound/retreat, vertical rise/speed, pitch and material nose crush; stationary road support; and 90 km/h passenger-car versus 18-tonne-truck jump/rebound/crush behaviour.
- The accepted wall regression records approximately 0.541 m front crush, 0.731 m/s maximum reverse speed, 0.136 m retreat, 2 mm vertical rise and 0.32 degrees pitch.
- The accepted 90 km/h car-versus-truck regression records approximately 0.948 m passenger-car crush, 0.981 m/s maximum reverse speed, 2 mm vertical rise and 0.33 degrees pitch.
- M12 does not silently fall back to the old production world-motion solver. Rigid lorry, motorcycle, bicycle and pedestrian simulation are temporarily blocked until ported to the rigid-body path.
- Visual Compare and Comparison Lab are temporarily unavailable for the same reason: their historical synchronous runner remains in the repository for legacy regression but is not presented as production physics.
- The M8 calibration runner remains a separate historical reduced-order correlation/regression path and does not validate the M12 rigid-body/crush coupling.
- Corrective prerelease `0.4.0-beta.1` was published after the M12 real-engine physics and package gates passed.

See `docs/M12_HYBRID_PHYSICS.md` for the detailed architecture and coverage boundaries.

## M13 — Progressive whole-body structural failure — complete

M13 removes the remaining high-energy discontinuity in M12. M12 deliberately protected the passenger cell from the old unstable structural solver, but that also meant an extreme frontal impact could exhaust roughly the first metre of front crush while the firewall, roof and cabin remained effectively indestructible.

- M12 `RigidBody3D` world translation/rotation, gravity, CCD and suspension remain unchanged and authoritative.
- Structural failure now progresses through front crush, firewall/cowl intrusion, floor/rocker and A-pillar/roof deformation, passenger-cell shortening and rear-body buckling as collision demand rises.
- Stage activation uses normal collision energy and measured front-zone exhaustion rather than a simple speed threshold.
- Dynamic rigid targets use relative normal speed and reduced mass for the collision-demand estimate.
- The front crush zone retains a finite physical travel. Residual demand beyond that stage is transferred into later structural zones instead of silently disappearing at a fixed clamp.
- Base cabin stations remain solver-pinned so the historical structural graph still cannot move the whole vehicle. M13 moves those stations locally relative to the rigid chassis only after the appropriate failure stage activates.
- The protected-cell rigid collision face retreats as catastrophic firewall/cabin collapse develops, so the additional shortening produces real obstacle travel rather than being only a painted-mesh animation.
- The production metrics panel exposes peak collision demand, firewall intrusion, cabin collapse, rear buckle and combined longitudinal collapse in addition to front crush.
- A 50 km/h B-class rigid-wall preservation regression records about 105.0 kJ demand, 0.536 m front crush and zero firewall/cabin/rear collapse.
- A 200 km/h B-class rigid-wall severe regression records about 1,739.2 kJ demand, 0.945 m front-zone crush, 0.300 m firewall intrusion, 0.820 m passenger-cell collapse, 0.231 m rear buckle and 1.948 m combined longitudinal collapse.
- The same 200 km/h run remains stable at about 0.015 m/s maximum reverse speed, 0.005 m chassis vertical rise and 0.89 degrees pitch, so whole-body failure does not reintroduce the old launch/jump behaviour.
- The severe M13 condition is enforced both by the dedicated M13 workflow and by the canonical hybrid regression executed inside Core CI.
- Corrective prerelease `0.5.0-beta.1` was published after PR #16, the final M10–M13 validation gates, canonical Core CI, macOS Universal 2 packaging and the Windows install/uninstall lifecycle all passed.

The M13 capacity and collapse values are phenomenological generic CrashVector parameters. They are not manufacturer body-in-white data, finite-element predictions, injury estimates or regulatory crash corridors.

See `docs/M13_PROGRESSIVE_FAILURE.md` for the detailed staged-failure architecture and limitations.

## Beyond M13

The next physics work should port rigid lorry, motorcycle, bicycle/pedestrian contact and the comparison recorder to the rigid-body world architecture before those paths are re-enabled. Additional independent public/licensed crash references should then be added before narrowing or extending any validation claim. Side-impact geometry, richer contact manifolds, articulated truck fifth-wheel dynamics, cyclist coupling, moving pedestrians and additional structural/biomechanical references remain explicit future work rather than implied by M8–M13 completion.
