# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name M17HeavyTruckVisual
extends M162HeavyTruckVisual

# Presentation only. The M17HeavyTruck structural model and collision shapes
# are authoritative; this skin merely follows their changing front/rear spans.

func _update_pose() -> void:
	super._update_pose()
	if truck == null or truck.model == null:
		return
	_m17_update_geometry_from_model()

func _m17_update_geometry_from_model() -> void:
	var inverse := global_transform.affine_inverse()
	var rear := inverse * truck.model.average_position_for_nodes(HeavyTruckBuilder.station_nodes(HeavyTruckBuilder.REAR_STATION))
	var trailer_front := inverse * truck.model.average_position_for_nodes(HeavyTruckBuilder.station_nodes(HeavyTruckBuilder.TRAILER_END_STATION))
	var cab_rear := inverse * truck.model.average_position_for_nodes(HeavyTruckBuilder.station_nodes(5))
	var front := inverse * truck.model.average_position_for_nodes(HeavyTruckBuilder.station_nodes(HeavyTruckBuilder.FRONT_STATION))

	var trailer_rear_x := rear.x + 0.18
	var trailer_front_x := trailer_front.x + 0.32
	var trailer_length := maxf(trailer_front_x - trailer_rear_x, 3.8)
	_m17_resize_box_x(trailer_instance, trailer_length, (trailer_front_x + trailer_rear_x) * 0.5)
	if trailer_rear_trim != null:
		trailer_rear_trim.position.x = trailer_rear_x
	if trailer_front_trim != null:
		trailer_front_trim.position.x = trailer_front_x

	var chassis_rear_x := rear.x
	var chassis_front_x := front.x
	_m17_resize_box_x(chassis_instance, maxf(chassis_front_x - chassis_rear_x, 7.0), (chassis_front_x + chassis_rear_x) * 0.5)
	if fifth_wheel_instance != null:
		fifth_wheel_instance.position.x = cab_rear.x - 0.38

	# The cab mesh is authored in local X 7.14..9.50. Scale/translate that span so
	# the tractor nose visibly follows front collapse while keeping its generic
	# cab-over silhouette and fixed width/height.
	if cab_instance != null:
		var base_rear := 7.14
		var base_front := 9.50
		var wanted_rear := cab_rear.x - 0.08
		var wanted_front := front.x
		var scale_x := clampf((wanted_front - wanted_rear) / (base_front - base_rear), 0.58, 1.08)
		cab_instance.scale = Vector3(scale_x, 1.0, 1.0)
		cab_instance.position.x = wanted_rear - base_rear * scale_x
	if windshield_instance != null:
		windshield_instance.position.x = front.x - 0.17
	if grille_instance != null:
		grille_instance.position.x = front.x - 0.02
	if bumper_instance != null:
		bumper_instance.position.x = front.x + 0.03

func _m17_resize_box_x(instance: MeshInstance3D, length: float, center_x: float) -> void:
	if instance == null:
		return
	var mesh := instance.mesh as BoxMesh
	if mesh != null:
		var size := mesh.size
		size.x = length
		mesh.size = size
	instance.position.x = center_x
