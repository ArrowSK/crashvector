# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name KenneyVehicleSkin3D
extends Node3D

# Kenney supplies presentation geometry only. CrashVector's M12-M18 structural
# graph, rigid-body motion, collision shapes and replay remain authoritative.
# The imported body is remapped into M16.2's existing structural cross-section
# cage each frame so front/rear crush and M18 side intrusion remain visible.

var host: M162VehicleVisual
var vehicle: CompactHatchback
var profile: Dictionary = {}
var active := false
var body_asset_path := ""
var wheel_asset_path := KenneyVehicleAssetCatalog.WHEEL_DEFAULT
var body_instance: MeshInstance3D
var source_arrays: Array = []
var surface_primitives: Array[int] = []
var surface_materials: Array[Material] = []
var surface_base_colors: Array[Color] = []
var source_aabb := AABB()
var wheel_nodes: Array[Node3D] = []
var last_paint := Color(-1.0, -1.0, -1.0, -1.0)

func configure(owner_visual: M162VehicleVisual) -> void:
	host = owner_visual
	if host == null:
		return
	vehicle = host.vehicle
	profile = host.profile
	name = "KenneyVehicleSkin"
	process_priority = host.process_priority + 10
	_install_skin()
	set_process(active)

func _process(_delta: float) -> void:
	if not active or host == null or vehicle == null or not is_instance_valid(vehicle) or vehicle.model == null:
		return
	_update_body()
	_update_paint()
	_set_procedural_body_visible(false)
	_hide_procedural_wheels()

func _install_skin() -> void:
	active = false
	body_asset_path = KenneyVehicleAssetCatalog.passenger_car_body_path(host.profile_id)
	if not ResourceLoader.exists(body_asset_path):
		push_warning("Kenney Car Kit body asset is unavailable; keeping the proven procedural CrashVector skin: %s" % body_asset_path)
		return
	var body_resource := ResourceLoader.load(body_asset_path)
	if not body_resource is PackedScene:
		push_warning("Kenney Car Kit body did not import as a PackedScene: %s" % body_asset_path)
		return
	var imported_root := (body_resource as PackedScene).instantiate()
	var source_body := _find_mesh_named(imported_root, "body")
	if source_body == null:
		source_body = _largest_non_wheel_mesh(imported_root)
	if source_body == null or source_body.mesh == null:
		imported_root.free()
		push_warning("Kenney Car Kit body mesh could not be resolved: %s" % body_asset_path)
		return
	if not _capture_body_mesh(source_body.mesh):
		imported_root.free()
		push_warning("Kenney Car Kit body mesh contained no usable vertices: %s" % body_asset_path)
		return
	imported_root.free()

	body_instance = MeshInstance3D.new()
	body_instance.name = "KenneyCarKitBody"
	body_instance.set_meta("source_asset", body_asset_path)
	add_child(body_instance)
	_install_wheels()
	active = true
	set_meta("presentation_asset_source", "Kenney Car Kit 3.1")
	set_meta("presentation_asset_path", body_asset_path)
	_update_body()
	_update_paint()
	_set_procedural_body_visible(false)
	_hide_procedural_wheels()

func _capture_body_mesh(source_mesh: Mesh) -> bool:
	source_arrays.clear()
	surface_primitives.clear()
	surface_materials.clear()
	surface_base_colors.clear()
	var have_vertex := false
	var minimum := Vector3.ZERO
	var maximum := Vector3.ZERO
	for surface_index in range(source_mesh.get_surface_count()):
		var arrays: Array = source_mesh.surface_get_arrays(surface_index).duplicate(true)
		if arrays.size() <= Mesh.ARRAY_VERTEX:
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if vertices.is_empty():
			continue
		for vertex in vertices:
			if not have_vertex:
				minimum = vertex
				maximum = vertex
				have_vertex = true
			else:
				minimum = minimum.min(vertex)
				maximum = maximum.max(vertex)
		source_arrays.append(arrays)
		surface_primitives.append(source_mesh.surface_get_primitive_type(surface_index))
		var source_material := source_mesh.surface_get_material(surface_index)
		var material: Material = null
		if source_material != null:
			material = source_material.duplicate(true) as Material
		surface_materials.append(material)
		if material is BaseMaterial3D:
			surface_base_colors.append((material as BaseMaterial3D).albedo_color)
		else:
			surface_base_colors.append(Color.WHITE)
	if not have_vertex:
		return false
	source_aabb = AABB(minimum, maximum - minimum)
	return source_aabb.size.x > 0.001 and source_aabb.size.y > 0.001 and source_aabb.size.z > 0.001

