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

static func collision_footprint_bounds(actor: Node) -> Dictionary:
	var result: Dictionary = {}
	if actor == null:
		return result
	# Read the actual current collision geometry rather than assuming a symmetric
	# body around the actor origin. This naturally follows heading changes and the
	# two independently articulated M21 rigid bodies.
	for node in actor.find_children("*", "CollisionShape3D", true, false):
		var collision := node as CollisionShape3D
		if collision == null or collision.disabled or collision.shape == null:
			continue
		var extent := _collision_horizontal_extent(collision)
		if extent.x <= 0.0 and extent.y <= 0.0:
			continue
		var center := collision.global_position
		_append_horizontal_bounds(result, center.x - extent.x, center.x + extent.x, center.z - extent.y, center.z + extent.y)
	return result

static func structural_footprint_bounds(actor: Node) -> Dictionary:
	var result: Dictionary = {}
	if actor == null:
		return result
	var value: Variant = actor.get("model")
	if not value is StructuralModel:
		return result
	var model := value as StructuralModel
	for structural_node in model.nodes:
		var position: Vector3 = structural_node.position_m
		_append_horizontal_bounds(result, position.x, position.x, position.z, position.z)
	return result

static func _collision_horizontal_extent(collision: CollisionShape3D) -> Vector2:
	var shape := collision.shape
	var basis := collision.global_transform.basis
	var row_x := Vector3(basis.x.x, basis.y.x, basis.z.x)
	var row_z := Vector3(basis.x.z, basis.y.z, basis.z.z)
	if shape is BoxShape3D:
		var half := (shape as BoxShape3D).size * 0.5
		return Vector2(
			absf(row_x.x) * half.x + absf(row_x.y) * half.y + absf(row_x.z) * half.z,
			absf(row_z.x) * half.x + absf(row_z.y) * half.y + absf(row_z.z) * half.z
		)
	if shape is SphereShape3D:
		var radius := (shape as SphereShape3D).radius
		return Vector2(radius * row_x.length(), radius * row_z.length())
	if shape is CylinderShape3D:
		var cylinder := shape as CylinderShape3D
		var half_height := cylinder.height * 0.5
		return Vector2(
			absf(row_x.y) * half_height + cylinder.radius * sqrt(row_x.x * row_x.x + row_x.z * row_x.z),
			absf(row_z.y) * half_height + cylinder.radius * sqrt(row_z.x * row_z.x + row_z.z * row_z.z)
		)
	if shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		var half_cylinder := maxf(capsule.height * 0.5 - capsule.radius, 0.0)
		return Vector2(
			absf(row_x.y) * half_cylinder + capsule.radius * row_x.length(),
			absf(row_z.y) * half_cylinder + capsule.radius * row_z.length()
		)
	return Vector2.ZERO

static func _append_horizontal_bounds(result: Dictionary, min_x: float, max_x: float, min_z: float, max_z: float) -> void:
	if result.is_empty():
		result["min_x"] = min_x
		result["max_x"] = max_x
		result["min_z"] = min_z
		result["max_z"] = max_z
		return
	result["min_x"] = minf(float(result["min_x"]), min_x)
	result["max_x"] = maxf(float(result["max_x"]), max_x)
	result["min_z"] = minf(float(result["min_z"]), min_z)
	result["max_z"] = maxf(float(result["max_z"]), max_z)

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
