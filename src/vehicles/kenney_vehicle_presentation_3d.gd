# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name KenneyVehiclePresentation3D
extends KenneyVehicleSkin3D

# Presentation-only adapter over KenneyVehicleSkin3D. The base class preserves
# the pristine Kenney body at zero deformation and applies only displacement
# from CrashVector's authoritative structural state. This layer adds the final
# production-presentation concerns that must not leak back into physics:
# layered body/glass/trim/lamp/wheel materials and per-body wheel-opening alignment.

const SOURCE_TO_HOST_WHEEL := {
	"wheel-back-left": 0,
	"wheel-back-right": 1,
	"wheel-front-left": 2,
	"wheel-front-right": 3,
}
const BODY_PRESENTATION_METALLIC := 0.34
const BODY_PRESENTATION_ROUGHNESS := 0.22
const GLASS_ALPHA := 0.74
const GLASS_ROUGHNESS := 0.07
const TRIM_ROUGHNESS := 0.42
const LAMP_EMISSION_ENERGY := 0.42
const TAIL_EMISSION_ENERGY := 0.34
const TIRE_ROUGHNESS := 0.88
const RIM_METALLIC := 0.92
const RIM_ROUGHNESS := 0.16

var neutral_wheel_offsets: Array[Vector3] = []
var source_wheel_centres: Array[Vector3] = []
var fitted_wheel_world_positions: Array[Vector3] = []
var physical_wheel_world_positions: Array[Vector3] = []
var body_mount_offset := Vector3.ZERO
var source_wheel_alignment_complete := false
var presentation_tire_material: StandardMaterial3D
var presentation_rim_material: StandardMaterial3D
var presentation_hub_material: StandardMaterial3D

func configure(owner_visual: M162VehicleVisual) -> void:
	super.configure(owner_visual)
	if not active:
		return
	_tune_body_finish()
	_configure_detail_materials()
	_configure_wheel_finish()
	_show_presentation_details()
	# Imported wheels are intentionally disabled because their nested mesh-space
	# transform cannot be reconciled with the structural suspension anchors.
	# The established M16 wheel roots remain authoritative for road support and
	# spin. Fit the body to those roots; never move a suspension root to suit a
	# source mesh, or the car visibly floats above the road.
	neutral_wheel_offsets.resize(host.wheel_groups.size())
	source_wheel_centres.resize(host.wheel_groups.size())
	fitted_wheel_world_positions.resize(host.wheel_groups.size())
	physical_wheel_world_positions.resize(host.wheel_groups.size())
	for index in range(neutral_wheel_offsets.size()):
		neutral_wheel_offsets[index] = Vector3.ZERO
		source_wheel_centres[index] = Vector3.ZERO
		fitted_wheel_world_positions[index] = Vector3.ZERO
		physical_wheel_world_positions[index] = Vector3.ZERO
	source_wheel_alignment_complete = _capture_source_wheel_centres()
	set_meta("presentation_pristine_body", true)
	set_meta("presentation_wheel_alignment", source_wheel_alignment_complete)
	set_meta("presentation_wheel_mode", "source-body-grounded-fit")
	set_meta("presentation_body_finish", "layered_automotive")
	set_meta("presentation_detail_layers", "glass_trim_lamps_wheels")
	set_meta("presentation_detail_overlay", true)

func _process(delta: float) -> void:
	super._process(delta)
	_update_grounded_body_mount()
	# The base Kenney skin hides the procedural shell every frame. Re-enable only
	# the dedicated presentation layers after that hide pass: never the procedural
	# painted body. These layers supply real material separation that the single
	# Kenney colormap surface cannot express on its own.
	_show_presentation_details()

func _map_vertex(source: Vector3) -> Vector3:
	# The body follows the same deformation mapping as before, plus one neutral
	# mounting correction that aligns its source wheel openings vertically to the
	# road-supported wheel roots. This is presentation-only.
	return super._map_vertex(source) + body_mount_offset

func _tune_body_finish() -> void:
	# Car Kit uses one colour-map material for the complete body. Keep its texture
	# and CrashVector paint multiplier intact, but give the imported shell a real
	# painted-metal response. Glass, trim and lamps are deliberately supplied by
	# separate structural presentation layers below so they are not forced to
	# share this metallic/roughness response.
	for material in surface_materials:
		if not material is BaseMaterial3D:
			continue
		var base := material as BaseMaterial3D
		base.metallic = maxf(base.metallic, BODY_PRESENTATION_METALLIC)
		base.roughness = minf(base.roughness, BODY_PRESENTATION_ROUGHNESS)