func _update_body() -> void:
	if body_instance == null or host == null or vehicle == null or vehicle.model == null:
		return
	var output := ArrayMesh.new()
	var reference := vehicle.global_reference_transform()
	var forward := reference.basis.x.normalized()
	var up := reference.basis.y.normalized()
	var right := reference.basis.z.normalized()
	for surface_index in range(source_arrays.size()):
		var arrays: Array = source_arrays[surface_index].duplicate(true)
		var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var mapped_vertices := PackedVector3Array()
		mapped_vertices.resize(source_vertices.size())
		for index in range(source_vertices.size()):
			mapped_vertices[index] = _map_vertex(source_vertices[index])
		arrays[Mesh.ARRAY_VERTEX] = mapped_vertices

		if arrays.size() > Mesh.ARRAY_NORMAL:
			var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			if source_normals.size() == source_vertices.size():
				var mapped_normals := PackedVector3Array()
				mapped_normals.resize(source_normals.size())
				for index in range(source_normals.size()):
					var normal := source_normals[index]
					# Kenney: +Z forward, +Y up, +X left. CrashVector's
					# structural reference uses +X forward, +Y up, +Z right.
					mapped_normals[index] = (forward * normal.z + up * normal.y - right * normal.x).normalized()
				arrays[Mesh.ARRAY_NORMAL] = mapped_normals

		output.add_surface_from_arrays(surface_primitives[surface_index], arrays)
		if surface_index < surface_materials.size() and surface_materials[surface_index] != null:
			output.surface_set_material(surface_index, surface_materials[surface_index])
	body_instance.mesh = output

func _map_vertex(source: Vector3) -> Vector3:
	var size := source_aabb.size
	var u := clampf((source.z - source_aabb.position.z) / maxf(size.z, 0.001), 0.0, 1.0)
	# Kenney +X is vehicle-left, therefore X is reversed when interpolating the
	# explicit CrashVector left/right cage.
	var side_t := clampf(1.0 - (source.x - source_aabb.position.x) / maxf(size.x, 0.001), 0.0, 1.0)
	var height_t := clampf((source.y - source_aabb.position.y) / maxf(size.y, 0.001), 0.0, 1.0)
	var section: Dictionary = host._section_at_u(u)
	var lower_left: Vector3 = section.get("lower_left", Vector3.ZERO)
	var lower_right: Vector3 = section.get("lower_right", Vector3.ZERO)
	var belt_left: Vector3 = section.get("belt_left", Vector3.ZERO)
	var belt_right: Vector3 = section.get("belt_right", Vector3.ZERO)
	var upper_left: Vector3 = section.get("upper_left", Vector3.ZERO)
	var upper_right: Vector3 = section.get("upper_right", Vector3.ZERO)
	var lower := lower_left.lerp(lower_right, side_t)
	var belt := belt_left.lerp(belt_right, side_t)
	var upper := upper_left.lerp(upper_right, side_t)
	var belt_t := clampf(float(profile.get("belt_ratio", 0.58)), 0.35, 0.78)
	if height_t <= belt_t:
		return lower.lerp(belt, height_t / maxf(belt_t, 0.001))
	return belt.lerp(upper, (height_t - belt_t) / maxf(1.0 - belt_t, 0.001))

