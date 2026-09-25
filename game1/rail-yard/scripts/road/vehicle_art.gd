extends RefCounted
class_name VehicleArt

## Procedural top-down art for road vehicles, the same way WagonArt paints
## rolling stock: each painter draws one vehicle in its own frame (x
## towards the front, y across, centred on the origin), light from the
## top-left, no image assets. `ci` is a TriBatch in practice, so every
## vehicle is baked once (VehicleCatalog.frame) and only moved each frame.

const GLASS := Color(0.16, 0.22, 0.3)
const GLASS_HI := Color(0.42, 0.55, 0.68)
const TYRE := Color(0.08, 0.08, 0.09)
const HEAD := Color(1.0, 0.97, 0.82)
const TAIL := Color(0.85, 0.12, 0.1)
const CHROME := Color(0.72, 0.74, 0.77)
const WHITE := Color(0.95, 0.95, 0.94)

var _w := WagonArt.new()

func rr(ci, x: float, y: float, w: float, h: float, r: float, col: Color, outline: Color = Color(0, 0, 0, 0)) -> void:
	_w.rr(ci, x, y, w, h, r, col, outline)

func quad(ci, a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([a, b, c, d]), col)

## Wheels peeking out at the corners (drawn first, under the body).
func wheels(ci, l: float, w: float, xs: Array) -> void:
	for x in xs:
		for side in [-1.0, 1.0]:
			rr(ci, x, side * (w * 0.5 - 0.6), 4.2, 2.4, 0.8, TYRE)

## Head and tail lights on the body's front and back corners.
func lamps(ci, l: float, w: float, inset: float = 2.2) -> void:
	for side in [-1.0, 1.0]:
		rr(ci, l * 0.5 - 0.7, side * (w * 0.5 - inset), 1.4, 2.4, 0.5, HEAD)
		rr(ci, -l * 0.5 + 0.6, side * (w * 0.5 - inset), 1.2, 2.2, 0.4, TAIL)

## A car-shaped body: bonnet, windscreen, roof, rear window and boot, the
## cabin spanning `c0`..`c1` (fractions of the length, -0.5 = back).
func car(ci, l: float, w: float, col: Color, c0: float, c1: float, roof_col: Color = Color(0, 0, 0, 0)) -> void:
	var hl := l * 0.5
	var hw := w * 0.5
	var edge := col.darkened(0.55)
	wheels(ci, l, w, [hl - l * 0.22, -hl + l * 0.2])
	rr(ci, 0.0, 0.0, l, w, w * 0.34, col, edge)
	# Bonnet crease and the light catching the left flank.
	ci.draw_line(Vector2(-hl + 2.0, -hw + 1.3), Vector2(hl - 2.5, -hw + 1.3), col.lightened(0.35), 0.8, true)
	var x0 := l * c0
	var x1 := l * c1
	var ws := minf((x1 - x0) * 0.3, 5.0) # windscreen depth
	var rw := minf((x1 - x0) * 0.22, 3.6) # rear window depth
	var gw := hw - 1.1
	quad(ci, Vector2(x1, -gw + 0.4), Vector2(x1, gw - 0.4), Vector2(x1 - ws, gw - 1.2), Vector2(x1 - ws, -gw + 1.2), GLASS)
	ci.draw_line(Vector2(x1 - ws * 0.35, -gw + 1.5), Vector2(x1 - ws * 0.6, -gw + 2.8), GLASS_HI, 0.6, true)
	quad(ci, Vector2(x0, -gw + 0.8), Vector2(x0, gw - 0.8), Vector2(x0 + rw, gw - 1.3), Vector2(x0 + rw, -gw + 1.3), GLASS)
	var roof := roof_col if roof_col.a > 0.0 else col.lightened(0.1)
	rr(ci, (x0 + rw + x1 - ws) * 0.5, 0.0, (x1 - ws) - (x0 + rw) + 0.6, w - 3.2, 1.6, roof, roof.darkened(0.3))
	ci.draw_line(Vector2(x0 + rw + 1.0, -hw + 2.3), Vector2(x1 - ws - 1.0, -hw + 2.3), roof.lightened(0.3), 0.7, true)
	# Side windows: thin dark strips between the pillars.
	for side in [-1.0, 1.0]:
		ci.draw_line(Vector2(x0 + rw, side * (gw - 0.4)), Vector2(x1 - ws, side * (gw - 0.4)), GLASS, 0.9)
		rr(ci, x1 - ws + 0.5, side * (hw + 0.3), 1.6, 1.2, 0.4, col.darkened(0.3)) # mirrors
	lamps(ci, l, w)

