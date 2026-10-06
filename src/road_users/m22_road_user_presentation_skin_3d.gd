# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name M22RoadUserPresentationSkin3D
extends RoadUserPresentationSkin3D

# M22 presentation composes the riderless bicycle and articulated-person skins
# without creating or owning physics bodies. Cyclists use a dedicated seated
# visual solve so the presentation follows the actual CyclistPelvis/limb bodies
# instead of the pedestrian-only proxy-relative pelvis fallback.

func configure(target: RoadUserRigidProxy3D) -> void:
	proxy = target
	name = "M22RoadUserPresentation"
	if proxy == null:
		return
	_scale = RoadUserCatalog.pedestrian_height_m(proxy.preset_id) / 1.75 if proxy.target_type == ScenarioConfig.TARGET_PEDESTRIAN else 1.0
	_build_materials()
	_index_proxy_nodes()
	_hide_primitive_visuals()
	if proxy.target_type == ScenarioConfig.TARGET_CYCLIST:
		_build_bicycle_skin()
		_build_pedestrian_skin()
		_build_cyclist_detail_skin()
	elif proxy.target_type == ScenarioConfig.TARGET_BICYCLE:
		_build_bicycle_skin()
	else:
		_build_pedestrian_skin()
	process_priority = 70
	set_process(true)
	_update_skin()

func _update_skin() -> void:
	if proxy == null:
		return
	if proxy.target_type == ScenarioConfig.TARGET_CYCLIST:
		_update_bicycle_skin()
		_update_cyclist_rider_skin()
	elif proxy.target_type == ScenarioConfig.TARGET_BICYCLE:
		_update_bicycle_skin()
	else:
		_update_pedestrian_skin()


func _build_cyclist_detail_skin() -> void:
	# The generic rider physics already exposes 11 articulated bodies. Keep that
	# topology authoritative and only refine how those bodies are connected on
	# screen. A slightly slimmer seated silhouette avoids the oversized upright
	# pedestrian look that was previously overlaid on the bicycle.
	_set_capsule_radius("pelvis", 0.14)
	_set_capsule_radius("torso", 0.16)
	_set_capsule_radius("left_upper_arm", 0.060)
	_set_capsule_radius("right_upper_arm", 0.060)
	_set_capsule_radius("left_lower_arm", 0.052)
	_set_capsule_radius("right_lower_arm", 0.052)
	_set_capsule_radius("left_upper_leg", 0.085)
	_set_capsule_radius("right_upper_leg", 0.085)
	_set_capsule_radius("left_lower_leg", 0.070)
	_set_capsule_radius("right_lower_leg", 0.070)
	_set_capsule_radius("left_foot", 0.060)
	_set_capsule_radius("right_foot", 0.060)
	var head := _visuals.get("head", null) as MeshInstance3D
	if head != null and head.mesh is SphereMesh:
		var sphere := head.mesh as SphereMesh
		sphere.radius = 0.13
		sphere.height = 0.26
	_visuals["cyclist_helmet"] = _sphere("CyclistHelmetSkin", 0.145, _cloth_dark_material)
	_visuals["cyclist_left_glove"] = _sphere("CyclistLeftGloveSkin", 0.060, _shoe_material)
	_visuals["cyclist_right_glove"] = _sphere("CyclistRightGloveSkin", 0.060, _shoe_material)

