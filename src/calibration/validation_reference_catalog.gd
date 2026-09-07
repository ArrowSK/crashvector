# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name ValidationReferenceCatalog
extends RefCounted

# M19 keeps evidence references separate from simulation capability. A protocol
# can describe a useful real-world load case without implying that CrashVector
# currently implements the corresponding barrier geometry or has correlated its
# outcome metrics to that source.

const REFERENCE_PATHS := [
	"res://calibration/references/nhtsa_ncap_full_frontal_midsize_56kph.json",
	"res://calibration/references/nhtsa_oblique_yaris_7441_90kph.json",
	"res://calibration/references/iihs_small_overlap_64kph_25pct.json",
	"res://calibration/references/iihs_moderate_overlap_64kph_40pct.json",
]

static func load_all() -> Array[CalibrationReference]:
	var result: Array[CalibrationReference] = []
	for path in REFERENCE_PATHS:
		var reference := CalibrationReference.load_from_path(path)
		if reference != null:
			result.append(reference)
	return result

static func source_correlation_references() -> Array[CalibrationReference]:
	return _with_role(&"source_correlation")

static func protocol_geometry_references() -> Array[CalibrationReference]:
	return _with_role(&"protocol_geometry_only")

static func evidence_role(reference: CalibrationReference) -> StringName:
	if reference == null:
		return &"unknown"
	return StringName(String(reference.scope().get("evidence_role", "unknown")))

static func production_runnable(reference: CalibrationReference) -> bool:
	if reference == null:
		return false
	return bool(reference.scope().get("production_runnable", false))

static func _with_role(role: StringName) -> Array[CalibrationReference]:
	var result: Array[CalibrationReference] = []
	for reference in load_all():
		if evidence_role(reference) == role:
			result.append(reference)
	return result