# --- Cars --------------------------------------------------------------------

func mini(ci, l: float, w: float, col: Color, _seed: int) -> void:
	car(ci, l, w, col, -0.36, 0.22, WHITE)

func hatch(ci, l: float, w: float, col: Color, _seed: int) -> void:
	car(ci, l, w, col, -0.46, 0.2)

func sedan(ci, l: float, w: float, col: Color, _seed: int) -> void:
	car(ci, l, w, col, -0.3, 0.18)

func estate(ci, l: float, w: float, col: Color, _seed: int) -> void:
	car(ci, l, w, col, -0.45, 0.18)
	for side in [-1.0, 1.0]:
		ci.draw_line(Vector2(-l * 0.3, side * (w * 0.5 - 2.4)), Vector2(l * 0.02, side * (w * 0.5 - 2.4)), CHROME, 0.6)

func suv(ci, l: float, w: float, col: Color, _seed: int) -> void:
	car(ci, l, w, col, -0.44, 0.16)
	for side in [-1.0, 1.0]:
		ci.draw_line(Vector2(-l * 0.28, side * (w * 0.5 - 2.3)), Vector2(l * 0.0, side * (w * 0.5 - 2.3)), Color(0.12, 0.12, 0.13), 0.8)
	_w.circle(ci, Vector2(-l * 0.5 - 0.6, 0.0), 2.6, TYRE, Color(0.3, 0.3, 0.32))

func sports(ci, l: float, w: float, col: Color, seed: int) -> void:
	car(ci, l, w, col, -0.2, 0.12, Color(0.1, 0.1, 0.12) if seed % 2 == 0 else Color(0, 0, 0, 0))
	for y in [-1.1, 1.1]:
		ci.draw_line(Vector2(l * 0.13, y), Vector2(l * 0.5 - 0.8, y), WHITE, 0.9)
		ci.draw_line(Vector2(-l * 0.5 + 0.8, y), Vector2(-l * 0.2, y), WHITE, 0.9)
	rr(ci, -l * 0.5 + 1.2, 0.0, 1.6, w - 2.0, 0.5, col.darkened(0.4)) # spoiler

func taxi(ci, l: float, w: float, col: Color, _seed: int) -> void:
	car(ci, l, w, col, -0.3, 0.18)
	rr(ci, -l * 0.08, 0.0, 3.4, 6.5, 0.8, Color(0.15, 0.15, 0.15))
	rr(ci, -l * 0.08, 0.0, 2.2, 5.3, 0.5, Color(1.0, 0.95, 0.6))
	for k in range(4):
		rr(ci, -l * 0.3 + 1.6 + k * 1.6, w * 0.5 - 0.9, 1.2, 1.0, 0.0, Color(0.1, 0.1, 0.1) if k % 2 == 0 else WHITE)

func police(ci, l: float, w: float, col: Color, _seed: int) -> void:
	car(ci, l, w, col, -0.3, 0.18)
	for side in [-1.0, 1.0]:
		rr(ci, 0.0, side * (w * 0.5 - 0.6), l * 0.55, 1.2, 0.3, Color(0.12, 0.3, 0.75))
	rr(ci, -l * 0.02, -1.8, 2.2, 3.4, 0.5, Color(0.2, 0.45, 1.0))
	rr(ci, -l * 0.02, 1.8, 2.2, 3.4, 0.5, Color(1.0, 0.2, 0.2))

func pickup(ci, l: float, w: float, col: Color, seed: int) -> void:
	var hl := l * 0.5
	car(ci, l, w, col, -0.06, 0.2)
	# Open load bed behind the cab, maybe with something in it.
	rr(ci, -hl + l * 0.23, 0.0, l * 0.4, w - 2.2, 0.6, col.darkened(0.45))
	for k in range(3):
		ci.draw_line(Vector2(-hl + 2.0, -w * 0.25 + k * w * 0.25), Vector2(-hl + l * 0.42, -w * 0.25 + k * w * 0.25), col.darkened(0.55), 0.4)
	if seed % 3 == 0:
		rr(ci, -hl + l * 0.2, -1.4, 4.0, 3.6, 0.4, Color(0.7, 0.52, 0.3), Color(0.45, 0.32, 0.18))
		rr(ci, -hl + l * 0.3, 1.8, 3.4, 3.0, 0.4, Color(0.62, 0.45, 0.26), Color(0.45, 0.32, 0.18))

