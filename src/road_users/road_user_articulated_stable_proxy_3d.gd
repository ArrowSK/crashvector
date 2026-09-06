# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name RoadUserArticulatedStableProxy3D
extends RoadUserArticulatedProxy3D

# Corrective production wrapper for the established M15 articulated target.
# The topology, joints, masses, road collision and replay API are unchanged.
# Only the one-shot front-probe transfer is bounded at very high closing speeds
# so the deliberately generic contact model cannot scale its synthetic upward
# component without limit and launch a pedestrian vertically.

const PEDESTRIAN_MAX_TRANSFER_SPEED_MS := 18.0
const PEDESTRIAN_MAX_VERTICAL_COM_SPEED_MS := 1.25

func apply_probe_contact(source: VehicleRigidChassis, collider: Object = null) -> void:
	if impact_received or source == null or not simulation_active:
		return
	var forward := source.global_transform.basis.x.normalized()
	var target_velocity := center_of_mass_velocity_ms()
	var closing_speed := maxf((source.linear_velocity - target_velocity).dot(forward), 0.0)
	if closing_speed < 0.25:
		return
	var effective_mass := source.mass * target_mass_kg / maxf(source.mass + target_mass_kg, 1.0)
	var transfer_impulse_ns := effective_mass * closing_speed * 0.88

	if target_type == ScenarioConfig.TARGET_BICYCLE:
		# Preserve the finalized M15 bicycle transfer path. The reported regression
		# concerns pedestrian vertical launch, not bicycle hub/frame behaviour.
		apply_central_impulse(forward * transfer_impulse_ns * 0.72 + Vector3.UP * transfer_impulse_ns * 0.025)
		var contacted := _owned_body_from_collider(collider)
		if contacted != null and contacted != self:
			contacted.apply_central_impulse(forward * transfer_impulse_ns * 0.28)
		elif not _bicycle_wheels.is_empty():
			_bicycle_wheels[0].apply_central_impulse(forward * transfer_impulse_ns * 0.14)
			_bicycle_wheels[1].apply_central_impulse(forward * transfer_impulse_ns * 0.14)
		impact_received = true
		return

	# M15 deliberately uses a phenomenological one-shot probe coupling instead of
	# rigid limb/car collision. At ordinary regression speeds the original demand
	# remains untouched. Above that range, bound the total transfer and especially
	# the synthetic upward component; otherwise both grow linearly with closing
	# speed and can turn a 130 km/h contact into an artificial vertical jump.
	transfer_impulse_ns = minf(transfer_impulse_ns, target_mass_kg * PEDESTRIAN_MAX_TRANSFER_SPEED_MS)
	var vertical_impulse_ns := minf(
		transfer_impulse_ns * 0.08,
		target_mass_kg * PEDESTRIAN_MAX_VERTICAL_COM_SPEED_MS
	)
	var pelvis_vertical := vertical_impulse_ns * 0.4375
	var torso_vertical := vertical_impulse_ns * 0.5625

	apply_central_impulse(forward * transfer_impulse_ns * 0.48 + Vector3.UP * pelvis_vertical)
	if _pedestrian_torso != null:
		_pedestrian_torso.apply_central_impulse(forward * transfer_impulse_ns * 0.44 + Vector3.UP * torso_vertical)
	var contacted := _owned_body_from_collider(collider)
	if contacted != null and contacted != self and contacted != _pedestrian_torso:
		contacted.apply_central_impulse(forward * transfer_impulse_ns * 0.08)
	impact_received = true
