# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not KenneyVehicleAssetCatalog.assets_available():
		_fail("Pinned Kenney Car Kit assets are not available")
		return
	if not _verify_catalog_mapping():
		return

	var packed := load("res://app/main.tscn") as PackedScene
	if packed == null:
		_fail("Kenney regression could not load the production scene")
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	for _frame in range(8):
		await process_frame

	var visual := _find_named(instance, "M16PrimaryVehicleVisual") as M162VehicleVisual
	if visual == null:
		_fail("Production scene did not attach the M16.2 passenger-car visual")
		return
	if visual.kenney_skin == null or not visual.kenney_skin.active:
		_fail("Production passenger car did not activate the Kenney Car Kit skin")
		return
	var skin := visual.kenney_skin
	var vehicle := visual.vehicle
	if vehicle == null or vehicle.model == null:
		_fail("Kenney skin is not attached to an authoritative passenger-car model")
		return
	if skin.body_instance == null or skin.body_instance.mesh == null or skin.body_instance.mesh.get_surface_count() <= 0:
		_fail("Kenney passenger-car body did not import into the production visual")
		return
	if String(skin.get_meta("presentation_asset_source", "")) != "Kenney Car Kit 3.1":
		_fail("Kenney presentation provenance metadata is missing")
		return
	if skin.body_asset_path != KenneyVehicleAssetCatalog.passenger_car_body_path(vehicle.vehicle_preset_id):
		_fail("Production passenger car used the wrong Kenney body mapping")
		return
	if visual.body_instance.visible or visual.glass_instance.visible or visual.trim_instance.visible:
		_fail("Procedural passenger-car body remained visible below the Kenney replacement")
		return
	if skin.wheel_nodes.size() != visual.wheel_groups.size() or skin.wheel_nodes.size() != 4:
		_fail("Kenney wheel package did not replace all four passenger-car wheels")
		return
	for index in range(skin.wheel_nodes.size()):
		if skin.wheel_nodes[index].get_parent() != visual.wheel_groups[index]:
			_fail("Kenney wheel is not attached to the authoritative wheel anchor group")
			return

	if not _verify_paint(vehicle, skin):
		return
	if not _verify_structural_mapping(vehicle, visual, skin):
		return
	if not await _verify_class_rebuild(instance):
		return

	instance.queue_free()
	await process_frame
	print("CrashVector Kenney Car Kit presentation regression test passed.")
	quit(0)

func _verify_catalog_mapping() -> bool:
	var expected := {
		PassengerCarCatalog.A_SEGMENT_CITY: "hatchback-sports.glb",
		PassengerCarCatalog.B_SEGMENT_HATCHBACK: "hatchback-sports.glb",
		PassengerCarCatalog.C_SEGMENT_COMPACT: "sedan.glb",
		PassengerCarCatalog.D_SEGMENT_MIDSIZE: "sedan-sports.glb",
		PassengerCarCatalog.J_SEGMENT_SUV: "suv.glb",
		PassengerCarCatalog.M_SEGMENT_MPV: "van.glb",
	}
	for preset_id in PassengerCarCatalog.preset_ids():
		var path := KenneyVehicleAssetCatalog.passenger_car_body_path(preset_id)
		if not path.ends_with(String(expected[preset_id])):
			_fail("Unexpected Kenney mapping for %s: %s" % [preset_id, path])
			return false
		if not ResourceLoader.exists(path):
			_fail("Mapped Kenney body is missing: %s" % path)
			return false
	if not ResourceLoader.exists(KenneyVehicleAssetCatalog.WHEEL_DEFAULT):
		_fail("Kenney passenger-car wheel asset is missing")
		return false
	return true

func _verify_paint(vehicle: CompactHatchback, skin: KenneyVehicleSkin3D) -> bool:
	var material := _first_base_material(skin)
	if material == null:
		_fail("Kenney body has no paintable imported material")
		return false
	vehicle.paint_id = CarPaintCatalog.ELECTRIC_BLUE
	skin._update_paint()
	var blue := material.albedo_color
	vehicle.paint_id = CarPaintCatalog.CRIMSON
	skin._update_paint()
	var red := material.albedo_color
	if blue.is_equal_approx(red):
		_fail("Existing CrashVector paint selection no longer affects the Kenney body")
		return false
	vehicle.paint_id = CarPaintCatalog.ELECTRIC_BLUE
	skin._update_paint()
	return true

