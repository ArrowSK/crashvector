# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name StructuralNode
extends RefCounted

var position_m: Vector3
var velocity_ms: Vector3 = Vector3.ZERO
var force_n: Vector3 = Vector3.ZERO
var mass_kg: float
var inverse_mass: float
var pinned: bool

func _init(initial_position_m: Vector3 = Vector3.ZERO, node_mass_kg: float = 1.0, is_pinned: bool = false) -> void:
	position_m = initial_position_m
	mass_kg = maxf(node_mass_kg, 0.001)
	pinned = is_pinned
	inverse_mass = 0.0 if pinned else 1.0 / mass_kg

func reset_force() -> void:
	force_n = Vector3.ZERO

func add_force(applied_force_n: Vector3) -> void:
	if not pinned:
		force_n += applied_force_n

func integrate(delta_s: float) -> void:
	if pinned or delta_s <= 0.0:
		return
	velocity_ms += force_n * inverse_mass * delta_s
	position_m += velocity_ms * delta_s

func kinetic_energy_j() -> float:
	if pinned:
		return 0.0
	return 0.5 * mass_kg * velocity_ms.length_squared()
