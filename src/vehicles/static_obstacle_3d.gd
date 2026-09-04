# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name StaticObstacle3D
extends Node3D

var obstacle_type: StringName = ScenarioConfig.TARGET_WALL
var surface_position_m := Vector3.ZERO
var heading_deg := 0.0
var physics_body: PhysicsBody3D
var yield_body: RigidBody3D

# M14 narrow-obstacle response. Wall/barrier stay fixed StaticBody3D targets.
# Pole/tree begin as frozen rigid fixtures (effectively anchored) and are
# released into normal Godot rigid-body motion once generic collision demand
# exceeds their yielding threshold. This prevents a moving/rotating StaticBody
# from numerically throwing the car upward while still allowing the target's
# collision geometry and visible geometry to fall together after failure.
var yield_peak_demand_j: float = 0.0
var yield_impact_direction_world := Vector3.RIGHT
var yield_failed: bool = false
var yield_started: bool = false
var yield_dynamic_mass_kg: float = 0.0

func configure(type_id: StringName, position_m: Vector3, yaw_deg: float) -> void:
	obstacle_type = type_id
	surface_position_m = position_m
	heading_deg = yaw_deg
	_build_visuals()
	reset_yield()
	_apply_visual_transform()

func set_editor_transform(position_m: Vector3, yaw_deg: float) -> void:
	surface_position_m = position_m
	heading_deg = yaw_deg
	_apply_visual_transform()

func reset_yield() -> void:
	yield_peak_demand_j = 0.0
	yield_impact_direction_world = Vector3.RIGHT
	yield_failed = false
	yield_started = false
	if yield_body != null:
		yield_body.freeze = true
		yield_body.mass = 1000000.0
		yield_body.position = Vector3.ZERO
		yield_body.rotation = Vector3.ZERO
		yield_body.linear_velocity = Vector3.ZERO
		yield_body.angular_velocity = Vector3.ZERO

func apply_collision_demand(energy_j: float, impact_direction_world: Vector3) -> void:
	if obstacle_type != ScenarioConfig.TARGET_POLE and obstacle_type != ScenarioConfig.TARGET_TREE:
		return
	if yield_body == null or not is_finite(energy_j) or energy_j <= 0.0:
		return
	if energy_j > yield_peak_demand_j:
		yield_peak_demand_j = energy_j
	var horizontal := Vector3(impact_direction_world.x, 0.0, impact_direction_world.z)
	if horizontal.length_squared() > 0.0001:
		yield_impact_direction_world = horizontal.normalized()
	var yield_start_j := 70000.0
	var failure_j := 480000.0
	if obstacle_type == ScenarioConfig.TARGET_TREE:
		yield_start_j = 240000.0
		failure_j = 1650000.0
	if yield_peak_demand_j >= failure_j:
		yield_failed = true
	if yield_started or yield_peak_demand_j < yield_start_j:
		return
	yield_started = true
	# The fixture behaves as effectively infinite mass before yielding. Once its
	# base/foundation gives way, switch to the generic moving mass and seed the
	# target with only a fraction of the residual collision energy. The car's
	# existing front-crush resistance provides the opposing nose load.
	yield_body.mass = maxf(yield_dynamic_mass_kg, 1.0)
	yield_body.freeze = false
	yield_body.sleeping = false
	var residual_energy := maxf(yield_peak_demand_j - yield_start_j, 0.0)
	var transfer_fraction := 0.05
	var impulse_ns := sqrt(2.0 * yield_body.mass * residual_energy) * transfer_fraction
	yield_body.apply_central_impulse(yield_impact_direction_world * impulse_ns)
	var bend_axis := Vector3.UP.cross(yield_impact_direction_world).normalized()
	if not bend_axis.is_zero_approx():
		var torque_cap := 250.0
		var torque_fraction := 0.10
		if obstacle_type == ScenarioConfig.TARGET_TREE:
			# The tree has a much larger transverse inertia than the generic pole.
			# Give a failed root/base enough rotational impulse to produce visible
			# toppling, while keeping the translational impulse deliberately small
			# so target failure cannot become an artificial car launch mechanism.
			torque_cap = 4000.0
			torque_fraction = 1.50
		var torque_impulse := minf(impulse_ns * torque_fraction, torque_cap)
		yield_body.apply_torque_impulse(bend_axis * torque_impulse)

