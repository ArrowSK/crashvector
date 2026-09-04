# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name StaticObstacle3D
extends Node3D

var obstacle_type: StringName = ScenarioConfig.TARGET_WALL
var surface_position_m := Vector3.ZERO
var heading_deg := 0.0
var physics_body: StaticBody3D

# M14 narrow-obstacle response. Wall/barrier remain rigid. Pole/tree keep a
# static collision body for stable Godot contact, but its complete collision
# geometry and visible geometry rotate permanently about the ground attachment
# as collision demand exceeds generic yielding capacity. This is deliberately a
# reduced-order yielding model, not a soil/foundation or timber/steel FE model.
var yield_peak_demand_j: float = 0.0
var yield_bend_angle_rad: float = 0.0
var yield_impact_direction_world := Vector3.RIGHT
var yield_failed: bool = false

func configure(type_id: StringName, position_m: Vector3, yaw_deg: float) -> void:
	obstacle_type = type_id
	surface_position_m = position_m
	heading_deg = yaw_deg
	reset_yield()
	_build_visuals()

func set_editor_transform(position_m: Vector3, yaw_deg: float) -> void:
	surface_position_m = position_m
	heading_deg = yaw_deg
	_apply_visual_transform()

func reset_yield() -> void:
	yield_peak_demand_j = 0.0
	yield_bend_angle_rad = 0.0
	yield_impact_direction_world = Vector3.RIGHT
	yield_failed = false
	_apply_visual_transform()

func apply_collision_demand(energy_j: float, impact_direction_world: Vector3) -> void:
	if obstacle_type != ScenarioConfig.TARGET_POLE and obstacle_type != ScenarioConfig.TARGET_TREE:
		return
	if not is_finite(energy_j) or energy_j <= yield_peak_demand_j:
		return
	yield_peak_demand_j = energy_j
	var horizontal := Vector3(impact_direction_world.x, 0.0, impact_direction_world.z)
	if horizontal.length_squared() > 0.0001:
		yield_impact_direction_world = horizontal.normalized()
	var yield_start_j := 70000.0
	var full_bend_j := 420000.0
	var maximum_angle_deg := 78.0
	var failure_multiplier := 1.15
	if obstacle_type == ScenarioConfig.TARGET_TREE:
		yield_start_j = 240000.0
		full_bend_j = 1550000.0
		maximum_angle_deg = 62.0
		failure_multiplier = 1.15
	var fraction := clampf((yield_peak_demand_j - yield_start_j) / maxf(full_bend_j - yield_start_j, 1.0), 0.0, 1.0)
	fraction = fraction * fraction * (3.0 - 2.0 * fraction)
	yield_bend_angle_rad = deg_to_rad(maximum_angle_deg) * fraction
	if yield_peak_demand_j >= full_bend_j * failure_multiplier:
		yield_failed = true
		yield_bend_angle_rad = deg_to_rad(88.0 if obstacle_type == ScenarioConfig.TARGET_POLE else 76.0)
	_apply_visual_transform()

func bend_angle_deg() -> float:
	return rad_to_deg(yield_bend_angle_rad)

func has_yielded() -> bool:
	return yield_bend_angle_rad > deg_to_rad(0.25)

func has_failed() -> bool:
	return yield_failed

func _build_visuals() -> void:
	for child in get_children():
		child.queue_free()
	physics_body = null
	match obstacle_type:
		ScenarioConfig.TARGET_BARRIER:
			_build_concrete_barrier()
		ScenarioConfig.TARGET_POLE:
			_build_pole()
		ScenarioConfig.TARGET_TREE:
			_build_tree()
		_:
			_build_rigid_wall()
	_build_physics_body()
	_apply_visual_transform()

func _build_rigid_wall() -> void:
	var concrete := _material(Color(0.58, 0.60, 0.61), 0.0, 0.92)
	var dark := _material(Color(0.25, 0.27, 0.28), 0.0, 0.96)
	_add_box("RigidWall", Vector3(0.45, 3.25, 9.0), concrete, Vector3(0.0, 1.625, 0.0))
	_add_box("WallFoot", Vector3(0.72, 0.20, 9.35), dark, Vector3(0.13, 0.10, 0.0))
	for z in [-3.0, 0.0, 3.0]:
		_add_box("WallJoint", Vector3(0.012, 3.08, 0.026), dark, Vector3(-0.231, 1.62, z))
	var stripe := _material(Color(0.86, 0.16, 0.08), 0.05, 0.55)
	_add_box("ImpactReferenceStripe", Vector3(0.014, 0.075, 8.45), stripe, Vector3(-0.235, 0.73, 0.0))

