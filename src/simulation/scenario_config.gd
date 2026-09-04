# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name ScenarioConfig
extends RefCounted

const FORMAT_VERSION: int = 1
const MAX_SOLVER_SUBSTEPS: int = 64
const TARGET_PASSENGER_CAR: StringName = &"passenger_car"
const TARGET_TRUCK: StringName = &"heavy_truck"
const TARGET_LORRY: StringName = &"rigid_lorry"
const TARGET_MOTORCYCLE: StringName = &"motorcycle"
const TARGET_BICYCLE: StringName = &"bicycle"
const TARGET_PEDESTRIAN: StringName = &"pedestrian"
const TARGET_WALL: StringName = &"rigid_wall"
const TARGET_BARRIER: StringName = &"concrete_barrier"
const TARGET_POLE: StringName = &"pole"
const TARGET_TREE: StringName = &"tree"

var title: String = "Car vs Truck"
var target_type: StringName = TARGET_TRUCK
var car_preset_id: StringName = PassengerCarCatalog.B_SEGMENT_HATCHBACK
var car_mass_kg: float = 1150.0
var car_speed_kmh: float = 50.0
var car_position_m: Vector3 = Vector3(-6.0, 0.0, 0.0)
var car_heading_deg: float = 0.0
var target_car_preset_id: StringName = PassengerCarCatalog.C_SEGMENT_COMPACT
var target_preset_id: StringName = &""
var target_mass_kg: float = 18000.0
var target_speed_kmh: float = 0.0
var target_position_m: Vector3 = Vector3(2.5, 0.0, 0.0)
var target_heading_deg: float = 0.0
var contact_friction: float = 0.55
var restitution: float = 0.03
var duration_s: float = 4.0
var solver_substeps: int = 8
var show_structure: bool = false

static func target_ids() -> Array[StringName]:
	return [
		TARGET_PASSENGER_CAR,
		TARGET_TRUCK,
		TARGET_LORRY,
		TARGET_MOTORCYCLE,
		TARGET_BICYCLE,
		TARGET_PEDESTRIAN,
		TARGET_WALL,
		TARGET_BARRIER,
		TARGET_POLE,
		TARGET_TREE,
	]

static func target_display_name(id: StringName) -> String:
	match id:
		TARGET_PASSENGER_CAR:
			return "Passenger Car"
		TARGET_TRUCK:
			return "Heavy Articulated Truck"
		TARGET_LORRY:
			return "Rigid Lorry / Box Truck"
		TARGET_MOTORCYCLE:
			return "Motorcycle (riderless)"
		TARGET_BICYCLE:
			return "Bicycle (riderless)"
		TARGET_PEDESTRIAN:
			return "Pedestrian"
		TARGET_WALL:
			return "Rigid Wall (full-frontal)"
		TARGET_BARRIER:
			return "Concrete Barrier"
		TARGET_POLE:
			return "Pole"
		TARGET_TREE:
			return "Tree"
		_:
			return "Unknown target"

func reset_defaults() -> void:
	title = "Car vs Truck"
	car_preset_id = PassengerCarCatalog.B_SEGMENT_HATCHBACK
	car_mass_kg = PassengerCarCatalog.default_mass_kg(car_preset_id)
	car_speed_kmh = 50.0
	car_position_m = Vector3(-6.0, 0.0, 0.0)
	car_heading_deg = 0.0
	target_car_preset_id = PassengerCarCatalog.C_SEGMENT_COMPACT
	target_preset_id = &""
	target_position_m = Vector3(2.5, 0.0, 0.0)
	target_heading_deg = 0.0
	contact_friction = 0.55
	restitution = 0.03
	duration_s = 4.0
	solver_substeps = 8
	show_structure = false
	apply_target_defaults(TARGET_TRUCK)

func apply_target_defaults(id: StringName) -> void:
	target_type = id
	target_speed_kmh = 0.0
	match id:
		TARGET_PASSENGER_CAR:
			target_car_preset_id = PassengerCarCatalog.C_SEGMENT_COMPACT
			target_preset_id = &""
			target_mass_kg = PassengerCarCatalog.default_mass_kg(target_car_preset_id)
		TARGET_TRUCK:
			target_preset_id = &""
			target_mass_kg = 18000.0
		TARGET_LORRY:
			target_preset_id = &""
			target_mass_kg = 12000.0
		TARGET_MOTORCYCLE:
			target_preset_id = &""
			target_mass_kg = 220.0
		TARGET_BICYCLE:
			target_preset_id = RoadUserCatalog.BICYCLE_CITY
			target_mass_kg = RoadUserCatalog.default_mass_kg(target_preset_id)
		TARGET_PEDESTRIAN:
			target_preset_id = RoadUserCatalog.PEDESTRIAN_ADULT
			target_mass_kg = RoadUserCatalog.default_mass_kg(target_preset_id)
		_:
			target_preset_id = &""
			target_mass_kg = 0.0

