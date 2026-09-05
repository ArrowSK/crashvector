# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name M16VehicleVisualRefined
extends M16VehicleVisual

# The first M16 skin established class-specific proportions. This production
# refinement closes the upper body outside the greenhouse and adds lightweight
# wheel-arch/rim detail so the generated cars read as finished vehicles rather
# than scaled structural envelopes. It remains presentation-only.

var accent_mesh := ImmediateMesh.new()
var accent_instance := MeshInstance3D.new()
var spoke_roots: Array[Node3D] = []

func _build_surface_nodes() -> void:
	super._build_surface_nodes()
	accent_instance.name = "M16BodyAccents"
	accent_instance.mesh = accent_mesh
	add_child(accent_instance)

func _build_body_surface() -> void:
	body_mesh.clear_surfaces()
	body_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, body_material)
	var glass_start: float = float(profile.get("glass_start_u", 0.20))
	var glass_end: float = float(profile.get("glass_end_u", 0.71))
	var previous_u := 0.0
	var previous: Dictionary = _section_at_u(previous_u)
	for i in range(1, VISUAL_SECTION_COUNT):
		var u: float = float(i) / float(VISUAL_SECTION_COUNT - 1)
		var current: Dictionary = _section_at_u(u)
		var midpoint := (previous_u + u) * 0.5

		# Lower painted flanks and the upper horizontal surface are continuous.
		_quad_on(body_mesh, _v3(previous, "lower_left"), _v3(current, "lower_left"), _v3(current, "belt_left"), _v3(previous, "belt_left"))
		_quad_on(body_mesh, _v3(previous, "lower_right"), _v3(previous, "belt_right"), _v3(current, "belt_right"), _v3(current, "lower_right"))
		_quad_on(body_mesh, _v3(previous, "upper_left"), _v3(current, "upper_left"), _v3(current, "upper_right"), _v3(previous, "upper_right"))
		_quad_on(body_mesh, _v3(previous, "lower_left"), _v3(previous, "lower_right"), _v3(current, "lower_right"), _v3(current, "lower_left"))

		# Outside the greenhouse, close the upper side envelope with painted body.
		# Inside it the glazing surface occupies the same belt-to-roof region.
		if midpoint < glass_start or midpoint > glass_end:
			_quad_on(body_mesh, _v3(previous, "belt_left"), _v3(current, "belt_left"), _v3(current, "upper_left"), _v3(previous, "upper_left"))
			_quad_on(body_mesh, _v3(previous, "belt_right"), _v3(previous, "upper_right"), _v3(current, "upper_right"), _v3(current, "belt_right"))

		previous = current
		previous_u = u

	var rear: Dictionary = _section_at_u(0.0)
	var front: Dictionary = _section_at_u(1.0)
	_quad_on(body_mesh, _v3(rear, "lower_right"), _v3(rear, "lower_left"), _v3(rear, "upper_left"), _v3(rear, "upper_right"))
	_quad_on(body_mesh, _v3(front, "lower_left"), _v3(front, "lower_right"), _v3(front, "upper_right"), _v3(front, "upper_left"))
	body_mesh.surface_end()

func _build_wheels() -> void:
	super._build_wheels()
	spoke_roots.clear()
	var radius: float = float(profile.get("wheel_radius_m", 0.305))
	var width: float = float(profile.get("wheel_width_m", 0.195))
	var rim_ratio: float = float(profile.get("rim_ratio", 0.60))
	var rim_radius := radius * rim_ratio
	var style := String(profile.get("style", "hatch"))
	var spoke_count := 6 if style in ["suv", "mpv"] else 5

	for i in range(wheel_groups.size()):
		# A dark inner barrel behind brighter spokes reads much more naturally than
		# the original solid metallic cylinder while staying cheap to regenerate.
		var rim_mesh := wheel_rims[i].mesh as CylinderMesh
		if rim_mesh != null:
			rim_mesh.material = dark_material
		var hub_mesh := wheel_hubs[i].mesh as CylinderMesh
		if hub_mesh != null:
			hub_mesh.material = chrome_material

		var spoke_root := Node3D.new()
		spoke_root.name = "AlloySpokes"
		wheel_groups[i].add_child(spoke_root)
		spoke_roots.append(spoke_root)
		for spoke_index in range(spoke_count):
			var angle := TAU * float(spoke_index) / float(spoke_count)
			var spoke_mesh := BoxMesh.new()
			spoke_mesh.size = Vector3(rim_radius * 0.72, maxf(rim_radius * 0.075, 0.018), width * 1.07)
			spoke_mesh.material = chrome_material
			var spoke := MeshInstance3D.new()
			spoke.name = "Spoke"
			spoke.mesh = spoke_mesh
			spoke.position = Vector3(cos(angle), sin(angle), 0.0) * rim_radius * 0.30
			spoke.rotation.z = angle
			spoke_root.add_child(spoke)

func _build_trim_surface() -> void:
	super._build_trim_surface()
	_build_arch_accents()

func _build_arch_accents() -> void:
	accent_mesh.clear_surfaces()
	accent_mesh.surface_begin(Mesh.PRIMITIVE_LINES, trim_material)
	if vehicle == null or vehicle.model == null:
		accent_mesh.surface_end()
		return
	var anchors := CompactHatchbackBuilder.wheel_anchor_indices()
	var reference := vehicle.global_reference_transform()
	var forward := reference.basis.x.normalized()
	var up := reference.basis.y.normalized()
	var right := reference.basis.z.normalized()
	var radius: float = float(profile.get("wheel_radius_m", 0.305))
	var width: float = float(profile.get("wheel_width_m", 0.195))
	var center := Vector3.ZERO
	for index in anchors:
		center += vehicle.model.nodes[index].position_m
	center /= maxf(float(anchors.size()), 1.0)

	for index in anchors:
		var node: StructuralNode = vehicle.model.nodes[index]
		var side := -1.0 if (node.position_m - center).dot(right) < 0.0 else 1.0
		var wheel_center := node.position_m - up * (radius + 0.10) + right * side * (width * 0.52 + 0.018)
		if wheel_center.y < radius:
			wheel_center.y = radius
		var arch_radius := radius * 1.13
		var previous := wheel_center + forward * arch_radius
		for step in range(1, 13):
			var angle := PI * float(step) / 12.0
			var current := wheel_center + forward * cos(angle) * arch_radius + up * sin(angle) * arch_radius
			_line_on(accent_mesh, previous, current)
			previous = current
	accent_mesh.surface_end()

func _update_wheels(delta: float) -> void:
	super._update_wheels(delta)
	for i in range(mini(spoke_roots.size(), wheel_rims.size())):
		spoke_roots[i].rotation.z = wheel_rims[i].rotation.z
