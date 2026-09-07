# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_presentation.gd"

# M19 foundation: expose the real Godot contact manifold as diagnostics in the
# production replay/analysis path. This layer is observational only. It does not
# change collision geometry, impulses, crush classification, deformation demand,
# suspension or any M12-M18 world-motion behaviour.

func _current_replay_context() -> Dictionary:
	var result := super._current_replay_context()
	result["contact_manifold_scope"] = "diagnostic_only_no_solver_feedback"
	if car != null and car.rigid_chassis != null:
		result["primary_contact_manifold"] = car.rigid_chassis.contact_manifold_diagnostics()
	var target_chassis := _m19_target_chassis()
	if target_chassis != null:
		result["target_contact_manifold"] = target_chassis.contact_manifold_diagnostics()
	return result

func _passenger_car_metrics(vehicle: CompactHatchback) -> Dictionary:
	var result := super._passenger_car_metrics(vehicle)
	if vehicle != null and vehicle.rigid_chassis != null:
		result["contact_manifold"] = vehicle.rigid_chassis.contact_manifold_diagnostics()
	return result

func _truck_metrics(vehicle: HeavyTruck) -> Dictionary:
	var result := super._truck_metrics(vehicle)
	if vehicle != null and vehicle.rigid_chassis != null:
		result["contact_manifold"] = vehicle.rigid_chassis.contact_manifold_diagnostics()
	return result

func _m17_lorry_metrics() -> Dictionary:
	var result := super._m17_lorry_metrics()
	if m17_lorry != null and m17_lorry.rigid_chassis != null:
		result["contact_manifold"] = m17_lorry.rigid_chassis.contact_manifold_diagnostics()
	return result

func _m17_motorcycle_metrics() -> Dictionary:
	var result := super._m17_motorcycle_metrics()
	if m17_motorcycle != null and m17_motorcycle.rigid_chassis != null:
		result["contact_manifold"] = m17_motorcycle.rigid_chassis.contact_manifold_diagnostics()
	return result

func _refresh_analysis_ui() -> void:
	super._refresh_analysis_ui()
	if analysis_summary_label == null or analysis_report.is_empty():
		return
	var primary_value: Variant = analysis_report.get("primary_contact_manifold", {})
	if not primary_value is Dictionary:
		return
	var primary: Dictionary = primary_value
	var max_points := int(primary.get("maximum_contact_points", 0))
	var peak_impulse := float(primary.get("peak_total_impulse_ns", 0.0))
	if max_points <= 0 and peak_impulse <= 0.0:
		return
	var span_value: Variant = primary.get("maximum_span_local_m", Vector3.ZERO)
	var span := span_value as Vector3 if span_value is Vector3 else Vector3.ZERO
	analysis_summary_label.text += (
		"\nContact manifold diagnostic: max %d simultaneous reported points • local spread %.2f × %.2f m • peak reported-step impulse %.0f N·s. Diagnostic only; not a physical contact-patch area or validation corridor."
	) % [max_points, span.x, span.z, peak_impulse]

func _update_metrics() -> void:
	super._update_metrics()
	if metrics_label == null or car == null or car.rigid_chassis == null:
		return
	var diagnostics := car.rigid_chassis.contact_manifold_diagnostics()
	var max_points := int(diagnostics.get("maximum_contact_points", 0))
	var peak_impulse := float(diagnostics.get("peak_total_impulse_ns", 0.0))
	if max_points <= 0 and peak_impulse <= 0.0:
		return
	var span_value: Variant = diagnostics.get("maximum_span_local_m", Vector3.ZERO)
	var span := span_value as Vector3 if span_value is Vector3 else Vector3.ZERO
	metrics_label.text += "\nContact manifold • max %d pts • spread %.2f × %.2f m • peak %.0f N·s" % [
		max_points,
		span.x,
		span.z,
		peak_impulse,
	]

func _m19_target_chassis() -> VehicleRigidChassis:
	if target_car != null and target_car.rigid_chassis != null:
		return target_car.rigid_chassis
	if truck != null and truck.rigid_chassis != null:
		return truck.rigid_chassis
	if m17_lorry != null and m17_lorry.rigid_chassis != null:
		return m17_lorry.rigid_chassis
	if m17_motorcycle != null and m17_motorcycle.rigid_chassis != null:
		return m17_motorcycle.rigid_chassis
	return null
