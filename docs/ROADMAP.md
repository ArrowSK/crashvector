# Roadmap

CrashVector's roadmap distinguishes **implemented source**, **runtime-validated source**, and **public packaged release**. That distinction matters after M18 because GitHub-hosted Actions capacity was exhausted while M19–M22 were implemented.

Current state:

- **M0–M18:** complete and historically runtime/package validated through the published `0.8.0-beta.3` line.
- **M19–M22:** implemented on `main`, with regression/package gates wired, but runtime validation is still pending.
- **Current source release candidate:** `0.9.0-beta.1`.
- **Current verified public package:** `0.8.0-beta.3`.
- **Next required work:** run current Godot validation + visual review + native packages before publishing `0.9.0-beta.1`. Do not start another physics milestone merely because source work exists through M22.

## M0 — Physics skeleton — complete

- Godot bootstrap and 240 Hz fixed physics tick.
- Rigid test vehicle/barrier.
- Telemetry, energy and momentum diagnostics.
- Headless CI baseline.

## M1 — Structural proof — complete

- Lumped structural nodes and axial beam response.
- Plastic yield, permanent deformation and fracture.
- Structural debug rendering and energy diagnostics.

## M2 — Generic compact hatchback — complete

- Original 28-node passenger-car proof architecture.
- Front/rear/safety-cell structural zones.
- Procedural deformable body and wheel anchors.

## M3 — Generic vehicle classes and heavy vehicles — complete

- Generic A/B/C/D/J/M passenger-car classes.
- Generic heavy articulated truck, rigid lorry / box truck and riderless motorcycle development models.
- Historical coupled node-contact solver.

## M4 — Scenario editor — complete

- Desktop scenario editing instead of keyboard-only configuration.
- Generic passenger-car + target workflow.
- Editable mass/speed/position/heading/contact settings.
- Human-readable `.crashvector.json` save/load.
- Preflight rejection of unsupported layouts.

## M5 — Analysis and replay — complete

- 120 Hz recorded replay independent of subsequent live state.
- Timeline scrubbing and slow-motion playback.
- Crash pulse, deformation, delta-v, energy and failure diagnostics.
- Event markers and 3D velocity/momentum vectors.

## M6 — Visual comparison — complete

- Two/three-speed comparison including arbitrary close speeds such as 130 vs 140 km/h.
- B/C/D class comparison.
- Synchronized comparison playback and metrics.

## M7 — Cinematic video export — complete

- Offline replay rendering at 1080p/1440p/4K and 30/60 fps.
- Cinematic camera modes and impact slow motion.
- External FFmpeg H.264 encoding.
- Optional frames and metadata sidecar.

## M8 — Calibration, broader scenario library and evidence scope — complete

- Historical NHTSA DOT HS 812 237 / test 7078 reference condition.
- Explicit separation of source observations from CrashVector regression guardrails.
- Evidence labels: Reference-correlated / Near reference / Class-scaled / Extrapolated.
- Riderless bicycle and pedestrian presets.
- Comparison Lab matrices.
- Road-user contact/trajectory-only evidence wording.

M8 remains a historical reduced-order correlation path. It does not validate later M12+ production rigid-body physics.

## M9 — Desktop distribution, updater and release hardening — complete

- Canonical semantic version in `project.godot`.
- Built-in Updates UI with verified release discovery/download.
- macOS Universal 2 DMG pipeline.
- Windows x64 Inno Setup pipeline.
- SHA-256 package verification and update manifest.
- Optional signing/notarization paths.
- Architecture audit against runtime script monkey-patching.

## M10 — Visual and UX rebuild — complete

- Responsive Scenario/Compare desktop shell.
- Vehicle/Target/Physics/Appearance inspector structure.
- Collapsible replay/analysis drawer.
- Improved technical road, environment and target presentation.
- Responsive-layout regression at supported desktop sizes.

## M11 — Crush dynamics rebuild — complete

- Passenger-car structural graph expanded from 28 to 44 nodes.
- Progressive axial/plastic/bending response.
- Improved safety-cell stability and anti-inversion protection.
- Multi-point historical contact and 1–64 structural substeps.

