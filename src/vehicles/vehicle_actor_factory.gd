# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name VehicleActorFactory
extends RefCounted

# Central construction point for movable vehicle actors. It deliberately has no
# scene ownership: callers add the returned node where their lifecycle, replay,
# and camera code require it. Both primary and target roles use the same data
# contract, preventing a role-specific copy of vehicle dimensions or defaults.

static func create(
	actor_type: StringName,
	mass_kg: float,
	speed_kmh: float,
	position_m: Vector3,
	heading_deg: float,
	show_structure: bool,
	passenger_preset_id: StringName = PassengerCarCatalog.B_SEGMENT_HATCHBACK
) -> Node3D:
	match actor_type:
		ScenarioConfig.TARGET_PASSENGER_CAR:
			var passenger := M162CompactHatchback.new()
			passenger.vehicle_preset_id = passenger_preset_id
			passenger.total_mass_kg = mass_kg
			passenger.initial_speed_kmh = speed_kmh
			passenger.origin_offset_m = position_m
			passenger.heading_deg = heading_deg
			passenger.auto_step = false
			passenger.show_structure = show_structure
			return passenger
		ScenarioConfig.TARGET_TRUCK:
			var truck := M21HeavyTruck.new()
			truck.total_mass_kg = mass_kg
			truck.initial_speed_kmh = speed_kmh
			truck.origin_offset_m = position_m
			truck.heading_deg = heading_deg
			truck.auto_step = false
			truck.show_structure = show_structure
			return truck
		ScenarioConfig.TARGET_LORRY:
			var lorry := M20RigidLorry.new()
			lorry.total_mass_kg = mass_kg
			lorry.initial_speed_kmh = speed_kmh
			lorry.origin_offset_m = position_m
			lorry.heading_deg = heading_deg
			lorry.auto_step = false
			lorry.show_structure = show_structure
			return lorry
		ScenarioConfig.TARGET_MOTORCYCLE:
			var motorcycle := M20Motorcycle.new()
			motorcycle.total_mass_kg = mass_kg
			motorcycle.initial_speed_kmh = speed_kmh
			motorcycle.origin_offset_m = position_m
			motorcycle.heading_deg = heading_deg
			motorcycle.auto_step = false
			motorcycle.show_structure = show_structure
			return motorcycle
		ScenarioConfig.TARGET_TANK:
			var tank := DynamicTank3D.new()
			tank.total_mass_kg = mass_kg
			tank.initial_speed_kmh = speed_kmh
			tank.origin_offset_m = position_m
			tank.heading_deg = heading_deg
			return tank
	return null
