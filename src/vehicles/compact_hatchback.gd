# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name CompactHatchback
extends Node3D

@export var vehicle_preset_id: StringName = PassengerCarCatalog.B_SEGMENT_HATCHBACK
@export var paint_id: StringName = CarPaintCatalog.ELECTRIC_BLUE
@export_range(1.0, 100000.0, 1.0, "or_greater") var total_mass_kg: float = 1150.0
@export_range(0.0, 300.0, 1.0, "or_greater") var initial_speed_kmh: float = 50.0
@export var barrier_x_m: float = 5.0
@export var origin_offset_m: Vector3 = Vector3.ZERO
@export_range(-180.0, 180.0, 1.0) var heading_deg: float = 0.0
@export_range(1, 16, 1) var solver_substeps: int = 6
@export var show_structure: bool = true
@export var auto_step: bool = true

var model: StructuralModel
var body_shell: DeformableBodyShell
var wheel_rig: SimpleWheelRig
var debug_renderer: StructuralDebugRenderer
var front_bumper := MeshInstance3D.new()
var front_bumper_detached: bool = false
var front_bumper_velocity_ms := Vector3.ZERO

func _ready() -> void:
	model = PassengerCarBuilder.build(vehicle_preset_id, total_mass_kg, initial_speed_kmh, barrier_x_m, origin_offset_m)
	model.rotate_y_about(origin_offset_m, deg_to_rad(heading_deg), true)
	_build_body_shell()
	_build_wheels()
	_build_structure_debugger()
	_build_front_bumper()
	_update_visuals(0.0)

func _physics_process(delta: float) -> void:
	if model == null or not auto_step:
		return
	model.step(delta, solver_substeps)
	_update_visuals(delta)

func step_external(delta: float) -> void:
	_update_visuals(delta)

func toggle_structure_debug() -> void:
	show_structure = not show_structure
	if debug_renderer != null:
		debug_renderer.visible = show_structure

func set_structure_debug(value: bool) -> void:
	show_structure = value
	if debug_renderer != null:
		debug_renderer.visible = value

func set_paint_id(value: StringName) -> void:
	paint_id = value if CarPaintCatalog.is_valid(value) else CarPaintCatalog.ELECTRIC_BLUE
	if body_shell != null:
		body_shell.set_paint_color(CarPaintCatalog.color(paint_id))

func vehicle_class_name() -> String:
	return PassengerCarCatalog.display_name(vehicle_preset_id)

func global_linear_velocity_ms() -> Vector3:
	return VehicleKinematics.linear_velocity_ms(model)

func global_angular_velocity_rad_s() -> Vector3:
	return VehicleKinematics.angular_velocity_rad_s(model)

func global_reference_transform() -> Transform3D:
	return VehicleKinematics.reference_transform(
		model,
		CompactHatchbackBuilder.rear_reference_nodes(),
		CompactHatchbackBuilder.front_reference_nodes(),
		CompactHatchbackBuilder.left_reference_nodes(),
		CompactHatchbackBuilder.right_reference_nodes()
	)

func front_crush_deformation_m() -> float:
	return model.max_permanent_deformation_for_role(&"front_crush")

func safety_cell_deformation_m() -> float:
	return model.max_permanent_deformation_for_role(&"safety_cell")

func replay_visual_state() -> Dictionary:
	return {
		"front_bumper_detached": front_bumper_detached,
		"front_bumper_position_m": front_bumper.position,
		"front_bumper_velocity_ms": front_bumper_velocity_ms,
	}

func apply_replay_visual_state(state: Dictionary) -> void:
	front_bumper_detached = bool(state.get("front_bumper_detached", false))
	front_bumper_velocity_ms = state.get("front_bumper_velocity_ms", Vector3.ZERO)
	if front_bumper_detached:
		front_bumper.position = state.get("front_bumper_position_m", front_bumper.position)
	_update_visuals(0.0)

func _build_body_shell() -> void:
	body_shell = DeformableBodyShell.new()
	body_shell.name = "DeformableBodyShell"
	add_child(body_shell)
	body_shell.configure(model, CompactHatchbackBuilder.STATION_X.size(), CarPaintCatalog.color(paint_id))

func _build_wheels() -> void:
	wheel_rig = SimpleWheelRig.new()
	wheel_rig.name = "SimpleWheelRig"
	add_child(wheel_rig)
	wheel_rig.configure(model, CompactHatchbackBuilder.wheel_anchor_indices())

func _build_structure_debugger() -> void:
	debug_renderer = StructuralDebugRenderer.new()
	debug_renderer.name = "StructuralDebugRenderer"
	add_child(debug_renderer)
	debug_renderer.configure(model)
	debug_renderer.visible = show_structure

func _build_front_bumper() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.16, 0.24, 1.45)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.06, 0.08, 0.11)
	material.metallic = 0.15
	material.roughness = 0.48
	mesh.material = material
	front_bumper.mesh = mesh
	front_bumper.name = "FrontBumper"
	add_child(front_bumper)

func _update_visuals(delta: float) -> void:
	if body_shell != null:
		body_shell.update_from_model()
	if wheel_rig != null:
		wheel_rig.update_from_model(delta)
	if debug_renderer != null:
		debug_renderer.update_from_model()
	_update_front_bumper(delta)

func _update_front_bumper(delta: float) -> void:
	if model == null:
		return
	if not front_bumper_detached:
		var front_nodes := CompactHatchbackBuilder.station_nodes(CompactHatchbackBuilder.FRONT_STATION)
		var forward := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(heading_deg)).normalized()
		front_bumper.position = model.average_position_for_nodes(front_nodes) + forward * 0.10 + Vector3(0.0, -0.12, 0.0)
		var should_detach := (
			model.broken_beam_count_for_role(&"front_crush") > 0
			or model.max_permanent_deformation_for_role(&"front_crush") > 0.18
		)
		if should_detach:
			front_bumper_detached = true
			front_bumper_velocity_ms = model.average_velocity_for_nodes(front_nodes)
		return

	if delta <= 0.0:
		return
	front_bumper_velocity_ms.y -= 9.80665 * delta
	front_bumper.position += front_bumper_velocity_ms * delta
	if front_bumper.position.y < 0.12:
		front_bumper.position.y = 0.12
		if front_bumper_velocity_ms.y < 0.0:
			front_bumper_velocity_ms.y *= -0.18
		front_bumper_velocity_ms.x *= 0.94
		front_bumper_velocity_ms.z *= 0.94
