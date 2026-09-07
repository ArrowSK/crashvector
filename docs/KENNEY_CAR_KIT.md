# Kenney Car Kit presentation layer

CrashVector uses **Kenney Car Kit 3.1** as the production presentation source for passenger cars while keeping the M12-M18 simulation model authoritative.

## Source and licence

- Creator: Kenney.
- Canonical pack: `https://kenney.nl/assets/car-kit`.
- Licence: Creative Commons Zero (CC0 1.0 Universal).
- CrashVector source: `third_party/kenney_car_kit` Git submodule.
- Pinned source commit: `153591d606970058a4d0e44aeadf435c2d3f89ed`.
- Attribution is not required by CC0, but CrashVector credits Kenney in `THIRD_PARTY_NOTICES.md`.

The submodule is commit-pinned. A normal `git submodule update --init --recursive` resolves the exact asset tree used by CrashVector; CI and packaging also initialise it automatically and fail if the required files are incomplete.

## Passenger-car mapping

| CrashVector class | Kenney body |
| --- | --- |
| A-segment city car | `hatchback-sports.glb` |
| B-segment small hatchback | `hatchback-sports.glb` |
| C-segment compact car | `sedan.glb` |
| D-segment midsize car | `sedan-sports.glb` |
| J-segment SUV / crossover | `suv.glb` |
| M-segment MPV / minivan | `van.glb` |

Passenger cars use Kenney `wheel-default.glb` for all four presentation wheels. The existing wheel-anchor groups remain authoritative for wheel location and rolling motion.

## Physics and deformation boundary

The Kenney meshes are not collision geometry and do not replace CrashVector's structural model.

`M162VehicleVisual` creates a `KenneyVehicleSkin3D`. The imported Kenney body is remapped into the same structural cross-section cage that already drives the M16.2 presentation. Consequently:

- M12/M13 front deformation still comes from the production structural graph and rigid-body contact path;
- M17 rear deformation still moves the rear presentation anchors;
- M18 lateral intrusion still moves the struck-side presentation anchors;
- rigid-body pose, collision shapes, masses, contact impulses, replay snapshots and analysis remain unchanged;
- switching paint colours changes the imported presentation material without changing simulation state.

If the Car Kit assets are absent in an ordinary developer checkout, the established procedural passenger-car skin remains a development fallback. CI and release packaging deliberately do **not** accept that fallback: they initialise the pinned submodule and fail if the required Kenney files are unavailable.

## Scope limits

Kenney Car Kit does not contain a semantically appropriate articulated heavy tractor-trailer, motorcycle, bicycle or pedestrian model matching CrashVector's current simulated classes. Those objects retain their existing purpose-built presentation rather than being replaced by a visually convenient but physically misleading Car Kit asset. Static obstacle presentation is also unchanged.

This is a presentation limitation only; the corresponding M14-M18 simulation paths are unchanged.

## Regression gate

`tests/kenney_car_kit_visuals.gd` verifies:

- all six passenger-car class mappings;
- availability of the pinned Kenney bodies and wheel model;
- production-scene activation of the Kenney skin;
- replacement of the generated passenger-car body and four presentation wheels;
- existing CrashVector paint selection;
- direct coupling to front, rear and lateral structural anchors;
- class-specific rebuild to the SUV asset.

The pre-existing M17 and M18 regressions remain responsible for reciprocal-impact and side-impact physics. The Kenney integration does not weaken or replace those gates.