func _update_paint() -> void:
	if vehicle == null:
		return
	var paint := CarPaintCatalog.color(vehicle.paint_id)
	if paint.is_equal_approx(last_paint):
		return
	last_paint = paint
	for index in range(surface_materials.size()):
		var material := surface_materials[index]
		if not material is BaseMaterial3D:
			continue
		var base := surface_base_colors[index]
		# Preserve Kenney's palette texture/details and use albedo as a per-instance
		# multiplier so the existing CrashVector paint selector remains effective.
		# Black glazing/trim stays black while the coloured body follows the chosen
		# CrashVector paint. The original texture remains attached to the material.
		(material as BaseMaterial3D).albedo_color = Color(
			base.r * paint.r,
			base.g * paint.g,
			base.b * paint.b,
			base.a
		)

func _set_procedural_body_visible(value: bool) -> void:
	if host == null:
		return
	for control in [host.body_instance, host.glass_instance, host.trim_instance, host.accent_instance, host.grille, host.lower_front_trim, host.rear_trim]:
		if control != null:
			control.visible = value
	for collection in [host.headlamps, host.tail_lamps, host.mirrors, host.rocker_cladding, host.roof_rails]:
		for item in collection:
			if item != null:
				item.visible = value

func _install_wheels() -> void:
	wheel_nodes.clear()
	if host == null or not ResourceLoader.exists(wheel_asset_path):
		return
	var wheel_resource := ResourceLoader.load(wheel_asset_path)
	if not wheel_resource is PackedScene:
		return
	for index in range(host.wheel_groups.size()):
		var imported := (wheel_resource as PackedScene).instantiate()
		if not imported is Node3D:
			imported.free()
			continue
		var wheel := imported as Node3D
		wheel.name = "KenneyWheel"
		wheel.set_meta("source_asset", wheel_asset_path)
		var source_mesh := _find_first_mesh(wheel)
		if source_mesh == null or source_mesh.mesh == null:
			wheel.free()
			continue
		var aabb := source_mesh.mesh.get_aabb()
		var source_radius := maxf(aabb.size.y, aabb.size.z) * 0.5
		if source_radius <= 0.001:
			wheel.free()
			continue
		var target_radius := float(profile.get("wheel_radius_m", 0.305))
		var scale_factor := target_radius / source_radius
		wheel.scale = Vector3.ONE * scale_factor
		# Kenney's wheel axle is local X; M16 wheel groups spin about local Z.
		wheel.rotation_degrees.y = 90.0
		host.wheel_groups[index].add_child(wheel)
		wheel_nodes.append(wheel)

func _hide_procedural_wheels() -> void:
	if host == null or wheel_nodes.size() != host.wheel_groups.size():
		return
	for index in range(host.wheel_groups.size()):
		if index < host.wheel_tires.size():
			host.wheel_tires[index].visible = false
		if index < host.wheel_rims.size():
			host.wheel_rims[index].visible = false
		if index < host.wheel_hubs.size():
			host.wheel_hubs[index].visible = false
		if index < host.spoke_roots.size():
			host.spoke_roots[index].visible = false

func _find_mesh_named(node: Node, wanted: String) -> MeshInstance3D:
	if node is MeshInstance3D and String(node.name).to_lower() == wanted.to_lower():
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh_named(child, wanted)
		if found != null:
			return found
	return null

func _find_first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_first_mesh(child)
		if found != null:
			return found
	return null

func _largest_non_wheel_mesh(node: Node) -> MeshInstance3D:
	var best: MeshInstance3D = null
	var best_volume := -1.0
	var candidates: Array[MeshInstance3D] = []
	_collect_meshes(node, candidates)
	for candidate in candidates:
		if candidate.mesh == null or "wheel" in String(candidate.name).to_lower():
			continue
		var size := candidate.mesh.get_aabb().size
		var volume := size.x * size.y * size.z
		if volume > best_volume:
			best_volume = volume
			best = candidate
	return best

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, output)
