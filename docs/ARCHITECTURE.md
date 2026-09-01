# Architecture

## Layering

CrashVector separates structural mechanics, vehicle construction, contact resolution, scenario data, editor UI, and later replay/analysis layers.

### Structural layer

- `StructuralNode` — lumped mass, position, velocity, and accumulated force.
- `StructuralBeam` — axial spring/damper response, plastic flow, and fracture.
- `StructuralModel` — fixed-substep graph integration plus energy/contact diagnostics. M4 adds whole-model translation and yaw rotation helpers so editor transforms are applied directly to the physical state rather than only to visuals.

### Passenger-car layer

- `PassengerCarCatalog` defines generic B-, C-, and D-segment development presets without production-model branding.
- `PassengerCarBuilder` scales the shared 28-node architecture by dimensions, mass, and stiffness.
- `CompactHatchback` can instantiate any catalog preset and now supports an initial world heading.
- `DeformableBodyShell`, `SimpleWheelRig`, and `StructuralDebugRenderer` map structural state into the visible car.

A second `CompactHatchback` instance is used for car-vs-car scenarios. There is no hidden rigid proxy or truck substitution.

### Heavy-truck layer

- `HeavyTruckBuilder` creates the 32-node tractor/trailer structural approximation.
- `HeavyTruck` owns truck visuals and now supports an initial world heading.

### Dynamic-pair collision layer

- `VehiclePairContact` resolves paired node contacts using equal-and-opposite normal and Coulomb-limited tangent impulses.
- `VehiclePairSimulation` advances any two structural models on one substep clock. It is used for both car-vs-truck and car-vs-car scenarios.
- The pair normal is scenario-defined, so heading-aware rear-end and near head-on car-vs-car layouts can share the same deterministic contact implementation.

M4 deliberately limits passenger-car pair contact to rear-end or near head-on layouts. Side-impact contact needs richer body-surface geometry and will not be approximated by pretending the existing front/rear node pairs are valid side structures.

### Static-target collision layer

- `VehicleStaticContact` resolves structural-node contact with a fixed wall, barrier, pole, or tree.
- `VehicleStaticSimulation` advances the deformable car and applies static contact after each substep.
- `StaticObstacle3D` renders the editor-visible target geometry from the same scenario transform used by the contact layer.

### Scenario layer

- `ScenarioConfig` is the in-memory source of truth for object types, generic vehicle classes, masses, speeds, world positions, headings, contact parameters, duration, and solver settings.
- `ScenarioStore` serialises/deserialises human-readable `.crashvector.json` files.
- Preflight validation belongs in `ScenarioConfig`, not scattered across UI callbacks, so saved scenarios and future command-line/batch runs can share the same constraints.

### Editor layer

`src/demo/crash_demo.gd` is now the M4 application editor rather than a keyboard-only demo. It owns:

- top-level scenario actions;
- object palette;
- selected-object inspector;
- 3D move/rotate interactions;
- preview reconstruction;
- preflight invocation;
- runtime simulation state;
- save/load file dialogs;
- current diagnostics display.

The editor rebuilds a clean physical preview before every run. This avoids continuing from partially deformed state after parameter edits.

## Determinism

Identical scenario inputs, engine version, and solver configuration are expected to produce identical state within regression tolerance. CI covers structural determinism, paired-contact momentum conservation, static contact, and scenario serialisation invariants.

## Units

Internal calculations use SI units: metres, seconds, kilograms, newtons, joules, and radians. The editor displays km/h where useful but converts at the UI/physics boundary.

## Scope boundary

M4 makes CrashVector usable as a scenario-building application, but it does not make the vehicle models production-specific or validated. The B/C/D cars remain generic representative classes, the heavy truck remains a simplified tractor/trailer graph, and broadside/complex oblique contact awaits a richer contact-geometry system.
