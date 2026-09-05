# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name M16VehicleVisual
extends Node3D

const VISUAL_SECTION_COUNT := 19

var vehicle: CompactHatchback
var profile: Dictionary = {}
var profile_id: StringName = PassengerCarCatalog.B_SEGMENT_HATCHBACK

var body_mesh := ImmediateMesh.new()
var glass_mesh := ImmediateMesh.new()
var trim_mesh := ImmediateMesh.new()
var body_instance := MeshInstance3D.new()
var glass_instance := MeshInstance3D.new()
var trim_instance := MeshInstance3D.new()

var body_material := StandardMaterial3D.new()
var glass_material := StandardMaterial3D.new()
var trim_material := StandardMaterial3D.new()
var lamp_material := StandardMaterial3D.new()
var tail_material := StandardMaterial3D.new()
var dark_material := StandardMaterial3D.new()
var chrome_material := StandardMaterial3D.new()

var headlamps: Array[MeshInstance3D] = []
var tail_lamps: Array[MeshInstance3D] = []
var mirrors: Array[MeshInstance3D] = []
var rocker_cladding: Array[MeshInstance3D] = []
var roof_rails: Array[MeshInstance3D] = []
var grille: MeshInstance3D
var lower_front_trim: MeshInstance3D
var rear_trim: MeshInstance3D

var wheel_groups: Array[Node3D] = []
var wheel_tires: Array[MeshInstance3D] = []
var wheel_rims: Array[MeshInstance3D] = []
var wheel_hubs: Array[MeshInstance3D] = []
var last_paint := Color.TRANSPARENT

func configure(target: CompactHatchback) -> void:
	vehicle = target
	if vehicle == null:
		return
	profile_id = vehicle.vehicle_preset_id
	profile = VehicleVisualProfileCatalog.data(profile_id)
	name = "M16VehicleVisual"
	process_priority = 50
	_build_materials()
	_build_surface_nodes()
	_build_details()
	_build_wheels()
	_hide_legacy_visuals()
	update_from_vehicle(0.0)
	set_process(true)

func _process(delta: float) -> void:
	if vehicle == null or not is_instance_valid(vehicle) or vehicle.model == null:
		return
	update_from_vehicle(delta)

func _hide_legacy_visuals() -> void:
	# M16 is presentation-only. Hiding the old generated shell/wheels leaves the
	# M11-M14 structural model, rigid chassis and collision geometry untouched.
	if vehicle.body_shell != null:
		vehicle.body_shell.visible = false
	if vehicle.wheel_rig != null:
		vehicle.wheel_rig.visible = false

func _build_materials() -> void:
	body_material.metallic = 0.38
	body_material.roughness = 0.24
	body_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass_material.albedo_color = Color(0.035, 0.060, 0.085, 0.96)
	glass_material.metallic = 0.10
	glass_material.roughness = 0.09
	glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	trim_material.albedo_color = Color(0.018, 0.024, 0.032)
	trim_material.metallic = 0.20
	trim_material.roughness = 0.38
	lamp_material.albedo_color = Color(0.86, 0.93, 1.00)
	lamp_material.emission_enabled = true
	lamp_material.emission = Color(0.24, 0.34, 0.46)
	lamp_material.emission_energy_multiplier = 0.22
	lamp_material.roughness = 0.15
	tail_material.albedo_color = Color(0.62, 0.018, 0.014)
	tail_material.emission_enabled = true
	tail_material.emission = Color(0.28, 0.006, 0.004)
	tail_material.emission_energy_multiplier = 0.18
	tail_material.roughness = 0.18
	dark_material.albedo_color = Color(0.024, 0.030, 0.038)
	dark_material.metallic = 0.18
	dark_material.roughness = 0.56
	chrome_material.albedo_color = Color(0.42, 0.46, 0.52)
	chrome_material.metallic = 0.88
	chrome_material.roughness = 0.20

func _build_surface_nodes() -> void:
	body_instance.name = "M16PaintedBody"
	body_instance.mesh = body_mesh
	add_child(body_instance)
	glass_instance.name = "M16Glazing"
	glass_instance.mesh = glass_mesh
	add_child(glass_instance)
	trim_instance.name = "M16BodyLines"
	trim_instance.mesh = trim_mesh
	add_child(trim_instance)

