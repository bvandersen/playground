extends Node2D
class_name DrawOverlay

## Live preview while laying track: the stroke so far as a ghost of the
## track bed, plus a ring wherever its start/end will join existing track.

var stroke := PackedVector2Array()
var snap_start := Vector2.INF
var snap_end := Vector2.INF
## The smoothing brush's ring while it's held (radius 0 = hidden).
var brush_pos := Vector2.ZERO
var brush_radius := 0.0
var brush_line := 2.0

func clear() -> void:
	stroke = PackedVector2Array()
	snap_start = Vector2.INF
	snap_end = Vector2.INF
	brush_radius = 0.0
	queue_redraw()

func _draw() -> void:
	if stroke.size() >= 2:
		draw_polyline(stroke, Color(1, 1, 1, 0.22), 26.0, true)
		draw_polyline(stroke, Color(1, 1, 1, 0.85), 2.0, true)
	for p in [snap_start, snap_end]:
		if p != Vector2.INF:
			draw_circle(p, 12.0, Color(0.35, 0.95, 0.45, 0.25))
			draw_arc(p, 12.0, 0.0, TAU, 28, Color(0.35, 0.95, 0.45, 0.95), 2.0, true)
	if brush_radius > 0.0:
		draw_circle(brush_pos, brush_radius, Color(0.55, 0.8, 1.0, 0.16))
		draw_arc(brush_pos, brush_radius, 0.0, TAU, 48, Color(0.75, 0.9, 1.0, 0.9), brush_line, true)
