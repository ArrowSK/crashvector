# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name KenneyFittedAsset3D
extends Node3D

# Presentation-only adapter for a pinned Kenney GLB scene. The imported asset is
# fitted to a world-space box supplied by an authoritative CrashVector vehicle.
# It never supplies collision geometry, mass, suspension, contact or deformation
# state. Source wheels can optionally be hidden when the host keeps its own wheel
# presentation.
#
# Kenney Car Kit uses +Z forward, +Y up and +X left. CrashVector uses +X
# forward, +Y up and +Z right, so a +90 degree rotation around Y converts the
# source axes before the target fit is applied.

var active: bool = false
var source_asset_path: String = ""
var asset_root: Node3D
var source_aabb := AABB()

func configure(asset_path: String, hide_source_wheels: bool = false) -> void:
	source_asset_path = asset_path
	active = false
	if not ResourceLoader.exists(asset_path):
		push_warning("Kenney fitted presentation asset is unavailable: %s" % asset_path)
		return

	var resource := ResourceLoader.load(asset_path)
	if not resource is PackedScene:
		push_warning("Kenney fitted presentation asset did not import as a PackedScene: %s" % asset_path)
		return

	asset_root = Node3D.new()
	asset_root.name = "KenneySourceRoot"
	add_child(asset_root)
	var imported := (resource as PackedScene).instantiate()
	asset_root.add_child(imported)

	if hide_source_wheels:
		_hide_wheel_meshes(imported, false)
	_tune_materials(imported)
	if not _capture_source_bounds():
		asset_root.queue_free()
		asset_root = null
		push_warning("Kenney fitted presentation asset has no usable visible mesh bounds: %s" % asset_path)
		return

	active = true
	set_meta("presentation_asset_source", "Kenney Car Kit 3.1")
	set_meta("presentation_asset_path", source_asset_path)
	set_meta("presentation_only", true)

func fit_to_world_box(world_basis: Basis, world_center: Vector3, target_size_m: Vector3) -> void:
	if not active or asset_root == null:
		return
	var size := source_aabb.size
	if size.x <= 0.001 or size.y <= 0.001 or size.z <= 0.001:
		return
	var target := Vector3(
		maxf(target_size_m.x, 0.05),
		maxf(target_size_m.y, 0.05),
		maxf(target_size_m.z, 0.05)
	)
	# Source X -> -host Z, source Y -> host Y, source Z -> host X.
	var source_scale := Vector3(
		target.z / size.x,
		target.y / size.y,
		target.x / size.z
	)
	source_scale.x = clampf(source_scale.x, 0.08, 12.0)
	source_scale.y = clampf(source_scale.y, 0.08, 12.0)
	source_scale.z = clampf(source_scale.z, 0.08, 12.0)

	var axis_conversion := Basis(Vector3.UP, PI * 0.5)
	var fitted_basis := world_basis.orthonormalized() * axis_conversion * Basis.from_scale(source_scale)
	var source_center := source_aabb.get_center()
	global_transform = Transform3D(fitted_basis, world_center - fitted_basis * source_center)

func _capture_source_bounds() -> bool:
	if asset_root == null:
		return false
	var state := {
		"found": false,
		"minimum": Vector3.ZERO,
		"maximum": Vector3.ZERO,
	}
	_collect_bounds(asset_root, Transform3D.IDENTITY, state)
	if not bool(state["found"]):
		return false
	var minimum: Vector3 = state["minimum"]
	var maximum: Vector3 = state["maximum"]
	source_aabb = AABB(minimum, maximum - minimum)
	return source_aabb.size.x > 0.001 and source_aabb.size.y > 0.001 and source_aabb.size.z > 0.001

func _collect_bounds(node: Node, parent_transform: Transform3D, state: Dictionary) -> void:
	var accumulated := parent_transform
	if node is Node3D:
		accumulated = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.visible and mesh_instance.mesh != null:
			var box := mesh_instance.mesh.get_aabb()
			for x_value in [0.0, 1.0]:
				for y_value in [0.0, 1.0]:
					for z_value in [0.0, 1.0]:
						var point := box.position + Vector3(
							box.size.x * x_value,
							box.size.y * y_value,
							box.size.z * z_value
						)
						_expand_bounds(accumulated * point, state)
	for child in node.get_children():
		_collect_bounds(child, accumulated, state)

func _expand_bounds(point: Vector3, state: Dictionary) -> void:
	if not bool(state["found"]):
		state["found"] = true
		state["minimum"] = point
		state["maximum"] = point
		return
	var minimum: Vector3 = state["minimum"]
	var maximum: Vector3 = state["maximum"]
	state["minimum"] = minimum.min(point)
	state["maximum"] = maximum.max(point)

func _hide_wheel_meshes(node: Node, inherited_wheel_branch: bool) -> void:
	var lowered := String(node.name).to_lower()
	var wheel_branch := inherited_wheel_branch or "wheel" in lowered or "tyre" in lowered or "tire" in lowered
	if node is GeometryInstance3D and wheel_branch:
		(node as GeometryInstance3D).visible = false
	for child in node.get_children():
		_hide_wheel_meshes(child, wheel_branch)

func _tune_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		if instance.mesh != null:
			for surface in range(instance.mesh.get_surface_count()):
				var source := instance.mesh.surface_get_material(surface)
				if not source is BaseMaterial3D:
					continue
				var material := (source as BaseMaterial3D).duplicate(true) as BaseMaterial3D
				material.metallic = maxf(material.metallic, 0.10)
				material.roughness = clampf(material.roughness, 0.30, 0.58)
				instance.set_surface_override_material(surface, material)
	for child in node.get_children():
		_tune_materials(child)