func _build_details() -> void:
	for side in [-1.0, 1.0]:
		var head := _box_detail("M16Headlamp", Vector3(0.12, 0.16, 0.32), lamp_material)
		head.set_meta("side", side)
		headlamps.append(head)
		var tail := _box_detail("M16TailLamp", Vector3(0.11, 0.18, 0.28), tail_material)
		tail.set_meta("side", side)
		tail_lamps.append(tail)
		var mirror := _box_detail("M16Mirror", Vector3(0.16, 0.10, 0.20), dark_material)
		mirror.set_meta("side", side)
		mirrors.append(mirror)
		var rocker := _box_detail("M16RockerCladding", Vector3(2.4, 0.10, 0.075), dark_material)
		rocker.set_meta("side", side)
		rocker_cladding.append(rocker)
	grille = _box_detail("M16Grille", Vector3(0.10, 0.34, 1.08), dark_material)
	lower_front_trim = _box_detail("M16LowerFrontTrim", Vector3(0.12, 0.16, 1.34), dark_material)
	rear_trim = _box_detail("M16RearTrim", Vector3(0.10, 0.13, 1.22), dark_material)
	if String(profile.get("style", "hatch")) == "suv":
		for side in [-1.0, 1.0]:
			var rail := _box_detail("M16RoofRail", Vector3(2.1, 0.045, 0.045), chrome_material)
			rail.set_meta("side", side)
			roof_rails.append(rail)

func _build_wheels() -> void:
	var radius := float(profile.get("wheel_radius_m", 0.305))
	var width := float(profile.get("wheel_width_m", 0.195))
	var rim_ratio := float(profile.get("rim_ratio", 0.60))
	var tire_material := StandardMaterial3D.new()
	tire_material.albedo_color = Color(0.015, 0.017, 0.020)
	tire_material.roughness = 0.92
	var rim_material := StandardMaterial3D.new()
	rim_material.albedo_color = Color(0.48, 0.51, 0.56)
	rim_material.metallic = 0.90
	rim_material.roughness = 0.18
	var hub_material := StandardMaterial3D.new()
	hub_material.albedo_color = Color(0.10, 0.11, 0.13)
	hub_material.metallic = 0.74
	hub_material.roughness = 0.30
	for _index in CompactHatchbackBuilder.wheel_anchor_indices():
		var group := Node3D.new()
		group.name = "M16Wheel"
		add_child(group)
		wheel_groups.append(group)

		var tire_mesh := CylinderMesh.new()
		tire_mesh.top_radius = radius
		tire_mesh.bottom_radius = radius
		tire_mesh.height = width
		tire_mesh.radial_segments = 36
		tire_mesh.rings = 3
		tire_mesh.material = tire_material
		var tire := MeshInstance3D.new()
		tire.name = "Tyre"
		tire.mesh = tire_mesh
		tire.rotation_degrees.x = 90.0
		group.add_child(tire)
		wheel_tires.append(tire)

		var rim_mesh := CylinderMesh.new()
		rim_mesh.top_radius = radius * rim_ratio
		rim_mesh.bottom_radius = radius * rim_ratio
		rim_mesh.height = width * 1.04
		rim_mesh.radial_segments = 28
		rim_mesh.rings = 1
		rim_mesh.material = rim_material
		var rim := MeshInstance3D.new()
		rim.name = "AlloyRim"
		rim.mesh = rim_mesh
		rim.rotation_degrees.x = 90.0
		group.add_child(rim)
		wheel_rims.append(rim)

		var hub_mesh := CylinderMesh.new()
		hub_mesh.top_radius = radius * 0.16
		hub_mesh.bottom_radius = radius * 0.16
		hub_mesh.height = width * 1.08
		hub_mesh.radial_segments = 18
		hub_mesh.material = hub_material
		var hub := MeshInstance3D.new()
		hub.name = "Hub"
		hub.mesh = hub_mesh
		hub.rotation_degrees.x = 90.0
		group.add_child(hub)
		wheel_hubs.append(hub)

