# M13 — Progressive whole-body structural failure

M13 extends the M12 hybrid rigid-body architecture so extreme frontal impacts do not terminate structurally when the engineered front crush zone reaches its travel limit.

## Why this milestone exists

M12 fixed the more serious whole-vehicle dynamics problem: the passenger car and articulated truck now use Godot `RigidBody3D` for world translation, rotation, mass/inertia, gravity, CCD, road support and collision response. That removed the visibly implausible launch and jump behaviour of the older spring-cloud world solver.

However, M12 deliberately anchored the passenger compartment to the rigid chassis and only allowed the refined engine-bay nodes to deform. That was stable at ordinary crash speeds but created an artificial high-energy boundary. Once roughly the front crush-zone length had disappeared, extra impact demand could no longer propagate through the firewall and body structure.

M13 keeps M12's stable world dynamics and changes only the local structural-failure model.

## Architecture

The production passenger car remains two coupled layers:

1. `VehicleRigidChassis` is authoritative for whole-car position, orientation, linear/angular velocity, gravity, road contact, suspension and rigid collision response.
2. `CompactHatchback` maintains the M11/M12 structural station graph as local deformation relative to that rigid chassis.

Base passenger-cell nodes remain pinned in the structural solver. This is intentional: unpinning them would let the historical reduced-order graph move the whole car again and would reintroduce the instability M12 was designed to eliminate. M13 instead moves those anchored stations kinematically relative to the rigid chassis only when a later failure stage is activated.

## Collision demand

M13 tracks the peak normal collision energy while the front distance probe is engaged.

For a static target the generic demand estimate is:

`E = 0.5 * m * v_normal^2`

For a rigid dynamic target the model uses relative normal closing speed and reduced mass:

`m_eff = m1*m2/(m1+m2)`

`E = 0.5 * m_eff * v_relative_normal^2`

This prevents stage selection from being a simple speed lookup. The same car speed can therefore produce different structural demand against a wall, another passenger car or a much heavier truck.

## Staged structural failure

The current generic B-class-scaled progression is:

- front crush zone: bumper, crash boxes, rails and engine bay;
- firewall/cowl intrusion after the front zone is substantially exhausted;
- floor/rocker and A-pillar/roof deformation;
- passenger-cell longitudinal shortening and roof collapse at larger residual demand;
- rear-body buckling at the highest demand represented by the educational model.

The project reference capacities are approximately 430 kJ for the front stage, followed by 260 kJ firewall, 620 kJ passenger-cell and 520 kJ rear-body stages, scaled by the generic class longitudinal/stiffness factors. They are phenomenological CrashVector calibration parameters, not manufacturer body-in-white energies.

Stage transitions also require the front zone to be materially exhausted. Energy alone cannot cause a remote cabin collapse before the front structure has consumed its available travel.

## Collision-volume coupling

M12's protected-cell collision box originally stayed fixed even when local visual structure was exhausted. M13 stores its undeformed dimensions and progressively retreats the front collision face when firewall/passenger-cell collapse occurs.

This matters because the wall can then advance physically farther relative to the rigid chassis while the cell collapses. The additional shortening is therefore not merely a mesh animation hidden inside an unchanged invisible collision box.

The collision box keeps a minimum remaining length so it cannot invert or disappear numerically. The front distance probe follows the current structural front face throughout catastrophic collapse.

## Visual deformation

The existing `DeformableBodyShell` rebuilds painted body, glass and trim from the structural stations every update. Because M13 moves the base cabin stations themselves, severe impacts naturally change:

- firewall/cowl position;
- A-pillar and roof-line geometry;
- window/door aperture shape;
- floor and rocker relationship;
- rear passenger-cell stations and rear body where the final stage activates.

This is still a coarse generic shell, not a finite-element body panel simulation.

## Regression gates

M13 has two complementary acceptance cases.

### 50 km/h B-class into rigid wall

The moderate-impact preservation test ensures M13 does not destroy the cabin simply because the new failure path exists. Current branch result:

- peak normal collision demand: about 105.0 kJ;
- front crush: about 0.536 m;
- firewall intrusion: 0.000 m;
- cabin collapse: 0.000 m;
- rear buckle: 0.000 m.

### 200 km/h B-class into rigid wall

The severe test explicitly rejects the original user-visible failure where only the nose collapsed. Current branch result:

- peak normal collision demand: about 1,739.2 kJ;
- front-zone crush: about 0.945 m;
- firewall intrusion: about 0.300 m;
- passenger-cell collapse: about 0.820 m;
- rear-body buckle: about 0.231 m;
- combined longitudinal collapse: about 1.948 m;
- maximum reverse speed: about 0.015 m/s;
- maximum vertical chassis rise: about 0.005 m;
- maximum pitch: about 0.89°.

The same severe condition is also included in the canonical hybrid-physics regression that Core CI already executes, so a release cannot pass solely because the dedicated M13 workflow is green.

## Limitations

CrashVector remains an educational reduced-order simulator. M13 does not claim:

- manufacturer-specific crashworthiness;
- finite-element structural accuracy;
- exact intrusion measurements for a real vehicle;
- occupant injury or survivability prediction;
- homologation, NCAP or accident-reconstruction validity.

The purpose of M13 is to remove an obvious nonphysical discontinuity: extreme collision demand can now progressively defeat later body zones instead of reaching an artificial hard stop after the front metre of the vehicle.
