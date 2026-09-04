# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name CrashVectorM10Theme
extends RefCounted

const BG := Color("0b1017")
const PANEL := Color("121923")
const PANEL_ALT := Color("171f2b")
const PANEL_HOVER := Color("202b39")
const BORDER := Color("2b3747")
const TEXT := Color("e8edf4")
const MUTED := Color("96a4b6")
const ACCENT := Color("ff5a36")
const ACCENT_SOFT := Color("703225")
const SUCCESS := Color("42c58a")

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 14

	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_shadow_color", "Label", Color(0.0, 0.0, 0.0, 0.35))
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", MUTED.darkened(0.25))
	theme.set_color("font_color", "CheckButton", TEXT)
	theme.set_color("font_color", "OptionButton", TEXT)
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("font_color", "SpinBox", TEXT)
	theme.set_color("font_color", "TabBar", TEXT)
	theme.set_color("font_unselected_color", "TabBar", MUTED)
	theme.set_color("font_selected_color", "TabBar", Color.WHITE)

	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, 10, BORDER, 1))
	theme.set_stylebox("normal", "Button", _box(PANEL_ALT, 8, BORDER, 1))
	theme.set_stylebox("hover", "Button", _box(PANEL_HOVER, 8, BORDER.lightened(0.12), 1))
	theme.set_stylebox("pressed", "Button", _box(ACCENT_SOFT, 8, ACCENT.darkened(0.05), 1))
	theme.set_stylebox("disabled", "Button", _box(PANEL.darkened(0.10), 8, BORDER.darkened(0.15), 1))
	theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), 8, ACCENT, 2))

	theme.set_stylebox("normal", "LineEdit", _box(Color("0d141e"), 7, BORDER, 1))
	theme.set_stylebox("focus", "LineEdit", _box(Color("0d141e"), 7, ACCENT, 2))
	theme.set_stylebox("read_only", "LineEdit", _box(PANEL, 7, BORDER, 1))
	theme.set_stylebox("normal", "OptionButton", _box(Color("0d141e"), 7, BORDER, 1))
	theme.set_stylebox("hover", "OptionButton", _box(PANEL_HOVER, 7, BORDER.lightened(0.10), 1))
	theme.set_stylebox("pressed", "OptionButton", _box(ACCENT_SOFT, 7, ACCENT.darkened(0.05), 1))
	theme.set_stylebox("focus", "OptionButton", _box(Color(0, 0, 0, 0), 7, ACCENT, 2))

	theme.set_stylebox("normal", "SpinBox", _box(Color("0d141e"), 7, BORDER, 1))
	theme.set_stylebox("normal", "ProgressBar", _box(Color("0d141e"), 6, BORDER, 1))
	theme.set_stylebox("fill", "ProgressBar", _box(ACCENT, 6, ACCENT, 0))

	theme.set_stylebox("tab_selected", "TabBar", _box(PANEL_ALT, 7, ACCENT, 1))
	theme.set_stylebox("tab_unselected", "TabBar", _box(PANEL, 7, BORDER, 1))
	theme.set_stylebox("tab_hovered", "TabBar", _box(PANEL_HOVER, 7, BORDER.lightened(0.10), 1))
	theme.set_stylebox("panel", "TabContainer", _box(PANEL, 8, BORDER, 1))

	theme.set_constant("separation", "HBoxContainer", 8)
	theme.set_constant("separation", "VBoxContainer", 8)
	theme.set_constant("h_separation", "GridContainer", 8)
	theme.set_constant("v_separation", "GridContainer", 8)
	return theme

static func accent_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _box(ACCENT, 8, ACCENT, 1))
	button.add_theme_stylebox_override("hover", _box(ACCENT.lightened(0.08), 8, ACCENT.lightened(0.12), 1))
	button.add_theme_stylebox_override("pressed", _box(ACCENT.darkened(0.12), 8, ACCENT.darkened(0.10), 1))
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)

static func chip(control: Control, color: Color = ACCENT) -> StyleBoxFlat:
	return _box(color.darkened(0.62), 999, color.darkened(0.10), 1)

static func _box(color: Color, radius: int, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style
