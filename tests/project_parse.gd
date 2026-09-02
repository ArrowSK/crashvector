# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

const REQUIRED_SCRIPTS: Array[String] = [
	"res://src/demo/crash_demo.gd",
	"res://src/demo/crash_demo_m5.gd",
	"res://src/demo/crash_demo_m6.gd",
	"res://src/demo/crash_demo_m7.gd",
	"res://src/demo/crash_demo_m8.gd",
	"res://src/structural/structural_sled_builder.gd",
	"res://src/vehicles/compact_hatchback_builder.gd",
	"res://src/vehicles/passenger_car_builder.gd",
	"res://src/vehicles/heavy_truck_builder.gd",
	"res://src/simulation/scenario_config.gd",
	"res://src/simulation/scenario_store.gd",
	"res://src/simulation/vehicle_pair_contact.gd",
	"res://src/simulation/vehicle_pair_simulation.gd",
	"res://src/simulation/vehicle_static_contact.gd",
	"res://src/simulation/vehicle_static_simulation.gd",
	"res://src/replay/structural_snapshot.gd",
	"res://src/replay/replay_recording.gd",
	"res://src/replay/replay_recorder.gd",
	"res://src/analysis/crash_analysis.gd",
	"res://src/analysis/analysis_overlay_3d.gd",
	"res://src/ui/crash_metric_graph.gd",
	"res://src/comparison/comparison_runner.gd",
	"res://src/comparison/comparison_lane_3d.gd",
	"res://src/visual/car_paint_catalog.gd",
	"res://src/export/cinematic_export_profile.gd",
	"res://src/export/cinematic_timeline.gd",
	"res://src/export/cinematic_camera_planner.gd",
	"res://src/export/cinematic_render_stage.gd",
	"res://src/export/ffmpeg_video_encoder.gd",
	"res://src/export/cinematic_exporter.gd",
	"res://src/calibration/calibration_reference.gd",
	"res://src/calibration/calibration_metrics.gd",
	"res://src/calibration/calibration_scope.gd",
	"res://src/calibration/calibration_runner.gd",
]

func _initialize() -> void:
	var failures: Array[String] = []
	for path in REQUIRED_SCRIPTS:
		var resource: Resource = load(path)
		if resource == null:
			failures.append("Could not load script: %s" % path)
		elif resource is Script and not (resource as Script).can_instantiate():
			failures.append("Script cannot instantiate because compilation failed: %s" % path)

	var packed: Resource = load("res://app/main.tscn")
	if packed == null or not (packed is PackedScene):
		failures.append("Could not load app/main.tscn")
	else:
		var instance: Node = (packed as PackedScene).instantiate()
		if instance == null:
			failures.append("Could not instantiate app/main.tscn")
		elif instance.get_script() == null:
			failures.append("Main editor scene has no compiled script")
		else:
			instance.free()

	if failures.is_empty():
		print("CrashVector project parse smoke test passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