## M12 — Hybrid rigid-body correction — complete

M12 established the production architecture still used today.

- Godot `RigidBody3D` became authoritative for whole-object world motion.
- CCD, gravity and force-producing suspension added to supported production vehicles.
- Passenger-car structural graph became local deformation relative to the rigid chassis.
- Real rigid wall/barrier/pole/tree collision geometry.
- Passenger-car nose crush observed through a finite crush zone instead of moving the whole car through the structural graph.

## M13 — Progressive whole-body structural failure — complete

- Severe collision demand can progress from front crush into firewall/cowl, floor/rocker, A-pillar/roof, passenger-cell and rear-body stages.
- Protected-cell collision geometry retreats as severe local collapse progresses.
- Generic B-class historical preservation cases distinguish moderate 50 km/h and severe 200 km/h wall loading.

All capacities remain phenomenological project parameters, not manufacturer body-in-white data.

## M14 — Vulnerable road users and yielding narrow obstacles — complete

- Pedestrian and riderless-bicycle targets moved onto production Godot rigid-body world motion.
- Generic pole/tree targets can yield into permanent motion while wall/barrier remain non-yielding.
- Evidence-scope modal stacking fixed without redesigning the calibration panel.

Road-user results remain contact/trajectory visualisations only.

## M15 — Articulated pedestrian and bicycle dynamics — complete

- Pedestrian upgraded to an 11-body articulated rigid chain with 10 bounded `Generic6DOFJoint3D` joints.
- Riderless bicycle upgraded to frame + two independently simulated wheels.
- Replay stores articulated part transforms/velocities.
- Joint limits are numerical stability envelopes, not biomechanical ranges.

## M16 — UX reset and class-specific vehicle visuals — complete

- Task-focused desktop workflow retained over M15 physics.
- Class-specific A/B/C/D/J/M presentation profiles.
- Presentation remains separate from collision geometry and stiffness/mass.

## M16.1 / M16.2 — presentation corrections — complete

- Packaged visual/UX corrections after real application review.
- Improved camera framing, selected-state presentation and target composition.
- Passenger-car presentation later moved to pinned Kenney Car Kit 3.1 assets.
- Current neutral Kenney integration preserves source proportions with one uniform scale and applies structural deformation as displacement from a captured neutral cage rather than globally stretching the pristine mesh at load time.

These corrections are presentation-only unless explicitly documented otherwise.

## M17 — Reciprocal impacts, production comparison and long proving road — complete

- Supported dynamic actors can approach from ahead or behind.
- Passenger cars gain bounded direct rear deformation.
- Heavy truck gains bounded front/rear local collapse.
- Rigid lorry and riderless motorcycle move through production Godot rigid-body world motion.
- Visual Compare and Comparison Lab execute variants through isolated current production scenes rather than the historical reduced-order comparison runner.
- Production road extended to roughly 4 km × 20 m.

## M18 — Passenger-car side impacts — complete

- Passenger-car pairs support arbitrary relative headings including T-bone layouts.
- Real Godot side contacts drive bounded generic protected-cell lateral deformation.
- Impacted physical side collision face retreats with commanded intrusion.
- Replay stores independent left/right side state.

The historical reference regression uses a stationary C-segment car struck by a B-segment car at 55 km/h and records roughly 0.058 m lateral intrusion and 0.305 m striker front deformation. These are project regression values, not external validation data.

`0.8.0-beta.3` remains the current verified public package on the M17/M18 line.

## M19 — Contact fidelity and external-validation foundation — implemented, runtime validation pending

M19 deliberately starts with observation rather than another solver.

- `VehicleRigidChassis` exposes real non-ground Godot contact-manifold diagnostics.
- Diagnostics include reported point count, local spread, centroid/normal and reported-step impulse.
- Diagnostic fields are explicitly no-solver-feedback.
- Passenger-car front-crush observation keeps the original centre ray and adds two symmetric lateral rays to reduce offset/oblique blind spots.
- Additional NHTSA/IIHS references are stored as protocol geometry where outcome corridors are not available.
- A manual four-case aligned/offset/oblique/broadside observation matrix writes machine-readable contact diagnostics for review.

