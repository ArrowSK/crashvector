# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name M22RoadUserPresentationSkin3D
extends RoadUserPresentationSkin3D

# M22 presentation composes the already-finalized M16.2 riderless bicycle and
# articulated-person skins. It does not create or own any physics bodies.

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
		_update_pedestrian_skin()
	elif proxy.target_type == ScenarioConfig.TARGET_BICYCLE:
		_update_bicycle_skin()
	else:
		_update_pedestrian_skin()
