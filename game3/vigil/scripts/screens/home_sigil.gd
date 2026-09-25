class_name HomeSigil
extends Node2D

## The home sigil: a heptagram in a circle, drawn (never a texture),
## breathing slowly. Also the hidden door to the Enigma Scroll: pressing
## and holding it for HOLD_S seconds emits `held_long`. Nothing hints at
## it -- no glow, no progress, no haptic.

signal tapped
signal held_long

const HOLD_S := 7.0
const TAP_MAX_S := 0.5
const TAP_SLOP_PX := 24.0
const BREATH_S := 9.0

var radius := 90.0
var dim := false # the sealed state: faint and nearly still
var color := Color("#d9d1bd")

var _t := 0.0
var _pressed := false
var _press_pos := Vector2.ZERO
var _press_t := 0.0
var _on_sigil := false

func _process(delta: float) -> void:
	_t += delta
	if _pressed:
		_press_t += delta
		if _on_sigil and _press_t >= HOLD_S:
			_pressed = false
			held_long.emit()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		if event is InputEventMouseMotion and _pressed and event.position.distance_to(_press_pos) > TAP_SLOP_PX * 3:
			_on_sigil = false # a drag off the sigil cancels the hold
		return
	if event.pressed:
		_pressed = true
		_press_pos = event.position
		_press_t = 0.0
		_on_sigil = to_local(event.position).length() <= radius * 1.25
	elif _pressed:
		_pressed = false
		if _press_t <= TAP_MAX_S and event.position.distance_to(_press_pos) <= TAP_SLOP_PX:
			tapped.emit()

func _draw() -> void:
	var b := 0.5 - 0.5 * cos(TAU * _t / BREATH_S)
	var r := radius * (0.97 + (0.01 if dim else 0.05) * b)
	var c := color
	c.a = (0.22 + 0.04 * b) if dim else (0.7 + 0.25 * b)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 160, c, 1.6, true)
	var pts := PackedVector2Array()
	for i in 8:
		var a := -PI * 0.5 + TAU * float((i * 3) % 7) / 7.0
		pts.append(Vector2(cos(a), sin(a)) * r * 0.97)
	draw_polyline(pts, c, 1.6, true)
	draw_circle(Vector2.ZERO, 2.2, c)
