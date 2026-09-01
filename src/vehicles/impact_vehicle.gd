class_name ImpactVehicle
extends RigidBody3D

@export_range(1.0, 100000.0, 1.0, "or_greater") var configured_mass_kg: float = 1150.0
@export_range(0.0, 400.0, 0.5, "or_greater") var initial_speed_kmh: float = 50.0
@export var initial_direction: Vector3 = Vector3.RIGHT
@export var arm_on_ready: bool = true

var is_armed: bool = false

func _ready() -> void:
	mass = maxf(configured_mass_kg, 1.0)
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 16
	if arm_on_ready:
		arm()

func arm() -> void:
	var direction := initial_direction.normalized()
	if direction.is_zero_approx():
		direction = Vector3.RIGHT
	mass = maxf(configured_mass_kg, 1.0)
	linear_velocity = direction * PhysicsMetrics.kmh_to_ms(initial_speed_kmh)
	angular_velocity = Vector3.ZERO
	sleeping = false
	is_armed = true

func stop() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	is_armed = false

func current_kinetic_energy_j() -> float:
	return PhysicsMetrics.kinetic_energy_j(mass, linear_velocity)

func current_momentum_kg_ms() -> Vector3:
	return PhysicsMetrics.momentum_kg_ms(mass, linear_velocity)
