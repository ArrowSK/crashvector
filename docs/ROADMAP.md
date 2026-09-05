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

## M14 — Vulnerable road users and yielding narrow obstacles — complete

M14 closes the two remaining production gaps exposed after M13 without changing the stable passenger-car M12/M13 rigid-body and staged-failure architecture.

- Pedestrian and riderless-bicycle targets now run through `RoadUserRigidProxy3D`, a real Godot `RigidBody3D` world-motion path with gravity, CCD, friction, collision geometry and post-impact translation/rotation.
- Their existing `Pedestrian` and `Bicycle` structural objects remain presentation/contact proxies inside the rigid body; they are not biomechanical, injury or rider models.
- The passenger-car front probe transfers a reduced-mass contact impulse to a vulnerable target while the existing phenomenological nose-crush resistance remains on the car side.
- Generic pole and tree targets can now yield into permanent motion when collision demand exceeds their generic phenomenological capacity; wall and concrete barrier remain rigid.
- The Calibration / evidence-scope modal keeps its existing content and callbacks but its historical CanvasLayer is raised above the M10 desktop UI so labels such as **Extrapolated** open a usable modal whose **Close** control receives input.
- A production regression opens the evidence-scope control, verifies the normal UI remains present and the modal is on top, closes it, and verifies the normal UI remains intact.
- The stale pre-M14 road-user editor smoke expectation was updated to the `RoadUserRigidProxy3D` production route without changing application physics.
- Dedicated M14 regression covers pedestrian/bicycle post-contact trajectory, pole/tree permanent yielding, wall/barrier non-yielding behaviour, production routing and bounded passenger-car rebound/vertical motion.
- M10, M11, M12, M13, M14, canonical Core CI, macOS Universal 2 packaging and the Windows x64 install/uninstall lifecycle were green for the final M14 head.
- Corrective prerelease `0.6.0-beta.1` was published from merge commit `00667ccf78b582772b42adbad9b2718ce431cb68` with the Universal 2 DMG, Windows x64 Setup EXE, both SHA-256 sidecars and `update-manifest.json`.

Road-user output remains explicitly contact/trajectory visualisation only. M14 does not add injury, survivability, HIC, AIS, tissue-loading or rider modelling, and its pole/tree capacities are generic educational parameters rather than claims about a specific roadside object.

See `docs/M14_ROAD_USERS_OBSTACLES.md` for the detailed architecture, scope and release gates.

## M15 — Articulated pedestrian and bicycle dynamics — complete

M15 upgrades the M14 vulnerable-road-user target implementation without replacing the stable passenger-car M12–M14 production architecture.

- `RoadUserRigidProxy3D` remains the compatibility root/API used by the production editor, contact routing and replay layer.
- Pedestrian targets use an 11-body articulated rigid chain connected by 10 bounded `Generic6DOFJoint3D` constraints.
- Riderless bicycles use a rigid frame plus two independently simulated wheel bodies joined at the hubs.
- The passenger-car front probe recognizes contact with any owned articulated road-user body.
- Vulnerable-target contact impulse is distributed through the articulated target instead of relying on the old fixed tumble-torque lever.
- Replay captures/restores articulated part transforms and velocities.
- An earlier `ConeTwistJoint3D` pedestrian topology was rejected after high-speed Godot 4.4.1 testing exposed excessive numerical energy and near-180-degree direct-joint folding.
- Dedicated M15 regression adds topology, trajectory, direct-joint-motion, passenger-car rebound/vertical, bicycle-wheel and 22 m/s target-COM sanity gates while preserving M14 compatibility tests.
- Final 60 km/h pedestrian regression: 11 bodies / 10 joints, 2.51 m/s final COM speed, 13.97 m maximum COM travel, 105.2° maximum direct-joint motion, 0.001 m maximum passenger-car vertical rise and no measured reverse launch.
- Final 60 km/h riderless-city-bicycle regression: 3 bodies / 2 joints, 9.21 m/s final COM speed, 19.22 m maximum COM travel, 34.85 rad/s maximum wheel angular motion and 0.001 m maximum passenger-car vertical rise.

The joint limits and regression values are numerical stability/trajectory guardrails only, not biomechanical or injury-validation data.

See `docs/M15_ARTICULATED_ROAD_USERS.md`.

## M16 — UX reset and class-specific vehicle visuals — complete

M16 replaces the accumulated M10 desktop information architecture with a task-focused shell while preserving the finalized M15 production physics underneath it.

- Normal setup is organized around Scenario builder → 3D viewport → contextual Properties → Playback dock.
- Solver/contact controls move behind **Advanced setup** instead of competing with the normal crash-building flow.
- File, update, calibration/evidence, replay, analysis and cinematic export functions remain available through the new hierarchy.
- Stable M10 shell-region identifiers remain in place so historical responsive-layout tests continue to guard non-overlap and viewport minimums.
- `M16VehicleVisualRefined` and `VehicleVisualProfileCatalog` replace the visibly scaled-hatchback passenger-car presentation with generated class-specific A/B/C/D/J/M archetypes.
- SUV, MPV and midsize profiles have materially different stance, roof/windscreen proportions, greenhouse extent, wheel packages and class details rather than only different scale.
- The M16 visual reads the existing deforming structural model but does not change rigid collision geometry, mass, stiffness, structural beams, crush behaviour, contact probes or solver settings.
- The legacy shell/wheels are hidden only while the replacement M16 presentation skin is active.
- The M16 production regression verifies that pedestrian selection through the actual UI still instantiates the finalized `RoadUserArticulatedProxy3D` topology and isolated M15 collision channels.
- M10–M16 dedicated workflows, canonical Core CI and both native packaging gates are required for the `0.7.0-beta.1` release.

M16 broadens presentation quality and usability, not CrashVector's evidence claim. The class-specific visuals remain generic and the M15 road-user model remains contact/trajectory-only.

See `docs/M16_UX_AND_VEHICLE_VISUALS.md`.

## Beyond M16

The next physics work should port rigid lorry and motorcycle production simulation, then the comparison recorder, to the rigid-body world architecture before those paths are re-enabled. Additional independent public/licensed crash references should then be added before narrowing or extending any validation claim.

Side-impact geometry, richer contact manifolds, articulated truck fifth-wheel dynamics, cyclist coupling, moving pedestrians and additional structural/biomechanical references remain explicit future work rather than implied by M8–M16 completion.
