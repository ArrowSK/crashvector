# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name RoadUserArticulatedStableProxy3D
extends RoadUserArticulatedProxy3D

# Corrective production wrapper for the established M15 articulated target.
# The topology, joints, masses, road collision and replay API are unchanged.
# The one-shot front-probe transfer remains horizontal so the deliberately
# generic contact model cannot manufacture an upward launch for a pedestrian.

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
	# rigid limb/car collision. Keep its longitudinal transfer bounded at high
	# closing speed, but never invent an upward impulse: the former vertical term
	# was the direct cause of pedestrians vaulting over a car without real contact.
	transfer_impulse_ns = minf(transfer_impulse_ns, target_mass_kg * PEDESTRIAN_MAX_TRANSFER_SPEED_MS)
	# Apply the bounded one-shot demand across the complete articulated mass. The
	# previous pelvis/torso split accelerated the small pelvis several times more
	# than the torso, so the constraint solver had to correct a large artificial
	# mismatch and could launch the figure. A mass-proportional transfer preserves
	# the same centre-of-mass impulse without creating that internal energy spike.
	var bodies: Array[RigidBody3D] = [self]
	for body in articulated_bodies:
		if body != null and is_instance_valid(body):
			bodies.append(body)
	var combined_mass := 0.0
	for body in bodies:
		combined_mass += body.mass
	var total_impulse := forward * transfer_impulse_ns
	for body in bodies:
		body.apply_central_impulse(total_impulse * (body.mass / maxf(combined_mass, 0.001)))
	impact_received = true
