# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name AnalysisOverlay3D
extends Node3D

var primary_model: StructuralModel
var target_model: StructuralModel
var enabled: bool = true

var _primary_velocity := MeshInstance3D.new()
var _primary_momentum := MeshInstance3D.new()
var _target_velocity := MeshInstance3D.new()
var _target_momentum := MeshInstance3D.new()

func _ready() -> void:
	_primary_velocity.name = "PrimaryVelocityVector"
	_primary_momentum.name = "PrimaryMomentumVector"
	_target_velocity.name = "TargetVelocityVector"
	_target_momentum.name = "TargetMomentumVector"
	add_child(_primary_velocity)
	add_child(_primary_momentum)
	add_child(_target_velocity)
	add_child(_target_momentum)
	_primary_velocity.material_override = _material(Color(0.20, 0.72, 1.00))
	_primary_momentum.material_override = _material(Color(1.00, 0.62, 0.18))
	_target_velocity.material_override = _material(Color(0.42, 0.92, 0.56))
	_target_momentum.material_override = _material(Color(0.92, 0.36, 0.72))

func configure(primary: StructuralModel, target: StructuralModel = null) -> void:
	primary_model = primary
	target_model = target
	update_from_models()

func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	if value:
		update_from_models()

func update_from_models() -> void:
	if not enabled:
		return
	_update_vehicle_vectors(primary_model, _primary_velocity, _primary_momentum, 0.0)
	_update_vehicle_vectors(target_model, _target_velocity, _target_momentum, 0.18)

func _update_vehicle_vectors(
	model: StructuralModel,
	velocity_instance: MeshInstance3D,
	momentum_instance: MeshInstance3D,
	y_offset: float
) -> void:
	if model == null or model.nodes.is_empty():
		velocity_instance.visible = false
		momentum_instance.visible = false
		return
	velocity_instance.visible = true
	momentum_instance.visible = true
	var origin := model.center_of_mass_m() + Vector3(0.0, 1.0 + y_offset, 0.0)
	var velocity := model.average_velocity_ms()
	var momentum := model.total_momentum_kg_ms()
	velocity_instance.mesh = _arrow_mesh(origin, velocity, 0.10, 4.5)
	momentum_instance.mesh = _arrow_mesh(origin + Vector3(0.0, 0.20, 0.0), momentum, 0.00008, 4.5)

func _arrow_mesh(origin: Vector3, vector: Vector3, scale: float, max_length: float) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var magnitude := vector.length()
	if magnitude <= 0.000001:
		return mesh
	var direction := vector / magnitude
	var length := clampf(magnitude * scale, 0.35, max_length)
	var tip := origin + direction * length
	var side := direction.cross(Vector3.UP).normalized()
	if side.is_zero_approx():
		side = direction.cross(Vector3.RIGHT).normalized()
	var wing_length := minf(0.35, length * 0.22)
	var wing_base := tip - direction * wing_length
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(origin)
	mesh.surface_add_vertex(tip)
	mesh.surface_add_vertex(tip)
	mesh.surface_add_vertex(wing_base + side * wing_length * 0.45)
	mesh.surface_add_vertex(tip)
	mesh.surface_add_vertex(wing_base - side * wing_length * 0.45)
	mesh.surface_end()
	return mesh

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.no_depth_test = true
	return material