func van(ci, l: float, w: float, col: Color, _seed: int) -> void:
	var hl := l * 0.5
	var hw := w * 0.5
	wheels(ci, l, w, [hl - l * 0.18, -hl + l * 0.18])
	rr(ci, 0.0, 0.0, l, w, 2.4, col, col.darkened(0.55))
	quad(ci, Vector2(hl - 2.6, -hw + 1.2), Vector2(hl - 2.6, hw - 1.2), Vector2(hl - 6.2, hw - 1.5), Vector2(hl - 6.2, -hw + 1.5), GLASS)
	rr(ci, -2.0, 0.0, l - 11.0, w - 2.2, 1.2, col.lightened(0.1), col.darkened(0.25))
	for k in range(1, 5):
		var x := -hl + 3.0 + k * (l - 12.0) / 5.0
		ci.draw_line(Vector2(x, -hw + 1.6), Vector2(x, hw - 1.6), col.darkened(0.12), 0.6)
	ci.draw_line(Vector2(-hl + 2.0, -hw + 1.4), Vector2(hl - 7.0, -hw + 1.4), col.lightened(0.35), 0.7, true)
	for side in [-1.0, 1.0]:
		rr(ci, hl - 6.0, side * (hw + 0.3), 1.6, 1.2, 0.4, col.darkened(0.3))
	lamps(ci, l, w)

func icecream(ci, l: float, w: float, col: Color, seed: int) -> void:
	van(ci, l, w, col, seed)
	# A giant cone on the roof.
	var c := Vector2(-3.0, 0.0)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-7.5, 0.0), c + Vector2(1.0, -3.2), c + Vector2(1.0, 3.2)]), Color(0.86, 0.62, 0.32))
	for k in range(3):
		ci.draw_line(c + Vector2(-5.5 + k * 2.2, -1.0), c + Vector2(-4.5 + k * 2.2, 1.0), Color(0.66, 0.44, 0.2), 0.4)
	ci.draw_circle(c + Vector2(2.4, 0.0), 3.4, Color(1.0, 0.72, 0.8))
	ci.draw_circle(c + Vector2(3.4, -1.0), 2.0, Color(1.0, 0.85, 0.9))
	ci.draw_circle(c + Vector2(5.2, 0.4), 1.0, Color(0.85, 0.15, 0.2))

# --- Trucks ------------------------------------------------------------------

## The cab every lorry shares, its front at `front` (x), `len` long.
func cab(ci, front: float, cab_len: float, w: float, col: Color) -> void:
	var hw := w * 0.5
	var x := front - cab_len * 0.5
	rr(ci, x, 0.0, cab_len, w, 2.2, col, col.darkened(0.55))
	rr(ci, x - 0.6, 0.0, cab_len - 4.4, w - 3.0, 1.4, col.lightened(0.14))
	ci.draw_line(Vector2(x - cab_len * 0.3, -hw + 1.3), Vector2(front - 2.0, -hw + 1.3), col.lightened(0.4), 0.7, true)
	quad(ci, Vector2(front - 0.6, -hw + 1.2), Vector2(front - 0.6, hw - 1.2), Vector2(front - 2.6, hw - 1.6), Vector2(front - 2.6, -hw + 1.6), GLASS)
	for side in [-1.0, 1.0]:
		rr(ci, front - 3.0, side * (hw + 0.6), 1.4, 1.6, 0.4, Color(0.12, 0.12, 0.13))
		rr(ci, front - 0.5, side * (hw - 2.0), 1.0, 2.4, 0.4, HEAD)

func _truck_base(ci, l: float, w: float) -> void:
	var hl := l * 0.5
	wheels(ci, l, w, [hl - 5.0, -hl + 9.0, -hl + 4.5])
	rr(ci, -2.0, 0.0, l - 4.0, w - 5.0, 0.8, Color(0.16, 0.16, 0.17)) # chassis