func bend_angle_deg() -> float:
	if yield_body == null:
		return 0.0
	var local_up := yield_body.global_transform.basis.y.normalized()
	if local_up.is_zero_approx():
		return 0.0
	return rad_to_deg(Vector3.UP.angle_to(local_up))

func has_yielded() -> bool:
	return yield_started or bend_angle_deg() > 0.25

func has_failed() -> bool:
	return yield_failed

func _build_visuals() -> void:
	for child in get_children():
		child.queue_free()
	physics_body = null
	yield_body = null
	yield_dynamic_mass_kg = 0.0
	if obstacle_type == ScenarioConfig.TARGET_POLE or obstacle_type == ScenarioConfig.TARGET_TREE:
		_build_yielding_body()
		if obstacle_type == ScenarioConfig.TARGET_POLE:
			_build_pole(yield_body)
		else:
			_build_tree(yield_body)
		return
	match obstacle_type:
		ScenarioConfig.TARGET_BARRIER:
			_build_concrete_barrier(self)
		_:
			_build_rigid_wall(self)
	_build_static_physics_body()

func _build_yielding_body() -> void:
	yield_body = RigidBody3D.new()
	yield_body.name = "YieldingTargetPhysics"
	yield_dynamic_mass_kg = 180.0 if obstacle_type == ScenarioConfig.TARGET_POLE else 650.0
	# While frozen, an intentionally very large mass makes the passenger-car
	# collision-demand probe treat the fixture like an anchored/static target.
	# apply_collision_demand switches to the moving mass before release.
	yield_body.mass = 1000000.0
	yield_body.freeze = true
	yield_body.can_sleep = false
	yield_body.continuous_cd = true
	yield_body.linear_damp = 0.04
	yield_body.angular_damp = 0.08 if obstacle_type == ScenarioConfig.TARGET_TREE else 0.18
	yield_body.contact_monitor = true
	yield_body.max_contacts_reported = 16
	var material := PhysicsMaterial.new()
	material.friction = 0.92
	material.bounce = 0.0
	yield_body.physics_material_override = material
	add_child(yield_body)
	physics_body = yield_body
	if obstacle_type == ScenarioConfig.TARGET_POLE:
		_add_cylinder_collision(yield_body, 0.18, 2.90, Vector3(0.0, 1.45, 0.0))
	else:
		_add_cylinder_collision(yield_body, 0.32, 3.50, Vector3(0.0, 1.75, 0.0))

func _build_static_physics_body() -> void:
	var static_body := StaticBody3D.new()
	static_body.name = "StaticTargetPhysics"
	var material := PhysicsMaterial.new()
	material.friction = 0.85
	material.bounce = 0.0
	static_body.physics_material_override = material
	add_child(static_body)
	physics_body = static_body
	if obstacle_type == ScenarioConfig.TARGET_BARRIER:
		_add_box_collision(static_body, Vector3(0.42, 0.96, 4.10), Vector3(0.0, 0.48, 0.0))
	else:
		_add_box_collision(static_body, Vector3(0.45, 3.25, 9.0), Vector3(0.0, 1.625, 0.0))

func _build_rigid_wall(parent: Node3D) -> void:
	var concrete := _material(Color(0.58, 0.60, 0.61), 0.0, 0.92)
	var dark := _material(Color(0.25, 0.27, 0.28), 0.0, 0.96)
	_add_box(parent, "RigidWall", Vector3(0.45, 3.25, 9.0), concrete, Vector3(0.0, 1.625, 0.0))
	_add_box(parent, "WallFoot", Vector3(0.72, 0.20, 9.35), dark, Vector3(0.13, 0.10, 0.0))
	for z in [-3.0, 0.0, 3.0]:
		_add_box(parent, "WallJoint", Vector3(0.012, 3.08, 0.026), dark, Vector3(-0.231, 1.62, z))
	var stripe := _material(Color(0.86, 0.16, 0.08), 0.05, 0.55)
	_add_box(parent, "ImpactReferenceStripe", Vector3(0.014, 0.075, 8.45), stripe, Vector3(-0.235, 0.73, 0.0))

