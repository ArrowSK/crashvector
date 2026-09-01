# Architecture

## M0 and M1 foundation

CrashVector separates deterministic physics state from rendering and UI.

- `src/analysis/physics_metrics.gd` contains side-effect-free SI-unit calculations.
- `src/vehicles/impact_vehicle.gd` remains the original M0 rigid-body baseline.
- `src/structural/structural_node.gd` defines lumped structural masses.
- `src/structural/structural_beam.gd` implements elastic, damping, plastic, and fracture behaviour.
- `src/structural/structural_model.gd` advances the structural graph and records energy/contact diagnostics.
- `src/structural/structural_sled_builder.gd` and `structural_sled.gd` remain the M1 development proof.

## M2 vehicle composition

M2 introduces a full generic compact-hatchback architecture without pretending to be an OEM vehicle model.

### Structural definition

`CompactHatchbackBuilder` creates seven longitudinal stations and four structural nodes per station. The stations define a hatchback-like envelope and distribute the configured vehicle mass across the structure.

Beams are grouped into four behaviour zones:

- `rear_crush` — sacrificial rear structure;
- `safety_cell` — deliberately stiff passenger compartment;
- `front_transition` — intermediate load path between cabin and nose;
- `front_crush` — sacrificial front structure.

These profiles are development parameters, not material cards derived from a production car.

### Global motion extraction

The structural node graph remains the authoritative physical state. `VehicleKinematics` derives whole-vehicle quantities from that state:

- mass-weighted centre-of-mass translation;
- total linear momentum;
- an approximate rigid angular velocity from nodal angular momentum and a scalar inertia approximation;
- translational and rotational kinetic-energy components;
- residual internal/deformation kinetic energy;
- a live reference transform from front/rear and left/right structural node groups.

This prevents the rendering layer from inventing a second, conflicting vehicle trajectory while still giving later systems a stable whole-vehicle reference frame.

### Exterior deformation mapping

`DeformableBodyShell` generates a procedural surface from the live structural station nodes. Side, roof/bonnet/hatch, underbody, front, and rear surfaces are rebuilt from the current structural positions.

The M2 shell is intentionally low-resolution. It proves that visible body geometry can be driven directly by the structural solution. Production body-panel topology, skinning weights, glass, seams, doors, and local buckling remain later work.

### Wheels and suspension

`SimpleWheelRig` creates four wheel visuals anchored to the lower structural nodes at representative front and rear axle stations. It applies a small spring-like visual following response and a ground clamp to expose suspension travel in the prototype.

This is not yet a tyre-force or suspension-dynamics solver. M2 establishes attachment and deformation-following architecture only.

### Detachable components

`CompactHatchback` contains a front-bumper visual that remains attached to the front structure until front-crush damage exceeds a configured development threshold. It then transitions to simple ballistic motion.

This establishes the state transition required for later detachable panels without treating the current bumper motion as calibrated crash behaviour.

## Determinism

For identical scenario inputs, engine version, fixed timestep, and solver settings, the structural state must remain deterministic within regression tolerances. M2 extends determinism tests to the complete generic hatchback model.

## Units

All internal calculations use SI units: metres, seconds, kilograms, newtons, joules, and radians. Display conversions belong at the UI/analysis boundary.
