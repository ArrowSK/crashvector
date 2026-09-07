# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_m20.gd"

# M21 changes only the heavy articulated truck target. Passenger cars, rigid
# lorries, motorcycles, road users, UI, replay, comparison and M19/M20 evidence
# boundaries remain inherited. The truck now has separate trailer and tractor
# RigidBody3D assemblies connected by a constrained fifth wheel.

func _m17_replace_heavy_truck() -> void:
	if truck != null and is_instance_valid(truck):
		if truck.get_parent() == self:
			remove_child(truck)
		truck.queue_free()
	truck = M21HeavyTruck.new()
	truck.name = "HeavyTruck"
	truck.total_mass_kg = scenario.target_mass_kg
	truck.initial_speed_kmh = scenario.target_speed_kmh
	truck.origin_offset_m = scenario.target_position_m
	truck.heading_deg = scenario.target_heading_deg
	truck.auto_step = false
	truck.show_structure = scenario.show_structure
	add_child(truck)
	truck.hybrid_physics_enabled = true
	truck.solver_substeps = scenario.solver_substeps
	_configure_chassis_material(truck.rigid_chassis)
	if (truck as M21HeavyTruck).tractor_chassis != null:
		_configure_chassis_material((truck as M21HeavyTruck).tractor_chassis)
	pair_simulation = null
	static_simulation = null
	hybrid_production_active = true
	call_deferred("_m162_refresh_presentation_skins")

func _m162_refresh_presentation_skins() -> void:
	super._m162_refresh_presentation_skins()
	if not (truck is M21HeavyTruck):
		return
	if m162_truck_skin is M21HeavyTruckVisual and m162_truck_skin.truck == truck:
		return
	if m162_truck_skin != null and is_instance_valid(m162_truck_skin):
		m162_truck_skin.queue_free()
	m162_truck_skin = M21HeavyTruckVisual.new()
	truck.add_child(m162_truck_skin)
	m162_truck_skin.configure(truck)

func _truck_metrics(vehicle: HeavyTruck) -> Dictionary:
	var result := super._truck_metrics(vehicle)
	if vehicle is M21HeavyTruck:
		var articulated := vehicle as M21HeavyTruck
		result["articulation_yaw_deg"] = articulated.articulation_yaw_deg()
		result["maximum_articulation_yaw_deg"] = articulated.maximum_articulation_yaw_deg
		result["fifth_wheel_separation_m"] = articulated.fifth_wheel_separation_m()
		result["contact_manifold"] = articulated.combined_contact_manifold_diagnostics()
	return result

func _current_replay_context() -> Dictionary:
	var result := super._current_replay_context()
	if truck is M21HeavyTruck:
		var articulated := truck as M21HeavyTruck
		result["target_contact_manifold"] = articulated.combined_contact_manifold_diagnostics()
		result["target_articulation_yaw_deg"] = articulated.articulation_yaw_deg()
		result["target_fifth_wheel_separation_m"] = articulated.fifth_wheel_separation_m()
	return result

func _update_metrics() -> void:
	super._update_metrics()
	if metrics_label == null or not (truck is M21HeavyTruck):
		return
	var articulated := truck as M21HeavyTruck
	metrics_label.text += "\nFifth-wheel articulation • yaw %.1f° • peak %.1f° • joint gap %.0f mm" % [
		articulated.articulation_yaw_deg(),
		articulated.maximum_articulation_yaw_deg,
		articulated.fifth_wheel_separation_m() * 1000.0,
	]