func _build_concrete_barrier(parent: Node3D) -> void:
	var concrete := _material(Color(0.58, 0.59, 0.58), 0.0, 0.94)
	var seam := _material(Color(0.33, 0.34, 0.34), 0.0, 0.96)
	_add_box(parent, "BarrierBase", Vector3(0.58, 0.24, 4.1), concrete, Vector3(0.08, 0.12, 0.0))
	_add_box(parent, "BarrierLower", Vector3(0.48, 0.34, 4.05), concrete, Vector3(0.03, 0.39, 0.0))
	_add_box(parent, "BarrierUpper", Vector3(0.32, 0.43, 4.0), concrete, Vector3(-0.04, 0.775, 0.0))
	for z in [-1.35, 0.0, 1.35]:
		_add_box(parent, "BarrierJoint", Vector3(0.014, 0.88, 0.022), seam, Vector3(-0.205, 0.52, z))

func _build_pole(parent: Node3D) -> void:
	var pole_material := _material(Color(0.38, 0.41, 0.44), 0.72, 0.34)
	var base_material := _material(Color(0.22, 0.24, 0.26), 0.62, 0.38)
	_add_cylinder(parent, "Pole", 0.17, 0.16, 2.9, pole_material, Vector3(0.0, 1.45, 0.0))
	_add_cylinder(parent, "PoleBase", 0.31, 0.28, 0.16, base_material, Vector3(0.0, 0.08, 0.0))
	_add_cylinder(parent, "PoleCollar", 0.23, 0.20, 0.11, base_material, Vector3(0.0, 0.22, 0.0))

func _build_tree(parent: Node3D) -> void:
	var bark := _material(Color(0.28, 0.15, 0.075), 0.0, 0.98)
	var bark_light := _material(Color(0.39, 0.22, 0.10), 0.0, 0.97)
	var leaves_a := _material(Color(0.15, 0.36, 0.15), 0.0, 0.98)
	var leaves_b := _material(Color(0.21, 0.45, 0.18), 0.0, 0.97)
	_add_cylinder(parent, "TreeTrunk", 0.25, 0.36, 3.5, bark, Vector3(0.0, 1.75, 0.0))
	_add_cylinder(parent, "TreeBase", 0.38, 0.30, 0.28, bark_light, Vector3(0.0, 0.14, 0.0))
	_add_sphere(parent, "TreeCrownA", 1.18, leaves_a, Vector3(0.0, 3.95, 0.0))
	_add_sphere(parent, "TreeCrownB", 0.88, leaves_b, Vector3(0.42, 4.42, 0.36))
	_add_sphere(parent, "TreeCrownC", 0.84, leaves_a, Vector3(-0.38, 4.35, -0.32))

func _add_box_collision(parent: CollisionObject3D, size_m: Vector3, local_position_m: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size_m
	var collision := CollisionShape3D.new()
	collision.name = "ObstacleCollision"
	collision.shape = shape
	collision.position = local_position_m
	parent.add_child(collision)

func _add_cylinder_collision(parent: CollisionObject3D, radius_m: float, height_m: float, local_position_m: Vector3) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius_m
	shape.height = height_m
	var collision := CollisionShape3D.new()
	collision.name = "ObstacleCollision"
	collision.shape = shape
	collision.position = local_position_m
	parent.add_child(collision)

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _add_box(parent: Node3D, node_name: String, size: Vector3, material: Material, local_position: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = local_position
	parent.add_child(instance)
	return instance

func _add_cylinder(parent: Node3D, node_name: String, top_radius: float, bottom_radius: float, height: float, material: Material, local_position: Vector3) -> MeshInstance3D:
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
	parent.add_child(instance)
	return instance

func _add_sphere(parent: Node3D, node_name: String, radius: float, material: Material, local_position: Vector3) -> MeshInstance3D:
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
	parent.add_child(instance)
	return instance

func _apply_visual_transform() -> void:
	basis = Basis(Vector3.UP, deg_to_rad(heading_deg))
	if obstacle_type == ScenarioConfig.TARGET_WALL or obstacle_type == ScenarioConfig.TARGET_BARRIER:
		var forward := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(heading_deg)).normalized()
		var thickness := 0.45 if obstacle_type == ScenarioConfig.TARGET_WALL else 0.42
		position = surface_position_m + forward * thickness * 0.5
	else:
		position = surface_position_m
