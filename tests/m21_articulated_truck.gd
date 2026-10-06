# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

var failures: Array[String] = []
var finished := false

func _initialize() -> void:
	create_timer(95.0).timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://app/main.tscn") as PackedScene
	_expect(packed != null, "M21 production scene must load")
	if packed == null:
		_finish()
		return

	var editor := packed.instantiate()
	editor.set("m10_first_run_applied", true)
	var config := ScenarioConfig.new()
	config.title = "M21 articulated truck rear-quarter broadside regression"
	config.car_preset_id = PassengerCarCatalog.C_SEGMENT_COMPACT
	config.car_mass_kg = PassengerCarCatalog.default_mass_kg(config.car_preset_id)
	config.car_position_m = Vector3(-8.0, 0.0, 0.0)
	config.car_heading_deg = 0.0
	config.car_speed_kmh = 60.0
	config.apply_target_defaults(ScenarioConfig.TARGET_TRUCK)
	config.target_heading_deg = -90.0
	config.target_speed_kmh = 0.0
	# Local truck +X maps approximately across world +Z at -90 degrees. Placing
	# the origin at z=-1.5 brings a rear-quarter trailer section onto the primary
	# lane, creating an articulation moment rather than a perfectly centred hit.
	config.target_position_m = Vector3(3.0, 0.0, -1.5)
	config.duration_s = 2.4
	config.solver_substeps = 12
	_expect(config.validation_errors().is_empty(), "M21 articulation scenario failed preflight: %s" % "; ".join(config.validation_errors()))
	editor.set("scenario", config)
	root.add_child(editor)
	for _frame in range(8):
		await process_frame
	await physics_frame

	var preview_truck := editor.get("truck") as M21HeavyTruck
	_expect(preview_truck != null, "M21 production routing did not instantiate M21HeavyTruck")
	if preview_truck != null:
		_expect(preview_truck.rigid_chassis != null and preview_truck.tractor_chassis != null, "M21 truck does not expose separate trailer and tractor rigid bodies")
		_expect(preview_truck.fifth_wheel_joint != null, "M21 truck has no fifth-wheel joint")
		var represented_mass := preview_truck.rigid_chassis.mass + preview_truck.tractor_chassis.mass
		_expect(absf(represented_mass - config.target_mass_kg) < 1.0, "M21 articulated body masses do not preserve target mass: %.1f vs %.1f kg" % [represented_mass, config.target_mass_kg])
		_expect(preview_truck.fifth_wheel_separation_m() < 0.01, "M21 fifth-wheel anchors are separated before simulation")
		var preview_skin := editor.get("m162_truck_skin") as M21HeavyTruckVisual
		_check_articulated_presentation(preview_skin, preview_truck)

	editor.call("_on_simulate_pressed")
	# M17's inherited begin path historically restores a one-piece frame. M21
	# must immediately restore the split trailer/tractor frame dimensions before
	# the first physics tick so an invisible trailer-attached frame cannot span
	# through the articulated tractor region.
	if preview_truck != null:
		var trailer_frame_box := preview_truck.frame_collision.shape as BoxShape3D if preview_truck.frame_collision != null else null
		var tractor_frame_box := preview_truck.tractor_frame_collision.shape as BoxShape3D if preview_truck.tractor_frame_collision != null else null
		_expect(trailer_frame_box != null and trailer_frame_box.size.x <= M21HeavyTruck.TRAILER_FRAME_BASE_SIZE.x + 0.01, "M21 run start restored the historical full-length frame onto the trailer body")
		_expect(tractor_frame_box != null and tractor_frame_box.size.x <= M21HeavyTruck.TRACTOR_FRAME_BASE_SIZE.x + 0.01, "M21 run start lost the separate tractor frame dimensions")
	await physics_frame
	var completed := false
	for _frame in range(1500):
		if not bool(editor.get("simulation_running")):
			completed = true
			break
		await physics_frame
	_expect(completed, "M21 articulated-truck production run did not complete")
	for _frame in range(5):
		await process_frame

	var truck := editor.get("truck") as M21HeavyTruck
	var impacting_car := editor.get("car") as M17CompactHatchback
	_expect(truck != null, "M21 articulated truck disappeared during production run")
	if truck != null:
		_expect(impacting_car != null and impacting_car.hybrid_contact_count() > 0, "M21 rear-quarter scenario produced no real Godot contact with the articulated truck")
		_expect(truck.maximum_articulation_yaw_deg > 0.05, "M21 rear-quarter hit produced no measurable tractor/trailer articulation")
		_expect(truck.maximum_articulation_yaw_deg <= M21HeavyTruck.MAX_FIFTH_WHEEL_YAW_DEG + 2.0, "M21 fifth-wheel yaw exceeded its configured generic envelope: %.2f deg" % truck.maximum_articulation_yaw_deg)
		_expect(truck.fifth_wheel_separation_m() < 0.18, "M21 fifth-wheel linear constraint separated by %.3f m" % truck.fifth_wheel_separation_m())
		_expect(_finite_vector(truck.rigid_chassis.global_position) and _finite_vector(truck.tractor_chassis.global_position), "M21 articulated body position became non-finite")
		_expect(truck.rigid_chassis.maximum_vertical_speed_ms < 20.0 and truck.tractor_chassis.maximum_vertical_speed_ms < 20.0, "M21 articulated truck produced an implausible vertical launch")
		var diagnostics := truck.combined_contact_manifold_diagnostics()
		_expect(String(diagnostics.get("scope", "")) == "diagnostic_only_no_solver_feedback_articulated_pair", "M21 combined contact diagnostics lost their explicit scope")
		var skin := editor.get("m162_truck_skin") as M21HeavyTruckVisual
		_check_articulated_presentation(skin, truck)

	var recorder := editor.get("replay_recorder") as ReplayRecorder
	_expect(recorder != null and recorder.recording != null and recorder.recording.has_frames(), "M21 articulated-truck case produced no replay")
	if recorder != null and recorder.recording != null:
		var last_context_value: Variant = recorder.recording.last_frame().get("context", {})
		_expect(last_context_value is Dictionary, "M21 replay final frame lost context")
		if last_context_value is Dictionary:
			var last_context: Dictionary = last_context_value
			_expect(last_context.has("target_articulation_yaw_deg"), "M21 replay context does not preserve articulation diagnostics")
			var target_contact_value: Variant = last_context.get("target_contact_manifold", {})
			_expect(target_contact_value is Dictionary and String((target_contact_value as Dictionary).get("scope", "")) == "diagnostic_only_no_solver_feedback_articulated_pair", "M21 replay context did not preserve combined articulated contact diagnostics")

	editor.queue_free()
	await process_frame
	_finish()

