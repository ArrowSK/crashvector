class_name PhysicsMetrics
extends RefCounted

const KMH_TO_MS: float = 1.0 / 3.6
const MS_TO_KMH: float = 3.6

static func kmh_to_ms(speed_kmh: float) -> float:
	return speed_kmh * KMH_TO_MS

static func ms_to_kmh(speed_ms: float) -> float:
	return speed_ms * MS_TO_KMH

static func kinetic_energy_j(mass_kg: float, velocity_ms: Vector3) -> float:
	if mass_kg <= 0.0:
		return 0.0
	return 0.5 * mass_kg * velocity_ms.length_squared()

static func kinetic_energy_from_speed_kmh(mass_kg: float, speed_kmh: float) -> float:
	var speed_ms := kmh_to_ms(speed_kmh)
	return 0.5 * maxf(mass_kg, 0.0) * speed_ms * speed_ms

static func momentum_kg_ms(mass_kg: float, velocity_ms: Vector3) -> Vector3:
	return maxf(mass_kg, 0.0) * velocity_ms

static func momentum_magnitude_from_speed_kmh(mass_kg: float, speed_kmh: float) -> float:
	return maxf(mass_kg, 0.0) * absf(kmh_to_ms(speed_kmh))

static func relative_speed_kmh(velocity_a_ms: Vector3, velocity_b_ms: Vector3) -> float:
	return ms_to_kmh((velocity_a_ms - velocity_b_ms).length())

static func relative_error(reference: float, measured: float) -> float:
	if is_zero_approx(reference):
		return absf(measured)
	return absf((measured - reference) / reference)
