<p align="center">
  <img src="assets/branding/crashvector-icon.svg" alt="CrashVector — educational 3D crash simulation" width="170">
</p>

<h1 align="center">CrashVector</h1>

<p align="center">
  <strong>Build a crash. Change the speed. Inspect the outcome.</strong>
</p>

<p align="center">
  Educational 3D collision simulation with generic deformable vehicles, replay, analysis and cinematic export.
</p>

<p align="center">
  <img alt="M22 source milestone" src="https://img.shields.io/badge/source-M22%20cyclist%20%2B%20articulated%20truck-ff4d1f?style=for-the-badge">
  <a href="https://github.com/ArrowSK/crashvector/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/ArrowSK/crashvector/actions/workflows/ci.yml/badge.svg?branch=main"></a>
</p>

<p align="center">
  <a href="https://github.com/ArrowSK/crashvector/releases/download/v0.8.0-beta.3/CrashVector-0.8.0-beta.3-macOS-universal.dmg"><img alt="Download CrashVector for macOS" src="https://img.shields.io/badge/Download-macOS%20Universal%202-111111?style=for-the-badge&logo=apple"></a>
  <a href="https://github.com/ArrowSK/crashvector/releases/download/v0.8.0-beta.3/CrashVector-0.8.0-beta.3-Windows-x64-Setup.exe"><img alt="Download CrashVector for Windows" src="https://img.shields.io/badge/Download-Windows%20x64-0078D4?style=for-the-badge&logo=windows11"></a>
</p>

<p align="center">
  <a href="https://github.com/ArrowSK/crashvector/releases/tag/v0.8.0-beta.3">Release notes & checksums</a>
  ·
  <a href="docs/DISTRIBUTION.md">Installation & updates</a>
</p>

<p align="center">
  <img alt="Godot 4.4.1+" src="https://img.shields.io/badge/Godot-4.4.1%2B-478cbf">
  <img alt="MPL 2.0" src="https://img.shields.io/badge/license-MPL--2.0-6c7a89">
  <img alt="Generic models" src="https://img.shields.io/badge/models-generic%20classes-19b5a5">
  <img alt="Educational simulation" src="https://img.shields.io/badge/scope-educational-19b5a5">
</p>

CrashVector is an open-source desktop crash-simulation sandbox for people who want to **see what speed, mass and impact configuration change** without turning the exercise into specialist engineering software.

The current M12–M22 source architecture separates whole-object world motion, permanent structural deformation and presentation. Godot `RigidBody3D` owns supported vehicle/target world motion; CrashVector's structural graphs remain local deformation/presentation state. M13 extends severe passenger-car failure beyond the nose, M14 adds vulnerable-target trajectories and yielding pole/tree targets, M15 adds articulated pedestrian and bicycle dynamics, M16 reorganises the desktop workflow, M17 restores Comparison on the production rigid-body scene, M18 adds passenger-car broadside deformation, M19 adds real-contact diagnostics and offset/oblique front-probe coverage, M20 adds bounded heavy-truck/lorry/motorcycle deformation for broadside/oblique layouts, M21 splits the heavy truck into tractor and trailer rigid bodies connected by a constrained fifth wheel, and M22 adds a generic cyclist plus configurable initial pedestrian translation.

> **Current source state:** `main` is implemented through **M22** and is versioned as the **`0.9.0-beta.1` release candidate**. M19–M22 were committed while GitHub-hosted Actions capacity was exhausted, so they are **implemented but runtime-unvalidated** until Godot executes the current regression stack. Do not treat `0.9.0-beta.1` as a tested public release until those gates pass and the release is actually published.

> **Packaged release:** **`0.8.0-beta.3`** remains the current verified public desktop beta. It predates M19–M22 and packages the completed M17/M18 production stack together with the working Updates modal and Kenney Car Kit 3.1 passenger-car presentation for macOS Universal 2 and Windows x64.

> **Important boundaries:** M20 permits generic broadside/oblique heavy-truck, rigid-lorry and riderless-motorcycle deformation, while the old riderless-bicycle broadside path remains intentionally rejected. M21 fifth-wheel articulation is generic and not a manufacturer truck model. M22's cyclist and moving-pedestrian additions remain trajectory/contact models only; they do not add biomechanics, injury prediction, gait, steering, tyre-force or forensic-reconstruction validity.