func update_from_vehicle(delta: float) -> void:
	if vehicle == null or vehicle.model == null:
		return
	var paint := CarPaintCatalog.color(vehicle.paint_id)
	if paint != last_paint:
		last_paint = paint
		body_material.albedo_color = paint
	_build_body_surface()
	_build_glass_surface()
	_build_trim_surface()
	_update_details()
	_update_wheels(delta)

func _build_body_surface() -> void:
	body_mesh.clear_surfaces()
	body_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, body_material)
	var previous := _section_at_u(0.0)
	for i in range(1, VISUAL_SECTION_COUNT):
		var u := float(i) / float(VISUAL_SECTION_COUNT - 1)
		var current := _section_at_u(u)
		_quad_on(body_mesh, previous.lower_left, current.lower_left, current.belt_left, previous.belt_left)
		_quad_on(body_mesh, previous.lower_right, previous.belt_right, current.belt_right, current.lower_right)
		_quad_on(body_mesh, previous.upper_left, current.upper_left, current.upper_right, previous.upper_right)
		_quad_on(body_mesh, previous.lower_left, previous.lower_right, current.lower_right, current.lower_left)
		previous = current
	var rear := _section_at_u(0.0)
	var front := _section_at_u(1.0)
	_quad_on(body_mesh, rear.lower_right, rear.lower_left, rear.upper_left, rear.upper_right)
	_quad_on(body_mesh, front.lower_left, front.lower_right, front.upper_right, front.upper_left)
	body_mesh.surface_end()

func _build_glass_surface() -> void:
	glass_mesh.clear_surfaces()
	glass_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, glass_material)
	var glass_start := float(profile.get("glass_start_u", 0.20))
	var glass_end := float(profile.get("glass_end_u", 0.71))
	var previous := _section_at_u(glass_start)
	var glass_sections := maxi(int(ceil((glass_end - glass_start) * float(VISUAL_SECTION_COUNT))), 4)
	for i in range(1, glass_sections + 1):
		var u := lerpf(glass_start, glass_end, float(i) / float(glass_sections))
		var current := _section_at_u(u)
		_quad_on(glass_mesh, previous.belt_left, current.belt_left, current.upper_left, previous.upper_left)
		_quad_on(glass_mesh, previous.belt_right, previous.upper_right, current.upper_right, current.belt_right)
		previous = current
	var rear := _section_at_u(glass_start)
	var front := _section_at_u(glass_end)
	_quad_on(glass_mesh, rear.belt_right, rear.belt_left, rear.upper_left, rear.upper_right)
	_quad_on(glass_mesh, front.belt_left, front.belt_right, front.upper_right, front.upper_left)
	glass_mesh.surface_end()

func _build_trim_surface() -> void:
	trim_mesh.clear_surfaces()
	trim_mesh.surface_begin(Mesh.PRIMITIVE_LINES, trim_material)
	var glass_start := float(profile.get("glass_start_u", 0.20))
	var glass_end := float(profile.get("glass_end_u", 0.71))
	for side in ["left", "right"]:
		var previous := _section_at_u(glass_start)
		for i in range(1, 11):
			var current := _section_at_u(lerpf(glass_start, glass_end, float(i) / 10.0))
			_line_on(trim_mesh, previous.get("belt_%s" % side), current.get("belt_%s" % side))
			_line_on(trim_mesh, previous.get("upper_%s" % side), current.get("upper_%s" % side))
			previous = current
	for pillar_u in [glass_start, lerpf(glass_start, glass_end, 0.34), lerpf(glass_start, glass_end, 0.66), glass_end]:
		var section := _section_at_u(pillar_u)
		_line_on(trim_mesh, section.belt_left, section.upper_left)
		_line_on(trim_mesh, section.belt_right, section.upper_right)
	for door_u in [lerpf(glass_start, glass_end, 0.38), lerpf(glass_start, glass_end, 0.69)]:
		var section := _section_at_u(door_u)
		var left_low: Vector3 = section.lower_left.lerp(section.belt_left, 0.18)
		var right_low: Vector3 = section.lower_right.lerp(section.belt_right, 0.18)
		_line_on(trim_mesh, left_low, section.belt_left)
		_line_on(trim_mesh, right_low, section.belt_right)
	trim_mesh.surface_end()

