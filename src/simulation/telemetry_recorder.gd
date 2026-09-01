class_name TelemetryRecorder
extends Node

signal sample_recorded(sample: Dictionary)

@export_range(1, 240, 1) var sample_stride_physics_ticks: int = 1

var tracked_body: RigidBody3D
var samples: Array[Dictionary] = []
var elapsed_s: float = 0.0
var _physics_tick: int = 0
var _previous_velocity: Vector3 = Vector3.ZERO

func configure(body: RigidBody3D) -> void:
	tracked_body = body
	clear()
	if tracked_body != null:
		_previous_velocity = tracked_body.linear_velocity
		capture_sample(0.0)

func clear() -> void:
	samples.clear()
	elapsed_s = 0.0
	_physics_tick = 0
	_previous_velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if tracked_body == null or not is_instance_valid(tracked_body):
		return

	elapsed_s += delta
	_physics_tick += 1
	if _physics_tick % sample_stride_physics_ticks == 0:
		capture_sample(delta * float(sample_stride_physics_ticks))

func capture_sample(sample_delta_s: float) -> void:
	if tracked_body == null or not is_instance_valid(tracked_body):
		return

	var velocity := tracked_body.linear_velocity
	var acceleration := Vector3.ZERO
	if sample_delta_s > 0.0:
		acceleration = (velocity - _previous_velocity) / sample_delta_s

	var sample := {
		"time_s": elapsed_s,
		"position_m": tracked_body.global_position,
		"velocity_ms": velocity,
		"speed_kmh": PhysicsMetrics.ms_to_kmh(velocity.length()),
		"angular_velocity_rad_s": tracked_body.angular_velocity,
		"acceleration_ms2": acceleration,
		"acceleration_g": acceleration.length() / 9.80665,
		"kinetic_energy_j": PhysicsMetrics.kinetic_energy_j(tracked_body.mass, velocity),
		"momentum_kg_ms": PhysicsMetrics.momentum_kg_ms(tracked_body.mass, velocity),
	}
	samples.append(sample)
	_previous_velocity = velocity
	sample_recorded.emit(sample)

func latest_sample() -> Dictionary:
	if samples.is_empty():
		return {}
	return samples[-1]

func summary() -> Dictionary:
	if samples.is_empty():
		return {}

	var peak_acceleration_g := 0.0
	var max_speed_kmh := 0.0
	for sample in samples:
		peak_acceleration_g = maxf(peak_acceleration_g, float(sample["acceleration_g"]))
		max_speed_kmh = maxf(max_speed_kmh, float(sample["speed_kmh"]))

	var first := samples[0]
	var last := samples[-1]
	return {
		"sample_count": samples.size(),
		"duration_s": float(last["time_s"]),
		"initial_kinetic_energy_j": float(first["kinetic_energy_j"]),
		"final_kinetic_energy_j": float(last["kinetic_energy_j"]),
		"peak_acceleration_g": peak_acceleration_g,
		"max_speed_kmh": max_speed_kmh,
	}
