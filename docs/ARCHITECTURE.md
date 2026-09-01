# Architecture

## Layering

CrashVector deliberately separates structural mechanics, whole-vehicle kinematics, rendering and scenario orchestration.

### Structural layer

- `StructuralNode` — lumped mass, position, velocity and accumulated force.
- `StructuralBeam` — axial spring/damper response, plastic flow and fracture.
- `StructuralModel` — fixed-substep graph integration and energy/contact diagnostics.

### Passenger-car layer

- `PassengerCarCatalog` defines generic B-, C- and D-segment development presets without production-model branding.
- `PassengerCarBuilder` scales the M2 28-node architecture by preset dimensions, mass and stiffness.
- `CompactHatchback` remains the compatibility vehicle node from M2, but can now instantiate any catalog preset.
- `DeformableBodyShell`, `SimpleWheelRig` and `StructuralDebugRenderer` map structural state into the visible car.

### Heavy-truck layer

- `HeavyTruckBuilder` creates a 32-node tractor/trailer structural approximation with trailer, tractor, chassis, fifth-wheel and rear-underride roles.
- `HeavyTruck` owns the truck model and low-resolution procedural visuals.

### Coupled collision layer

- `VehiclePairContact` resolves paired node contacts with equal-and-opposite impulses.
- `VehiclePairSimulation` advances the car and truck on a common substep clock, applies contact after each structural substep and tracks system momentum/energy diagnostics.

The M3 rear-impact model intentionally contacts the lower front car nodes against the truck's rear-underride nodes. This makes underride geometry an explicit part of the structural scenario instead of replacing the truck with an immovable wall.

## Determinism

Identical scenario inputs, engine version and solver configuration are expected to produce identical state within regression tolerance. CI covers the deterministic structural baseline and coupled-contact invariants.

## Units

Internal calculations use SI units: metres, seconds, kilograms, newtons, joules and radians. Display conversion belongs at the UI/analysis boundary.

## Scope boundary

M3 is still an educational development model. Generic car classes are representative categories rather than specific production vehicles. The heavy truck is a simplified deformable tractor/trailer graph and does not yet include a true articulated multibody fifth-wheel joint, tyre-force model or suspension-force model.
