# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_m12.gd"

# M13 keeps the M12 production routing and editor intact. This thin release
# layer only exposes the new staged structural-failure state in the normal
# metrics panel so an extreme crash no longer looks like 'front crush' is the
# only deformation quantity the simulator understands.
func _update_metrics() -> void:
	super._update_metrics()
	if not hybrid_production_active or car == null or metrics_label == null:
		return
	var demand_kj := car.hybrid_collision_energy_j() / 1000.0
	var firewall_mm := car.hybrid_firewall_intrusion_deformation_m() * 1000.0
	var cabin_mm := car.hybrid_cabin_collapse_deformation_m() * 1000.0
	var rear_mm := car.hybrid_rear_buckle_deformation_m() * 1000.0
	var total_mm := car.hybrid_total_longitudinal_collapse_m() * 1000.0
	metrics_label.text += "\nM13 structure: demand %.0f kJ • firewall %.0f mm • cabin %.0f mm • rear %.0f mm • total collapse %.0f mm" % [
		demand_kj, firewall_mm, cabin_mm, rear_mm, total_mm,
	]