func car_forward() -> Vector3:
	return Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(car_heading_deg)).normalized()

func heading_delta_deg() -> float:
	return absf(wrapf(car_heading_deg - target_heading_deg, -180.0, 180.0))

func target_vehicle_uses_front_contact() -> bool:
	return heading_delta_deg() > 90.0

func target_car_uses_front_contact() -> bool:
	return target_vehicle_uses_front_contact()

func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if not PassengerCarCatalog.preset_ids().has(car_preset_id):
		errors.append("Unknown primary passenger-car class")
	if not target_ids().has(target_type):
		errors.append("Unknown target type")
	if car_mass_kg < 500.0 or car_mass_kg > 5000.0:
		errors.append("Primary passenger-car mass must be between 500 and 5,000 kg")
	if car_speed_kmh < 0.0 or car_speed_kmh > 300.0:
		errors.append("Primary passenger-car speed must be between 0 and 300 km/h")
	if target_type == TARGET_PASSENGER_CAR:
		if not PassengerCarCatalog.preset_ids().has(target_car_preset_id):
			errors.append("Unknown target passenger-car class")
		if target_mass_kg < 500.0 or target_mass_kg > 5000.0:
			errors.append("Target passenger-car mass must be between 500 and 5,000 kg")
		if target_speed_kmh < 0.0 or target_speed_kmh > 300.0:
			errors.append("Target passenger-car speed must be between 0 and 300 km/h")
		var car_delta := heading_delta_deg()
		if car_delta > 25.0 and car_delta < 155.0:
			errors.append("Passenger-car pair contact supports rear-end or near head-on layouts, not broadside impacts yet")
	elif target_type == TARGET_TRUCK:
		if target_mass_kg < 3500.0 or target_mass_kg > 60000.0:
			errors.append("Heavy-truck mass must be between 3,500 and 60,000 kg")
		if target_speed_kmh < 0.0 or target_speed_kmh > 140.0:
			errors.append("Heavy-truck speed must be between 0 and 140 km/h")
		if heading_delta_deg() > 25.0:
			errors.append("Car/truck rear-contact model supports heading differences up to 25 degrees")
	elif target_type == TARGET_LORRY:
		if target_mass_kg < 3500.0 or target_mass_kg > 26000.0:
			errors.append("Rigid-lorry mass must be between 3,500 and 26,000 kg")
		if target_speed_kmh < 0.0 or target_speed_kmh > 140.0:
			errors.append("Rigid-lorry speed must be between 0 and 140 km/h")
		if heading_delta_deg() > 25.0:
			errors.append("Car/lorry rear-contact model supports heading differences up to 25 degrees")
	elif target_type == TARGET_MOTORCYCLE:
		if target_mass_kg < 80.0 or target_mass_kg > 600.0:
			errors.append("Motorcycle mass must be between 80 and 600 kg")
		if target_speed_kmh < 0.0 or target_speed_kmh > 250.0:
			errors.append("Motorcycle speed must be between 0 and 250 km/h")
		var motorcycle_delta := heading_delta_deg()
		if motorcycle_delta > 25.0 and motorcycle_delta < 155.0:
			errors.append("Motorcycle contact supports rear-end or near head-on layouts, not broadside impacts yet")
	elif target_type == TARGET_BICYCLE:
		if not RoadUserCatalog.bicycle_ids().has(target_preset_id):
			errors.append("Unknown bicycle preset")
		if target_mass_kg < 5.0 or target_mass_kg > 60.0:
			errors.append("Bicycle mass must be between 5 and 60 kg")
		if target_speed_kmh < 0.0 or target_speed_kmh > 80.0:
			errors.append("Bicycle speed must be between 0 and 80 km/h")
		var bicycle_delta := heading_delta_deg()
		if bicycle_delta > 25.0 and bicycle_delta < 155.0:
			errors.append("Bicycle contact supports rear-end or near head-on layouts, not broadside impacts yet")
	elif target_type == TARGET_PEDESTRIAN:
		if not RoadUserCatalog.pedestrian_ids().has(target_preset_id):
			errors.append("Unknown pedestrian body preset")
		if target_mass_kg < 15.0 or target_mass_kg > 200.0:
			errors.append("Pedestrian mass must be between 15 and 200 kg")
		if absf(target_speed_kmh) > 0.001:
			errors.append("The current pedestrian proxy starts stationary; pedestrian walking/running motion is not modelled yet")
	if contact_friction < 0.0 or contact_friction > 1.5:
		errors.append("Contact friction must be between 0 and 1.5")
	if restitution < 0.0 or restitution > 0.5:
		errors.append("Restitution must be between 0 and 0.5")
	if duration_s < 0.5 or duration_s > 20.0:
		errors.append("Simulation duration must be between 0.5 and 20 seconds")
	if solver_substeps < 1 or solver_substeps > MAX_SOLVER_SUBSTEPS:
		errors.append("Solver substeps must be between 1 and %d" % MAX_SOLVER_SUBSTEPS)
	if not _finite_vector(car_position_m) or not _finite_vector(target_position_m):
		errors.append("Object positions must contain finite numbers")
	var forward_separation := (target_position_m - car_position_m).dot(car_forward())
	if forward_separation < 2.0:
		errors.append("Target must begin at least 2 m ahead of the primary passenger car")
	return errors

