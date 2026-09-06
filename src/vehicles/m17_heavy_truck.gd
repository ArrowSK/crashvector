# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name M17HeavyTruck
extends HeavyTruck

# The truck remains one Godot rigid-body world assembly in M17. These variables
# represent bounded local structural collapse at the trailer rear and tractor
# front. They do not model fifth-wheel articulation or manufacturer-specific
# crashworthiness.

var hybrid_rear_collision_energy_j: float = 0.0
var hybrid_front_collision_energy_j: float = 0.0
var hybrid_rear_crush_m: float = 0.0
var hybrid_front_crush_m: float = 0.0
var hybrid_reference_local_positions: Array[Vector3] = []
var trailer_collision: CollisionShape3D
var tractor_collision: CollisionShape3D
var frame_collision: CollisionShape3D
var underride_collision: CollisionShape3D

const TRAILER_BASE_SIZE := Vector3(6.10, 2.95, 2.42)
const TRAILER_BASE_POS := Vector3(3.55, 2.05, 0.0)
const TRACTOR_BASE_SIZE := Vector3(2.65, 2.55, 2.28)
const TRACTOR_BASE_POS := Vector3(8.20, 1.72, 0.0)
const FRAME_BASE_SIZE := Vector3(9.45, 0.30, 1.80)
const FRAME_BASE_POS := Vector3(4.72, 0.58, 0.0)
const UNDERRIDE_BASE_SIZE := Vector3(0.24, 0.68, 2.20)
const UNDERRIDE_BASE_POS := Vector3(0.02, 0.70, 0.0)

func _ready() -> void:
	super._ready()
	_capture_m17_reference_geometry()
	trailer_collision = rigid_chassis.get_node_or_null("TrailerCollision") as CollisionShape3D
	tractor_collision = rigid_chassis.get_node_or_null("TractorCollision") as CollisionShape3D
	frame_collision = rigid_chassis.get_node_or_null("TruckFrameCollision") as CollisionShape3D
	underride_collision = rigid_chassis.get_node_or_null("RearUnderrideCollision") as CollisionShape3D

func begin_simulation() -> void:
	hybrid_rear_collision_energy_j = 0.0
	hybrid_front_collision_energy_j = 0.0
	hybrid_rear_crush_m = 0.0
	hybrid_front_crush_m = 0.0
	super.begin_simulation()
	_restore_m17_reference_geometry()
	_reset_m17_collision_shapes()
	update_from_model()

func step_external(delta: float) -> void:
	if not hybrid_physics_enabled:
		super.step_external(delta)
		return
	# Replay applies an authoritative StructuralSnapshot before calling this with
	# zero delta. Do not re-synchronize that historical model to the live chassis.
	if delta <= 0.0:
		update_from_model()
		return
	_sync_model_to_chassis()
	_m17_consume_contacts()
	_m17_enforce_crush(delta)
	update_from_model()

func rear_guard_deformation_m() -> float:
	return maxf(super.rear_guard_deformation_m(), hybrid_rear_crush_m)

func front_crush_deformation_m() -> float:
	return hybrid_front_crush_m

func _capture_m17_reference_geometry() -> void:
	hybrid_reference_local_positions.clear()
	if rigid_chassis == null or model == null:
		return
	hybrid_reference_local_positions.resize(model.nodes.size())
	for index in range(model.nodes.size()):
		hybrid_reference_local_positions[index] = rigid_chassis.to_local(model.nodes[index].position_m)

func _restore_m17_reference_geometry() -> void:
	if rigid_chassis == null or model == null or hybrid_reference_local_positions.size() != model.nodes.size():
		return
	for index in range(model.nodes.size()):
		model.nodes[index].position_m = rigid_chassis.to_global(hybrid_reference_local_positions[index])
		model.nodes[index].velocity_ms = Vector3.ZERO