func _tail(ci, l: float, w: float) -> void:
	for side in [-1.0, 1.0]:
		rr(ci, -l * 0.5 + 0.5, side * (w * 0.5 - 1.6), 1.0, 2.0, 0.3, TAIL)

func box_truck(ci, l: float, w: float, col: Color, seed: int) -> void:
	var hl := l * 0.5
	_truck_base(ci, l, w)
	cab(ci, hl, 10.0, w - 0.6, col)
	var box: Color = [WHITE, Color(0.9, 0.86, 0.72), Color(0.75, 0.78, 0.8)][seed % 3]
	var bl := l - 12.0
	rr(ci, -hl + bl * 0.5, 0.0, bl, w, 1.2, box, box.darkened(0.4))
	for k in range(1, 6):
		var x := -hl + k * bl / 6.0
		ci.draw_line(Vector2(x, -w * 0.5 + 0.8), Vector2(x, w * 0.5 - 0.8), box.darkened(0.1), 0.6)
	ci.draw_line(Vector2(-hl + 1.0, -w * 0.5 + 1.2), Vector2(-hl + bl - 1.0, -w * 0.5 + 1.2), box.lightened(0.5), 0.8, true)
	rr(ci, -hl + bl * 0.5, 0.0, bl * 0.5, 3.0, 0.6, col) # logo stripe on the roof
	_tail(ci, l, w)

func tanker_truck(ci, l: float, w: float, col: Color, seed: int) -> void:
	var hl := l * 0.5
	_truck_base(ci, l, w)
	cab(ci, hl, 10.0, w - 0.6, col)
	var tank: Color = [CHROME, Color(0.95, 0.95, 0.93), Color(0.2, 0.55, 0.3)][seed % 3]
	var tl := l - 13.0
	var tx := -hl + tl * 0.5 + 0.5
	rr(ci, tx, 0.0, tl, w - 0.5, (w - 0.5) * 0.48, tank.darkened(0.3), tank.darkened(0.55))
	rr(ci, tx, -1.2, tl - 2.0, w - 5.0, (w - 5.0) * 0.48, tank)
	ci.draw_line(Vector2(tx - tl * 0.45, -w * 0.25), Vector2(tx + tl * 0.45, -w * 0.25), tank.lightened(0.6), 1.2, true)
	for k in range(3):
		_w.circle(ci, Vector2(tx - tl * 0.3 + k * tl * 0.3, 0.0), 1.6, tank.darkened(0.2), tank.darkened(0.45))
	ci.draw_line(Vector2(tx - tl * 0.45, 0.0), Vector2(tx + tl * 0.45, 0.0), Color(0.3, 0.3, 0.32, 0.8), 0.6)
	_tail(ci, l, w)

