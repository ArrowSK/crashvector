# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name VehicleActorRuntime
extends RefCounted

# Role-neutral bridge for production vehicle nodes. This is intentionally a
# narrow adapter over the established actor APIs, not a second physics system.

static func chassis(actor: Node) -> VehicleRigidChassis:
	if actor is CompactHatchback:
		return (actor as CompactHatchback).rigid_chassis
	if actor is HeavyTruck:
		return (actor as HeavyTruck).rigid_chassis
	if actor is M17RigidLorry:
		return (actor as M17RigidLorry).rigid_chassis
	if actor is M17Motorcycle:
		return (actor as M17Motorcycle).rigid_chassis
	if actor is DynamicTank3D:
		return (actor as DynamicTank3D).rigid_chassis
	return null

static func physics_bodies(actor: Node) -> Array[VehicleRigidChassis]:
	var result: Array[VehicleRigidChassis] = []
	if actor is M21HeavyTruck:
		var truck := actor as M21HeavyTruck
		if truck.rigid_chassis != null:
			result.append(truck.rigid_chassis)
		if truck.tractor_chassis != null:
			result.append(truck.tractor_chassis)
		return result
	var body := chassis(actor)
	if body != null:
		result.append(body)
	return result

static func contact_event_count(actor: Node) -> int:
	# Keep the replay/analysis contact counter role-neutral. VehicleRigidChassis
	# stores a cumulative count of real non-ground contact samples for the current
	# run, so this remains monotonic in the same way as the established passenger-
	# car hybrid_contact_count() contract.
	if actor is M21HeavyTruck:
		var truck := actor as M21HeavyTruck
		var count := 0
		if truck.rigid_chassis != null:
			count += truck.rigid_chassis.non_ground_contact_events
		if truck.tractor_chassis != null:
			count += truck.tractor_chassis.non_ground_contact_events
		return count
	var body := chassis(actor)
	return body.non_ground_contact_events if body != null else 0

static func contact_manifold_diagnostics(actor: Node) -> Dictionary:
	if actor is M21HeavyTruck:
		return (actor as M21HeavyTruck).combined_contact_manifold_diagnostics()
	var body := chassis(actor)
	return body.contact_manifold_diagnostics() if body != null else {}

static func deformation_metrics(actor: Node) -> Dictionary:
	# Preserve the actor-specific production metrics that the pre-M23 replay path
	# already exposed. The role-neutral world must not erase deformation merely
	# because a vehicle moved from the historical target role to primary.
	var result: Dictionary = {}
	if actor == null:
		return result
	if actor.has_method("front_crush_deformation_m"):
		result["front_crush_m"] = float(actor.call("front_crush_deformation_m"))
	if actor.has_method("safety_cell_deformation_m"):
		result["safety_cell_m"] = float(actor.call("safety_cell_deformation_m"))
	if actor.has_method("rear_impact_deformation_m"):
		result["rear_crush_m"] = float(actor.call("rear_impact_deformation_m"))
	elif actor is M17HeavyTruck:
		result["rear_crush_m"] = float((actor as M17HeavyTruck).hybrid_rear_crush_m)
	if actor.has_method("rear_guard_deformation_m"):
		result["rear_guard_m"] = float(actor.call("rear_guard_deformation_m"))
	if actor.has_method("side_impact_deformation_m"):
		result["side_crush_m"] = float(actor.call("side_impact_deformation_m"))
	if actor.has_method("side_impact_energy_j"):
		result["side_impact_energy_j"] = float(actor.call("side_impact_energy_j"))
	if actor is M21HeavyTruck:
		var articulated := actor as M21HeavyTruck
		result["articulation_yaw_deg"] = articulated.articulation_yaw_deg()
		result["maximum_articulation_yaw_deg"] = articulated.maximum_articulation_yaw_deg
		result["fifth_wheel_separation_m"] = articulated.fifth_wheel_separation_m()
	return result

static func set_preview_pose(actor: Node, position_m: Vector3, heading_deg: float) -> void:
	if actor != null and actor.has_method("set_preview_pose"):
		actor.call("set_preview_pose", position_m, heading_deg)

static func begin(actor: Node) -> void:
	if actor != null and actor.has_method("begin_simulation"):
		actor.call("begin_simulation")

static func set_paused(actor: Node, value: bool) -> void:
	if actor != null and actor.has_method("set_simulation_paused"):
		actor.call("set_simulation_paused", value)

static func stop(actor: Node) -> void:
	if actor != null and actor.has_method("end_simulation"):
		actor.call("end_simulation")

static func step_external(actor: Node, delta: float) -> void:
	# Actors with a local structural model keep it synchronized from the
	# authoritative RigidBody3D transform here. This is also where the motorcycle
	# consumes real contacts, updates its frame deformation, and advances its
	# rider release state. Actors without local presentation work simply have no
	# hook, so the shared world remains role-neutral.
	if actor != null and actor.has_method("step_external"):
		actor.call("step_external", delta)

static func linear_velocity_ms(actor: Node) -> Vector3:
	if actor != null and actor.has_method("global_linear_velocity_ms"):
		var result: Variant = actor.call("global_linear_velocity_ms")
		return result as Vector3 if result is Vector3 else Vector3.ZERO
	var body := chassis(actor)
	return body.linear_velocity if body != null else Vector3.ZERO

static func momentum_kg_ms(actor: Node) -> Vector3:
	if actor != null and actor.has_method("global_momentum_kg_ms"):
		var result: Variant = actor.call("global_momentum_kg_ms")
		return result as Vector3 if result is Vector3 else Vector3.ZERO
	var body := chassis(actor)
	return body.linear_velocity * body.mass if body != null else Vector3.ZERO

static func kinetic_energy_j(actor: Node) -> float:
	if actor != null and actor.has_method("global_kinetic_energy_j"):
		return float(actor.call("global_kinetic_energy_j"))
	var body := chassis(actor)
	return 0.5 * body.mass * body.linear_velocity.length_squared() if body != null else 0.0