func _m17_consume_contacts() -> void:
	if rigid_chassis == null:
		return
	var forward := rigid_chassis.global_transform.basis.x.normalized()
	for sample in rigid_chassis.drain_contact_samples():
		var collider_name: StringName = sample.get("collider_name", StringName(""))
		if collider_name == &"Road" or collider_name == &"Ground" or collider_name == &"ProvingGround":
			continue
		var collider: Object = sample.get("collider", null)
		var contact_side_x := float((sample.get("position_local", Vector3.ZERO) as Vector3).x)
		# The truck origin is at the trailer rear. For near-collinear vehicle
		# impacts, the other actor's centre relative to the truck gives a stable
		# front/rear classification even after the contact solver has corrected
		# penetration and contact-point coordinates have shifted between shapes.
		if collider is Node3D:
			contact_side_x = rigid_chassis.to_local((collider as Node3D).global_position).x
		var other_velocity := Vector3.ZERO
		var other_mass := rigid_chassis.mass
		if collider is RigidBody3D:
			var other := collider as RigidBody3D
			other_velocity = other.linear_velocity
			other_mass = maxf(other.mass, 1.0)
		var longitudinal_relative := absf((rigid_chassis.linear_velocity - other_velocity).dot(forward))
		var reduced_mass := rigid_chassis.mass * other_mass / maxf(rigid_chassis.mass + other_mass, 1.0)
		var velocity_energy := 0.5 * reduced_mass * longitudinal_relative * longitudinal_relative
		var impulse: Vector3 = sample.get("impulse", Vector3.ZERO)
		# Contact callbacks expose post-solve velocities. Preserve the collision
		# demand represented by Godot's actual normal impulse so a striker does not
		# appear perfectly rigid merely because both actors have already converged
		# to similar velocities by the time this presentation/deformation layer runs.
		var impulse_energy := impulse.length_squared() / maxf(2.0 * reduced_mass, 1.0)
		var energy := maxf(velocity_energy, impulse_energy)
		if contact_side_x < 4.2:
			hybrid_rear_collision_energy_j = maxf(hybrid_rear_collision_energy_j, energy)
		else:
			hybrid_front_collision_energy_j = maxf(hybrid_front_collision_energy_j, energy)

	hybrid_rear_crush_m = maxf(hybrid_rear_crush_m, minf(_m17_energy_to_crush(hybrid_rear_collision_energy_j, 190000.0, 520000.0), 0.90))
	hybrid_front_crush_m = maxf(hybrid_front_crush_m, minf(_m17_energy_to_crush(hybrid_front_collision_energy_j, 520000.0, 1050000.0), 0.78))

func _m17_energy_to_crush(energy_j: float, force0_n: float, stiffness_n_m: float) -> float:
	if energy_j <= 0.0:
		return 0.0
	var discriminant := force0_n * force0_n + 2.0 * stiffness_n_m * energy_j
	return maxf((-force0_n + sqrt(maxf(discriminant, 0.0))) / maxf(stiffness_n_m, 1.0), 0.0)

func _m17_enforce_crush(delta: float) -> void:
	if rigid_chassis == null or hybrid_reference_local_positions.size() != model.nodes.size():
		return
	if hybrid_rear_crush_m <= 0.0001 and hybrid_front_crush_m <= 0.0001:
		return
	var alpha := clampf(1.0 - exp(-20.0 * maxf(delta, 0.0)), 0.0, 1.0)
	_m17_deform_station(HeavyTruckBuilder.REAR_STATION, hybrid_rear_crush_m, 1.0, true, alpha)
	_m17_deform_station(1, hybrid_rear_crush_m, 0.34, true, alpha)
	_m17_deform_station(HeavyTruckBuilder.FRONT_STATION, hybrid_front_crush_m, 1.0, false, alpha)
	_m17_deform_station(6, hybrid_front_crush_m, 0.42, false, alpha)
	_m17_update_collision_shapes()