func _section_at_u(u: float) -> Dictionary:
	var station_position := clampf(u, 0.0, 1.0) * float(CompactHatchbackBuilder.STATION_X.size() - 1)
	var a := int(floor(station_position))
	var b := mini(a + 1, CompactHatchbackBuilder.STATION_X.size() - 1)
	var t := station_position - float(a)
	var lower_left := _node_position(a, 0).lerp(_node_position(b, 0), t)
	var lower_right := _node_position(a, 1).lerp(_node_position(b, 1), t)
	var raw_upper_left := _node_position(a, 2).lerp(_node_position(b, 2), t)
	var raw_upper_right := _node_position(a, 3).lerp(_node_position(b, 3), t)
	var reference := vehicle.global_reference_transform()
	var forward := reference.basis.x.normalized()
	var up := reference.basis.y.normalized()
	var upper_center := (raw_upper_left + raw_upper_right) * 0.5
	var upper_half := (raw_upper_right - raw_upper_left) * 0.5
	var width_scale := VehicleVisualProfileCatalog.sample_station(profile, "upper_width_scale", station_position)
	var x_offset := VehicleVisualProfileCatalog.sample_station(profile, "upper_x_offset_m", station_position)
	var roof_offset := VehicleVisualProfileCatalog.sample_station(profile, "roof_offset_m", station_position)
	var glass_end := float(profile.get("glass_end_u", 0.71))
	if u > glass_end:
		var hood_t := smoothstep(glass_end, minf(glass_end + 0.16, 0.98), u)
		roof_offset += float(profile.get("hood_raise_m", 0.0)) * hood_t
	upper_center += forward * x_offset + up * roof_offset
	var upper_left := upper_center - upper_half * width_scale
	var upper_right := upper_center + upper_half * width_scale
	var belt_ratio := float(profile.get("belt_ratio", 0.58))
	var belt_left := lower_left.lerp(upper_left, belt_ratio)
	var belt_right := lower_right.lerp(upper_right, belt_ratio)
	return {
		"lower_left": lower_left,
		"lower_right": lower_right,
		"belt_left": belt_left,
		"belt_right": belt_right,
		"upper_left": upper_left,
		"upper_right": upper_right,
	}

func _node_position(station: int, corner: int) -> Vector3:
	var index := CompactHatchbackBuilder.node_index(station, corner)
	if index < 0 or index >= vehicle.model.nodes.size():
		return Vector3.ZERO
	return vehicle.model.nodes[index].position_m