func to_dictionary() -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"title": title,
		"scenario_type": "single_car_impact",
		"target_type": String(target_type),
		"car": {
			"class_id": String(car_preset_id),
			"mass_kg": car_mass_kg,
			"speed_kmh": car_speed_kmh,
			"position_m": _vector_to_array(car_position_m),
			"heading_deg": car_heading_deg,
		},
		"target": {
			"car_class_id": String(target_car_preset_id),
			"preset_id": String(target_preset_id),
			"mass_kg": target_mass_kg,
			"speed_kmh": target_speed_kmh,
			"position_m": _vector_to_array(target_position_m),
			"heading_deg": target_heading_deg,
		},
		"contact": {
			"friction": contact_friction,
			"restitution": restitution,
		},
		"simulation": {
			"duration_s": duration_s,
			"solver_substeps": solver_substeps,
			"show_structure": show_structure,
		},
	}

func to_json(pretty: bool = true) -> String:
	return JSON.stringify(to_dictionary(), "\t" if pretty else "")

static func from_dictionary(data: Dictionary) -> ScenarioConfig:
	var config := ScenarioConfig.new()
	config.title = String(data.get("title", config.title))
	config.target_type = StringName(String(data.get("target_type", String(config.target_type))))
	var car_data: Dictionary = data.get("car", {})
	config.car_preset_id = StringName(String(car_data.get("class_id", String(config.car_preset_id))))
	config.car_mass_kg = float(car_data.get("mass_kg", config.car_mass_kg))
	config.car_speed_kmh = float(car_data.get("speed_kmh", config.car_speed_kmh))
	config.car_position_m = _array_to_vector(car_data.get("position_m", []), config.car_position_m)
	config.car_heading_deg = float(car_data.get("heading_deg", config.car_heading_deg))
	var target_data: Dictionary = data.get("target", {})
	config.target_car_preset_id = StringName(String(target_data.get("car_class_id", String(config.target_car_preset_id))))
	config.target_preset_id = StringName(String(target_data.get("preset_id", String(config.target_preset_id))))
	config.target_mass_kg = float(target_data.get("mass_kg", config.target_mass_kg))
	config.target_speed_kmh = float(target_data.get("speed_kmh", config.target_speed_kmh))
	config.target_position_m = _array_to_vector(target_data.get("position_m", []), config.target_position_m)
	config.target_heading_deg = float(target_data.get("heading_deg", config.target_heading_deg))
	var contact_data: Dictionary = data.get("contact", {})
	config.contact_friction = float(contact_data.get("friction", config.contact_friction))
	config.restitution = float(contact_data.get("restitution", config.restitution))
	var simulation_data: Dictionary = data.get("simulation", {})
	config.duration_s = float(simulation_data.get("duration_s", config.duration_s))
	config.solver_substeps = int(simulation_data.get("solver_substeps", config.solver_substeps))
	config.show_structure = bool(simulation_data.get("show_structure", config.show_structure))
	return config

static func from_json(text: String) -> ScenarioConfig:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return null
	return from_dictionary(parsed)

static func _vector_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

static func _array_to_vector(value: Variant, fallback: Vector3) -> Vector3:
	if not (value is Array) or value.size() < 3:
		return fallback
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

static func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