func _verify_structural_mapping(vehicle: CompactHatchback, visual: M162VehicleVisual, skin: KenneyVehicleSkin3D) -> bool:
	var reference := vehicle.global_reference_transform()
	var forward := reference.basis.x.normalized()
	var right := reference.basis.z.normalized()
	var front_source := _normalized_source_point(skin, 1.0, 0.5, 0.50)
	var rear_source := _normalized_source_point(skin, 0.0, 0.5, 0.50)
	var left_source := _normalized_source_point(skin, 0.50, 0.0, 0.55)

	var front_before := skin._map_vertex(front_source)
	_shift_station(vehicle, CompactHatchbackBuilder.STATION_X.size() - 1, -forward * 0.12)
	var front_after := skin._map_vertex(front_source)
	_shift_station(vehicle, CompactHatchbackBuilder.STATION_X.size() - 1, forward * 0.12)
	if (front_after - front_before).dot(forward) > -0.075:
		_fail("Kenney body does not follow authoritative front-crush anchors")
		return false

	var rear_before := skin._map_vertex(rear_source)
	_shift_station(vehicle, 0, forward * 0.12)
	var rear_after := skin._map_vertex(rear_source)
	_shift_station(vehicle, 0, -forward * 0.12)
	if (rear_after - rear_before).dot(forward) < 0.075:
		_fail("Kenney body does not follow authoritative M17 rear-crush anchors")
		return false

	var left_before := skin._map_vertex(left_source)
	for station in range(CompactHatchbackBuilder.STATION_X.size()):
		_shift_node(vehicle, CompactHatchbackBuilder.node_index(station, 0), right * 0.10)
		_shift_node(vehicle, CompactHatchbackBuilder.node_index(station, 2), right * 0.10)
	var left_after := skin._map_vertex(left_source)
	for station in range(CompactHatchbackBuilder.STATION_X.size()):
		_shift_node(vehicle, CompactHatchbackBuilder.node_index(station, 0), -right * 0.10)
		_shift_node(vehicle, CompactHatchbackBuilder.node_index(station, 2), -right * 0.10)
	if (left_after - left_before).dot(right) < 0.060:
		_fail("Kenney body does not follow authoritative M18 lateral-intrusion anchors")
		return false

	# Rebuild once after the restored graph so the actual MeshInstance uses the
	# same path exercised above, not only the point-mapping helper.
	skin._update_body()
	if skin.body_instance.mesh == null or skin.body_instance.mesh.get_surface_count() <= 0:
		_fail("Kenney body mesh failed to rebuild after structural deformation updates")
		return false
	if visual.vehicle != vehicle:
		_fail("Kenney mapping detached presentation from the production physics object")
		return false
	return true

func _verify_class_rebuild(instance: Node) -> bool:
	var selector := _find_named(instance, "M16VehicleSelector") as OptionButton
	var suv_index := _metadata_index(selector, PassengerCarCatalog.J_SEGMENT_SUV)
	if suv_index < 0:
		_fail("Vehicle selector does not expose the SUV class")
		return false
	selector.select(suv_index)
	selector.item_selected.emit(suv_index)
	for _frame in range(8):
		await process_frame
	var visual := _find_named(instance, "M16PrimaryVehicleVisual") as M162VehicleVisual
	if visual == null or visual.kenney_skin == null or not visual.kenney_skin.active:
		_fail("Kenney skin did not survive class-specific preview rebuild")
		return false
	if not visual.kenney_skin.body_asset_path.ends_with("suv.glb"):
		_fail("SUV class did not rebuild with the Kenney SUV body")
		return false
	return true

func _normalized_source_point(skin: KenneyVehicleSkin3D, u: float, side_t: float, height_t: float) -> Vector3:
	var box := skin.source_aabb
	return Vector3(
		box.position.x + (1.0 - clampf(side_t, 0.0, 1.0)) * box.size.x,
		box.position.y + clampf(height_t, 0.0, 1.0) * box.size.y,
		box.position.z + clampf(u, 0.0, 1.0) * box.size.z
	)

func _shift_station(vehicle: CompactHatchback, station: int, delta: Vector3) -> void:
	for corner in range(4):
		_shift_node(vehicle, CompactHatchbackBuilder.node_index(station, corner), delta)

func _shift_node(vehicle: CompactHatchback, index: int, delta: Vector3) -> void:
	if index >= 0 and index < vehicle.model.nodes.size():
		vehicle.model.nodes[index].position_m += delta

func _first_base_material(skin: KenneyVehicleSkin3D) -> BaseMaterial3D:
	for material in skin.surface_materials:
		if material is BaseMaterial3D:
			return material as BaseMaterial3D
	return null

func _metadata_index(option: OptionButton, wanted: StringName) -> int:
	if option == null:
		return -1
	for index in range(option.item_count):
		if StringName(String(option.get_item_metadata(index))) == wanted:
			return index
	return -1

func _find_named(node: Node, wanted: String) -> Node:
	if String(node.name) == wanted:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted)
		if found != null:
			return found
	return null

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
