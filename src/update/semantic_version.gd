# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name SemanticVersion
extends RefCounted

var original: String = ""
var major: int = 0
var minor: int = 0
var patch: int = 0
var prerelease: String = ""
var prerelease_parts: Array[String] = []
var valid: bool = false

static func parse(version_text: String) -> SemanticVersion:
	var result := SemanticVersion.new()
	result.original = version_text.strip_edges()
	var text := result.original
	if text.begins_with("v"):
		text = text.substr(1)
	var build_index := text.find("+")
	if build_index >= 0:
		text = text.substr(0, build_index)
	var dash_index := text.find("-")
	var core := text
	if dash_index >= 0:
		core = text.substr(0, dash_index)
		result.prerelease = text.substr(dash_index + 1)
		if result.prerelease.is_empty():
			return result
		for part in result.prerelease.split(".", false):
			result.prerelease_parts.append(String(part))
	var core_parts := core.split(".", false)
	if core_parts.size() != 3:
		return result
	for part in core_parts:
		if not _is_digits(String(part)):
			return result
	result.major = int(core_parts[0])
	result.minor = int(core_parts[1])
	result.patch = int(core_parts[2])
	result.valid = true
	return result

static func compare_strings(left: String, right: String) -> int:
	var a := parse(left)
	var b := parse(right)
	if not a.valid or not b.valid:
		return 0
	return a.compare_to(b)

static func is_newer(candidate: String, installed: String) -> bool:
	return compare_strings(candidate, installed) > 0

static func should_offer(installed_text: String, candidate_text: String) -> bool:
	var installed := parse(installed_text)
	var candidate := parse(candidate_text)
	if not installed.valid or not candidate.valid:
		return false
	if candidate.compare_to(installed) <= 0:
		return false
	# Stable users stay on the stable channel. Prerelease users may move to a
	# later prerelease or to the eventual stable build.
	if installed.prerelease.is_empty() and not candidate.prerelease.is_empty():
		return false
	return true

func compare_to(other: SemanticVersion) -> int:
	if major != other.major:
		return 1 if major > other.major else -1
	if minor != other.minor:
		return 1 if minor > other.minor else -1
	if patch != other.patch:
		return 1 if patch > other.patch else -1
	if prerelease.is_empty() and other.prerelease.is_empty():
		return 0
	if prerelease.is_empty():
		return 1
	if other.prerelease.is_empty():
		return -1
	var count := maxi(prerelease_parts.size(), other.prerelease_parts.size())
	for i in range(count):
		if i >= prerelease_parts.size():
			return -1
		if i >= other.prerelease_parts.size():
			return 1
		var comparison := _compare_identifier(prerelease_parts[i], other.prerelease_parts[i])
		if comparison != 0:
			return comparison
	return 0

static func _compare_identifier(left: String, right: String) -> int:
	var left_numeric := _is_digits(left)
	var right_numeric := _is_digits(right)
	if left_numeric and right_numeric:
		var left_value := int(left)
		var right_value := int(right)
		if left_value == right_value:
			return 0
		return 1 if left_value > right_value else -1
	if left_numeric != right_numeric:
		return -1 if left_numeric else 1
	if left == right:
		return 0
	return 1 if left > right else -1

static func _is_digits(text: String) -> bool:
	if text.is_empty():
		return false
	for i in range(text.length()):
		var code := text.unicode_at(i)
		if code < 48 or code > 57:
			return false
	return true
