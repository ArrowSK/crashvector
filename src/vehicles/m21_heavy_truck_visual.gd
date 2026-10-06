# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name M21HeavyTruckVisual
extends M20HeavyTruckVisual

# M21 keeps the existing articulated physics and deformation authority, but the
# production presentation now has explicit trailer and tractor roots. The
# tractor uses the pinned CC0 Kenney truck body as presentation-only geometry,
# fitted to the current tractor structural envelope. The box trailer remains
# CrashVector-authored because the pinned Car Kit contains no semantically
# suitable semi-trailer mesh. Both roots are reconstructed from structural nodes,
# so replay never depends on the live final RigidBody3D transforms.

var trailer_presentation_root: Node3D
var tractor_presentation_root: Node3D
var tractor_frame_instance: MeshInstance3D
var tractor_kenney_skin: KenneyFittedAsset3D
var trailer_roof_instance: MeshInstance3D
var trailer_floor_instance: MeshInstance3D
var trailer_rear_door_left: MeshInstance3D
var trailer_rear_door_right: MeshInstance3D
var trailer_kingpin_plate: MeshInstance3D
var trailer_kingpin: MeshInstance3D
var trailer_landing_legs: Array[MeshInstance3D] = []

func configure(target: HeavyTruck) -> void:
	super.configure(target)
	if not (target is M21HeavyTruck):
		return

	trailer_presentation_root = Node3D.new()
	trailer_presentation_root.name = "ArticulatedTrailerPresentationRoot"
	add_child(trailer_presentation_root)
	for instance in [trailer_instance, chassis_instance, trailer_front_trim, trailer_rear_trim]:
		_m21_reparent_preserving_local(instance, trailer_presentation_root)

	tractor_presentation_root = Node3D.new()
	tractor_presentation_root.name = "ArticulatedTractorPresentationRoot"
	add_child(tractor_presentation_root)
	for instance in [cab_instance, windshield_instance, grille_instance, bumper_instance, fifth_wheel_instance]:
		_m21_reparent_preserving_local(instance, tractor_presentation_root)

	tractor_frame_instance = _box("ArticulatedTractorFramePresentation", M21HeavyTruck.TRACTOR_FRAME_BASE_SIZE, _dark_material)
	tractor_frame_instance.position = M21HeavyTruck.TRACTOR_FRAME_BASE_POS
	_m21_reparent_preserving_local(tractor_frame_instance, tractor_presentation_root)

	_build_articulated_trailer_details()
	_build_kenney_tractor_skin()
	_update_pose()

func _process(_delta: float) -> void:
	if truck == null or not is_instance_valid(truck):
		queue_free()
		return
	_update_pose()

func _update_pose() -> void:
	super._update_pose()
	if tractor_presentation_root == null or not (truck is M21HeavyTruck) or truck.model == null:
		return

	var trailer_mapping := _m21_structural_mapping(1, HeavyTruckBuilder.TRAILER_END_STATION, 1)
	var tractor_mapping := _m21_structural_mapping(5, HeavyTruckBuilder.FRONT_STATION, 6)
	global_transform = trailer_mapping
	if trailer_presentation_root != null:
		trailer_presentation_root.transform = Transform3D.IDENTITY
	tractor_presentation_root.global_transform = tractor_mapping

	# Re-run the inherited structure-derived trailer widths in the corrected
	# trailer frame. The M17 update above ran before the articulated root was
	# reconstructed, so these absolute structural readings are the authoritative
	# final presentation step.
	_m17_update_geometry_from_model()
	_m20_resize_box_from_stations(trailer_instance, [1, 2, 3, 4], 2.42, 2.44, 1.55)
	_m20_resize_box_from_stations(trailer_front_trim, [4], 2.34, 2.44, 1.50)
	_m20_resize_box_from_stations(trailer_rear_trim, [1], 2.34, 2.44, 1.50)

	# The inherited single frame would otherwise visually bridge the articulated
	# joint. Keep it as the trailer frame and provide a separate tractor frame.
	if chassis_instance != null:
		var frame_mesh := chassis_instance.mesh as BoxMesh
		if frame_mesh != null:
			var frame_size := frame_mesh.size
			frame_size.x = M21HeavyTruck.TRAILER_FRAME_BASE_SIZE.x
			frame_mesh.size = frame_size
		chassis_instance.position.x = M21HeavyTruck.TRAILER_FRAME_BASE_POS.x
	_m21_update_tractor_geometry(tractor_mapping)
	_m21_update_kenney_tractor_fit(tractor_mapping)
	_m21_update_trailer_detail_geometry()

