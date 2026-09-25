extends Node2D
class_name TrainsView

## Draws every train in passes across *all* trains -- shadows, headlight
## glow, bogies, couplers, bodies -- so one train's shadow never lands on
## top of another's roof. Each car's body sits on the chord between its
## two bogies, nudged by its sway, scaled a hair by its bounce; its shadow
## moves with sway, bounce and pitch, which is what reads as the body
## rocking on its springs from straight above.

const SUN := Vector2(3.5, 4.5)

var main: Node

func _draw() -> void:
	var trains: Array = main.trains
	var art: WagonArt = WagonCatalog.art
	var playing: bool = main.mode == main.MODE_PLAY
	for t in trains:
		for i in range(t.world.size()):
			var w: Dictionary = t.world[i]
			var z: float = t.bounce[i]
			var off: Vector2 = SUN * (1.0 + z * 0.12) + w["n"] * t.sway[i] * 1.1 + w["dir"] * t.pitch[i]
			draw_set_transform(w["center"] + off, (w["dir"] as Vector2).angle())
			art.shadow(self, w["len"], w["width"], Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0)
	if playing:
		for t in trains:
			_draw_headlights(t)
	for t in trains:
		for i in range(t.world.size()):
			var w: Dictionary = t.world[i]
			_draw_bogie(art, w["pf"], w["tf"], w["width"])
			_draw_bogie(art, w["pr"], w["tr"], w["width"])
	draw_set_transform(Vector2.ZERO, 0.0)
	for t in trains:
		_draw_couplers(t)
	for t in trains:
		for i in range(t.world.size()):
			var w: Dictionary = t.world[i]
			var sc: float = 1.0 + t.bounce[i] * 0.012
			var center: Vector2 = w["center"] + w["n"] * t.sway[i] * 0.35
			draw_set_transform(center, (w["dir"] as Vector2).angle(), Vector2(sc, sc))
			WagonCatalog.paint(t.cars[i]["type"], self, t.cars[i])
	draw_set_transform(Vector2.ZERO, 0.0)
	for t in trains:
		if not t.running and not t.world.is_empty() and t.has_power():
			_draw_stopped_marker(t)
	var sel = main.selected_train
	if sel != null and not playing and not sel.world.is_empty():
		_draw_selection(art, sel)

func _draw_bogie(art: WagonArt, p: Vector2, tangent: Vector2, width: float) -> void:
	draw_set_transform(p, tangent.angle())
	art.rr(self, 0.0, 0.0, 15.0, width - 3.0, 1.5, Color(0.1, 0.1, 0.11))
	for x in [-4.5, 4.5]:
		for y in [-6.2, 6.2]:
			draw_rect(Rect2(x - 2.2, y - 1.1, 4.4, 2.2), Color(0.32, 0.32, 0.34))

func _draw_couplers(t) -> void:
	var w: Array = t.world
	for i in range(w.size() - 1):
		var a: Vector2 = w[i]["back"] + w[i]["n"] * t.sway[i] * 0.35
		var b: Vector2 = w[i + 1]["front"] + w[i + 1]["n"] * t.sway[i + 1] * 0.35
		draw_line(a, b, Color(0.08, 0.08, 0.09), 3.0, true)
		draw_circle(a.lerp(b, 0.5), 1.8, Color(0.25, 0.25, 0.27))
		# Buffers: two little pads either side of the coupler.
		for side in [-1.0, 1.0]:
			var na: Vector2 = w[i]["n"] * side * 6.0
			var nb: Vector2 = w[i + 1]["n"] * side * 6.0
			draw_line(a + na, a + na - w[i]["dir"] * 1.8, Color(0.12, 0.12, 0.13), 2.2)
			draw_line(b + nb, b + nb + w[i + 1]["dir"] * 1.8, Color(0.12, 0.12, 0.13), 2.2)

## A soft light cone ahead of the lead loco (car 0 always faces forward).
func _draw_headlights(t) -> void:
	if t.world.is_empty() or not t.is_powered(0):
		return
	var w: Dictionary = t.world[0]
	var front: Vector2 = w["front"]
	var dir: Vector2 = w["dir"]
	var side: Vector2 = w["n"]
	var glow := PackedVector2Array([
		front - side * 5.0, front + side * 5.0,
		front + dir * 70.0 + side * 26.0, front + dir * 78.0, front + dir * 70.0 - side * 26.0,
	])
	var lit := Color(1.0, 0.95, 0.7, 0.28)
	var clear := Color(1.0, 0.95, 0.7, 0.0)
	draw_polygon(glow, PackedColorArray([lit, lit, clear, clear, clear]))

func _draw_stopped_marker(t) -> void:
	var w: Dictionary = t.world[0]
	var p: Vector2 = w["center"] - w["n"] * 16.0
	draw_circle(p, 6.5, Color(0.1, 0.1, 0.1, 0.8))
	draw_rect(Rect2(p + Vector2(-3.0, -3.0), Vector2(2.2, 6.0)), Color(1, 0.35, 0.3))
	draw_rect(Rect2(p + Vector2(0.8, -3.0), Vector2(2.2, 6.0)), Color(1, 0.35, 0.3))

func _draw_selection(art: WagonArt, t) -> void:
	for i in range(t.world.size()):
		var w: Dictionary = t.world[i]
		draw_set_transform(w["center"], (w["dir"] as Vector2).angle())
		var poly := art.rr_poly(w["len"] + 7.0, w["width"] + 7.0, 5.0)
		var loop := poly.duplicate()
		loop.append(poly[0])
		draw_polyline(loop, Color(1, 1, 1, 0.9), 1.6, true)
	draw_set_transform(Vector2.ZERO, 0.0)
	# Arrow off the leading end: which way the train will set off.
	var lead: int = 0 if t.direction > 0 else t.world.size() - 1
	var lw: Dictionary = t.world[lead]
	var fwd: Vector2 = lw["dir"] * float(t.direction)
	var start: Vector2 = (lw["front"] if t.direction > 0 else lw["back"]) + fwd * 6.0
	var tip: Vector2 = start + fwd * 26.0
	draw_line(start, tip, Color(1, 1, 1, 0.9), 2.5, true)
	var side: Vector2 = fwd.orthogonal() * 6.0
	draw_colored_polygon(PackedVector2Array([tip + fwd * 6.0, tip + side, tip - side]), Color(1, 1, 1, 0.9))
