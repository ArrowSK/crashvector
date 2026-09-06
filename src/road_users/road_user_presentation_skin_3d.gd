# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name RoadUserPresentationSkin3D
extends Node3D

# Presentation-only skin for the M15 articulated road-user proxy. The rigid
# bodies, collisions, joints and replay state remain authoritative. This layer
# replaces the deliberately primitive segment meshes with connected visual
# geometry so joint motion reads as one pedestrian / one bicycle instead of a
# collection of detached blocks.

var proxy: RoadUserRigidProxy3D
var _body_by_name: Dictionary = {}
var _joint_by_name: Dictionary = {}
var _visuals: Dictionary = {}
var _bicycle_wheel_groups: Array[Node3D] = []
var _scale: float = 1.0

var _cloth_material := StandardMaterial3D.new()
var _cloth_dark_material := StandardMaterial3D.new()
var _skin_material := StandardMaterial3D.new()
var _shoe_material := StandardMaterial3D.new()
var _bike_material := StandardMaterial3D.new()
var _bike_dark_material := StandardMaterial3D.new()
var _metal_material := StandardMaterial3D.new()

func configure(target: RoadUserRigidProxy3D) -> void:
	proxy = target
	name = "M162RoadUserPresentation"
	if proxy == null:
		return
	_scale = RoadUserCatalog.pedestrian_height_m(proxy.preset_id) / 1.75 if proxy.target_type == ScenarioConfig.TARGET_PEDESTRIAN else 1.0
	_build_materials()
	_index_proxy_nodes()
	_hide_primitive_visuals()
	if proxy.target_type == ScenarioConfig.TARGET_BICYCLE:
		_build_bicycle_skin()
	else:
		_build_pedestrian_skin()
	process_priority = 70
	set_process(true)
	_update_skin()

func _process(_delta: float) -> void:
	if proxy == null or not is_instance_valid(proxy):
		queue_free()
		return
	_update_skin()

func _build_materials() -> void:
	_cloth_material.albedo_color = Color(0.10, 0.29, 0.56)
	_cloth_material.roughness = 0.72
	_cloth_dark_material.albedo_color = Color(0.055, 0.085, 0.13)
	_cloth_dark_material.roughness = 0.78
	_skin_material.albedo_color = Color(0.76, 0.57, 0.43)
	_skin_material.roughness = 0.82
	_shoe_material.albedo_color = Color(0.025, 0.030, 0.038)
	_shoe_material.roughness = 0.90
	_bike_material.albedo_color = Color(0.78, 0.18, 0.08)
	_bike_material.metallic = 0.34
	_bike_material.roughness = 0.34
	_bike_dark_material.albedo_color = Color(0.018, 0.022, 0.028)
	_bike_dark_material.roughness = 0.92
	_metal_material.albedo_color = Color(0.48, 0.52, 0.58)
	_metal_material.metallic = 0.82
	_metal_material.roughness = 0.25

func _index_proxy_nodes() -> void:
	_body_by_name.clear()
	_joint_by_name.clear()
	_body_by_name[String(proxy.name)] = proxy
	for body in proxy.articulated_bodies:
		if body != null and is_instance_valid(body):
			_body_by_name[String(body.name)] = body
	for joint in proxy.articulated_joints:
		if joint != null and is_instance_valid(joint):
			_joint_by_name[String(joint.name)] = joint

func _hide_primitive_visuals() -> void:
	_hide_mesh_descendants(proxy)
	for body in proxy.articulated_bodies:
		if body != null and is_instance_valid(body):
			_hide_mesh_descendants(body)