func _build_kenney_tractor_skin() -> void:
	tractor_kenney_skin = KenneyFittedAsset3D.new()
	tractor_kenney_skin.name = "KenneyArticulatedTractorPresentation"
	tractor_presentation_root.add_child(tractor_kenney_skin)
	# Car Kit does not contain a dedicated semi-tractor. Its generic CC0 truck is
	# nevertheless a much clearer cab/chassis presentation than the old extruded
	# polygon. Wheels stay hidden because CrashVector's structural wheel anchors
	# remain the authoritative rolling presentation.
	tractor_kenney_skin.configure(KenneyVehicleAssetCatalog.articulated_tractor_body_path(), true)
	if not tractor_kenney_skin.active:
		return
	tractor_kenney_skin.set_meta("presentation_role", "generic_articulated_tractor")
	tractor_kenney_skin.set_meta("presentation_semantics", "cc0_truck_fitted_to_crashvector_tractor")
	# Hide only the old authored cab shell and its decorative children. The
	# fifth-wheel plate and structural tractor frame remain visible because they
	# communicate the articulation boundary.
	for instance in [cab_instance, windshield_instance, grille_instance, bumper_instance]:
		if instance != null:
			instance.visible = false

func _build_articulated_trailer_details() -> void:
	trailer_roof_instance = _box("ArticulatedTrailerRoof", Vector3(5.72, 0.10, 2.42), _metal_material)
	trailer_roof_instance.position = Vector3(3.48, 3.56, 0.0)
	_m21_reparent_preserving_local(trailer_roof_instance, trailer_presentation_root)

	trailer_floor_instance = _box("ArticulatedTrailerLowerRail", Vector3(5.72, 0.12, 2.20), _dark_material)
	trailer_floor_instance.position = Vector3(3.48, 0.72, 0.0)
	_m21_reparent_preserving_local(trailer_floor_instance, trailer_presentation_root)

	trailer_rear_door_left = _box("ArticulatedTrailerRearDoorLeft", Vector3(0.055, 2.46, 1.12), _trailer_material)
	trailer_rear_door_left.position = Vector3(0.575, 2.13, -0.58)
	_m21_reparent_preserving_local(trailer_rear_door_left, trailer_presentation_root)
	trailer_rear_door_right = _box("ArticulatedTrailerRearDoorRight", Vector3(0.055, 2.46, 1.12), _trailer_material)
	trailer_rear_door_right.position = Vector3(0.575, 2.13, 0.58)
	_m21_reparent_preserving_local(trailer_rear_door_right, trailer_presentation_root)

	trailer_kingpin_plate = _box("ArticulatedTrailerKingpinPlate", Vector3(0.82, 0.08, 1.18), _dark_material)
	trailer_kingpin_plate.position = Vector3(6.36, 0.91, 0.0)
	_m21_reparent_preserving_local(trailer_kingpin_plate, trailer_presentation_root)
	trailer_kingpin = _child_cylinder(trailer_presentation_root, "ArticulatedTrailerKingpin", 0.065, 0.28, _metal_material)
	trailer_kingpin.position = Vector3(6.50, 0.74, 0.0)

	for side in [-1.0, 1.0]:
		var leg := _box("ArticulatedTrailerLandingLeg", Vector3(0.12, 0.82, 0.12), _metal_material)
		leg.position = Vector3(5.92, 0.39, side * 0.78)
		_m21_reparent_preserving_local(leg, trailer_presentation_root)
		trailer_landing_legs.append(leg)