Important boundary: reported contact spread is not physical contact-patch area, and public test geometry does not create an outcome-correlation claim.

See `docs/M19_CONTACT_FIDELITY_VALIDATION.md`.

## M20 — Heavy and other-vehicle deformation — implemented, runtime validation pending

M20 closes the broadside/oblique target gap for three generic target families while preserving Godot rigid-body world motion.

- Heavy truck receives bounded front/rear/side local deformation driven by real contact demand.
- Rigid lorry / box truck receives bounded front/rear/side local deformation and collision-face retreat.
- Riderless motorcycle receives bounded frame/fork front/rear/side deformation.
- Oblique contacts can command both longitudinal and lateral local deformation.
- Riderless-bicycle broadside remains intentionally rejected.

Generic caps remain project assumptions, not manufacturer crashworthiness data.

See `docs/M20_HEAVY_OTHER_IMPACTS.md`.

## M21 — Articulated heavy truck — implemented, runtime validation pending

M21 removes the largest remaining truck-architecture simplification.

- Heavy truck uses separate trailer and tractor `RigidBody3D` assemblies.
- Configured target mass is preserved across both bodies through a generic project split.
- Tractor/trailer are connected through a constrained `Generic6DOFJoint3D` fifth wheel.
- M20 local deformation remains inherited on the body that owns the contacted structure.
- Replay/metrics add articulation yaw, peak articulation, fifth-wheel separation and combined contact diagnostics.
- Presentation gives tractor and trailer separate replayable transforms.

Fifth-wheel limits, mass split and suspension split remain generic educational assumptions.

See `docs/M21_ARTICULATED_HEAVY_TRUCK.md`.

## M22 — Cyclist coupling and moving pedestrians — implemented, runtime validation pending

M22 extends vulnerable-road-user trajectory/contact scope without turning it into a biomechanics package.

- Adds separate `Cyclist (generic rider + bicycle)` target.
- Cyclist combines existing bicycle frame/wheels with an 11-body generic rider.
- Five temporary rider↔bicycle coupling joints at seat/hands/feet release on first production-compatible contact.
- Combined scenario mass preserves a minimum 35 kg rider share above the selected bicycle's generic mass.
- Cyclist supports generic broadside/oblique trajectory layouts.
- Existing riderless `Bicycle` remains separate and preserves its previous near-longitudinal heading restriction.
- Existing articulated pedestrian gains configurable 0–20 km/h initial translation along heading.
- Moving pedestrian does not model gait, propulsion, foot placement or balance.
- Replay preserves articulated parts plus cyclist coupling-release state.

See `docs/M22_CYCLIST_MOVING_PEDESTRIAN.md`.

## Release/validation gate after M22

No M23 physics milestone is currently scheduled. The next work is evidence and runtime validation.

`project.godot` is now bumped to `0.9.0-beta.1` and matching release-candidate notes exist. This is preparation only; `0.8.0-beta.3` remains the current verified public package until the new candidate passes the gates below and is actually published.

Before `0.9.0-beta.1` is published:

1. Godot must import/parse the current `main` source successfully.
2. At minimum the publishable package `smoke` set must pass, including M19, M20, M21 and M22 production regressions.
3. Preferably the consolidated M0–M22 full suite should pass on the release candidate.
4. The manual presentation visual review must be inspected, including pristine A/B/C/D/J/M views, representative crash frames and the M19 contact-observation matrix.
5. macOS Universal 2 and Windows x64 packages must build and pass their existing package/install/checksum checks.
6. Only after those gates should the already-prepared `0.9.0-beta.1` candidate be published. If validation requires code changes after publication, bump again rather than replacing an immutable release.

A package built with `validation=none` is a diagnostic artifact only and cannot be presented as a validated release.

## Future physics work

Future physics should be evidence-driven rather than milestone-driven. Candidate work is acceptable only when a runtime/visual/validation observation identifies a specific modelling failure or when new public/licensed outcome data supports a stronger correlation task.

Likely future areas include richer tyre/steering dynamics, more target-specific geometry/deformation, improved rider/bicycle contact modelling and additional independent validation references. None should be implemented merely to make a crash look more dramatic.
