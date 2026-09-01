# CrashVector Scenario Format

CrashVector M4 uses human-readable JSON scenario files with the suffix:

`.crashvector.json`

The format is intentionally independent of Godot scene-node paths so saved scenarios remain stable as the UI and rendering implementation evolves.

## Version 1

Top-level fields:

- `format_version` — currently `1`;
- `title` — user-visible scenario name;
- `scenario_type` — currently `single_car_impact`;
- `target_type` — `passenger_car`, `heavy_truck`, `rigid_wall`, `concrete_barrier`, `pole`, or `tree`;
- `car` — primary passenger-car definition;
- `target` — dynamic or static target definition;
- `contact` — friction and restitution parameters;
- `simulation` — duration, structural substeps, and debug-display preference.

Example car-vs-car scenario:

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

A head-on car-vs-car scenario uses the same format but rotates the target passenger car approximately 180 degrees and gives it a non-zero speed.

## Generic passenger-car IDs

- `b_segment_hatchback`
- `c_segment_compact`
- `d_segment_midsize`

These IDs describe generic size classes only, not production models.

## Validation

`ScenarioConfig.validation_errors()` is the authoritative M4 preflight validation path. The editor invokes it before simulation and the loader invokes it before accepting a saved file.

M4 rejects unsupported broadside/strongly oblique car-vs-car layouts rather than silently using the front/rear paired-node contact model outside its intended range.

## Compatibility policy

Readers should use `format_version` rather than infer behaviour from application version. Future incompatible changes should increment the format version while keeping migration logic explicit.