func _m21_update_kenney_tractor_fit(tractor_mapping: Transform3D) -> void:
	if tractor_kenney_skin == null or not tractor_kenney_skin.active or truck == null or truck.model == null:
		return
	var inverse := tractor_mapping.affine_inverse()
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for station in [5, 6, 7]:
		for corner in range(4):
			var index := HeavyTruckBuilder.node_index(station, corner)
			if index < 0 or index >= truck.model.nodes.size():
				continue
			var local := inverse * truck.model.nodes[index].position_m
			minimum = minimum.min(local)
			maximum = maximum.max(local)

	# Extend the structural cab envelope down to the road-facing chassis and a
	# little rearward over the tractor frame, but keep a visible fifth-wheel gap.
	minimum.x -= 0.20
	maximum.x += 0.06
	minimum.y -= 0.48
	maximum.y += 0.05
	minimum.z -= 0.04
	maximum.z += 0.04
	var target_size := maximum - minimum
	var center_local := (minimum + maximum) * 0.5
	var center_world := tractor_mapping * center_local
	tractor_kenney_skin.fit_to_world_box(tractor_mapping.basis, center_world, target_size)
	tractor_kenney_skin.set_meta("presentation_target_size_m", target_size)
	tractor_kenney_skin.set_meta("presentation_target_center_local_m", center_local)

	var trailer_front_x := 6.34
	var visible_gap := maxf(minimum.x - trailer_front_x, 0.0)
	set_meta("presentation_fifth_wheel_gap_m", visible_gap)
	set_meta("presentation_tractor_length_m", target_size.x)
	set_meta("presentation_trailer_length_m", 5.72)

func _m21_update_trailer_detail_geometry() -> void:
	if trailer_instance == null:
		return
	var trailer_mesh := trailer_instance.mesh as BoxMesh
	if trailer_mesh == null:
		return
	var length := trailer_mesh.size.x
	var center_x := trailer_instance.position.x
	if trailer_roof_instance != null and trailer_roof_instance.mesh is BoxMesh:
		var roof_mesh := trailer_roof_instance.mesh as BoxMesh
		var roof_size := roof_mesh.size
		roof_size.x = length
		roof_mesh.size = roof_size
		trailer_roof_instance.position.x = center_x
	if trailer_floor_instance != null and trailer_floor_instance.mesh is BoxMesh:
		var floor_mesh := trailer_floor_instance.mesh as BoxMesh
		var floor_size := floor_mesh.size
		floor_size.x = length
		floor_mesh.size = floor_size
		trailer_floor_instance.position.x = center_x

func _m21_update_tractor_geometry(tractor_mapping: Transform3D) -> void:
	var inverse := tractor_mapping.affine_inverse()
	var cab_rear := inverse * truck.model.average_position_for_nodes(HeavyTruckBuilder.station_nodes(5))
	var front := inverse * truck.model.average_position_for_nodes(HeavyTruckBuilder.station_nodes(HeavyTruckBuilder.FRONT_STATION))

	if cab_instance != null:
		var base_rear := 7.14
		var base_front := 9.50
		var wanted_rear := cab_rear.x - 0.08
		var wanted_front := front.x
		var scale_x := clampf((wanted_front - wanted_rear) / (base_front - base_rear), 0.58, 1.08)
		var scale_value := cab_instance.scale
		scale_value.x = scale_x
		cab_instance.scale = scale_value
		cab_instance.position.x = wanted_rear - base_rear * scale_x
	if windshield_instance != null:
		windshield_instance.position.x = front.x - 0.17
	if grille_instance != null:
		grille_instance.position.x = front.x - 0.02
	if bumper_instance != null:
		bumper_instance.position.x = front.x + 0.03
	if fifth_wheel_instance != null:
		fifth_wheel_instance.position.x = M21HeavyTruck.FIFTH_WHEEL_LOCAL.x

	var bounds := _m21_lateral_bounds([5, 6, 7], tractor_mapping)
	var base_width := 2.24
	var width_scale := base_width / 2.36
	var negative_face := bounds.x * width_scale
	var positive_face := bounds.y * width_scale
	if positive_face - negative_face < 1.45:
		var center := (positive_face + negative_face) * 0.5
		negative_face = center - 1.45 * 0.5
		positive_face = center + 1.45 * 0.5
	var width := positive_face - negative_face
	var center_z := (positive_face + negative_face) * 0.5
	if cab_instance != null:
		var cab_scale := cab_instance.scale
		cab_scale.z = width / base_width
		cab_instance.scale = cab_scale
		cab_instance.position.z = center_z
	for detail in [windshield_instance, grille_instance, bumper_instance]:
		if detail == null:
			continue
		var detail_mesh := detail.mesh as BoxMesh
		if detail_mesh != null:
			var detail_size := detail_mesh.size
			detail_size.z = maxf(width * 0.82, 1.18)
			detail_mesh.size = detail_size
		detail.position.z = center_z

	if tractor_frame_instance != null:
		var frame_mesh := tractor_frame_instance.mesh as BoxMesh
		if frame_mesh != null:
			var frame_size := frame_mesh.size
			var rear_x := M21HeavyTruck.FIFTH_WHEEL_LOCAL.x - 0.12
			var front_x := maxf(front.x, rear_x + 2.35)
			frame_size.x = front_x - rear_x
			var frame_bounds := _m21_lateral_bounds([5, 6, 7], tractor_mapping)
			frame_size.z = maxf((frame_bounds.y - frame_bounds.x) * (M21HeavyTruck.TRACTOR_FRAME_BASE_SIZE.z / 2.36), 1.10)
			frame_mesh.size = frame_size
			tractor_frame_instance.position.x = (front_x + rear_x) * 0.5
			tractor_frame_instance.position.z = (frame_bounds.x + frame_bounds.y) * 0.5 * (M21HeavyTruck.TRACTOR_FRAME_BASE_SIZE.z / 2.36)