func _hide_mesh_descendants(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
		elif child is Node:
			_hide_mesh_descendants(child)

func _build_pedestrian_skin() -> void:
	_visuals["pelvis"] = _cylinder("PelvisSkin", 0.17 * _scale, _cloth_dark_material)
	_visuals["torso"] = _cylinder("TorsoSkin", 0.20 * _scale, _cloth_material)
	_visuals["head"] = _sphere("HeadSkin", 0.15 * _scale, _skin_material)
	_visuals["left_upper_arm"] = _cylinder("LeftUpperArmSkin", 0.072 * _scale, _cloth_material)
	_visuals["right_upper_arm"] = _cylinder("RightUpperArmSkin", 0.072 * _scale, _cloth_material)
	_visuals["left_lower_arm"] = _cylinder("LeftLowerArmSkin", 0.060 * _scale, _skin_material)
	_visuals["right_lower_arm"] = _cylinder("RightLowerArmSkin", 0.060 * _scale, _skin_material)
	_visuals["left_upper_leg"] = _cylinder("LeftUpperLegSkin", 0.098 * _scale, _cloth_dark_material)
	_visuals["right_upper_leg"] = _cylinder("RightUpperLegSkin", 0.098 * _scale, _cloth_dark_material)
	_visuals["left_lower_leg"] = _cylinder("LeftLowerLegSkin", 0.078 * _scale, _cloth_dark_material)
	_visuals["right_lower_leg"] = _cylinder("RightLowerLegSkin", 0.078 * _scale, _cloth_dark_material)
	_visuals["left_foot"] = _cylinder("LeftFootSkin", 0.072 * _scale, _shoe_material)
	_visuals["right_foot"] = _cylinder("RightFootSkin", 0.072 * _scale, _shoe_material)

func _update_pedestrian_skin() -> void:
	var spine := _joint_position("SpineJoint", proxy.global_position + Vector3.UP * 1.00 * _scale)
	var neck := _joint_position("NeckJoint", spine + Vector3.UP * 0.50 * _scale)
	var left_shoulder := _joint_position("LeftShoulderJoint", neck + Vector3(0.0, -0.15, -0.24) * _scale)
	var right_shoulder := _joint_position("RightShoulderJoint", neck + Vector3(0.0, -0.15, 0.24) * _scale)
	var left_elbow := _joint_position("LeftElbowJoint", left_shoulder + Vector3.DOWN * 0.32 * _scale)
	var right_elbow := _joint_position("RightElbowJoint", right_shoulder + Vector3.DOWN * 0.32 * _scale)
	var left_hip := _joint_position("LeftHipJoint", spine + Vector3(0.0, -0.20, -0.09) * _scale)
	var right_hip := _joint_position("RightHipJoint", spine + Vector3(0.0, -0.20, 0.09) * _scale)
	var left_knee := _joint_position("LeftKneeJoint", left_hip + Vector3.DOWN * 0.36 * _scale)
	var right_knee := _joint_position("RightKneeJoint", right_hip + Vector3.DOWN * 0.36 * _scale)

	var pelvis_center := (left_hip + right_hip) * 0.5
	_set_segment(_visuals["pelvis"], pelvis_center - Vector3.UP * 0.10 * _scale, spine + Vector3.DOWN * 0.05 * _scale)
	_set_segment(_visuals["torso"], spine, neck)
	_set_segment(_visuals["left_upper_arm"], left_shoulder, left_elbow)
	_set_segment(_visuals["right_upper_arm"], right_shoulder, right_elbow)
	_set_segment(_visuals["left_lower_arm"], left_elbow, _distal_endpoint("LeftLowerArm", left_elbow, 0.18 * _scale))
	_set_segment(_visuals["right_lower_arm"], right_elbow, _distal_endpoint("RightLowerArm", right_elbow, 0.18 * _scale))
	_set_segment(_visuals["left_upper_leg"], left_hip, left_knee)
	_set_segment(_visuals["right_upper_leg"], right_hip, right_knee)
	var left_ankle := _distal_endpoint("LeftLowerLeg", left_knee, 0.20 * _scale)
	var right_ankle := _distal_endpoint("RightLowerLeg", right_knee, 0.20 * _scale)
	_set_segment(_visuals["left_lower_leg"], left_knee, left_ankle)
	_set_segment(_visuals["right_lower_leg"], right_knee, right_ankle)
	_set_segment(_visuals["left_foot"], left_ankle, left_ankle + _body_forward("LeftLowerLeg") * 0.18 * _scale)
	_set_segment(_visuals["right_foot"], right_ankle, right_ankle + _body_forward("RightLowerLeg") * 0.18 * _scale)

	var head_body := _body("PedestrianHead")
	var head := _visuals["head"] as MeshInstance3D
	if head != null:
		head.global_position = head_body.global_position if head_body != null else neck + Vector3.UP * 0.16 * _scale

func _build_bicycle_skin() -> void:
	_visuals["rear_to_crank"] = _cylinder("RearStay", 0.028, _bike_material)
	_visuals["front_to_crank"] = _cylinder("DownTube", 0.034, _bike_material)
	_visuals["rear_to_seat"] = _cylinder("SeatStay", 0.026, _bike_material)
	_visuals["seat_to_head"] = _cylinder("TopTube", 0.032, _bike_material)
	_visuals["seat_post"] = _cylinder("SeatPost", 0.025, _metal_material)
	_visuals["fork"] = _cylinder("Fork", 0.026, _metal_material)
	_visuals["handlebar"] = _cylinder("Handlebar", 0.020, _metal_material)
	_visuals["saddle"] = _cylinder("Saddle", 0.055, _bike_dark_material)
	for wheel_name in ["BicycleRearWheel", "BicycleFrontWheel"]:
		var group := Node3D.new()
		group.name = "%sPresentation" % wheel_name
		add_child(group)
		var tyre_mesh := TorusMesh.new()
		tyre_mesh.inner_radius = 0.285
		tyre_mesh.outer_radius = 0.350
		tyre_mesh.rings = 24
		tyre_mesh.ring_segments = 10
		tyre_mesh.material = _bike_dark_material
		var tyre := MeshInstance3D.new()
		tyre.mesh = tyre_mesh
		tyre.rotation_degrees.x = 90.0
		group.add_child(tyre)
		var rim_mesh := TorusMesh.new()
		rim_mesh.inner_radius = 0.305
		rim_mesh.outer_radius = 0.318
		rim_mesh.rings = 20
		rim_mesh.ring_segments = 8
		rim_mesh.material = _metal_material
		var rim := MeshInstance3D.new()
		rim.mesh = rim_mesh
		rim.rotation_degrees.x = 90.0
		group.add_child(rim)
		_bicycle_wheel_groups.append(group)

func _update_bicycle_skin() -> void:
	var rear := _body("BicycleRearWheel")
	var front := _body("BicycleFrontWheel")
	if rear == null or front == null:
		return
	if _bicycle_wheel_groups.size() == 2:
		_bicycle_wheel_groups[0].global_transform = rear.global_transform
		_bicycle_wheel_groups[1].global_transform = front.global_transform

	var basis := proxy.global_transform.basis.orthonormalized()
	var origin := proxy.global_position
	var crank := origin + basis * Vector3(0.02, 0.70, 0.0)
	var seat := origin + basis * Vector3(-0.30, 1.05, 0.0)
	var head := origin + basis * Vector3(0.49, 1.02, 0.0)
	var handle_left := origin + basis * Vector3(0.55, 1.17, -0.22)
	var handle_right := origin + basis * Vector3(0.55, 1.17, 0.22)
	_set_segment(_visuals["rear_to_crank"], rear.global_position, crank)
	_set_segment(_visuals["front_to_crank"], front.global_position, crank)
	_set_segment(_visuals["rear_to_seat"], rear.global_position, seat)
	_set_segment(_visuals["seat_to_head"], seat, head)
	_set_segment(_visuals["seat_post"], crank, seat)
	_set_segment(_visuals["fork"], front.global_position, head)
	_set_segment(_visuals["handlebar"], handle_left, handle_right)
	_set_segment(_visuals["saddle"], seat + basis * Vector3(-0.11, 0.03, 0.0), seat + basis * Vector3(0.11, 0.03, 0.0))

func _update_skin() -> void:
	if proxy.target_type == ScenarioConfig.TARGET_BICYCLE:
		_update_bicycle_skin()
	else:
		_update_pedestrian_skin()

func _body(node_name: String) -> RigidBody3D:
	var value: Variant = _body_by_name.get(node_name, null)
	return value as RigidBody3D

func _joint_position(node_name: String, fallback: Vector3) -> Vector3:
	var value: Variant = _joint_by_name.get(node_name, null)
	var joint := value as Joint3D
	return joint.global_position if joint != null and is_instance_valid(joint) else fallback

func _distal_endpoint(body_name: String, proximal: Vector3, extension: float) -> Vector3:
	var body := _body(body_name)
	if body == null:
		return proximal + Vector3.DOWN * extension
	var delta := body.global_position - proximal
	if delta.length() < 0.02:
		delta = -body.global_transform.basis.y
	return body.global_position + delta.normalized() * extension

func _body_forward(body_name: String) -> Vector3:
	var body := _body(body_name)
	if body == null:
		return Vector3.RIGHT
	var forward := body.global_transform.basis.x.normalized()
	return forward if not forward.is_zero_approx() else Vector3.RIGHT

func _cylinder(node_name: String, radius: float, material: Material) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.4
	cylinder.radial_segments = 16
	cylinder.rings = 2
	cylinder.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = cylinder
	add_child(instance)
	return instance

func _sphere(node_name: String, radius: float, material: Material) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 18
	sphere.rings = 10
	sphere.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = sphere
	add_child(instance)
	return instance

func _set_segment(instance_value: Variant, start: Vector3, finish: Vector3) -> void:
	var instance := instance_value as MeshInstance3D
	if instance == null:
		return
	var delta := finish - start
	var length := delta.length()
	if length < 0.005:
		instance.visible = false
		return
	instance.visible = true
	var cylinder := instance.mesh as CylinderMesh
	if cylinder != null:
		cylinder.height = length
	instance.global_position = (start + finish) * 0.5
	instance.global_basis = _basis_y_along(delta / length)

func _basis_y_along(direction: Vector3) -> Basis:
	var target := direction.normalized()
	var dot := clampf(Vector3.UP.dot(target), -1.0, 1.0)
	if dot > 0.9999:
		return Basis.IDENTITY
	if dot < -0.9999:
		return Basis(Vector3.RIGHT, PI)
	var axis := Vector3.UP.cross(target).normalized()
	return Basis(axis, acos(dot))
