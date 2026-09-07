# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_m19.gd"

# M20 changes only the target implementation selected by the established M17
# production routing. Passenger-car M12-M19 physics, UI, replay, comparison,
# presentation and contact diagnostics remain inherited unchanged.

func _m17_replace_heavy_truck() -> void:
	if truck != null and is_instance_valid(truck):
		if truck.get_parent() == self:
			remove_child(truck)
		truck.queue_free()
	truck = M20HeavyTruck.new()
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
	pair_simulation = null
	static_simulation = null
	hybrid_production_active = true
	call_deferred("_m162_refresh_presentation_skins")

func _m17_replace_static_with_lorry() -> void:
	_m17_remove_obstacle_placeholder()
	m17_lorry = M20RigidLorry.new()
	m17_lorry.name = "RigidLorry"
	m17_lorry.total_mass_kg = scenario.target_mass_kg
	m17_lorry.initial_speed_kmh = scenario.target_speed_kmh
	m17_lorry.origin_offset_m = scenario.target_position_m
	m17_lorry.heading_deg = scenario.target_heading_deg
	m17_lorry.auto_step = false
	m17_lorry.show_structure = scenario.show_structure
	add_child(m17_lorry)
	_configure_chassis_material(m17_lorry.rigid_chassis)
	pair_simulation = null
	static_simulation = null
	hybrid_production_active = true

func _m17_replace_static_with_motorcycle() -> void:
	_m17_remove_obstacle_placeholder()
	m17_motorcycle = M20Motorcycle.new()
	m17_motorcycle.name = "Motorcycle"
	m17_motorcycle.total_mass_kg = scenario.target_mass_kg
	m17_motorcycle.initial_speed_kmh = scenario.target_speed_kmh
	m17_motorcycle.origin_offset_m = scenario.target_position_m
	m17_motorcycle.heading_deg = scenario.target_heading_deg
	m17_motorcycle.auto_step = false
	m17_motorcycle.show_structure = scenario.show_structure
	add_child(m17_motorcycle)
	_configure_chassis_material(m17_motorcycle.rigid_chassis)
	pair_simulation = null
	static_simulation = null
	hybrid_production_active = true

func _m162_refresh_presentation_skins() -> void:
	super._m162_refresh_presentation_skins()
	if not (truck is M20HeavyTruck):
		return
	if m162_truck_skin is M20HeavyTruckVisual and m162_truck_skin.truck == truck:
		return
	if m162_truck_skin != null and is_instance_valid(m162_truck_skin):
		m162_truck_skin.queue_free()
	m162_truck_skin = M20HeavyTruckVisual.new()
	truck.add_child(m162_truck_skin)
	m162_truck_skin.configure(truck)

func _truck_metrics(vehicle: HeavyTruck) -> Dictionary:
	var result := super._truck_metrics(vehicle)
	if vehicle is M20HeavyTruck:
		var m20_truck := vehicle as M20HeavyTruck
		result["side_crush_m"] = m20_truck.side_impact_deformation_m()
		result["side_impact_energy_j"] = m20_truck.side_impact_energy_j()
	return result

func _m17_lorry_metrics() -> Dictionary:
	var result := super._m17_lorry_metrics()
	if m17_lorry is M20RigidLorry:
		var m20_lorry := m17_lorry as M20RigidLorry
		result["rear_crush_m"] = m20_lorry.rear_impact_deformation_m()
		result["front_crush_m"] = m20_lorry.front_crush_deformation_m()
		result["side_crush_m"] = m20_lorry.side_impact_deformation_m()
		result["side_impact_energy_j"] = m20_lorry.side_impact_energy_j()
	return result

func _m17_motorcycle_metrics() -> Dictionary:
	var result := super._m17_motorcycle_metrics()
	if m17_motorcycle is M20Motorcycle:
		var m20_motorcycle := m17_motorcycle as M20Motorcycle
		result["rear_crush_m"] = m20_motorcycle.rear_impact_deformation_m()
		result["front_crush_m"] = m20_motorcycle.front_crush_deformation_m()
		result["side_crush_m"] = m20_motorcycle.side_impact_deformation_m()
		result["side_impact_energy_j"] = m20_motorcycle.side_impact_energy_j()
	return result

func _update_metrics() -> void:
	super._update_metrics()
	if metrics_label == null:
		return
	if truck is M20HeavyTruck:
		var m20_truck := truck as M20HeavyTruck
		if m20_truck.side_impact_deformation_m() > 0.001:
			metrics_label.text += "\nTruck generic side deformation %.0f mm" % (m20_truck.side_impact_deformation_m() * 1000.0)
	elif m17_lorry is M20RigidLorry:
		var m20_lorry := m17_lorry as M20RigidLorry
		metrics_label.text += "\nLorry local deformation • rear %.0f mm • front %.0f mm • side %.0f mm" % [
			m20_lorry.rear_impact_deformation_m() * 1000.0,
			m20_lorry.front_crush_deformation_m() * 1000.0,
			m20_lorry.side_impact_deformation_m() * 1000.0,
		]
	elif m17_motorcycle is M20Motorcycle:
		var m20_motorcycle := m17_motorcycle as M20Motorcycle
		metrics_label.text += "\nRiderless motorcycle local deformation • rear %.0f mm • front %.0f mm • side %.0f mm" % [
			m20_motorcycle.rear_impact_deformation_m() * 1000.0,
			m20_motorcycle.front_crush_deformation_m() * 1000.0,
			m20_motorcycle.side_impact_deformation_m() * 1000.0,
		]