func _m21_structural_mapping(rear_station: int, front_station: int, anchor_station: int) -> Transform3D:
	var left := PackedInt32Array([
		HeavyTruckBuilder.node_index(rear_station, 0), HeavyTruckBuilder.node_index(rear_station, 2),
		HeavyTruckBuilder.node_index(front_station, 0), HeavyTruckBuilder.node_index(front_station, 2),
	])
	var right := PackedInt32Array([
		HeavyTruckBuilder.node_index(rear_station, 1), HeavyTruckBuilder.node_index(rear_station, 3),
		HeavyTruckBuilder.node_index(front_station, 1), HeavyTruckBuilder.node_index(front_station, 3),
	])
	var reference := VehicleKinematics.reference_transform(
		truck.model,
		HeavyTruckBuilder.station_nodes(rear_station),
		HeavyTruckBuilder.station_nodes(front_station),
		left,
		right
	)
	var basis := reference.basis.orthonormalized()
	var anchor_world := truck.model.average_position_for_nodes(HeavyTruckBuilder.station_nodes(anchor_station))
	var anchor_local := Vector3(
		HeavyTruckBuilder.STATION_X[anchor_station],
		(HeavyTruckBuilder.LOWER_Y[anchor_station] + HeavyTruckBuilder.UPPER_Y[anchor_station]) * 0.5,
		0.0
	)
	return Transform3D(basis, anchor_world - basis * anchor_local)

func _m21_lateral_bounds(stations: Array[int], mapping: Transform3D) -> Vector2:
	var inverse := mapping.affine_inverse()
	var found := false
	var minimum_z := 0.0
	var maximum_z := 0.0
	for station in stations:
		for corner in range(4):
			var index := HeavyTruckBuilder.node_index(station, corner)
			if index < 0 or index >= truck.model.nodes.size():
				continue
			var local := inverse * truck.model.nodes[index].position_m
			if not found:
				minimum_z = local.z
				maximum_z = local.z
				found = true
			else:
				minimum_z = minf(minimum_z, local.z)
				maximum_z = maxf(maximum_z, local.z)
	return Vector2(minimum_z, maximum_z) if found else Vector2(-1.0, 1.0)

func _m21_reparent_preserving_local(instance: Node3D, new_parent: Node3D) -> void:
	if instance == null or new_parent == null or instance.get_parent() == new_parent:
		return
	var local_transform := instance.transform
	var old_parent := instance.get_parent()
	if old_parent != null:
		old_parent.remove_child(instance)
	new_parent.add_child(instance)
	instance.transform = local_transform
