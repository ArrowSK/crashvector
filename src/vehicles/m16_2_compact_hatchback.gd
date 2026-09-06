# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name M162CompactHatchback
extends CompactHatchback

# Narrow M16.2 corrective physics guard discovered during rendered acceptance.
# The production front-crush probe measures geometric overlap. Against a narrow,
# light articulated target (pedestrian/bicycle), that ray can pass almost a full
# crush-zone length through the target even though only a few kJ are available
# to deform the car. M12-M15 therefore could visually/structurally command nearly
# one metre of nose crush from a 50 km/h pedestrian contact.
#
# Keep the established probe and staged-failure model, but cap the commanded
# crush by the normal collision energy already calculated with reduced mass.
# Heavy vehicles and rigid obstacles retain the existing limit because their
# available collision energy reaches the design crush travel.

func _update_hybrid_crush_target() -> void:
	if rigid_chassis == null:
		return
	if rigid_chassis.front_crush_overlap_active():
		var collider := rigid_chassis.front_crush_collider()
		if hybrid_primary_collider == null:
			hybrid_primary_collider = collider
		hybrid_peak_collision_energy_j = maxf(hybrid_peak_collision_energy_j, _normal_collision_energy_j(collider))

	var preset := PassengerCarCatalog.data(vehicle_preset_id)
	var scale_x := maxf(float(preset.get("scale_x", 1.0)), 0.55)
	var stiffness_scale := maxf(float(preset.get("stiffness_scale", 1.0)), 0.45)
	var mass_scale := sqrt(maxf(total_mass_kg / 1150.0, 0.45))
	var resistance_scale := stiffness_scale * mass_scale
	var geometric_travel := rigid_chassis.front_crush_travel_m()
	var energy_travel := _m162_energy_limited_crush_m(hybrid_peak_collision_energy_j, resistance_scale)
	var allowed_travel := minf(geometric_travel, energy_travel)
	hybrid_target_front_crush_m = maxf(hybrid_target_front_crush_m, allowed_travel)
	hybrid_target_front_crush_m = clampf(hybrid_target_front_crush_m, 0.0, 0.98 * scale_x)

func _m162_energy_limited_crush_m(collision_energy_j: float, resistance_scale: float) -> float:
	if collision_energy_j <= 0.0:
		return 0.0
	# Invert the normal-zone resistance curve used by
	# CompactHatchback._apply_hybrid_crush_resistance:
	#   F(x) ~= F0 + k*x,  F0=105 kN, k=155 kN / 0.62 m.
	# Work E = F0*x + 0.5*k*x^2. This is only a guard against impossible probe
	# penetration; the existing structural solver remains authoritative below it.
	var scale := maxf(resistance_scale, 0.20)
	var force0_n := 105000.0 * scale
	var stiffness_n_m := (155000.0 / 0.62) * scale
	var discriminant := force0_n * force0_n + 2.0 * stiffness_n_m * collision_energy_j
	return maxf((-force0_n + sqrt(maxf(discriminant, 0.0))) / maxf(stiffness_n_m, 1.0), 0.0)

func apply_replay_visual_state(state: Dictionary) -> void:
	# Replay snapshots include the rigid transform, but the historical base
	# implementation restored only structural/deformation state. That left the
	# generated M16 skin using the final 4 s chassis basis while its structural
	# nodes belonged to an earlier impact frame. Restore the frozen chassis first
	# so body geometry, details, camera bounds and scrubbed replay all share one
	# authoritative transform.
	if rigid_chassis != null and hybrid_physics_enabled:
		var replay_transform: Variant = state.get("rigid_transform", null)
		if replay_transform is Transform3D:
			rigid_chassis.global_transform = replay_transform
			last_chassis_transform = rigid_chassis.global_transform
			chassis_sync_ready = true
		var replay_velocity: Variant = state.get("rigid_linear_velocity_ms", null)
		if replay_velocity is Vector3:
			rigid_chassis.linear_velocity = replay_velocity
	super.apply_replay_visual_state(state)