func _configure_detail_materials() -> void:
	if host == null:
		return

	host.glass_material.albedo_color = Color(0.025, 0.050, 0.075, GLASS_ALPHA)
	host.glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	host.glass_material.metallic = 0.06
	host.glass_material.roughness = GLASS_ROUGHNESS
	host.glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	host.trim_material.albedo_color = Color(0.015, 0.020, 0.028)
	host.trim_material.metallic = 0.16
	host.trim_material.roughness = TRIM_ROUGHNESS

	host.dark_material.albedo_color = Color(0.014, 0.017, 0.022)
	host.dark_material.metallic = 0.04
	host.dark_material.roughness = 0.72

	host.chrome_material.albedo_color = Color(0.48, 0.53, 0.60)
	host.chrome_material.metallic = 0.90
	host.chrome_material.roughness = 0.17

	host.lamp_material.albedo_color = Color(0.90, 0.96, 1.00)
	host.lamp_material.metallic = 0.04
	host.lamp_material.roughness = 0.10
	host.lamp_material.emission_enabled = true
	host.lamp_material.emission = Color(0.34, 0.46, 0.62)
	host.lamp_material.emission_energy_multiplier = LAMP_EMISSION_ENERGY

	host.tail_material.albedo_color = Color(0.72, 0.020, 0.014)
	host.tail_material.metallic = 0.02
	host.tail_material.roughness = 0.14
	host.tail_material.emission_enabled = true
	host.tail_material.emission = Color(0.42, 0.008, 0.004)
	host.tail_material.emission_energy_multiplier = TAIL_EMISSION_ENERGY

func _configure_wheel_finish() -> void:
	if host == null:
		return

	presentation_tire_material = StandardMaterial3D.new()
	presentation_tire_material.albedo_color = Color(0.010, 0.012, 0.016)
	presentation_tire_material.metallic = 0.02
	presentation_tire_material.roughness = TIRE_ROUGHNESS

	presentation_rim_material = StandardMaterial3D.new()
	presentation_rim_material.albedo_color = Color(0.52, 0.57, 0.64)
	presentation_rim_material.metallic = RIM_METALLIC
	presentation_rim_material.roughness = RIM_ROUGHNESS

	presentation_hub_material = StandardMaterial3D.new()
	presentation_hub_material.albedo_color = Color(0.36, 0.40, 0.46)
	presentation_hub_material.metallic = 0.84
	presentation_hub_material.roughness = 0.22

	for tire in host.wheel_tires:
		if tire != null and tire.mesh is PrimitiveMesh:
			(tire.mesh as PrimitiveMesh).material = presentation_tire_material
	for rim in host.wheel_rims:
		if rim != null and rim.mesh is PrimitiveMesh:
			(rim.mesh as PrimitiveMesh).material = presentation_rim_material
	for hub in host.wheel_hubs:
		if hub != null and hub.mesh is PrimitiveMesh:
			(hub.mesh as PrimitiveMesh).material = presentation_hub_material
	for spoke_root in host.spoke_roots:
		if spoke_root == null:
			continue
		for child in spoke_root.get_children():
			if child is MeshInstance3D:
				var spoke := child as MeshInstance3D
				if spoke.mesh is PrimitiveMesh:
					(spoke.mesh as PrimitiveMesh).material = presentation_rim_material

func _show_presentation_details() -> void:
	if host == null:
		return

	# The imported Kenney shell remains the only painted body.
	if host.body_instance != null:
		host.body_instance.visible = false

	# Existing M16 structural detail surfaces already follow the authoritative
	# deformation cage, so reusing them gives the imported body separate physical
	# material roles without introducing a second vehicle or changing collision.
	if host.glass_instance != null:
		host.glass_instance.visible = true
	if host.trim_instance != null:
		host.trim_instance.visible = true
	if host.accent_instance != null:
		host.accent_instance.visible = true
	for item in host.headlamps:
		if item != null:
			item.visible = true
	for item in host.tail_lamps:
		if item != null:
			item.visible = true
	for item in host.mirrors:
		if item != null:
			item.visible = true
	for item in host.rocker_cladding:
		if item != null:
			item.visible = true
	for item in host.roof_rails:
		if item != null:
			item.visible = true
	for item in [host.grille, host.lower_front_trim, host.rear_trim]:
		if item != null:
			item.visible = true

