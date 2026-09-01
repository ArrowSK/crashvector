extends SceneTree

const EPSILON: float = 0.001

func _initialize() -> void:
	var failures: Array[String] = []

	_check_close(
		PhysicsMetrics.kmh_to_ms(140.0),
		38.8888888889,
		EPSILON,
		"140 km/h conversion",
		failures
	)
	_check_close(
		PhysicsMetrics.kinetic_energy_from_speed_kmh(1150.0, 140.0),
		869598.765432,
		0.01,
		"1150 kg at 140 km/h kinetic energy",
		failures
	)
	_check_close(
		PhysicsMetrics.momentum_magnitude_from_speed_kmh(1150.0, 140.0),
		44722.222222,
		0.01,
		"1150 kg at 140 km/h momentum",
		failures
	)

	var packed_scene := load("res://app/main.tscn") as PackedScene
	if packed_scene == null:
		failures.append("M0 demo scene failed to load")
	else:
		var demo := packed_scene.instantiate()
		if demo == null:
			failures.append("M0 demo scene failed to instantiate")
		else:
			root.add_child(demo)
			demo.queue_free()

	if failures.is_empty():
		print("CrashVector M0 smoke test passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _check_close(actual: float, expected: float, tolerance: float, label: String, failures: Array[String]) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s: expected %.9f, got %.9f" % [label, expected, actual])
