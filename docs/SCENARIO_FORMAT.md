# CrashVector Scenario Format

CrashVector uses human-readable JSON scenario files with the suffix:

`.crashvector.json`

The format is intentionally independent of Godot scene-node paths so saved scenarios remain stable as the UI and rendering implementation evolves.

## Version 1

Top-level fields:

- `format_version` — currently `1`;
- `title` — user-visible scenario name;
- `scenario_type` — currently `single_car_impact`;
- `target_type` — target/object type identifier;
- `car` — primary passenger-car definition;
- `target` — dynamic or static target definition;
- `contact` — friction and restitution parameters;
- `simulation` — duration, structural substeps, and debug-display preference.

Supported `target_type` values are:

- `passenger_car`
- `heavy_truck`
- `rigid_lorry`
- `motorcycle`
- `bicycle`
- `cyclist`
- `pedestrian`
- `rigid_wall`
- `concrete_barrier`
- `pole`
- `tree`

The editor supplies defaults for each supported target. Mass and other parameters remain editable where the model permits them.

## Passenger-car classes

Generic class IDs are:

- `a_segment_city`
- `b_segment_hatchback`
- `c_segment_compact`
- `d_segment_midsize`
- `j_segment_suv`
- `m_segment_mpv`

These IDs describe generic representative size classes only, not production models or manufacturer crash performance.

## Road-user preset IDs

Pedestrian body presets:

- `pedestrian_adult` — default 75 kg, 1.75 m
- `pedestrian_child` — default 32 kg, 1.35 m
- `pedestrian_tall_adult` — default 90 kg, 1.90 m

Bicycle presets:

- `bicycle_city` — default 16 kg
- `bicycle_road` — default 9 kg
- `bicycle_ebike` — default 24 kg

The selected road-user preset is stored as `target.preset_id`. For a riderless `bicycle`, `target.mass_kg` is the bicycle mass. For an M22 `cyclist`, the same bicycle preset selects the bicycle archetype while `target.mass_kg` stores the **combined rider + bicycle mass**. The M22 validator preserves at least a 35 kg rider share above the selected bicycle's generic mass.

The stored mass remains authoritative for the scenario inside those validation limits, so users may override a preset default without creating a new preset.

## Example car-vs-car scenario

```json
{
  "format_version": 1,
  "title": "B-segment vs C-segment rear impact",
  "scenario_type": "single_car_impact",
  "target_type": "passenger_car",
  "car": {
    "class_id": "b_segment_hatchback",
    "mass_kg": 1150.0,
    "speed_kmh": 90.0,
    "position_m": [-6.0, 0.0, 0.0],
    "heading_deg": 0.0
  },
  "target": {
    "car_class_id": "c_segment_compact",
    "preset_id": "",
    "mass_kg": 1375.0,
    "speed_kmh": 30.0,
    "position_m": [2.5, 0.0, 0.0],
    "heading_deg": 0.0
  },
  "contact": {
    "friction": 0.55,
    "restitution": 0.03
  },
  "simulation": {
    "duration_s": 4.0,
    "solver_substeps": 8,
    "show_structure": false
  }
}
```

A near head-on car-vs-car scenario uses the same format but rotates the target passenger car approximately 180 degrees and gives it the desired speed. M18 passenger-car pairs also allow arbitrary relative headings, including broadside layouts.

## Example car-vs-pedestrian scenario

```json
{
  "format_version": 1,
  "title": "Compact car vs default adult pedestrian",
  "scenario_type": "single_car_impact",
  "target_type": "pedestrian",
  "car": {
    "class_id": "c_segment_compact",
    "mass_kg": 1375.0,
    "speed_kmh": 40.0,
    "position_m": [-6.0, 0.0, 0.0],
    "heading_deg": 0.0
  },
  "target": {
    "car_class_id": "c_segment_compact",
    "preset_id": "pedestrian_adult",
    "mass_kg": 75.0,
    "speed_kmh": 0.0,
    "position_m": [2.5, 0.0, 0.0],
    "heading_deg": 0.0
  },
  "contact": {
    "friction": 0.55,
    "restitution": 0.03
  },
  "simulation": {
    "duration_s": 4.0,
    "solver_substeps": 8,
    "show_structure": false
  }
}
```

M22 allows the pedestrian's `target.speed_kmh` to be set from 0 to 20 km/h. That value gives the whole articulated pedestrian an initial translational velocity along `target.heading_deg`; CrashVector does not model walking/running gait, propulsion, foot placement or balance control.

## Validation ranges

`ScenarioConfig.validation_errors()` is the authoritative preflight-validation path. The editor invokes it before simulation and the loader invokes it before accepting a saved file.

Current important ranges are:

- primary passenger car: 500–5,000 kg and 0–300 km/h;
- target passenger car: 500–5,000 kg and 0–300 km/h;
- heavy articulated truck: 3,500–60,000 kg and 0–140 km/h;
- rigid lorry / box truck: 3,500–26,000 kg and 0–140 km/h;
- motorcycle: 80–600 kg and 0–250 km/h;
- riderless bicycle: 5–60 kg and 0–80 km/h;
- cyclist: selected-bicycle generic mass + at least 35 kg rider share, up to 220 kg combined mass, and 0–80 km/h;
- pedestrian: 15–200 kg and 0–20 km/h initial translation;
- structural solver substeps: 1–64. Normal scenarios retain their existing defaults; the M11 M8-reference correlation run uses 64 on the same public solver path for the refined 44-node passenger-car structure.

Current heading scope is target-specific:

- passenger-car pairs may use arbitrary relative headings through the M18 side-impact path;
- M20 heavy-truck, rigid-lorry and riderless-motorcycle targets may use broadside/oblique layouts with their bounded generic deformation models;
- the old `bicycle` target remains riderless and rejects strongly broadside/oblique layouts, preserving its rear-end / near-head-on scope;
- the M22 `cyclist` target permits generic broadside/oblique rider+bicycle trajectory scenarios;
- pedestrians may use arbitrary heading for their configured initial translation.

Static wall/barrier/pole/tree targets do not use dynamic-target mass or speed. Wall and concrete barrier remain non-yielding; generic pole/tree yielding is a production-model behaviour rather than a scenario-format difference.

## Compatibility and implementation notes

`heavy_truck` remains the same scenario identifier after M21. The production implementation now routes that target through separate tractor/trailer rigid bodies and a constrained fifth wheel, so saved M17/M18 truck scenarios do not require a format migration.

Likewise, the original `bicycle` identifier remains riderless. M22 introduces `cyclist` as a new target type instead of changing the meaning of previously saved bicycle scenarios.

M19–M22 source support is implemented and runtime-validated on `main`. The current verified packaged `0.9.0-beta.2` includes those target and scope additions.

## Comparison data

Comparison Lab does not introduce a separate scenario-file format. It clones a normal `ScenarioConfig`, applies one selected class/target/preset and one selected primary-car speed to each variant, then runs each variant independently through the production-scene route. This keeps comparison behaviour aligned with normal scenario validation.

## Compatibility policy

Readers should use `format_version` rather than infer behaviour from application version. Future incompatible changes should increment the format version while keeping migration logic explicit.