func _capture_source_wheel_centres() -> bool:
	if host == null or vehicle == null or source_wheel_centres.size() != host.wheel_groups.size():
		return false
	var body_resource := ResourceLoader.load(body_asset_path)
	if not body_resource is PackedScene:
		return false
	var imported_root := (body_resource as PackedScene).instantiate()
	var source_body := _find_mesh_named(imported_root, "body")
	if source_body == null:
		source_body = _largest_non_wheel_mesh(imported_root)
	if source_body == null:
		imported_root.free()
		return false
	# _capture_body_mesh() maps vertices in the body mesh's local space. Wheel
	# centres are collected in the imported scene's root space, so convert them
	# through the body node before using the same pristine mapping. Otherwise a
	# parent transform is counted for the wheels but not for the body mesh.
	var root_to_body := _transform_from_ancestor(imported_root, source_body)
	var body_to_root := root_to_body.affine_inverse()
	var source_centres: Dictionary = {}
	_collect_named_source_wheels(imported_root, Transform3D.IDENTITY, source_centres)
	imported_root.free()

	if source_centres.size() < 4:
		push_warning("Kenney wheel fit could not resolve four source wheel centres for %s; leaving the established CrashVector wheel anchors in use." % body_asset_path)
		return false

	var aligned_count := 0
	for source_name in SOURCE_TO_HOST_WHEEL.keys():
		if not source_centres.has(source_name):
			continue
		var host_index: int = int(SOURCE_TO_HOST_WHEEL[source_name])
		if host_index < 0 or host_index >= source_wheel_centres.size():
			continue
		var source_point: Vector3 = body_to_root * (source_centres[source_name] as Vector3)
		source_wheel_centres[host_index] = source_point
		aligned_count += 1
	return aligned_count == 4

func _update_grounded_body_mount() -> void:
	if not source_wheel_alignment_complete or host == null or vehicle == null:
		return
	if source_wheel_centres.size() != host.wheel_groups.size() or physical_wheel_world_positions.size() != host.wheel_groups.size():
		return
	var accumulated_offset := Vector3.ZERO
	for index in range(host.wheel_groups.size()):
		# M16 rebuilds these roots from the suspension state. Preserve them exactly:
		# they are the only presentation positions guaranteed to share the tyre/road
		# contact plane with the production rigid chassis.
		var physical_world := host.wheel_groups[index].global_position
		physical_wheel_world_positions[index] = physical_world
	for index in range(host.wheel_groups.size()):
		var unmapped_source_world := super._map_vertex(source_wheel_centres[index])
		accumulated_offset += physical_wheel_world_positions[index] - unmapped_source_world
	body_mount_offset = accumulated_offset / float(host.wheel_groups.size())
	for index in range(host.wheel_groups.size()):
		fitted_wheel_world_positions[index] = _map_vertex(source_wheel_centres[index])
		_fit_visual_wheel_to_body(index)
	set_meta("presentation_wheel_alignment_error_m", _maximum_wheel_fit_error())

func _fit_visual_wheel_to_body(index: int) -> void:
	if index < 0 or index >= host.wheel_groups.size():
		return
	var group := host.wheel_groups[index]
	var desired_world := fitted_wheel_world_positions[index]
	var physical_world := physical_wheel_world_positions[index]
	# Preserve tyre-road height from the suspension root. Only the visual wheel
	# centre moves longitudinally/laterally into the selected body opening.
	var world_offset := desired_world - physical_world
	world_offset.y = 0.0
	var local_offset := group.global_transform.basis.inverse() * world_offset
	for wheel_part in [host.wheel_tires[index], host.wheel_rims[index], host.wheel_hubs[index]]:
		if wheel_part != null:
			wheel_part.position = local_offset
	if index < host.spoke_roots.size() and host.spoke_roots[index] != null:
		host.spoke_roots[index].position = local_offset

func _maximum_wheel_fit_error() -> float:
	var maximum := 0.0
	for index in range(mini(fitted_wheel_world_positions.size(), physical_wheel_world_positions.size())):
		maximum = maxf(maximum, fitted_wheel_world_positions[index].distance_to(physical_wheel_world_positions[index]))
	return maximum

func _collect_named_source_wheels(
	node: Node,
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
		_collect_named_source_wheels(child, accumulated, output)

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
