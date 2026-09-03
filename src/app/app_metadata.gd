# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name AppMetadata
extends RefCounted

const APP_NAME: String = "CrashVector"
const VERSION: String = "0.1.0-beta.1"
const REPOSITORY_URL: String = "https://github.com/ArrowSK/crashvector"
const RELEASES_API_URL: String = "https://api.github.com/repos/ArrowSK/crashvector/releases?per_page=20"
const UPDATE_CHECK_INTERVAL_S: int = 86400

static func version_tag() -> String:
	return "v%s" % VERSION

static func platform_package_suffix(platform_name: String = OS.get_name()) -> String:
	match platform_name:
		"macOS":
			return "-macOS-universal.dmg"
		"Windows":
			return "-Windows-x64-Setup.exe"
		_:
			return ""

static func platform_display_name(platform_name: String = OS.get_name()) -> String:
	match platform_name:
		"macOS":
			return "macOS Universal"
		"Windows":
			return "Windows x64"
		_:
			return platform_name

static func supports_installer_updates(platform_name: String = OS.get_name()) -> bool:
	return not platform_package_suffix(platform_name).is_empty()