func _m17_deform_station(station: int, crush_m: float, weight: float, rear: bool, alpha: float) -> void:
	if crush_m <= 0.0:
		return
	for corner in range(4):
		var index := HeavyTruckBuilder.node_index(station, corner)
		if index < 0 or index >= model.nodes.size():
			continue
		var target_local := hybrid_reference_local_positions[index]
		target_local.x += crush_m * weight * (1.0 if rear else -1.0)
		if corner >= 2:
			target_local.y -= crush_m * weight * (0.16 if rear else 0.24)
			target_local.z *= 1.0 - 0.045 * weight
		else:
			target_local.y += crush_m * weight * 0.012
		var target_world := rigid_chassis.to_global(target_local)
		model.nodes[index].position_m = model.nodes[index].position_m.lerp(target_world, alpha)
		model.nodes[index].velocity_ms = Vector3.ZERO

func _reset_m17_collision_shapes() -> void:
	_m17_set_box(trailer_collision, TRAILER_BASE_SIZE, TRAILER_BASE_POS)
	_m17_set_box(tractor_collision, TRACTOR_BASE_SIZE, TRACTOR_BASE_POS)
	_m17_set_box(frame_collision, FRAME_BASE_SIZE, FRAME_BASE_POS)
	_m17_set_box(underride_collision, UNDERRIDE_BASE_SIZE, UNDERRIDE_BASE_POS)

func _m17_update_collision_shapes() -> void:
	# Move collision faces with the local collapse so the invisible rigid volume
	# cannot remain at the undeformed silhouette and block further travel.
	var trailer_rear := TRAILER_BASE_POS.x - TRAILER_BASE_SIZE.x * 0.5 + hybrid_rear_crush_m * 0.72
	var trailer_front := TRAILER_BASE_POS.x + TRAILER_BASE_SIZE.x * 0.5
	var trailer_size := TRAILER_BASE_SIZE
	trailer_size.x = maxf(trailer_front - trailer_rear, 4.90)
	var trailer_pos := TRAILER_BASE_POS
	trailer_pos.x = (trailer_front + trailer_rear) * 0.5
	_m17_set_box(trailer_collision, trailer_size, trailer_pos)

	var tractor_rear := TRACTOR_BASE_POS.x - TRACTOR_BASE_SIZE.x * 0.5
	var tractor_front := TRACTOR_BASE_POS.x + TRACTOR_BASE_SIZE.x * 0.5 - hybrid_front_crush_m * 0.78
	var tractor_size := TRACTOR_BASE_SIZE
	tractor_size.x = maxf(tractor_front - tractor_rear, 1.82)
	var tractor_pos := TRACTOR_BASE_POS
	tractor_pos.x = (tractor_front + tractor_rear) * 0.5
	_m17_set_box(tractor_collision, tractor_size, tractor_pos)

	var frame_rear := FRAME_BASE_POS.x - FRAME_BASE_SIZE.x * 0.5 + hybrid_rear_crush_m * 0.42
	var frame_front := FRAME_BASE_POS.x + FRAME_BASE_SIZE.x * 0.5 - hybrid_front_crush_m * 0.42
	var frame_size := FRAME_BASE_SIZE
	frame_size.x = maxf(frame_front - frame_rear, 7.80)
	var frame_pos := FRAME_BASE_POS
	frame_pos.x = (frame_front + frame_rear) * 0.5
	_m17_set_box(frame_collision, frame_size, frame_pos)

	var underride_pos := UNDERRIDE_BASE_POS
	underride_pos.x += hybrid_rear_crush_m
	_m17_set_box(underride_collision, UNDERRIDE_BASE_SIZE, underride_pos)

func _m17_set_box(collision: CollisionShape3D, size: Vector3, position_value: Vector3) -> void:
	if collision == null:
		return
	var box := collision.shape as BoxShape3D
	if box != null:
		box.size = size
	collision.position = position_value