> **Scope:** CrashVector is an educational physics visualisation tool. It is **not** certified accident reconstruction, homologation, manufacturer crash-performance prediction, biomechanics, medical/injury prediction or a safety-rating system.

## Download and install

No Git, Godot, Python, Terminal or PowerShell is required for the packaged desktop beta.

| Platform | Download | Install |
| --- | --- | --- |
| macOS — Apple Silicon + Intel | **[Download macOS Universal 2 DMG](https://github.com/ArrowSK/crashvector/releases/download/v0.8.0-beta.3/CrashVector-0.8.0-beta.3-macOS-universal.dmg)** | Open the DMG, then drag **CrashVector.app** onto the **Applications** shortcut. Launch it from Applications. |
| Windows 10/11 x64 | **[Download Windows x64 Setup](https://github.com/ArrowSK/crashvector/releases/download/v0.8.0-beta.3/CrashVector-0.8.0-beta.3-Windows-x64-Setup.exe)** | Run Setup and follow the graphical installer. CrashVector installs under Program Files and appears in the Start menu and Installed apps. |

The matching SHA-256 checksum files and `update-manifest.json` are on the **[0.8.0-beta.3 release page](https://github.com/ArrowSK/crashvector/releases/tag/v0.8.0-beta.3)**.

This beta is ad-hoc signed on macOS and unsigned on Windows when paid signing credentials are not configured, so Gatekeeper or SmartScreen may warn about an unknown developer/publisher. Use only the files attached to the official `ArrowSK/crashvector` release.

To uninstall on macOS, quit CrashVector and move it from Applications to Trash. On Windows, use **Settings → Apps → Installed apps → CrashVector → Uninstall**.

CrashVector includes **Updates → Check for updates**. It can optionally check once per day; an update is downloaded and SHA-256 verified first, and installation is explicitly handed to the normal operating-system installer.

See **[Desktop distribution and updates](docs/DISTRIBUTION.md)** for detailed installation, removal, update, checksum and signing information.

## Normal M16 workflow

The default path is deliberately short:

```text
choose passenger-car class
          ↓
choose impact target
          ↓
set impact speed
          ↓
      Run simulation
          ↓
 replay · analysis · video
```

The desktop is organised around four jobs:

- **Scenario builder** — choose the primary passenger-car class, target and impact speed;
- **3D viewport** — inspect the crash and control the camera/overlays;
- **Properties** — edit the selected object, with solver/contact settings behind **Advanced setup**;
- **Playback dock** — replay, timeline, analysis and video export.

Defaults exist for normal scenarios, so mass and solver parameters are not mandatory setup work.

## Current production scope

| Area | What you get |
| --- | --- |
| Scenario editor | Task-focused M16/M16.1 desktop workflow with contextual Properties and Advanced setup |
| Passenger cars | Generic A / B / C / D / J / M classes with representative default masses and a refined 44-node local structural model |
| Vehicle presentation | Six distinct Kenney Car Kit 3.1 passenger-car bodies. At zero deformation the source Kenney body keeps its proportions through axis conversion, uniform scale, placement and paint; structural deformation is added as displacement from the captured neutral cage rather than globally warping the pristine mesh at load time |
| Whole-vehicle dynamics | Godot `RigidBody3D`, gravity, CCD and raycast suspension for the supported production path |
| Progressive structural failure | Front crush followed, when demand is sufficient, by firewall/cowl intrusion, floor/rocker and A-pillar/roof deformation, passenger-cell shortening and rear-body buckling |
| Reciprocal longitudinal impacts | Supported dynamic actors may strike from ahead or behind; passenger cars have bounded direct rear deformation and heavy/other targets use their current target-specific deformation paths |
| Passenger-car side impacts | Passenger-car pairs support arbitrary heading deltas including perpendicular T-bone layouts, with bounded lateral protected-cell deformation and physical collision-face retreat |
| Contact fidelity | M19 records real non-ground Godot contact-manifold diagnostics and adds two lateral front-crush observation rays while keeping Godot collision impulses authoritative |
| Heavy articulated truck | M21 uses separate trailer and tractor `RigidBody3D` assemblies connected by a constrained generic fifth wheel; inherited M20 front/rear/side local deformation remains bounded and contact-driven |
| Rigid lorry / box truck | Production Godot rigid-body world motion plus bounded generic M20 front/rear/side deformation; not manufacturer-specific crashworthiness |
| Riderless motorcycle | Production Godot rigid-body world motion plus bounded generic M20 frame/fork deformation; no rider or tyre/steering model |
| Vulnerable road users | M15 articulated pedestrians and riderless bicycles remain available; M22 adds pedestrian initial translation and a separate generic cyclist composed of an articulated rider plus bicycle with temporary pre-impact coupling |
| Static / narrow targets | Wall and concrete barrier remain rigid; generic pole and tree targets can yield and move permanently at severe collision demand |
| Car vs car | Rear-end, near head-on and broadside passenger-car layouts using rigid-body world motion |
| Replay & analysis | 120 Hz recorded replay, timeline scrubbing, rigid-body velocity/momentum, structural diagnostics, contact-manifold diagnostics and target-specific deformation/articulation state where present |
| Comparison | Visual Compare and Comparison Lab execute each variant through the current production scene in an isolated `SubViewport` / `World3D` and replay the resulting production recordings |
| Video export | 1080p / 1440p / 4K offline replay rendering at 30/60 fps with external FFmpeg H.264 encoding |
| Calibration | Historical M8 evidence labels/reference check retained separately; it does not validate the M12–M22 production source architecture |
| Desktop distribution | Current verified public package is still `0.8.0-beta.3` (M18-era source), with macOS Universal 2 DMG and Windows x64 Setup installer, checksums and update manifest |

## Passenger-car classes

CrashVector uses **generic classes rather than production models**. There are no manufacturer badges, proprietary CAD files or claims that a class reproduces a particular real car.

| Class | Representative type | Default mass |
| --- | --- | ---: |
| A | City car | 950 kg |
| B | Small hatchback | 1,150 kg |
| C | Compact car | 1,375 kg |
| D | Midsize car | 1,575 kg |
| J | SUV / crossover | 1,850 kg |
| M | MPV / minivan | 2,050 kg |

The default mass is only a starting point. You can override it directly in the scenario.

M16 introduced class-specific presentation profiles and M16.1 strengthened their silhouettes. The current source uses six distinct generic Kenney Car Kit 3.1 bodies. The pristine source body is preserved at neutral state with one uniform scale; the structural presentation adapter then applies only the displacement between the live and captured neutral deformation cages. The underlying physics remains the generic class-based CrashVector model.

## M12 — rigid-body correction

M12 moved supported whole-vehicle world motion away from the historical deformable point-mass graph and into Godot `RigidBody3D`. Passenger cars use real gravity, CCD and road suspension while the 44-node structural graph remains local deformation relative to the rigid chassis.

The passenger-car rigid collision volume ends around the protected cell/subframe. A forward probe measures available crush travel and drives the phenomenological nose-resistance path. The established 50 km/h wall and 90 km/h passenger-car-versus-truck engine regressions remain active historical preservation gates.

See [M12 hybrid physics](docs/M12_HYBRID_PHYSICS.md).

## M13 — progressive whole-body failure

M13 lets severe residual collision demand propagate beyond the finite front crush zone into firewall/cowl intrusion, floor/rocker and A-pillar/roof deformation, passenger-cell shortening and rear-body buckling. The stable M12 rigid-body world-motion path remains authoritative.

The generic B-class regression continues to distinguish moderate and extreme wall loading:

- **50 km/h:** about 105.0 kJ demand, 0.536 m front crush and effectively zero firewall/cabin/rear collapse;
- **200 km/h:** about 1,739.2 kJ demand, 0.945 m front-zone crush, 0.300 m firewall intrusion, 0.820 m passenger-cell collapse, 0.231 m rear-body buckle and 1.948 m combined longitudinal collapse.

These are generic project regression measurements, not predictions for a production car.

See [M13 progressive whole-body failure](docs/M13_PROGRESSIVE_FAILURE.md).

## M14 — vulnerable road users and yielding narrow obstacles

M14 moved pedestrian and riderless-bicycle targets onto a real Godot rigid-body world-motion path and allowed generic pole/tree targets to yield permanently at severe collision demand. Wall and concrete barrier remain rigid.

M14 also fixed the evidence-scope modal stacking issue without redesigning the calibration panel or changing its callbacks.

See [M14 road users and yielding obstacles](docs/M14_ROAD_USERS_OBSTACLES.md).

## M15 — articulated pedestrian and bicycle dynamics

M15 replaces the one-rigid-body vulnerable-target approximation with articulated production targets while keeping the existing production API and passenger-car architecture stable.

- Pedestrians use an 11-body articulated rigid chain with 10 bounded `Generic6DOFJoint3D` constraints.
- Riderless bicycles use a rigid frame plus two independently simulated wheel bodies joined at the hubs.
- Replay records/restores articulated part transforms and velocities.
- Dedicated regression rejects excessive target centre-of-mass energy, direct-joint folding and passenger-car launch/rebound instability.

At the final 60 km/h regression the pedestrian finishes at 2.51 m/s centre-of-mass speed with 13.97 m maximum travel and 105.2° maximum direct-joint motion; the riderless city bicycle finishes at 9.21 m/s with 19.22 m maximum travel and 34.85 rad/s maximum wheel motion. These are numerical stability/trajectory regressions, not biomechanical validation corridors.

See [M15 articulated road users](docs/M15_ARTICULATED_ROAD_USERS.md).

## M16 — UX and class-specific vehicle visuals

M16 reorganises the desktop around scenario building, the central 3D viewport, contextual Properties and a persistent playback dock. Solver/contact controls move behind **Advanced setup**, while file, update, calibration/evidence, replay, analysis and export functions remain available.

The new passenger-car skin is presentation-only. `VehicleVisualProfileCatalog` provides materially different generic city-car, hatchback, compact, midsize, SUV and MPV proportions. The visual layer reads the same deforming structural model every frame and does not change rigid collision geometry, mass, stiffness, structural beams, crush behaviour, contact probes or solver settings.

M16's production regression also verifies that selecting a pedestrian through the real UI still instantiates the finalized M15 articulated production target rather than falling back to the M14 proxy.

See [M16 UX and vehicle visuals](docs/M16_UX_AND_VEHICLE_VISUALS.md).

## M16.1 — packaged visual and UX correction

M16.1 is a presentation-only correction based on review of the packaged `0.7.0-beta.1` application. It keeps the M12–M15 production physics path intact while fixing stale automatic scenario names, misleading selected-workspace styling, duplicate helper text, the oversized completed-run selection oval and excessively wide camera framing.

The setup and aftermath cameras now frame the current vehicle/target bounds rather than enforcing the old 18 m minimum offset. D-segment, SUV and MPV archetypes receive stronger class-specific silhouettes while remaining generated from the same deforming structural anchors. A dedicated regression runs the D-segment midsize / concrete barrier / 200 km/h case through the real production controls and verifies completion, replay creation, final presentation synchronization and aftermath camera composition.

See [0.7.0-beta.2 release notes](docs/releases/0.7.0-beta.2.md).

## M17 — reciprocal impacts and production comparison

M17 removes the remaining direction and comparison assumptions from the production integration layer. Supported dynamic actors may approach from either direction; passenger cars gain bounded rear deformation; the heavy truck gains bounded front/rear collapse; rigid lorry and riderless motorcycle move through the production Godot rigid-body path; and the collision road is extended to approximately 4 km.

Visual Compare and Comparison Lab now execute each requested variant through the actual production scene in an isolated world and use the resulting production replay/analysis state. The historical reduced-order runner remains available only for legacy regression continuity.

See [M17 reciprocal impacts, production comparison and long proving road](docs/M17_RECIPROCAL_IMPACTS_COMPARISON.md).

## M18 — passenger-car side impacts

M18 adds bounded broadside deformation for passenger-car pairs without replacing the M12–M17 rigid-body architecture. Real Godot contact samples on a protected-cell side face drive a generic lateral intrusion envelope; the corresponding physical collision face retreats laterally and the existing deformable presentation graph follows the struck-side structural state.

The dedicated perpendicular regression uses a stationary C-segment passenger car and a B-segment passenger car approaching at 55 km/h and -90 degrees. It records approximately 0.058 m lateral intrusion on the struck car and 0.305 m front deformation on the striking car. These are CrashVector regression values, not manufacturer or regulatory side-impact data.

See [M18 passenger-car side impacts](docs/M18_SIDE_IMPACTS.md).

## M19 — contact fidelity and external-validation foundation

M19 makes the real Godot contact manifold observable without changing collision impulses. Production replay/analysis can retain non-ground contact-point count, local spread and reported-step impulse diagnostics, explicitly marked as diagnostic-only. M19 also keeps the original centre front-crush ray and adds two symmetric lateral observation rays to reduce offset/oblique measurement blind spots.

The stored NHTSA/IIHS references are kept separate from outcome claims: three new offset/oblique references are protocol-geometry-only and do not define CrashVector correlation corridors.

See [M19 contact fidelity and validation foundation](docs/M19_CONTACT_FIDELITY_VALIDATION.md).

## M20 — heavy and other-vehicle deformation

M20 extends broadside/oblique production scope to the generic heavy articulated truck, rigid lorry and riderless motorcycle. Godot rigid bodies remain authoritative for world motion; real non-ground contact demand drives bounded local front/rear/side deformation and corresponding collision-face retreat.

The riderless-bicycle broadside path remains intentionally blocked, and M20's deformation limits are generic project assumptions rather than manufacturer or regulatory data.

See [M20 heavy and other-vehicle deformation](docs/M20_HEAVY_OTHER_IMPACTS.md).

## M21 — articulated heavy truck

M21 replaces the heavy truck's previous one-piece rigid world assembly with separate trailer and tractor `RigidBody3D` bodies connected through a constrained generic `Generic6DOFJoint3D` fifth wheel. Existing M20 local deformation remains inherited while articulation, fifth-wheel separation and combined contact diagnostics are added to replay/metrics.

The generic mass split, joint envelopes, suspension split and deformation parameters are educational assumptions, not specifications for a particular tractor/trailer combination.

See [M21 articulated heavy truck](docs/M21_ARTICULATED_HEAVY_TRUCK.md).

## M22 — cyclist and moving pedestrian

M22 adds a separate **Cyclist (generic rider + bicycle)** target and configurable initial translation speed for the existing articulated pedestrian. The cyclist combines the existing bicycle topology with an 11-body generic rider and temporary seat/hand/foot coupling joints that release on first production-compatible contact.

The original **Bicycle (riderless)** target remains separate. Moving-pedestrian speed is only initial translation along heading; no gait, balance or propulsion model is introduced. Cyclist/pedestrian output remains contact/trajectory-only.

See [M22 cyclist coupling and moving pedestrians](docs/M22_CYCLIST_MOVING_PEDESTRIAN.md).

## Replay, analysis and cinematic export

CrashVector records supported production simulation at **120 Hz**. Replay stores rigid-body state plus local structural/articulated presentation state, so scrubbing and video export do not re-run the crash.

Playback supports 0.05× / 0.10× / 0.25× / 0.50× / 1× speeds, timeline scrubbing, structural diagnostics and velocity/momentum overlays where meaningful.

**Cinematic Video** renders from the recorded replay and supports:

- 1080p, 1440p and 4K;
- 30 or 60 fps;
- Auto Cinematic, Wide, Tracking, Impact Close-up and Aftermath Orbit cameras;
- impact-centred slow motion;
- title/result cards and educational overlays;
- optional retained source frames;
- machine-readable `.crashvector-video.json` metadata.

CrashVector calls an **external FFmpeg installation** for H.264 MP4 encoding. FFmpeg is not bundled with the repository. See [Video export](docs/VIDEO_EXPORT.md).

## Calibration and evidence labels

CrashVector deliberately separates **a convincing visual** from **a validated engineering claim**.

The historical M8 reduced-order reference uses the NHTSA NCAP full-frontal rigid-wall condition documented in **DOT HS 812 237 / laboratory test 7078**, with the documented **1,661 kg** test mass and **56.5 km/h** impact condition.

The application retains the labels **Reference-correlated**, **Near reference**, **Class-scaled** and **Extrapolated**.

The M8 calibration runner remains a historical regression/correlation path. It does **not** validate the M12–M22 rigid-body, staged-collapse, articulated-road-user, reciprocal-impact, comparison, broadside, heavy-target deformation, fifth-wheel or cyclist/moving-pedestrian production source path, and current project regression numbers are not manufacturer or regulatory corridors.

See [Calibration and validation scope](docs/CALIBRATION.md) and [Physics notes](docs/PHYSICS.md).

## Known modelling boundaries

CrashVector intentionally rejects or limits scenarios instead of making a visually plausible but unsupported claim.

- Current source rigid-body coverage includes wall, barrier, yielding generic pole/tree, passenger-car, articulated heavy truck, rigid lorry, riderless motorcycle, articulated pedestrian, riderless bicycle and generic cyclist targets.
- M18 passenger-car broadside is implemented. M20 adds generic broadside/oblique heavy-truck, rigid-lorry and riderless-motorcycle deformation. The old riderless-bicycle broadside path remains rejected; generic rider+bicycle broadside/oblique scenarios use the separate M22 cyclist target.
- M20 lorry/motorcycle deformation and M21 truck articulation are bounded generic educational models, not manufacturer-specific crashworthiness or multibody vehicle validation.
- Pedestrian, riderless-bicycle and cyclist output is contact/trajectory visualisation only. M22 pedestrian speed is initial translation, not gait; the cyclist has no validated rider-control, tyre-force, injury or ejection model.
- Visual Compare and Comparison Lab use the production scene introduced in M17; historical reduced-order comparison code remains only for regression continuity.
- Generic vehicle classes and the passenger-car presentation layer are not production-car crash models.
- M13 staged collapse, M14 narrow-target yielding, M17 reciprocal deformation, M18 lateral deformation and M20 target deformation are phenomenological reduced-order models, not finite-element structural analysis or manufacturer body-in-white/target data.
- M15/M22 joint limits and coupling choices are numerical/stability envelopes, not human biomechanical ranges.
- M19 contact-manifold spread is diagnostic reported-contact geometry, not physical contact-patch area or an external validation corridor.
- Target geometry remains simplified.
- M8 calibration does not validate the M12–M22 production source architecture.
- M19–M22 are currently runtime-unvalidated because their commits were made while GitHub-hosted Actions capacity was exhausted. The current source must pass Godot regression/package gates before those capabilities are claimed in a public release.
- CI validates deterministic logic, editor runtime and engine-physics regression paths, but does not perform a real 4K GPU render or invoke the machine's FFmpeg binary.

## Run from source

Requirements:

- **Godot 4.4.1 or newer**
- Git

```bash
git clone --recurse-submodules https://github.com/ArrowSK/crashvector.git
cd crashvector
godot --editor --path .
```

For an existing checkout, run `git submodule update --init --recursive` before launching if you want the same Kenney Car Kit passenger-car presentation shipped in the desktop packages. Without the pinned asset submodule, the established procedural passenger-car skin remains a development fallback.

Or open `project.godot` directly in Godot and run the project.

## Documentation

| Guide | What it is for |
| --- | --- |
| [Roadmap](docs/ROADMAP.md) | Implementation history, current validation state and future physics work |
| [Architecture](docs/ARCHITECTURE.md) | Structural, simulation, replay, distribution and presentation layers |
| [CI and release flow](docs/CI_AND_RELEASE.md) | Consolidated regression, visual review, package validation and Actions-quota behaviour |
| [0.9.0-beta.1 candidate notes](docs/releases/0.9.0-beta.1.md) | Prepared M19–M22 feature-beta notes; publication remains gated on current runtime/visual/native validation |
| [0.8.0-beta.3 release notes](docs/releases/0.8.0-beta.3.md) | Current verified packaged beta with the Updates modal correction and Kenney passenger-car presentation |
| [Kenney Car Kit presentation](docs/KENNEY_CAR_KIT.md) | Asset provenance, passenger-car mapping, neutral-body preservation, deformation coupling and scope limits |
| [M22 cyclist and moving pedestrian](docs/M22_CYCLIST_MOVING_PEDESTRIAN.md) | Generic rider+bicycle coupling, pedestrian initial translation, replay and evidence boundaries |
| [M21 articulated heavy truck](docs/M21_ARTICULATED_HEAVY_TRUCK.md) | Tractor/trailer rigid-body split, constrained fifth wheel, replay and generic limits |
| [M20 heavy and other-vehicle deformation](docs/M20_HEAVY_OTHER_IMPACTS.md) | Broadside/oblique truck/lorry/motorcycle deformation and scope limits |
| [M19 contact fidelity](docs/M19_CONTACT_FIDELITY_VALIDATION.md) | Real Godot contact diagnostics, offset/oblique probe coverage and external-reference roles |
| [M18 side impacts](docs/M18_SIDE_IMPACTS.md) | Passenger-car broadside contact, bounded lateral deformation and evidence limits |
| [M17 reciprocal impacts and comparison](docs/M17_RECIPROCAL_IMPACTS_COMPARISON.md) | Production comparison, reciprocal impact direction, lorry/motorcycle routing and long proving road |
| [M16 UX and vehicle visuals](docs/M16_UX_AND_VEHICLE_VISUALS.md) | Task-focused desktop shell and class-specific presentation layer |
| [M15 articulated road users](docs/M15_ARTICULATED_ROAD_USERS.md) | Articulated pedestrian/bicycle topology, stability decisions and validation limits |
| [M14 road users and yielding obstacles](docs/M14_ROAD_USERS_OBSTACLES.md) | Rigid vulnerable-target trajectories, generic pole/tree yielding and M14 gates |
| [M13 progressive failure](docs/M13_PROGRESSIVE_FAILURE.md) | Whole-body staged failure, collision-demand model and limitations |
| [M12 hybrid physics](docs/M12_HYBRID_PHYSICS.md) | Rigid-body world-motion architecture, road/contact coupling and coverage boundaries |
| [M11 crush dynamics](docs/M11_CRUSH_DYNAMICS.md) | Refined 44-node structure and historical reduced-order M11 dynamics |
| [Physics notes](docs/PHYSICS.md) | Contact, energy accounting, structural assumptions and modelling boundaries |
| [Calibration](docs/CALIBRATION.md) | Reference source, evidence labels and historical regression corridors |
| [Scenario format](docs/SCENARIO_FORMAT.md) | Human-readable `.crashvector.json` save/load format |
| [Video export](docs/VIDEO_EXPORT.md) | Offline rendering, camera modes, FFmpeg boundary and metadata |
| [Desktop distribution and updates](docs/DISTRIBUTION.md) | Installation, updater, packaging, signing and release architecture |

## Development status

**M22 is the current source milestone; M18 is the current verified packaged milestone.** M19–M22 are implemented on `main` but remain runtime-unvalidated until the current Godot regression stack runs successfully. `project.godot` is now **`0.9.0-beta.1`** as the prepared release candidate; the updater and public download links continue to point only at **`0.8.0-beta.3`** until the candidate passes the release gates and is published.

The current public installers are **`v0.8.0-beta.3`**, verified through canonical Core CI, macOS Universal 2 packaging, Windows x64 packaging, M10 updater regression, M16 Kenney presentation regression and the preserved M17/M18 production gates. Checksum sidecars and `update-manifest.json` are attached to the release.

Before `0.9.0-beta.1` is published, the current source must pass at least the publishable package `smoke` validation, successful macOS/Windows package construction and the manual presentation/contact-fidelity review. A full M0–M22 run remains the preferred release candidate gate once Actions capacity is available. Until then the correct next step is validation and visual inspection, not another physics milestone.

## Licence

CrashVector source code is licensed under the **Mozilla Public License 2.0 (MPL-2.0)**. See [LICENSE](LICENSE).

Third-party components and externally installed tools may carry their own licences; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
