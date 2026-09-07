# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name KenneyVehicleVisual
extends M162VehicleVisual

# Kenney supplies the presentation mesh only. The existing M12-M18 structural
# graph, collision geometry, rigid-body motion and replay state remain
# authoritative. Each low-poly Kenney body is remapped into the same six-point
# cross-section cage that M16.2 already derives from the structural nodes, so
# front/rear crush and M18 lateral intrusion remain visible instead of placing a
# rigid cosmetic shell over the simulation.

var kenney_active := false
var kenney_body_asset_path := ""
var kenney_wheel_asset_path := KenneyVehicleAssetCatalog.WHEEL_DEFAULT
var kenney_body_instance: MeshInstance3D
var kenney_source_arrays: Array[Array] = []
var kenney_surface_primitives: Array[int] = []
var kenney_surface_materials: Array[Material] = []
var kenney_surface_base_colors: Array[Color] = []
var kenney_source_aabb := AABB()
var kenney_wheel_nodes: Array[Node3D] = []

func configure(target: CompactHatchback) -> void:
	super.configure(target)
	_install_kenney_skin()
	if kenney_active:
		_update_kenney_body()
		_update_kenney_paint()

func update_from_vehicle(delta: float) -> void:
	super.update_from_vehicle(delta)
	if not kenney_active:
		return
	_update_kenney_body()
	_update_kenney_paint()

func _install_kenney_skin() -> void:
	kenney_active = false
	kenney_body_asset_path = KenneyVehicleAssetCatalog.passenger_car_body_path(profile_id)
	if not ResourceLoader.exists(kenney_body_asset_path):
		push_warning("Kenney Car Kit body asset is unavailable; keeping the proven procedural CrashVector skin: %s" % kenney_body_asset_path)
		return
	var body_resource := ResourceLoader.load(kenney_body_asset_path)
	if not body_resource is PackedScene:
		push_warning("Kenney Car Kit body asset did not import as a PackedScene: %s" % kenney_body_asset_path)
		return
	var imported_root := (body_resource as PackedScene).instantiate()
	var source_body := _find_mesh_named(imported_root, "body")
	if source_body == null:
		source_body = _largest_non_wheel_mesh(imported_root)
	if source_body == null or source_body.mesh == null:
		imported_root.free()
		push_warning("Kenney Car Kit body mesh could not be resolved: %s" % kenney_body_asset_path)
		return
	if not _capture_body_mesh(source_body.mesh):
		imported_root.free()
		push_warning("Kenney Car Kit body mesh contained no usable vertices: %s" % kenney_body_asset_path)
		return
	imported_root.free()

	kenney_body_instance = MeshInstance3D.new()
	kenney_body_instance.name = "KenneyCarKitBody"
	kenney_body_instance.set_meta("source_asset", kenney_body_asset_path)
	add_child(kenney_body_instance)
	_set_procedural_body_visible(false)
	_install_kenney_wheels()
	kenney_active = true
	set_meta("presentation_asset_source", "Kenney Car Kit 3.1")
	set_meta("presentation_asset_path", kenney_body_asset_path)

func _capture_body_mesh(source_mesh: Mesh) -> bool:
	kenney_source_arrays.clear()
	kenney_surface_primitives.clear()
	kenney_surface_materials.clear()
	kenney_surface_base_colors.clear()
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
		kenney_source_arrays.append(arrays)
		kenney_surface_primitives.append(source_mesh.surface_get_primitive_type(surface_index))
		var source_material := source_mesh.surface_get_material(surface_index)
		var material: Material = source_material.duplicate(true) as Material if source_material != null else null
		kenney_surface_materials.append(material)
		if material is BaseMaterial3D:
			kenney_surface_base_colors.append((material as BaseMaterial3D).albedo_color)
		else:
			kenney_surface_base_colors.append(Color.WHITE)
	if not have_vertex:
		return false
	kenney_source_aabb = AABB(minimum, maximum - minimum)
	return kenney_source_aabb.size.x > 0.001 and kenney_source_aabb.size.y > 0.001 and kenney_source_aabb.size.z > 0.001

