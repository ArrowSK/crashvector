# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name M21HeavyTruckVisual
extends M20HeavyTruckVisual

# M21 keeps the established M16.2/M17/M20 materials and silhouette, but places
# the tractor presentation under its own transform. Both trailer and tractor
# transforms are reconstructed from structural nodes, so replay does not depend
# on the live final RigidBody3D transforms.

var tractor_presentation_root: Node3D
var tractor_frame_instance: MeshInstance3D

func configure(target: HeavyTruck) -> void:
	super.configure(target)
	if not (target is M21HeavyTruck):
		return
	tractor_presentation_root = Node3D.new()
	tractor_presentation_root.name = "ArticulatedTractorPresentationRoot"
	add_child(tractor_presentation_root)
	for instance in [cab_instance, windshield_instance, grille_instance, bumper_instance, fifth_wheel_instance]:
		_m21_reparent_preserving_local(instance, tractor_presentation_root)
	tractor_frame_instance = _box("ArticulatedTractorFramePresentation", M21HeavyTruck.TRACTOR_FRAME_BASE_SIZE, _dark_material)
	tractor_frame_instance.position = M21HeavyTruck.TRACTOR_FRAME_BASE_POS
	_m21_reparent_preserving_local(tractor_frame_instance, tractor_presentation_root)
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
