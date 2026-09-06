# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_m14.gd"

# M15 deliberately keeps the proven M14 production/editor layer intact and
# upgrades the road-user implementation underneath it. Pedestrians are
# lightweight articulated rigid-body chains with bounded generic joints and
# bicycles have independently simulated wheel bodies joined to the rigid frame.
#
# Road-user rigid segments use a dedicated collision channel. They collide
# physically with the road but not the passenger-car protected-cell collider;
# car/road-user impact remains coupled through the existing front-crush probe.
# This prevents a limb or wheel joint from becoming an unintended rigid ramp
# under the car while still allowing the articulated target to tumble on-road.

const ROAD_USER_LAYER: int = 2
const ROAD_USER_GROUND_LAYER: int = 4

func _ready() -> void:
	super._ready()
	_configure_articulated_collision_channels()

func _rebuild_preview() -> void:
	super._rebuild_preview()
	_configure_articulated_collision_channels()

func _replace_legacy_road_user_with_rigid_proxy() -> void:
	if bicycle != null and is_instance_valid(bicycle) and bicycle.get_parent() == self:
		remove_child(bicycle)
		bicycle.queue_free()
	if pedestrian != null and is_instance_valid(pedestrian) and pedestrian.get_parent() == self:
		remove_child(pedestrian)
		pedestrian.queue_free()
	bicycle = null
	pedestrian = null
	pair_simulation = null
	static_simulation = null
	hybrid_production_active = true

	road_user_proxy = RoadUserArticulatedStableProxy3D.new()
	road_user_proxy.name = "RoadUserArticulatedProxy"
	road_user_proxy.configure(
		scenario.target_type,
		scenario.target_preset_id,
		scenario.target_mass_kg,
		scenario.target_speed_kmh,
		scenario.target_position_m,
		scenario.target_heading_deg,
		scenario.show_structure
	)
	add_child(road_user_proxy)
	bicycle = road_user_proxy.bicycle_visual
	pedestrian = road_user_proxy.pedestrian_visual
	if status_label != null:
		status_label.text = "Bounded articulated road-user preview — press Simulate"
	_update_metrics()

func _configure_articulated_collision_channels() -> void:
	if road_user_proxy == null or not is_instance_valid(road_user_proxy):
		return
	var road := get_node_or_null("Road") as StaticBody3D
	if road != null:
		# Keep the historical layer-1 road contact for cars and add a dedicated
		# layer consumed only by articulated vulnerable-road-user bodies.
		road.collision_layer |= ROAD_USER_GROUND_LAYER
	_set_road_user_body_channels(road_user_proxy)
	for body in road_user_proxy.articulated_bodies:
		if body != null and is_instance_valid(body):
			_set_road_user_body_channels(body)
	_rebind_articulated_joints()
	if car != null and car.rigid_chassis != null and car.rigid_chassis.front_crush_probe != null:
		car.rigid_chassis.front_crush_probe.collision_mask = ROAD_USER_LAYER

func _set_road_user_body_channels(body: PhysicsBody3D) -> void:
	body.collision_layer = ROAD_USER_LAYER
	body.collision_mask = ROAD_USER_GROUND_LAYER

func _rebind_articulated_joints() -> void:
	# Rebinding after preview placement makes Godot derive each local pivot from
	# the final body/joint transforms and avoids a large initial correction when
	# the bodies are unfrozen. The bounded M15 proxy performs the same operation
	# internally; repeating it here also covers the bicycle hub pins.
	for joint in road_user_proxy.articulated_joints:
		if joint == null or not is_instance_valid(joint):
			continue
		var body_a_path := joint.node_a
		var body_b_path := joint.node_b
		joint.node_a = NodePath()
		joint.node_b = NodePath()
		joint.node_a = body_a_path
		joint.node_b = body_b_path
