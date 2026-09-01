# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name CrashMetricGraph
extends Control

var title: String = "Metric"
var unit: String = ""
var points: Array[Vector2] = []
var markers: Array[Dictionary] = []

func configure(graph_title: String, graph_unit: String, series: Array[Vector2], event_markers: Array[Dictionary]) -> void:
	title = graph_title
	unit = graph_unit
	points = series.duplicate()
	markers = event_markers.duplicate(true)
	queue_redraw()

func clear() -> void:
	points.clear()
	markers.clear()
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var background := Color(0.035, 0.045, 0.060, 0.92)
	var grid := Color(0.20, 0.23, 0.28, 0.55)
	var curve := Color(0.33, 0.72, 0.96, 1.0)
	var marker_color := Color(0.95, 0.64, 0.24, 0.85)
	draw_rect(rect, background, true)
	if size.x < 20.0 or size.y < 20.0:
		return
	var plot := Rect2(Vector2(8.0, 20.0), Vector2(size.x - 16.0, size.y - 28.0))
	for i in range(1, 4):
		var y := plot.position.y + plot.size.y * float(i) / 4.0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), grid, 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(8.0, 14.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.88, 0.90, 0.94))
	if points.is_empty():
		return
	var min_time := points[0].x
	var max_time := points[-1].x
	var min_value := points[0].y
	var max_value := points[0].y
	for point in points:
		min_time = minf(min_time, point.x)
		max_time = maxf(max_time, point.x)
		min_value = minf(min_value, point.y)
		max_value = maxf(max_value, point.y)
	if is_equal_approx(min_value, max_value):
		min_value -= 0.5
		max_value += 0.5
	var time_span := maxf(max_time - min_time, 0.000001)
	var value_span := maxf(max_value - min_value, 0.000001)
	var polyline := PackedVector2Array()
	for point in points:
		var x := plot.position.x + (point.x - min_time) / time_span * plot.size.x
		var y := plot.end.y - (point.y - min_value) / value_span * plot.size.y
		polyline.append(Vector2(x, y))
	if polyline.size() >= 2:
		draw_polyline(polyline, curve, 2.0, true)
	for marker in markers:
		var marker_time := float(marker.get("time_s", -1.0))
		if marker_time < min_time or marker_time > max_time:
			continue
		var x := plot.position.x + (marker_time - min_time) / time_span * plot.size.x
		draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), marker_color, 1.0)
	var max_label := "%.1f %s" % [max_value, unit]
	draw_string(font, Vector2(plot.position.x + 2.0, plot.position.y + 12.0), max_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.70, 0.74, 0.80))