func _update_cyclist_rider_skin() -> void:
	var pelvis := _body("CyclistPelvis")
	var torso := _body("PedestrianTorso")
	var head_body := _body("PedestrianHead")
	var left_upper_arm := _body("LeftUpperArm")
	var right_upper_arm := _body("RightUpperArm")
	var left_lower_arm := _body("LeftLowerArm")
	var right_lower_arm := _body("RightLowerArm")
	var left_upper_leg := _body("LeftUpperLeg")
	var right_upper_leg := _body("RightUpperLeg")
	var left_lower_leg := _body("LeftLowerLeg")
	var right_lower_leg := _body("RightLowerLeg")
	if (
		pelvis == null
		or torso == null
		or head_body == null
		or left_upper_arm == null
		or right_upper_arm == null
		or left_lower_arm == null
		or right_lower_arm == null
		or left_upper_leg == null
		or right_upper_leg == null
		or left_lower_leg == null
		or right_lower_leg == null
	):
		_update_pedestrian_skin()
		return

	var bicycle_basis := proxy.global_transform.basis.orthonormalized()
	var rider_up := (torso.global_position - pelvis.global_position).normalized()
	if rider_up.is_zero_approx():
		rider_up = bicycle_basis.y.normalized()
	if rider_up.is_zero_approx():
		rider_up = Vector3.UP

	var torso_lateral := torso.global_transform.basis.z.normalized()
	if torso_lateral.is_zero_approx():
		torso_lateral = bicycle_basis.z.normalized()
	if torso_lateral.is_zero_approx():
		torso_lateral = Vector3.FORWARD

	var pelvis_lateral := pelvis.global_transform.basis.z.normalized()
	if pelvis_lateral.is_zero_approx():
		pelvis_lateral = torso_lateral

	_set_cyclist_segment(
		_visuals["pelvis"],
		pelvis.global_position - rider_up * 0.10,
		pelvis.global_position + rider_up * 0.10
	)

	var torso_axis := (head_body.global_position - pelvis.global_position).normalized()
	if torso_axis.is_zero_approx():
		torso_axis = rider_up
	_set_cyclist_segment(
		_visuals["torso"],
		torso.global_position - torso_axis * 0.23,
		torso.global_position + torso_axis * 0.23
	)

	var left_shoulder := torso.global_position - torso_lateral * 0.18 + torso_axis * 0.10
	var right_shoulder := torso.global_position + torso_lateral * 0.18 + torso_axis * 0.10
	var left_elbow := (left_upper_arm.global_position + left_lower_arm.global_position) * 0.5
	var right_elbow := (right_upper_arm.global_position + right_lower_arm.global_position) * 0.5
	var left_hand := left_lower_arm.global_position * 2.0 - left_elbow
	var right_hand := right_lower_arm.global_position * 2.0 - right_elbow
	var cyclist_proxy := proxy as M22RoadUserProxy3D
	if cyclist_proxy != null and not cyclist_proxy.cyclist_released:
		left_hand = proxy.to_global(Vector3(0.52, 1.20, -0.22))
		right_hand = proxy.to_global(Vector3(0.52, 1.20, 0.22))

	_set_cyclist_segment(_visuals["left_upper_arm"], left_shoulder, left_elbow)
	_set_cyclist_segment(_visuals["right_upper_arm"], right_shoulder, right_elbow)
	_set_cyclist_segment(_visuals["left_lower_arm"], left_elbow, left_hand)
	_set_cyclist_segment(_visuals["right_lower_arm"], right_elbow, right_hand)
	_set_point(_visuals.get("cyclist_left_glove"), left_hand)
	_set_point(_visuals.get("cyclist_right_glove"), right_hand)

	var left_hip := pelvis.global_position - pelvis_lateral * 0.09
	var right_hip := pelvis.global_position + pelvis_lateral * 0.09
	var left_knee := (left_upper_leg.global_position + left_lower_leg.global_position) * 0.5
	var right_knee := (right_upper_leg.global_position + right_lower_leg.global_position) * 0.5
	var left_ankle := left_lower_leg.global_position * 2.0 - left_knee
	var right_ankle := right_lower_leg.global_position * 2.0 - right_knee
	if cyclist_proxy != null and not cyclist_proxy.cyclist_released:
		left_ankle = proxy.to_global(Vector3(0.08, 0.46, -0.08))
		right_ankle = proxy.to_global(Vector3(0.08, 0.46, 0.08))
	_set_cyclist_segment(_visuals["left_upper_leg"], left_hip, left_knee)
	_set_cyclist_segment(_visuals["right_upper_leg"], right_hip, right_knee)
	_set_cyclist_segment(_visuals["left_lower_leg"], left_knee, left_ankle)
	_set_cyclist_segment(_visuals["right_lower_leg"], right_knee, right_ankle)

	var left_foot_forward := left_lower_leg.global_transform.basis.x.normalized()
	var right_foot_forward := right_lower_leg.global_transform.basis.x.normalized()
	if left_foot_forward.is_zero_approx():
		left_foot_forward = bicycle_basis.x.normalized()
	if right_foot_forward.is_zero_approx():
		right_foot_forward = bicycle_basis.x.normalized()
	_set_cyclist_segment(_visuals["left_foot"], left_ankle, left_ankle + left_foot_forward * 0.16)
	_set_cyclist_segment(_visuals["right_foot"], right_ankle, right_ankle + right_foot_forward * 0.16)

	var head := _visuals.get("head", null) as MeshInstance3D
	if head != null:
		head.global_position = head_body.global_position
	var helmet := _visuals.get("cyclist_helmet", null) as MeshInstance3D
	if helmet != null:
		helmet.global_position = head_body.global_position + head_body.global_transform.basis.y.normalized() * 0.025

func cyclist_visual_pelvis_position() -> Vector3:
	var visual := _visuals.get("pelvis", null) as MeshInstance3D
	return visual.global_position if visual != null else Vector3.ZERO

func cyclist_visual_hand_position(left_side: bool) -> Vector3:
	var key := "cyclist_left_glove" if left_side else "cyclist_right_glove"
	var visual := _visuals.get(key, null) as MeshInstance3D
	return visual.global_position if visual != null else Vector3.ZERO

func _set_capsule_radius(key: String, radius: float) -> void:
	var visual := _visuals.get(key, null) as MeshInstance3D
	if visual == null or not visual.mesh is CapsuleMesh:
		return
	var capsule := visual.mesh as CapsuleMesh
	capsule.radius = radius
	capsule.height = maxf(capsule.height, radius * 2.0 + 0.01)

func _set_cyclist_segment(instance_value: Variant, start: Vector3, finish: Vector3) -> void:
	_set_segment(instance_value, start, finish)
	var visual := instance_value as MeshInstance3D
	if visual != null:
		visual.set_meta("presentation_start", start)
		visual.set_meta("presentation_finish", finish)

func _set_point(instance_value: Variant, position_value: Vector3) -> void:
	var visual := instance_value as MeshInstance3D
	if visual != null:
		visual.global_position = position_value