func tipper(ci, l: float, w: float, col: Color, seed: int) -> void:
	var hl := l * 0.5
	_truck_base(ci, l, w)
	cab(ci, hl, 10.0, w - 0.6, col)
	var bl := l - 12.0
	var bx := -hl + bl * 0.5
	rr(ci, bx, 0.0, bl, w, 1.0, col.darkened(0.25), col.darkened(0.6))
	rr(ci, bx, 0.0, bl - 2.6, w - 2.6, 0.6, col.darkened(0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var load: Color = [Color(0.72, 0.6, 0.4), Color(0.45, 0.43, 0.42), Color(0.36, 0.26, 0.18)][seed % 3]
	ci.draw_circle(Vector2(bx, 0.0), (w - 5.0) * 0.4, Color(load.r, load.g, load.b, 0.55))
	for k in range(22):
		var p := Vector2(bx + rng.randf_range(-bl * 0.42, bl * 0.42), rng.randf_range(-w * 0.32, w * 0.32))
		ci.draw_circle(p, rng.randf_range(0.8, 1.6), load.darkened(rng.randf_range(-0.2, 0.25)))
	_tail(ci, l, w)

func mixer(ci, l: float, w: float, col: Color, _seed: int) -> void:
	var hl := l * 0.5
	_truck_base(ci, l, w)
	cab(ci, hl, 10.0, w - 0.6, col)
	var dl := l - 16.0
	var dx := -hl + 3.0 + dl * 0.5
	rr(ci, dx, 0.0, dl, w - 1.0, (w - 1.0) * 0.48, Color(0.86, 0.86, 0.84), Color(0.45, 0.45, 0.45))
	rr(ci, dx, -1.0, dl - 4.0, w - 6.0, (w - 6.0) * 0.48, WHITE)
	# Spiral stripes on the drum.
	for k in range(5):
		var x := dx - dl * 0.4 + k * dl * 0.2
		ci.draw_line(Vector2(x - 2.0, -w * 0.45), Vector2(x + 2.0, w * 0.45), col, 1.6, true)
	rr(ci, -hl + 1.5, 0.0, 3.0, 5.0, 0.8, Color(0.3, 0.3, 0.3)) # chute
	_tail(ci, l, w)

func log_truck(ci, l: float, w: float, col: Color, seed: int) -> void:
	var hl := l * 0.5
	_truck_base(ci, l, w)
	cab(ci, hl, 10.0, w - 0.6, col)
	rr(ci, hl - 11.0, 0.0, 1.6, w, 0.4, Color(0.2, 0.2, 0.22)) # headboard
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var bl := l - 13.0
	for row in range(4):
		var y := -w * 0.36 + row * w * 0.24
		var x0 := -hl + rng.randf_range(0.0, 2.0)
		var x1 := -hl + bl - rng.randf_range(0.0, 2.0)
		var bark := Color(0.46, 0.32, 0.2).darkened(rng.randf_range(0.0, 0.25))
		rr(ci, (x0 + x1) * 0.5, y, x1 - x0, 3.4, 1.6, bark, bark.darkened(0.4))
		ci.draw_line(Vector2(x0 + 1.5, y - 0.8), Vector2(x1 - 1.5, y - 0.8), bark.lightened(0.25), 0.5)
		_w.circle(ci, Vector2(x0 + 0.8, y), 1.5, Color(0.85, 0.7, 0.48), bark.darkened(0.3))
	for x in [-hl + bl * 0.25, -hl + bl * 0.75]:
		ci.draw_line(Vector2(x, -w * 0.5), Vector2(x, w * 0.5), Color(0.2, 0.2, 0.22), 0.7)
	_tail(ci, l, w)

func garbage(ci, l: float, w: float, col: Color, _seed: int) -> void:
	var hl := l * 0.5
	_truck_base(ci, l, w)
	cab(ci, hl, 10.0, w - 0.6, WHITE)
	var bl := l - 12.0
	var bx := -hl + bl * 0.5
	rr(ci, bx, 0.0, bl, w, 3.0, col, col.darkened(0.5))
	rr(ci, bx + 1.0, -0.8, bl - 6.0, w - 5.0, 2.0, col.lightened(0.14))
	for k in range(1, 5):
		var x := -hl + k * bl / 5.0
		ci.draw_line(Vector2(x, -w * 0.5 + 1.0), Vector2(x, w * 0.5 - 1.0), col.darkened(0.25), 0.8)
	rr(ci, -hl + 2.0, 0.0, 4.0, w - 1.0, 1.4, col.darkened(0.3), col.darkened(0.6)) # tailgate
	for side in [-1.0, 1.0]:
		ci.draw_line(Vector2(-hl + 0.4, side * 2.0), Vector2(-hl + 0.4, side * 5.0), Color(1.0, 0.8, 0.15), 0.9)
	_tail(ci, l, w)

func fire_engine(ci, l: float, w: float, col: Color, _seed: int) -> void:
	var hl := l * 0.5
	var hw := w * 0.5
	_truck_base(ci, l, w)
	rr(ci, -1.5, 0.0, l - 3.0, w, 1.8, col, col.darkened(0.55))
	cab(ci, hl, 11.0, w, col)
	rr(ci, -hl + 1.6, 0.0, 1.8, w - 1.0, 0.4, Color(0.95, 0.85, 0.2))
	# Ladder along the roof.
	for y in [-2.6, 2.6]:
		ci.draw_line(Vector2(-hl + 1.5, y), Vector2(hl - 8.0, y), CHROME.lightened(0.1), 1.0)
	for k in range(12):
		var x := -hl + 3.0 + k * (l - 12.0) / 11.0
		ci.draw_line(Vector2(x, -2.6), Vector2(x, 2.6), CHROME, 0.6)
	rr(ci, hl - 8.0, 0.0, 3.0, 3.0, 0.8, Color(0.25, 0.25, 0.27))
	rr(ci, hl - 12.2, -hw + 2.0, 1.8, 2.2, 0.5, Color(0.3, 0.55, 1.0))
	rr(ci, hl - 12.2, hw - 2.0, 1.8, 2.2, 0.5, Color(0.3, 0.55, 1.0))
	_tail(ci, l, w)

## Tractor unit of an articulated lorry: cab and the fifth wheel.
func tractor(ci, l: float, w: float, col: Color, _seed: int) -> void:
	var hl := l * 0.5
	wheels(ci, l, w, [hl - 4.5, -hl + 4.0])
	rr(ci, -1.0, 0.0, l - 2.0, w - 5.0, 0.8, Color(0.16, 0.16, 0.17))
	_w.circle(ci, Vector2(-hl + 5.0, 0.0), 3.0, Color(0.22, 0.22, 0.24), Color(0.1, 0.1, 0.1))
	cab(ci, hl, 11.0, w, col)
	for side in [-1.0, 1.0]:
		rr(ci, hl - 12.5, side * (w * 0.5 - 1.8), 2.0, 1.8, 0.6, CHROME) # exhaust stacks

func semi_trailer(ci, l: float, w: float, _col: Color, seed: int) -> void:
	var hl := l * 0.5
	wheels(ci, l, w, [-hl + 4.0, -hl + 8.5, -hl + 13.0])
	var c: Color = [Color(0.78, 0.2, 0.15), Color(0.15, 0.44, 0.7), Color(0.2, 0.58, 0.34), Color(0.9, 0.7, 0.12), Color(0.6, 0.6, 0.62), WHITE][seed % 6]
	rr(ci, 0.0, 0.0, l, w, 0.8, c, c.darkened(0.5))
	for k in range(1, 12):
		var x := -hl + k * l / 12.0
		ci.draw_line(Vector2(x, -w * 0.5 + 0.8), Vector2(x, w * 0.5 - 0.8), c.darkened(0.14), 0.6)
	ci.draw_line(Vector2(-hl + 1.0, -w * 0.5 + 1.2), Vector2(hl - 1.0, -w * 0.5 + 1.2), c.lightened(0.35), 0.8, true)
	_tail(ci, l, w)

# --- Buses -------------------------------------------------------------------

## A bus roof seen from above: body, window band down both sides, roof
## panel with hatches and an air-con pod, windscreen at the front.
func bus(ci, l: float, w: float, col: Color, roof: Color, band: Color = GLASS, front_glass: bool = true) -> void:
	var hl := l * 0.5
	var hw := w * 0.5
	wheels(ci, l, w, [hl - 7.0, -hl + 9.0])
	rr(ci, 0.0, 0.0, l, w, 2.8, col, col.darkened(0.55))
	rr(ci, -0.5, 0.0, l - 5.0, w - 1.6, 2.0, band)
	rr(ci, -0.5, 0.0, l - 6.0, w - 4.2, 1.6, roof, roof.darkened(0.3))
	ci.draw_line(Vector2(-hl + 3.0, -hw + 2.6), Vector2(hl - 4.0, -hw + 2.6), roof.lightened(0.3), 0.7, true)
	if front_glass:
		quad(ci, Vector2(hl - 0.5, -hw + 1.0), Vector2(hl - 0.5, hw - 1.0), Vector2(hl - 3.0, hw - 1.0), Vector2(hl - 3.0, -hw + 1.0), GLASS)
	for side in [-1.0, 1.0]:
		rr(ci, hl - 2.0, side * (hw + 0.6), 1.2, 1.8, 0.4, Color(0.12, 0.12, 0.13))
	lamps(ci, l, w, 2.0)

func city_bus(ci, l: float, w: float, col: Color, _seed: int) -> void:
	bus(ci, l, w, col, Color(0.86, 0.87, 0.88))
	rr(ci, -l * 0.12, 0.0, 10.0, 7.0, 1.4, Color(0.7, 0.72, 0.74), Color(0.5, 0.5, 0.52))
	for x in [l * 0.22, -l * 0.36]:
		rr(ci, x, 0.0, 4.0, 4.0, 0.6, Color(0.6, 0.62, 0.64))
	rr(ci, l * 0.5 - 4.5, 0.0, 1.8, 7.0, 0.4, Color(0.1, 0.1, 0.1)) # destination blind
	rr(ci, l * 0.5 - 4.5, 0.0, 1.0, 5.4, 0.2, Color(1.0, 0.72, 0.15))

func school_bus(ci, l: float, w: float, col: Color, _seed: int) -> void:
	bus(ci, l, w, col, col.lightened(0.1))
	for y in [-w * 0.5 + 2.4, w * 0.5 - 2.4]:
		ci.draw_line(Vector2(-l * 0.5 + 2.0, y), Vector2(l * 0.5 - 4.0, y), Color(0.1, 0.1, 0.1), 0.6)
	for x in [l * 0.1, -l * 0.25]:
		rr(ci, x, 0.0, 4.0, 4.0, 0.5, col.darkened(0.15), col.darkened(0.4))
	rr(ci, l * 0.5 - 1.0, 0.0, 2.0, w - 4.0, 0.6, Color(0.1, 0.1, 0.1)) # bonnet grille

func double_decker(ci, l: float, w: float, col: Color, _seed: int) -> void:
	bus(ci, l, w, col, col)
	rr(ci, -0.5, 0.0, l - 3.0, w - 1.2, 2.4, GLASS)
	rr(ci, -0.5, 0.0, l - 5.0, w - 4.0, 2.0, col.lightened(0.05), col.darkened(0.4))
	ci.draw_line(Vector2(-l * 0.5 + 3.0, -w * 0.5 + 2.4), Vector2(l * 0.5 - 3.0, -w * 0.5 + 2.4), col.lightened(0.35), 0.7, true)
	rr(ci, -l * 0.3, 0.0, 5.0, 4.0, 0.6, col.darkened(0.2))
	rr(ci, l * 0.5 - 2.0, 0.0, 1.6, 8.0, 0.4, Color(0.1, 0.1, 0.1))
	rr(ci, l * 0.5 - 2.0, 0.0, 0.9, 6.4, 0.2, Color(1.0, 0.72, 0.15))

func coach_bus(ci, l: float, w: float, col: Color, _seed: int) -> void:
	bus(ci, l, w, WHITE, Color(0.93, 0.93, 0.92))
	for side in [-1.0, 1.0]:
		ci.draw_line(Vector2(-l * 0.45, side * (w * 0.5 - 0.5)), Vector2(l * 0.1, side * (w * 0.5 - 0.5)), col, 1.0)
	rr(ci, 0.0, 0.0, l * 0.5, 2.6, 1.0, col)
	for x in [l * 0.25, -l * 0.3]:
		rr(ci, x, 0.0, 5.0, 4.0, 0.8, Color(0.8, 0.8, 0.8), Color(0.55, 0.55, 0.57))

func minibus(ci, l: float, w: float, col: Color, _seed: int) -> void:
	van(ci, l, w, col, 0)
	for side in [-1.0, 1.0]:
		ci.draw_line(Vector2(-l * 0.4, side * (w * 0.5 - 0.7)), Vector2(l * 0.25, side * (w * 0.5 - 0.7)), GLASS, 1.0)

## Front half of a bendy bus (the rear half is its trailer).
func bendy_front(ci, l: float, w: float, col: Color, _seed: int) -> void:
	bus(ci, l, w, col, Color(0.86, 0.87, 0.88))
	rr(ci, -l * 0.1, 0.0, 8.0, 7.0, 1.4, Color(0.7, 0.72, 0.74), Color(0.5, 0.5, 0.52))
	rr(ci, -l * 0.5 + 0.6, 0.0, 1.2, w - 3.0, 0.4, Color(0.15, 0.15, 0.15))

func bendy_rear(ci, l: float, w: float, col: Color, _seed: int) -> void:
	bus(ci, l, w, col, Color(0.86, 0.87, 0.88), GLASS, false)
	rr(ci, l * 0.5 - 0.6, 0.0, 1.2, w - 3.0, 0.4, Color(0.15, 0.15, 0.15))
	rr(ci, -l * 0.15, 0.0, 4.0, 4.0, 0.6, Color(0.6, 0.62, 0.64))