func _update_details() -> void:
	var reference := vehicle.global_reference_transform()
	var forward := reference.basis.x.normalized()
	var up := reference.basis.y.normalized()
	var right := reference.basis.z.normalized()
	var front := _section_at_u(0.985)
	var rear := _section_at_u(0.015)
	var front_center := (front.belt_left + front.belt_right) * 0.5
	var rear_center := (rear.belt_left + rear.belt_right) * 0.5
	var front_half_width := front.belt_left.distance_to(front.belt_right) * 0.5
	var rear_half_width := rear.belt_left.distance_to(rear.belt_right) * 0.5
	for i in range(2):
		var side := float(headlamps[i].get_meta("side"))
		headlamps[i].position = front_center + forward * 0.075 + right * side * front_half_width * 0.58 + up * 0.02
		headlamps[i].basis = reference.basis
		tail_lamps[i].position = rear_center - forward * 0.055 + right * side * rear_half_width * 0.62 + up * 0.04
		tail_lamps[i].basis = reference.basis

	var grille_height := 0.46 if String(profile.get("style", "hatch")) in ["suv", "mpv"] else 0.34
	var grille_mesh := grille.mesh as BoxMesh
	grille_mesh.size.y = grille_height
	grille.position = front_center + forward * 0.082 - up * 0.16
	grille.basis = reference.basis
	lower_front_trim.position = front_center + forward * 0.065 - up * 0.37
	lower_front_trim.basis = reference.basis
	rear_trim.position = rear_center - forward * 0.050 - up * 0.32
	rear_trim.basis = reference.basis

	var mirror_u := maxf(float(profile.get("glass_end_u", 0.71)) - 0.09, 0.45)
	var mirror_section := _section_at_u(mirror_u)
	for mirror in mirrors:
		var side := float(mirror.get_meta("side"))
		var edge: Vector3 = mirror_section.belt_left if side < 0.0 else mirror_section.belt_right
		mirror.position = edge + right * side * 0.12 + up * 0.10
		mirror.basis = reference.basis

	var cladding_height := float(profile.get("cladding_height_m", 0.0))
	var rocker_rear := _section_at_u(0.20)
	var rocker_front := _section_at_u(0.78)
	var rocker_center := ((rocker_rear.lower_left + rocker_rear.lower_right) + (rocker_front.lower_left + rocker_front.lower_right)) * 0.25
	var rocker_length := ((rocker_front.lower_left + rocker_front.lower_right) * 0.5 - (rocker_rear.lower_left + rocker_rear.lower_right) * 0.5).length()
	for rocker in rocker_cladding:
		var side := float(rocker.get_meta("side"))
		var mesh := rocker.mesh as BoxMesh
		mesh.size.x = maxf(rocker_length, 0.8)
		mesh.size.y = 0.10 + cladding_height
		var half_width := rocker_rear.lower_left.distance_to(rocker_rear.lower_right) * 0.5
		rocker.position = rocker_center + right * side * (half_width + 0.025) - up * (0.22 - cladding_height * 0.25)
		rocker.basis = reference.basis

	if not roof_rails.is_empty():
		var rail_rear := _section_at_u(0.28)
		var rail_front := _section_at_u(0.66)
		var rail_rear_center := (rail_rear.upper_left + rail_rear.upper_right) * 0.5
		var rail_front_center := (rail_front.upper_left + rail_front.upper_right) * 0.5
		var rail_length := rail_rear_center.distance_to(rail_front_center)
		for rail in roof_rails:
			var side := float(rail.get_meta("side"))
			var mesh := rail.mesh as BoxMesh
			mesh.size.x = maxf(rail_length, 0.8)
			var half_width := rail_rear.upper_left.distance_to(rail_rear.upper_right) * 0.5
			rail.position = (rail_rear_center + rail_front_center) * 0.5 + right * side * half_width * 0.78 + up * 0.06
			rail.basis = reference.basis

func _update_wheels(delta: float) -> void:
	var anchors := CompactHatchbackBuilder.wheel_anchor_indices()
	if anchors.size() != wheel_groups.size():
		return
	var reference := vehicle.global_reference_transform()
	var up := reference.basis.y.normalized()
	var right := reference.basis.z.normalized()
	var radius := float(profile.get("wheel_radius_m", 0.305))
	var width := float(profile.get("wheel_width_m", 0.195))
	var side_offset := width * 0.52
	var center := Vector3.ZERO
	for index in anchors:
		center += vehicle.model.nodes[index].position_m
	center /= float(anchors.size())
	for i in range(anchors.size()):
		var node = vehicle.model.nodes[anchors[i]]
		var side := -1.0 if (node.position_m - center).dot(right) < 0.0 else 1.0
		var position := node.position_m - up * (radius + 0.10) + right * side * side_offset
		if position.y < radius:
			position.y = radius
		wheel_groups[i].position = position
		wheel_groups[i].basis = reference.basis
		if delta > 0.0:
			var forward_speed := node.velocity_ms.dot(reference.basis.x.normalized())
			var spin := forward_speed / maxf(radius, 0.01) * delta
			wheel_tires[i].rotation.z -= spin
			wheel_rims[i].rotation.z -= spin
			wheel_hubs[i].rotation.z -= spin

func _box_detail(node_name: String, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	add_child(instance)
	return instance

func _quad_on(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_triangle_on(mesh, a, b, c)
	_triangle_on(mesh, a, c, d)

func _triangle_on(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.is_zero_approx():
		normal = Vector3.UP
	for vertex in [a, b, c]:
		mesh.surface_set_normal(normal)
		mesh.surface_add_vertex(vertex)

func _line_on(mesh: ImmediateMesh, a: Vector3, b: Vector3) -> void:
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)