func _update_kenney_body() -> void:
	if kenney_body_instance == null or vehicle == null or vehicle.model == null:
		return
	var output := ArrayMesh.new()
	var reference := vehicle.global_reference_transform()
	var forward := reference.basis.x.normalized()
	var up := reference.basis.y.normalized()
	var right := reference.basis.z.normalized()
	for surface_index in range(kenney_source_arrays.size()):
		var arrays: Array = kenney_source_arrays[surface_index].duplicate(true)
		var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var mapped_vertices := PackedVector3Array()
		mapped_vertices.resize(source_vertices.size())
		for index in range(source_vertices.size()):
			mapped_vertices[index] = _map_kenney_vertex(source_vertices[index])
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

		output.add_surface_from_arrays(kenney_surface_primitives[surface_index], arrays)
		if surface_index < kenney_surface_materials.size() and kenney_surface_materials[surface_index] != null:
			output.surface_set_material(surface_index, kenney_surface_materials[surface_index])
	kenney_body_instance.mesh = output

func _map_kenney_vertex(source: Vector3) -> Vector3:
	var size := kenney_source_aabb.size
	var u := clampf((source.z - kenney_source_aabb.position.z) / maxf(size.z, 0.001), 0.0, 1.0)
	# Kenney's +X is vehicle-left, so reverse X when interpolating CrashVector's
	# explicit left/right structural cage.
	var side_t := clampf(1.0 - (source.x - kenney_source_aabb.position.x) / maxf(size.x, 0.001), 0.0, 1.0)
	var height_t := clampf((source.y - kenney_source_aabb.position.y) / maxf(size.y, 0.001), 0.0, 1.0)
	var section: Dictionary = _section_at_u(u)
	var lower := _v3(section, "lower_left").lerp(_v3(section, "lower_right"), side_t)
	var belt := _v3(section, "belt_left").lerp(_v3(section, "belt_right"), side_t)
	var upper := _v3(section, "upper_left").lerp(_v3(section, "upper_right"), side_t)
	var belt_t := clampf(float(profile.get("belt_ratio", 0.58)), 0.35, 0.78)
	if height_t <= belt_t:
		return lower.lerp(belt, height_t / maxf(belt_t, 0.001))
	return belt.lerp(upper, (height_t - belt_t) / maxf(1.0 - belt_t, 0.001))

func _update_kenney_paint() -> void:
	if vehicle == null:
		return
	var paint := CarPaintCatalog.color(vehicle.paint_id)
	for index in range(kenney_surface_materials.size()):
		var material := kenney_surface_materials[index]
		if not material is BaseMaterial3D:
			continue
		var base := kenney_surface_base_colors[index]
		# Kenney's palette texture and baked details remain intact; albedo colour is
		# used as a per-instance multiplier so the existing CrashVector paint
		# selector still has an immediate, replay-safe effect.
		(material as BaseMaterial3D).albedo_color = Color(
			base.r * paint.r,
			base.g * paint.g,
			base.b * paint.b,
			base.a
		)

func _set_procedural_body_visible(value: bool) -> void:
	for control in [body_instance, glass_instance, trim_instance, accent_instance, grille, lower_front_trim, rear_trim]:
		if control != null:
			control.visible = value
	for collection in [headlamps, tail_lamps, mirrors, rocker_cladding, roof_rails]:
		for item in collection:
			if item != null:
				item.visible = value

func _install_kenney_wheels() -> void:
	kenney_wheel_nodes.clear()
	if not ResourceLoader.exists(kenney_wheel_asset_path):
		return
	var wheel_resource := ResourceLoader.load(kenney_wheel_asset_path)
	if not wheel_resource is PackedScene:
		return
	for index in range(wheel_groups.size()):
		var imported := (wheel_resource as PackedScene).instantiate()
		if not imported is Node3D:
			imported.free()
			continue
		var wheel := imported as Node3D
		wheel.name = "KenneyWheel"
		wheel.set_meta("source_asset", kenney_wheel_asset_path)
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
		# Kenney wheel axle is local X; CrashVector wheel groups spin about local Z.
		wheel.rotation_degrees.y = 90.0
		wheel_groups[index].add_child(wheel)
		kenney_wheel_nodes.append(wheel)
		if index < wheel_tires.size():
			wheel_tires[index].visible = false
		if index < wheel_rims.size():
			wheel_rims[index].visible = false
		if index < wheel_hubs.size():
			wheel_hubs[index].visible = false
		if index < spoke_roots.size():
			spoke_roots[index].visible = false

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
	var best: MeshInstance3D
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
