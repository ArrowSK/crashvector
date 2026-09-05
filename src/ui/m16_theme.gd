# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name CrashVectorM16Theme
extends RefCounted

const BG := Color("0a0f15")
const PANEL := Color("111820")
const PANEL_ALT := Color("161f29")
const FIELD := Color("0d141c")
const HOVER := Color("1c2733")
const BORDER := Color("263342")
const TEXT := Color("edf2f7")
const MUTED := Color("8e9bab")
const ACCENT := Color("ff633f")
const ACCENT_DARK := Color("7c3426")
const SUCCESS := Color("46c892")
const WARNING := Color("e6b85c")

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 14
	for control_name in ["Label", "Button", "CheckButton", "OptionButton", "LineEdit", "SpinBox", "MenuButton"]:
		theme.set_color("font_color", control_name, TEXT)
		theme.set_color("font_hover_color", control_name, Color.WHITE)
		theme.set_color("font_pressed_color", control_name, Color.WHITE)
		theme.set_color("font_disabled_color", control_name, MUTED.darkened(0.25))
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("font_color", "TabBar", TEXT)
	theme.set_color("font_unselected_color", "TabBar", MUTED)
	theme.set_color("font_selected_color", "TabBar", Color.WHITE)

	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, 12, BORDER, 1, 12.0, 10.0))
	theme.set_stylebox("normal", "Button", _box(Color(0.0, 0.0, 0.0, 0.0), 8, Color(0.0, 0.0, 0.0, 0.0), 0, 10.0, 7.0))
	theme.set_stylebox("hover", "Button", _box(HOVER, 8, BORDER, 1, 10.0, 7.0))
	theme.set_stylebox("pressed", "Button", _box(PANEL_ALT, 8, ACCENT_DARK, 1, 10.0, 7.0))
	theme.set_stylebox("disabled", "Button", _box(Color(0.0, 0.0, 0.0, 0.0), 8, Color(0.0, 0.0, 0.0, 0.0), 0, 10.0, 7.0))
	theme.set_stylebox("focus", "Button", _box(Color(0.0, 0.0, 0.0, 0.0), 8, ACCENT, 2, 10.0, 7.0))

	for field_name in ["LineEdit", "OptionButton", "SpinBox"]:
		theme.set_stylebox("normal", field_name, _box(FIELD, 8, BORDER, 1, 10.0, 7.0))
		theme.set_stylebox("focus", field_name, _box(FIELD, 8, ACCENT, 2, 10.0, 7.0))
	if true:
		theme.set_stylebox("hover", "OptionButton", _box(HOVER, 8, BORDER.lightened(0.08), 1, 10.0, 7.0))
		theme.set_stylebox("pressed", "OptionButton", _box(PANEL_ALT, 8, ACCENT_DARK, 1, 10.0, 7.0))

	theme.set_stylebox("normal", "ProgressBar", _box(FIELD, 7, BORDER, 1, 0.0, 0.0))
	theme.set_stylebox("fill", "ProgressBar", _box(ACCENT, 7, ACCENT, 0, 0.0, 0.0))
	theme.set_stylebox("tab_selected", "TabBar", _box(PANEL_ALT, 7, ACCENT, 1, 10.0, 7.0))
	theme.set_stylebox("tab_unselected", "TabBar", _box(Color(0.0, 0.0, 0.0, 0.0), 7, Color(0.0, 0.0, 0.0, 0.0), 0, 10.0, 7.0))
	theme.set_stylebox("tab_hovered", "TabBar", _box(HOVER, 7, BORDER, 1, 10.0, 7.0))
	theme.set_stylebox("panel", "TabContainer", _box(Color(0.0, 0.0, 0.0, 0.0), 8, Color(0.0, 0.0, 0.0, 0.0), 0, 0.0, 0.0))

	theme.set_constant("separation", "HBoxContainer", 9)
	theme.set_constant("separation", "VBoxContainer", 10)
	theme.set_constant("h_separation", "GridContainer", 9)
	theme.set_constant("v_separation", "GridContainer", 9)
	return theme

static func accent_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _box(ACCENT, 9, ACCENT, 0, 14.0, 8.0))
	button.add_theme_stylebox_override("hover", _box(ACCENT.lightened(0.08), 9, ACCENT.lightened(0.10), 0, 14.0, 8.0))
	button.add_theme_stylebox_override("pressed", _box(ACCENT.darkened(0.12), 9, ACCENT.darkened(0.12), 0, 14.0, 8.0))
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)

static func selected_button(button: Button, selected: bool) -> void:
	if selected:
		button.add_theme_stylebox_override("normal", _box(PANEL_ALT, 8, ACCENT, 1, 10.0, 7.0))
		button.add_theme_color_override("font_color", Color.WHITE)
	else:
		button.remove_theme_stylebox_override("normal")
		button.remove_theme_color_override("font_color")

static func chip(color: Color = SUCCESS) -> StyleBoxFlat:
	return _box(color.darkened(0.68), 999, color.darkened(0.08), 1, 10.0, 5.0)

static func _box(color: Color, radius: int, border_color: Color, border_width: int, margin_x: float, margin_y: float) -> StyleBoxFlat:
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
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	return style