func _build_concrete_barrier() -> void:
	var concrete := _material(Color(0.58, 0.59, 0.58), 0.0, 0.94)
	var seam := _material(Color(0.33, 0.34, 0.34), 0.0, 0.96)
	_add_box("BarrierBase", Vector3(0.58, 0.24, 4.1), concrete, Vector3(0.08, 0.12, 0.0))
	_add_box("BarrierLower", Vector3(0.48, 0.34, 4.05), concrete, Vector3(0.03, 0.39, 0.0))
	_add_box("BarrierUpper", Vector3(0.32, 0.43, 4.0), concrete, Vector3(-0.04, 0.775, 0.0))
	for z in [-1.35, 0.0, 1.35]:
		_add_box("BarrierJoint", Vector3(0.014, 0.88, 0.022), seam, Vector3(-0.205, 0.52, z))

func _build_pole() -> void:
	var pole_material := _material(Color(0.38, 0.41, 0.44), 0.72, 0.34)
	var base_material := _material(Color(0.22, 0.24, 0.26), 0.62, 0.38)
	_add_cylinder("Pole", 0.17, 0.16, 2.9, pole_material, Vector3(0.0, 1.45, 0.0))
	_add_cylinder("PoleBase", 0.31, 0.28, 0.16, base_material, Vector3(0.0, 0.08, 0.0))
	_add_cylinder("PoleCollar", 0.23, 0.20, 0.11, base_material, Vector3(0.0, 0.22, 0.0))

func _build_tree() -> void:
	var bark := _material(Color(0.28, 0.15, 0.075), 0.0, 0.98)
	var bark_light := _material(Color(0.39, 0.22, 0.10), 0.0, 0.97)
	var leaves_a := _material(Color(0.15, 0.36, 0.15), 0.0, 0.98)
	var leaves_b := _material(Color(0.21, 0.45, 0.18), 0.0, 0.97)
	_add_cylinder("TreeTrunk", 0.25, 0.36, 3.5, bark, Vector3(0.0, 1.75, 0.0))
	_add_cylinder("TreeBase", 0.38, 0.30, 0.28, bark_light, Vector3(0.0, 0.14, 0.0))
	_add_sphere("TreeCrownA", 1.18, leaves_a, Vector3(0.0, 3.95, 0.0))
	_add_sphere("TreeCrownB", 0.88, leaves_b, Vector3(0.42, 4.42, 0.36))
	_add_sphere("TreeCrownC", 0.84, leaves_a, Vector3(-0.38, 4.35, -0.32))

func _build_physics_body() -> void:
	physics_body = StaticBody3D.new()
	physics_body.name = "StaticTargetPhysics"
	var material := PhysicsMaterial.new()
	material.friction = 0.85
	material.bounce = 0.0
	physics_body.physics_material_override = material
	add_child(physics_body)
	match obstacle_type:
		ScenarioConfig.TARGET_BARRIER:
			_add_box_collision(Vector3(0.42, 0.96, 4.10), Vector3(0.0, 0.48, 0.0))
		ScenarioConfig.TARGET_POLE:
			_add_cylinder_collision(0.18, 2.90, Vector3(0.0, 1.45, 0.0))
		ScenarioConfig.TARGET_TREE:
			_add_cylinder_collision(0.32, 3.50, Vector3(0.0, 1.75, 0.0))
		_:
			_add_box_collision(Vector3(0.45, 3.25, 9.0), Vector3(0.0, 1.625, 0.0))

func _add_box_collision(size_m: Vector3, local_position_m: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size_m
	var collision := CollisionShape3D.new()
	collision.name = "ObstacleCollision"
	collision.shape = shape
	collision.position = local_position_m
	physics_body.add_child(collision)

func _add_cylinder_collision(radius_m: float, height_m: float, local_position_m: Vector3) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius_m
	shape.height = height_m
	var collision := CollisionShape3D.new()
	collision.name = "ObstacleCollision"
	collision.shape = shape
	collision.position = local_position_m
	physics_body.add_child(collision)

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _add_box(node_name: String, size: Vector3, material: Material, local_position: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	add_child(instance)
	return instance

func _add_cylinder(node_name: String, top_radius: float, bottom_radius: float, height: float, material: Material, local_position: Vector3) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 2
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	add_child(instance)
	return instance

func _add_sphere(node_name: String, radius: float, material: Material, local_position: Vector3) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 18
	mesh.rings = 10
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	add_child(instance)
	return instance

func _apply_visual_transform() -> void:
	var yaw_basis := Basis(Vector3.UP, deg_to_rad(heading_deg))
	if obstacle_type == ScenarioConfig.TARGET_POLE or obstacle_type == ScenarioConfig.TARGET_TREE:
		var bend_axis := Vector3.UP.cross(yield_impact_direction_world).normalized()
		if bend_axis.is_zero_approx() or yield_bend_angle_rad <= 0.00001:
			basis = yaw_basis
		else:
			basis = Basis(bend_axis, yield_bend_angle_rad) * yaw_basis
		position = surface_position_m
		return
	basis = yaw_basis
	if obstacle_type == ScenarioConfig.TARGET_WALL or obstacle_type == ScenarioConfig.TARGET_BARRIER:
		var forward := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(heading_deg)).normalized()
		var thickness := 0.45 if obstacle_type == ScenarioConfig.TARGET_WALL else 0.42
		position = surface_position_m + forward * thickness * 0.5
	else:
		position = surface_position_m
