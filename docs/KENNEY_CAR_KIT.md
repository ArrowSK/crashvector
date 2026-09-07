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

Each CrashVector passenger-car class has its own pinned Kenney body asset instead of sharing a presentation body with another class.

| CrashVector class | Kenney body |
| --- | --- |
| A-segment city car | `hatchback-sports.glb` |
| B-segment small hatchback | `sedan-sports.glb` |
| C-segment compact car | `sedan.glb` |
| D-segment midsize car | `taxi.glb` |
| J-segment SUV / crossover | `suv.glb` |
| M-segment MPV / minivan | `van.glb` |

The Car Kit has only one dedicated hatchback body and a limited set of ordinary passenger-car silhouettes. The D-segment therefore uses the additional Kenney passenger-sedan/taxi asset as a distinct presentation source rather than reusing the compact or sports-sedan body. These asset choices are visual class proxies only; they do not imply manufacturer-specific geometry or physics.

Passenger cars use Kenney `wheel-default.glb` for all four presentation wheels. CrashVector's established wheel-anchor groups remain authoritative for suspension position and rolling motion. `KenneyVehiclePresentation3D` additionally reads the four named wheel centres from the selected body asset and applies bounded presentation-only local offsets so the rendered wheels sit closer to that body's original wheel openings without moving the authoritative suspension anchors.

## Physics and deformation boundary

The Kenney meshes are not collision geometry and do not replace CrashVector's structural model.

`M162VehicleVisual` creates a `KenneyVehiclePresentation3D`, which extends the neutral/deformation behaviour in `KenneyVehicleSkin3D`. On initial load, the Kenney body is converted into CrashVector's vehicle axes, fitted with one **uniform** scale and positioned inside the neutral presentation envelope. The source body proportions are not stretched independently and are not forced into the procedural cross-section cage before the crash starts.

The neutral M16.2 cage is captured once when the presentation skin is installed. During simulation, the Kenney body receives only the displacement between the live structural cage and that neutral cage at the current rigid-body pose. Consequently:

- an undeformed vehicle preserves the source Kenney silhouette apart from axis conversion, one uniform scale, placement and the selected CrashVector paint;
- M12/M13 front deformation still comes from the production structural graph and rigid-body contact path;
- M17 rear deformation still moves the rear presentation anchors;
- M18 lateral intrusion still moves the struck-side presentation anchors;
- rigid-body pose, collision shapes, masses, contact impulses, replay snapshots and analysis remain unchanged;
- switching paint colours changes the imported presentation material without changing simulation state.

`KenneyVehiclePresentation3D` also applies conservative satin body-response bounds to the imported material while preserving the Kenney colour-map texture and CrashVector paint multiplier. This material tuning is presentation-only.

If the Car Kit assets are absent in an ordinary developer checkout, the established procedural passenger-car skin remains a development fallback. CI and release packaging deliberately do **not** accept that fallback: they initialise the pinned submodule and fail if the required Kenney files are unavailable. Packaging explicitly requires all six mapped body assets, including `taxi.glb`, plus the presentation wheel asset.

## Scope limits

Kenney Car Kit does not contain a semantically appropriate articulated heavy tractor-trailer, motorcycle, bicycle or pedestrian model matching CrashVector's current simulated classes. Those objects retain their existing purpose-built presentation rather than being replaced by a visually convenient but physically misleading Car Kit asset.

Static targets retain their existing simulation/collision geometry. The production presentation layer may mute materials or hide engineering reference overlays such as the rigid-wall impact stripe during the normal scenario view; those changes do not alter target physics.

This is a presentation limitation only; the corresponding M14-M18 simulation paths are unchanged.

## Regression and visual-review gates

`tests/kenney_car_kit_visuals.gd` verifies:

- six distinct passenger-car class mappings;
- availability of the pinned Kenney bodies and wheel model;
- production-scene activation of the Kenney skin;
- preservation of a uniformly scaled pristine source body before structural deformation;
- replacement of the generated passenger-car body and four presentation wheels;
- existing CrashVector paint selection;
- direct coupling to front, rear and lateral structural displacement;
- class-specific rebuild to the SUV asset.

The manual `tests/presentation_visual_snapshot.gd` review additionally covers all six classes at 1280x720, 1920x1080 and 2560x1440 in three camera views and checks the production presentation adapter, body finish and source wheel-opening alignment. `tests/presentation_deformation_snapshot.gd` renders representative frontal, rear and broadside production crashes for human review.

The pre-existing M17 and M18 regressions remain responsible for reciprocal-impact and side-impact physics. The Kenney integration does not weaken or replace those gates.
