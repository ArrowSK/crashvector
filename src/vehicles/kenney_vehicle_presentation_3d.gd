# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name KenneyVehiclePresentation3D
extends KenneyVehicleSkin3D

# Presentation-only adapter over KenneyVehicleSkin3D. The base class already
# preserves the pristine Kenney body and applies only structural deformation
# deltas. This layer additionally reads the wheel centres embedded in each
# selected Kenney vehicle asset and offsets the separately rendered Kenney
# wheels so they sit in that body's original wheel openings at neutral state.
# The authoritative CrashVector wheel groups still own motion and deformation.

const SOURCE_TO_HOST_WHEEL := {
	"wheel-back-left": 0,
	"wheel-back-right": 1,
	"wheel-front-left": 2,
	"wheel-front-right": 3,
}

var neutral_wheel_offsets: Array[Vector3] = []

func configure(owner_visual: M162VehicleVisual) -> void:
	super.configure(owner_visual)
	if not active:
		return
	neutral_wheel_offsets.resize(wheel_nodes.size())
	for index in range(neutral_wheel_offsets.size()):
		neutral_wheel_offsets[index] = Vector3.ZERO
	_capture_and_apply_source_wheel_alignment()

func _capture_and_apply_source_wheel_alignment() -> void:
	if host == null or vehicle == null or wheel_nodes.size() != host.wheel_groups.size():
		return
	var body_resource := ResourceLoader.load(body_asset_path)
	if not body_resource is PackedScene:
		return
	var imported_root := (body_resource as PackedScene).instantiate()
	var source_centres: Dictionary = {}
	_collect_named_source_wheels(imported_root, imported_root, Transform3D.IDENTITY, source_centres)
	imported_root.free()

	if source_centres.size() < 4:
		push_warning("Kenney wheel alignment could not resolve four source wheel centres for %s; authoritative CrashVector wheel anchors remain in use." % body_asset_path)
		return

	var reference := vehicle.global_reference_transform()
	for source_name in SOURCE_TO_HOST_WHEEL.keys():
		if not source_centres.has(source_name):
			continue
		var host_index: int = int(SOURCE_TO_HOST_WHEEL[source_name])
		if host_index < 0 or host_index >= wheel_nodes.size() or host_index >= host.wheel_groups.size():
			continue
		var source_point: Vector3 = source_centres[source_name]
		var desired_world: Vector3 = reference * _pristine_source_point_local(source_point)
		var wheel_group := host.wheel_groups[host_index]
		var local_offset: Vector3 = wheel_group.global_transform.affine_inverse() * desired_world
		neutral_wheel_offsets[host_index] = local_offset
		wheel_nodes[host_index].position = local_offset

func _collect_named_source_wheels(
	node: Node,
	root_node: Node,
	parent_transform: Transform3D,
	output: Dictionary
) -> void:
	var accumulated := parent_transform
	if node is Node3D:
		accumulated = parent_transform * (node as Node3D).transform
	var lowered := String(node.name).to_lower()
	if SOURCE_TO_HOST_WHEEL.has(lowered):
		var mesh_instance := _find_first_mesh(node)
		if mesh_instance != null and mesh_instance.mesh != null:
			var relative := _transform_from_ancestor(node, mesh_instance)
			var centre := mesh_instance.mesh.get_aabb().get_center()
			output[lowered] = accumulated * (relative * centre)
			return
	for child in node.get_children():
		_collect_named_source_wheels(child, root_node, accumulated, output)

func _transform_from_ancestor(ancestor: Node, descendant: Node3D) -> Transform3D:
	var chain: Array[Node3D] = []
	var current: Node = descendant
	while current != null and current != ancestor:
		if current is Node3D:
			chain.push_front(current as Node3D)
		current = current.get_parent()
	var result := Transform3D.IDENTITY
	for item in chain:
		result = result * item.transform
	return result
