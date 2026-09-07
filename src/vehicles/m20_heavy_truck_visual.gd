# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name M20HeavyTruckVisual
extends M17HeavyTruckVisual

# Presentation bridge for the M20 heavy-truck side-deformation state. The M17
# visual already follows longitudinal front/rear collapse from structural nodes;
# this layer adds bounded lateral width/centre changes from M20 without changing
# any physics or collision geometry.

func _update_pose() -> void:
	super._update_pose()
	if not (truck is M20HeavyTruck):
		return
	var target := truck as M20HeavyTruck
	_m20_resize_box_side(trailer_instance, 2.42, 3.55, 3.8, 1.55, 0.88, target)
	_m20_resize_box_side(chassis_instance, 1.76, 4.72, 5.3, 1.15, 0.52, target)
	_m20_resize_box_side(trailer_front_trim, 2.34, 6.34, 3.0, 1.50, 0.82, target)
	_m20_resize_box_side(trailer_rear_trim, 2.34, 0.62, 3.0, 1.50, 0.82, target)
	_m20_resize_cab_side(target)

func _m20_resize_box_side(
	instance: MeshInstance3D,
	base_width_m: float,
	local_x_m: float,
	influence_radius_m: float,
	minimum_width_m: float,
	fraction: float,
	target: M20HeavyTruck
) -> void:
	if instance == null:
		return
	var mesh := instance.mesh as BoxMesh
	if mesh == null:
		return
	var negative_weight := clampf(1.0 - absf(local_x_m - target.hybrid_side_negative_z_contact_x_m) / maxf(influence_radius_m, 0.1), 0.0, 1.0)
	var positive_weight := clampf(1.0 - absf(local_x_m - target.hybrid_side_positive_z_contact_x_m) / maxf(influence_radius_m, 0.1), 0.0, 1.0)
	var negative_face := -base_width_m * 0.5 + target.hybrid_side_negative_z_crush_m * fraction * negative_weight
	var positive_face := base_width_m * 0.5 - target.hybrid_side_positive_z_crush_m * fraction * positive_weight
	if positive_face - negative_face < minimum_width_m:
		var center := (positive_face + negative_face) * 0.5
		negative_face = center - minimum_width_m * 0.5
		positive_face = center + minimum_width_m * 0.5
	var size := mesh.size
	size.z = positive_face - negative_face
	mesh.size = size
	instance.position.z = (positive_face + negative_face) * 0.5

func _m20_resize_cab_side(target: M20HeavyTruck) -> void:
	if cab_instance == null:
		return
	var local_x := 8.20
	var influence := 2.10
	var negative_weight := clampf(1.0 - absf(local_x - target.hybrid_side_negative_z_contact_x_m) / influence, 0.0, 1.0)
	var positive_weight := clampf(1.0 - absf(local_x - target.hybrid_side_positive_z_contact_x_m) / influence, 0.0, 1.0)
	var base_width := 2.24
	var negative_face := -base_width * 0.5 + target.hybrid_side_negative_z_crush_m * 0.88 * negative_weight
	var positive_face := base_width * 0.5 - target.hybrid_side_positive_z_crush_m * 0.88 * positive_weight
	var width := maxf(positive_face - negative_face, 1.45)
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
			size.z = maxf(size.z * 0.0 + width * 0.82, 1.18)
			detail_mesh.size = size
		detail.position.z = center_z
