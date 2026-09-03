# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name VersionUtil
extends RefCounted

static func compare(left: String, right: String) -> int:
	var a := _parse(left)
	var b := _parse(right)
	if a.is_empty() or b.is_empty():
		return left.naturalnocasecmp_to(right)
	for key in ["major", "minor", "patch"]:
		var av := int(a[key])
		var bv := int(b[key])
		if av < bv:
			return -1
		if av > bv:
			return 1
	return _compare_prerelease(a["prerelease"], b["prerelease"])

static func is_newer(candidate: String, current: String) -> bool:
	return compare(candidate, current) > 0

static func has_prerelease(value: String) -> bool:
	var clean := value.strip_edges().trim_prefix("v")
	var plus_index := clean.find("+")
	if plus_index >= 0:
		clean = clean.substr(0, plus_index)
	return clean.contains("-")

static func _parse(value: String) -> Dictionary:
	var clean := value.strip_edges().trim_prefix("v")
	var plus_index := clean.find("+")
	if plus_index >= 0:
		clean = clean.substr(0, plus_index)
	var prerelease := ""
	var dash_index := clean.find("-")
	if dash_index >= 0:
		prerelease = clean.substr(dash_index + 1)
		clean = clean.substr(0, dash_index)
	var parts := clean.split(".")
	if parts.size() < 1 or parts.size() > 3:
		return {}
	var numbers: Array[int] = [0, 0, 0]
	for i in range(parts.size()):
		if not String(parts[i]).is_valid_int():
			return {}
		numbers[i] = int(parts[i])
	return {
		"major": numbers[0],
		"minor": numbers[1],
		"patch": numbers[2],
		"prerelease": prerelease,
	}

static func _compare_prerelease(left: Variant, right: Variant) -> int:
	var a := String(left)
	var b := String(right)
	if a.is_empty() and b.is_empty():
		return 0
	if a.is_empty():
		return 1
	if b.is_empty():
		return -1
	var ap := a.split(".")
	var bp := b.split(".")
	var count := maxi(ap.size(), bp.size())
	for i in range(count):
		if i >= ap.size():
			return -1
		if i >= bp.size():
			return 1
		var ai := String(ap[i])
		var bi := String(bp[i])
		var a_numeric := ai.is_valid_int()
		var b_numeric := bi.is_valid_int()
		if a_numeric and b_numeric:
			var an := int(ai)
			var bn := int(bi)
			if an < bn:
				return -1
			if an > bn:
				return 1
		elif a_numeric != b_numeric:
			return -1 if a_numeric else 1
		else:
			var text_cmp := ai.naturalnocasecmp_to(bi)
			if text_cmp < 0:
				return -1
			if text_cmp > 0:
				return 1
	return 0
