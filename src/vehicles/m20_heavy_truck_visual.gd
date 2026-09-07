# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name M20HeavyTruckVisual
extends M17HeavyTruckVisual

# Presentation bridge for M20 heavy-truck side deformation. M17 already derives
# longitudinal front/rear collapse from the structural model. M20 does the same
# for lateral presentation: width and centre are reconstructed from the current
# structural nodes instead of the live scalar crush accumulators. That matters
# for replay, because StructuralSnapshot restores historical node positions while
# the live peak-crush scalars intentionally remain monotonic for the completed
# simulation. Presentation therefore follows the replayed structure, not the
# final live deformation state.

func _update_pose() -> void:
	super._update_pose()
	if not (truck is M20HeavyTruck) or truck.model == null:
		return

	# The authored presentation widths are slightly smaller than the structural
	# envelopes. Preserve those visual proportions while following the current
	# structural lateral span/centre. All values are presentation-only.
	_m20_resize_box_from_stations(trailer_instance, [1, 2, 3, 4], 2.42, 2.44, 1.55)
	_m20_resize_box_from_stations(chassis_instance, [0, 1, 2, 3, 4, 5, 6, 7], 1.76, 2.44, 1.15)
	_m20_resize_box_from_stations(trailer_front_trim, [4], 2.34, 2.44, 1.50)
	_m20_resize_box_from_stations(trailer_rear_trim, [1], 2.34, 2.44, 1.50)
	_m20_resize_cab_from_structure()

func _m20_resize_box_from_stations(
	instance: MeshInstance3D,
	stations: Array[int],
	base_width_m: float,
	reference_span_m: float,
	minimum_width_m: float
) -> void:
	if instance == null:
		return
	var mesh := instance.mesh as BoxMesh
	if mesh == null:
		return
	var bounds := _m20_lateral_bounds(stations)
	var scale := base_width_m / maxf(reference_span_m, 0.01)
	var negative_face := bounds.x * scale
	var positive_face := bounds.y * scale
	if positive_face - negative_face < minimum_width_m:
		var center := (positive_face + negative_face) * 0.5
		negative_face = center - minimum_width_m * 0.5
		positive_face = center + minimum_width_m * 0.5
	var size := mesh.size
	size.z = positive_face - negative_face
	mesh.size = size
	instance.position.z = (positive_face + negative_face) * 0.5

func _m20_resize_cab_from_structure() -> void:
	if cab_instance == null:
		return
	var bounds := _m20_lateral_bounds([5, 6, 7])
	var base_width := 2.24
	var reference_span := 2.36
	var scale := base_width / reference_span
	var negative_face := bounds.x * scale
	var positive_face := bounds.y * scale
	if positive_face - negative_face < 1.45:
		var center := (positive_face + negative_face) * 0.5
		negative_face = center - 1.45 * 0.5
		positive_face = center + 1.45 * 0.5
	var width := positive_face - negative_face
	var center_z := (positive_face + negative_face) * 0.5
	var scale_value := cab_instance.scale
	scale_value.z = width / base_width
	cab_instance.scale = scale_value
	cab_instance.position.z = center_z

	for detail in [windshield_instance, grille_instance, bumper_instance]:
		if detail == null:
			continue
		var detail_mesh := detail.mesh as BoxMesh
		if detail_mesh != null:
			var size := detail_mesh.size
			size.z = maxf(width * 0.82, 1.18)
			detail_mesh.size = size
		detail.position.z = center_z

func _m20_lateral_bounds(stations: Array[int]) -> Vector2:
	if truck == null or truck.model == null:
		return Vector2(-1.0, 1.0)
	var inverse := global_transform.affine_inverse()
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
	if not found:
		return Vector2(-1.0, 1.0)
	return Vector2(minimum_z, maximum_z)