func _check_articulated_presentation(skin: M21HeavyTruckVisual, truck: M21HeavyTruck) -> void:
	_expect(skin != null, "M21 production presentation is missing")
	if skin == null:
		return
	_expect(skin.trailer_presentation_root != null, "M21 production presentation does not expose a separate articulated trailer root")
	_expect(skin.tractor_presentation_root != null, "M21 production presentation does not expose a separate articulated tractor root")
	if skin.trailer_presentation_root != null and skin.tractor_presentation_root != null:
		_expect(skin.trailer_presentation_root != skin.tractor_presentation_root, "M21 trailer and tractor presentation roots collapsed into one transform")

	_expect(skin.tractor_kenney_skin != null and skin.tractor_kenney_skin.active, "M21 tractor did not activate the pinned CC0 Kenney truck presentation")
	if skin.tractor_kenney_skin != null and skin.tractor_kenney_skin.active:
		_expect(
			skin.tractor_kenney_skin.source_asset_path == KenneyVehicleAssetCatalog.articulated_tractor_body_path(),
			"M21 articulated tractor used the wrong Kenney presentation asset"
		)
		_expect(
			String(skin.tractor_kenney_skin.get_meta("presentation_asset_source", "")) == "Kenney Car Kit 3.1",
			"M21 articulated tractor lost Kenney provenance metadata"
		)
		_expect(
			String(skin.tractor_kenney_skin.get_meta("presentation_role", "")) == "generic_articulated_tractor",
			"M21 articulated tractor presentation role metadata is missing"
		)
		var target_size_value: Variant = skin.tractor_kenney_skin.get_meta("presentation_target_size_m", Vector3.ZERO)
		_expect(target_size_value is Vector3, "M21 articulated tractor fit did not expose target dimensions")
		if target_size_value is Vector3:
			var target_size := target_size_value as Vector3
			_expect(target_size.x > 2.0 and target_size.x < 4.2, "M21 articulated tractor presentation length is implausible: %.2f m" % target_size.x)
			_expect(target_size.y > 2.0 and target_size.y < 3.8, "M21 articulated tractor presentation height is implausible: %.2f m" % target_size.y)
			_expect(target_size.z > 1.7 and target_size.z < 2.8, "M21 articulated tractor presentation width is implausible: %.2f m" % target_size.z)

	_expect(skin.cab_instance == null or not skin.cab_instance.visible, "M21 left the old extruded tractor cab visible below the Kenney presentation")
	_expect(skin.fifth_wheel_instance != null and skin.fifth_wheel_instance.visible, "M21 fifth-wheel plate is not visually exposed")
	_expect(skin.trailer_kingpin_plate != null and skin.trailer_kingpin_plate.visible, "M21 trailer kingpin plate is missing")
	_expect(skin.trailer_kingpin != null and skin.trailer_kingpin.visible, "M21 trailer kingpin is missing")
	_expect(skin.trailer_rear_door_left != null and skin.trailer_rear_door_right != null, "M21 trailer rear-door split is missing")
	_expect(skin.trailer_landing_legs.size() == 2, "M21 trailer landing gear does not expose two support legs")

	var gap := float(skin.get_meta("presentation_fifth_wheel_gap_m", 0.0))
	_expect(gap >= 0.12 and gap <= 1.10, "M21 visible fifth-wheel gap is implausible: %.2f m" % gap)
	var trailer_length := float(skin.get_meta("presentation_trailer_length_m", 0.0))
	var tractor_length := float(skin.get_meta("presentation_tractor_length_m", 0.0))
	_expect(trailer_length > tractor_length + 1.6, "M21 trailer/tractor visual proportions no longer read as a semi-trailer combination")

	if skin.trailer_instance != null and skin.trailer_instance.mesh is BoxMesh:
		var trailer_box := skin.trailer_instance.mesh as BoxMesh
		_expect(trailer_box.size.x > 4.8, "M21 trailer visual is too short to read as a semi-trailer")
		_expect(trailer_box.size.z > 2.0, "M21 trailer visual is too narrow to read as a road trailer")

	_expect(truck != null and truck.wheel_visuals.size() == HeavyTruckBuilder.wheel_anchor_indices().size(), "M21 articulated truck wheel presentation lost structural axle anchors")
	if truck != null:
		var station_counts := {1: 0, 4: 0, 6: 0}
		for wheel in truck.wheel_visuals:
			var anchor_index := int(wheel.get_meta("anchor_index", -1))
			var station := int(anchor_index / 4) if anchor_index >= 0 else -1
			if station_counts.has(station):
				station_counts[station] = int(station_counts[station]) + 1
		_expect(int(station_counts[1]) == 2, "M21 rear trailer axle presentation lost its left/right pair")
		_expect(int(station_counts[4]) == 2, "M21 forward trailer axle presentation lost its left/right pair")
		_expect(int(station_counts[6]) == 2, "M21 tractor axle presentation lost its left/right pair")

func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _on_watchdog_timeout() -> void:
	if finished:
		return
	push_error("M21 articulated-truck regression exceeded 95 seconds")
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if finished:
		return
	finished = true
	if failures.is_empty():
		print("CrashVector M21 articulated heavy-truck regression passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)