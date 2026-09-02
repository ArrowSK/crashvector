# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name StructuralSnapshot
extends RefCounted

static func capture(model: StructuralModel) -> Dictionary:
	if model == null:
		return {}
	var positions := PackedVector3Array()
	var velocities := PackedVector3Array()
	var pinned := PackedByteArray()
	for node in model.nodes:
		positions.append(node.position_m)
		velocities.append(node.velocity_ms)
		pinned.append(1 if node.pinned else 0)

	var rest_lengths := PackedFloat64Array()
	var broken := PackedByteArray()
	var last_force := PackedFloat64Array()
	var last_strain := PackedFloat64Array()
	var plastic_energy := PackedFloat64Array()
	var damping_energy := PackedFloat64Array()
	var fracture_energy := PackedFloat64Array()
	for beam in model.beams:
		rest_lengths.append(beam.rest_length_m)
		broken.append(1 if beam.broken else 0)
		last_force.append(beam.last_force_n)
		last_strain.append(beam.last_total_strain)
		plastic_energy.append(beam.plastic_energy_j)
		damping_energy.append(beam.damping_energy_j)
		fracture_energy.append(beam.fracture_energy_j)

	return {
		"positions_m": positions,
		"velocities_ms": velocities,
		"node_pinned": pinned,
		"beam_rest_lengths_m": rest_lengths,
		"beam_broken": broken,
		"beam_last_force_n": last_force,
		"beam_last_strain": last_strain,
		"beam_plastic_energy_j": plastic_energy,
		"beam_damping_energy_j": damping_energy,
		"beam_fracture_energy_j": fracture_energy,
		"elapsed_s": model.elapsed_s,
		"first_contact_time_s": model.first_contact_time_s,
		"contact_events": model.contact_events,
		"contact_dissipation_j": model.contact_dissipation_j,
		"initial_energy_j": model.initial_energy_j,
	}

static func apply(model: StructuralModel, snapshot: Dictionary) -> bool:
	if model == null or snapshot.is_empty():
		return false
	var positions: PackedVector3Array = snapshot.get("positions_m", PackedVector3Array())
	var velocities: PackedVector3Array = snapshot.get("velocities_ms", PackedVector3Array())
	var pinned: PackedByteArray = snapshot.get("node_pinned", PackedByteArray())
	var rest_lengths: PackedFloat64Array = snapshot.get("beam_rest_lengths_m", PackedFloat64Array())
	var broken: PackedByteArray = snapshot.get("beam_broken", PackedByteArray())
	if positions.size() != model.nodes.size() or velocities.size() != model.nodes.size():
		return false
	if rest_lengths.size() != model.beams.size() or broken.size() != model.beams.size():
		return false

	for i in range(model.nodes.size()):
		var node := model.nodes[i]
		node.position_m = positions[i]
		node.velocity_ms = velocities[i]
		node.force_n = Vector3.ZERO
		if pinned.size() == model.nodes.size():
			node.pinned = pinned[i] != 0
			node.inverse_mass = 0.0 if node.pinned else 1.0 / maxf(node.mass_kg, 0.001)

	var last_force: PackedFloat64Array = snapshot.get("beam_last_force_n", PackedFloat64Array())
	var last_strain: PackedFloat64Array = snapshot.get("beam_last_strain", PackedFloat64Array())
	var plastic_energy: PackedFloat64Array = snapshot.get("beam_plastic_energy_j", PackedFloat64Array())
	var damping_energy: PackedFloat64Array = snapshot.get("beam_damping_energy_j", PackedFloat64Array())
	var fracture_energy: PackedFloat64Array = snapshot.get("beam_fracture_energy_j", PackedFloat64Array())
	for i in range(model.beams.size()):
		var beam := model.beams[i]
		beam.rest_length_m = rest_lengths[i]
		beam.broken = broken[i] != 0
		if last_force.size() == model.beams.size():
			beam.last_force_n = last_force[i]
		if last_strain.size() == model.beams.size():
			beam.last_total_strain = last_strain[i]
		if plastic_energy.size() == model.beams.size():
			beam.plastic_energy_j = plastic_energy[i]
		if damping_energy.size() == model.beams.size():
			beam.damping_energy_j = damping_energy[i]
		if fracture_energy.size() == model.beams.size():
			beam.fracture_energy_j = fracture_energy[i]

	model.elapsed_s = float(snapshot.get("elapsed_s", model.elapsed_s))
	model.first_contact_time_s = float(snapshot.get("first_contact_time_s", model.first_contact_time_s))
	model.contact_events = int(snapshot.get("contact_events", model.contact_events))
	model.contact_dissipation_j = float(snapshot.get("contact_dissipation_j", model.contact_dissipation_j))
	model.initial_energy_j = float(snapshot.get("initial_energy_j", model.initial_energy_j))
	return true
