# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_m14.gd"

# M15 deliberately keeps the proven M14 production/editor layer intact and
# upgrades the shared RoadUserRigidProxy3D implementation underneath it.
# Pedestrians are now lightweight articulated rigid-body chains and bicycles
# have independently simulated wheel bodies joined to the rigid frame.
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
	if car != null and car.rigid_chassis != null and car.rigid_chassis.front_crush_probe != null:
		car.rigid_chassis.front_crush_probe.collision_mask = ROAD_USER_LAYER

func _set_road_user_body_channels(body: PhysicsBody3D) -> void:
	body.collision_layer = ROAD_USER_LAYER
	body.collision_mask = ROAD_USER_GROUND_LAYER
