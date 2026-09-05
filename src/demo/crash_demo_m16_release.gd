# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends "res://src/demo/crash_demo_m16.gd"

# The M10 responsive-layout regression and downstream extensions use these
# region names as stable shell contracts. M16 changes the content and hierarchy,
# not those compatibility identifiers.
func _ready() -> void:
	super._ready()
	if m10_top_bar != null:
		m10_top_bar.name = "M10TopBar"
	if m10_left_panel != null:
		m10_left_panel.name = "M10ScenarioPanel"
	if m10_right_panel != null:
		m10_right_panel.name = "M10Inspector"
	if m10_replay_drawer != null:
		m10_replay_drawer.name = "M10ReplayDrawer"
