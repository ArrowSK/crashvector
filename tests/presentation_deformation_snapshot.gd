# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

const OUTPUT_DIR := "res://build/presentation_deformation_review"
const VIEWPORT_SIZE := Vector2i(1280, 720)

var packed: PackedScene
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = VIEWPORT_SIZE
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		_fail("Could not create deformation-review output directory: %d" % dir_error)
		return
	packed = load("res://app/main.tscn") as PackedScene
	if packed == null:
		_fail("Could not load production scene for deformation snapshots")
		return

	await _capture_case(_frontal_case(), "01_b_segment_frontal_wall")
	await _capture_case(_rear_case(), "02_b_segment_rear_strike")
	await _capture_case(_side_case(), "03_c_segment_broadside")

	if failures.is_empty():
		print("CrashVector deformation presentation snapshots captured in %s" % absolute_dir)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _frontal_case() -> ScenarioConfig:
	var config := ScenarioConfig.new()
	config.title = "Presentation frontal reference"
	config.car_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	config.car_mass_kg = PassengerCarCatalog.default_mass_kg(config.car_preset_id)
	config.car_position_m = Vector3(-5.6, 0.0, 0.0)
	config.car_heading_deg = 0.0
	config.car_speed_kmh = 50.0
	config.apply_target_defaults(ScenarioConfig.TARGET_WALL)
	config.target_position_m = Vector3(3.2, 0.0, 0.0)
	config.target_heading_deg = 0.0
	config.duration_s = 2.4
	config.solver_substeps = 10
	return config

func _rear_case() -> ScenarioConfig:
	var config := ScenarioConfig.new()
	config.title = "Presentation rear-impact reference"
	config.car_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	config.car_mass_kg = PassengerCarCatalog.default_mass_kg(config.car_preset_id)
	config.car_position_m = Vector3(0.0, 0.0, 0.0)
	config.car_heading_deg = 0.0
	config.car_speed_kmh = 0.0
	config.apply_target_defaults(ScenarioConfig.TARGET_PASSENGER_CAR)
	config.target_car_preset_id = PassengerCarCatalog.C_SEGMENT_COMPACT
	config.target_mass_kg = PassengerCarCatalog.default_mass_kg(config.target_car_preset_id)
	config.target_position_m = Vector3(-7.0, 0.0, 0.0)
	config.target_heading_deg = 0.0
	config.target_speed_kmh = 55.0
	config.duration_s = 2.2
	config.solver_substeps = 10
	return config

func _side_case() -> ScenarioConfig:
	var config := ScenarioConfig.new()
	config.title = "Presentation broadside reference"
	config.car_preset_id = PassengerCarCatalog.C_SEGMENT_COMPACT
	config.car_mass_kg = PassengerCarCatalog.default_mass_kg(config.car_preset_id)
	config.car_position_m = Vector3.ZERO
	config.car_heading_deg = 0.0
	config.car_speed_kmh = 0.0
	config.apply_target_defaults(ScenarioConfig.TARGET_PASSENGER_CAR)
	config.target_car_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	config.target_mass_kg = PassengerCarCatalog.default_mass_kg(config.target_car_preset_id)
	config.target_position_m = Vector3(0.0, 0.0, -8.0)
	config.target_heading_deg = -90.0
	config.target_speed_kmh = 55.0
	config.duration_s = 1.7
	config.solver_substeps = 12
	return config

func _capture_case(config: ScenarioConfig, stem: String) -> void:
	var errors := config.validation_errors()
	if not errors.is_empty():
		failures.append("%s: invalid presentation case: %s" % [stem, "; ".join(errors)])
		return
	var editor := packed.instantiate()
	editor.set("m10_first_run_applied", true)
	editor.set("scenario", config)
	root.add_child(editor)
	for _frame in range(12):
		await process_frame
	await physics_frame

	editor.call("_frame_scenario")
	for _frame in range(5):
		await process_frame
	await _save_frame("%s_preview.png" % stem)

	editor.call("_on_simulate_pressed")
	await physics_frame
	var completed := false
	for _frame in range(1800):
		if not bool(editor.get("simulation_running")):
			completed = true
			break
		await physics_frame
	if not completed:
		failures.append("%s: production simulation did not complete" % stem)
	else:
		for _frame in range(10):
			await process_frame
		editor.call("_m161_frame_aftermath")
		for _frame in range(5):
			await process_frame
		await _save_frame("%s_aftermath.png" % stem)

	editor.queue_free()
	for _frame in range(4):
		await process_frame

func _save_frame(file_name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		failures.append("%s: rendered viewport image is empty" % file_name)
		return
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		failures.append("%s: PNG save failed with error %d" % [file_name, error])

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
