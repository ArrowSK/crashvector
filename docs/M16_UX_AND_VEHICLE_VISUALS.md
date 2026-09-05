# M16 — UX reset and vehicle visual overhaul

M16 is a presentation milestone. It changes how people build, inspect and replay a crash and replaces the old scaled passenger-car presentation skin with class-specific generated visual archetypes. It does **not** retune the M12–M14 crash physics.

## UX goals

The normal scenario workflow is intentionally short:

1. choose a primary vehicle class;
2. choose an impact target;
3. set the primary impact speed;
4. run the simulation.

The production shell is split into four stable regions:

- **Scenario builder** — scenario name, primary vehicle, target and impact speed;
- **3D viewport** — the crash itself, with camera/overlay controls inside the viewport;
- **Properties** — contextual primary/target geometry and mass, with solver/contact values behind **Advanced setup**;
- **Playback dock** — replay timeline, playback speed, analysis expansion and video export.

File operations and secondary application commands are removed from the primary-action cluster. Calibration/evidence, updates and About remain available through the secondary menu.

The M10 shell-region node names remain stable so older responsive-layout regressions continue to protect non-overlap and minimum viewport size.

## Vehicle visual architecture

The structural passenger-car model remains authoritative for physics. M16 attaches a presentation-only `M16VehicleVisual` to each production passenger car. It reads the current deforming structural nodes every frame and builds a denser visual skin, glazing, trim, class details and wheels around them.

When the M16 visual is active, the legacy `DeformableBodyShell` and `SimpleWheelRig` are hidden, not deleted or repurposed. Rigid collision geometry, structural beams, mass, stiffness, crush behaviour, contact probes and solver settings are unchanged.

`VehicleVisualProfileCatalog` defines visual archetypes for:

- A-segment city car;
- B-segment small hatchback;
- C-segment compact car;
- D-segment midsize car;
- J-segment SUV/crossover;
- M-segment MPV/minivan.

Profiles can vary windscreen/cabin offset, roof height, greenhouse extent, upper-body width, bonnet height, wheel radius/width, rim proportion and lower cladding. These are presentation values only and are not manufacturer-specific geometry or crash-performance claims.

## Visual target

CrashVector targets a clean engineering-visualisation style rather than photorealistic branded vehicles. Each class should be immediately recognisable by stance and silhouette while staying generic enough to avoid representing a specific production model.

In particular:

- the SUV must have a visibly taller body, higher bonnet, larger wheel package and lower cladding;
- the MPV must use a cab-forward, long-greenhouse silhouette rather than a scaled hatchback;
- the D-segment car must sit visually lower and longer than the B-segment baseline.

## Validation

M16 CI protects:

- project import/parse on Godot 4.4.1;
- the existing M10 responsive shell contract;
- presence of the new task-focused UI regions;
- attachment of the M16 production vehicle visual and hiding of the old scaled skin/wheels;
- material differences between B-class, D-class, SUV and MPV visual signatures;
- rebuilding the class-specific presentation skin when the selected vehicle class changes.

M16 does not broaden CrashVector's calibration/evidence claims. The generated class visuals are not homologation geometry and must not be described as validated manufacturer models.
