# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for preset_id in [
		PassengerCarCatalog.C_SEGMENT_COMPACT,
		PassengerCarCatalog.D_SEGMENT_MIDSIZE,
		PassengerCarCatalog.J_SEGMENT_SUV,
		PassengerCarCatalog.M_SEGMENT_MPV,
	]:
		await _check_material_presentation(preset_id)

	if failures.is_empty():
		print("CrashVector passenger-car material presentation regression passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _check_material_presentation(preset_id: StringName) -> void:
	var vehicle := M17CompactHatchback.new()
	vehicle.name = "PassengerMaterialRegression_%s" % preset_id
	vehicle.vehicle_preset_id = preset_id
	vehicle.origin_offset_m = Vector3.ZERO
	vehicle.auto_step = false
	root.add_child(vehicle)
	for _frame in range(3):
		await process_frame

	var visual := M162VehicleVisual.new()
	visual.name = "PassengerMaterialVisual_%s" % preset_id
	vehicle.add_child(visual)
	visual.configure(vehicle)
	for _frame in range(4):
		await process_frame

	var skin := visual.kenney_skin as KenneyVehiclePresentation3D
	_expect(skin != null and skin.active, "%s did not activate the Kenney production skin" % preset_id)
	if skin == null or not skin.active:
		vehicle.queue_free()
		await process_frame
		return

	_expect(
		String(skin.get_meta("presentation_body_finish", "")) == "layered_automotive",
		"%s did not activate the layered automotive body finish" % preset_id
	)
	_expect(
		bool(skin.get_meta("presentation_detail_overlay", false)),
		"%s did not activate separate detail-material layers" % preset_id
	)
	_expect(
		skin.body_asset_path == KenneyVehicleAssetCatalog.passenger_car_body_path(preset_id),
		"%s material pass changed the validated Kenney body mapping" % preset_id
	)

	var body_material := _first_base_material(skin)
	_expect(body_material != null, "%s imported body has no BaseMaterial3D" % preset_id)
	if body_material != null:
		_expect(body_material.metallic >= 0.30, "%s body finish is still effectively non-metallic" % preset_id)
		_expect(body_material.roughness <= 0.26, "%s body finish is still too matte" % preset_id)
		var previous_paint := vehicle.paint_id
		vehicle.paint_id = CarPaintCatalog.ELECTRIC_BLUE
		skin._update_paint()
		var blue := body_material.albedo_color
		vehicle.paint_id = CarPaintCatalog.CRIMSON
		skin._update_paint()
		var red := body_material.albedo_color
		_expect(not blue.is_equal_approx(red), "%s body paint no longer follows the CrashVector paint selector" % preset_id)
		vehicle.paint_id = previous_paint
		skin._update_paint()

	_expect(not visual.body_instance.visible, "%s procedural painted body is visible below the Kenney shell" % preset_id)
	_expect(visual.glass_instance.visible, "%s has no separate visible glass layer" % preset_id)
	_expect(visual.trim_instance.visible, "%s has no separate visible trim layer" % preset_id)
	_expect(visual.accent_instance.visible, "%s has no separate visible body-accent layer" % preset_id)

	_expect(
		visual.glass_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,
		"%s glass material is not using alpha transparency" % preset_id
	)
	_expect(visual.glass_material.albedo_color.a < 0.90, "%s glass layer is still effectively opaque" % preset_id)
	_expect(visual.glass_material.roughness < visual.trim_material.roughness, "%s glass and trim do not have distinct surface response" % preset_id)

	_expect(not visual.headlamps.is_empty(), "%s is missing headlamp detail nodes" % preset_id)
	_expect(not visual.tail_lamps.is_empty(), "%s is missing tail-lamp detail nodes" % preset_id)
	for lamp in visual.headlamps:
		_expect(lamp.visible, "%s headlamp detail is hidden" % preset_id)
	for lamp in visual.tail_lamps:
		_expect(lamp.visible, "%s tail-lamp detail is hidden" % preset_id)
	_expect(visual.lamp_material.emission_enabled, "%s headlamps are not emissive" % preset_id)
	_expect(visual.tail_material.emission_enabled, "%s tail lamps are not emissive" % preset_id)
	_expect(
		visual.lamp_material.emission_energy_multiplier >= 0.35,
		"%s headlamp emission is too weak to read as a separate lens/material" % preset_id
	)
	_expect(
		visual.tail_material.emission_energy_multiplier >= 0.28,
		"%s tail-lamp emission is too weak to read as a separate lens/material" % preset_id
	)

	_expect(visual.wheel_tires.size() == 4 and visual.wheel_rims.size() == 4 and visual.wheel_hubs.size() == 4, "%s wheel presentation is incomplete" % preset_id)
	if visual.wheel_tires.size() == 4 and visual.wheel_rims.size() == 4 and visual.wheel_hubs.size() == 4:
		var tire_material := _primitive_material(visual.wheel_tires[0])
		var rim_material := _primitive_material(visual.wheel_rims[0])
		var hub_material := _primitive_material(visual.wheel_hubs[0])
		_expect(tire_material != null and rim_material != null and hub_material != null, "%s wheel materials were not resolved" % preset_id)
		if tire_material != null and rim_material != null:
			_expect(tire_material.roughness >= 0.80, "%s tyre material is too glossy" % preset_id)
			_expect(rim_material.metallic >= 0.85, "%s rim material is not convincingly metallic" % preset_id)
			_expect(rim_material.roughness <= 0.22, "%s rim material is too matte" % preset_id)
			_expect(rim_material != tire_material, "%s tyre and rim still share one material" % preset_id)
		if hub_material != null and rim_material != null:
			_expect(hub_material != rim_material, "%s wheel hub and rim still share one material" % preset_id)

	vehicle.queue_free()
	await process_frame

func _first_base_material(skin: KenneyVehicleSkin3D) -> BaseMaterial3D:
	for material in skin.surface_materials:
		if material is BaseMaterial3D:
			return material as BaseMaterial3D
	return null

func _primitive_material(instance: MeshInstance3D) -> StandardMaterial3D:
	if instance == null or not instance.mesh is PrimitiveMesh:
		return null
	var material := (instance.mesh as PrimitiveMesh).material
	return material as StandardMaterial3D if material is StandardMaterial3D else null

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
