extends RefCounted
class_name IconArt

## Procedural button icons, no image assets or emoji font needed (the Web
## export has no system font fallback, so emoji would render as boxes).
## Every icon is drawn on a 24 x 24 grid that `paint` scales into the
## button, in bright, chunky shapes a small child can read without any
## words: a hand to grab, a pencil to draw, an eraser, a bin, a tick...

const WHITE := Color(0.95, 0.96, 0.97)
const GREEN := Color(0.36, 0.86, 0.46)
const RED := Color(0.95, 0.36, 0.3)
const YELLOW := Color(1.0, 0.82, 0.24)
const BLUE := Color(0.38, 0.66, 1.0)
const PINK := Color(1.0, 0.56, 0.66)
const SKIN := Color(1.0, 0.84, 0.62)
const DARK := Color(0.12, 0.13, 0.15)

## Draws icon `id` centred on `center`, `size` px square, on `ci`.
static func paint(ci: CanvasItem, id: String, center: Vector2, size: float) -> void:
	var k := size / 24.0
	ci.draw_set_transform(center - Vector2(size, size) * 0.5, 0.0, Vector2(k, k))
	match id:
		"play": _play(ci)
		"stop": _stop(ci)
		"hand": _hand(ci)
		"pencil": _pencil(ci)
		"eraser": _eraser(ci)
		"train": _train(ci)
		"menu": _menu(ci)
		"undo": _undo(ci)
		"fit": _fit(ci)
		"wand": _wand(ci)
		"bin": _bin(ci)
		"save": _tray_arrow(ci, true)
		"load": _tray_arrow(ci, false)
		"autosave": _autosave(ci)
		"rewind": _rewind(ci)
		"arrow_right": _arrow(ci, 1.0)
		"arrow_left": _arrow(ci, -1.0)
		"turn": _turn(ci)
		"eye": _eye(ci)
		"check": _check(ci)
		"pause": _pause(ci)
	ci.draw_set_transform(Vector2.ZERO, 0.0)

## A small round badge ("plus" / "cross") in the top-right corner of a
## `size` box centred on `center` -- e.g. the + on "add a wagon".
static func badge(ci: CanvasItem, kind: String, center: Vector2, size: float) -> void:
	var k := size / 24.0
	ci.draw_set_transform(center - Vector2(size, size) * 0.5, 0.0, Vector2(k, k))
	var c := Vector2(20.5, 4.5)
	if kind == "plus":
		disc(ci, c, 4.6, GREEN.darkened(0.15))
		stroke(ci, [c + Vector2(-2.4, 0), c + Vector2(2.4, 0)], WHITE, 1.6)
		stroke(ci, [c + Vector2(0, -2.4), c + Vector2(0, 2.4)], WHITE, 1.6)
	elif kind == "cross":
		disc(ci, c, 4.6, RED.darkened(0.1))
		stroke(ci, [c + Vector2(-1.8, -1.8), c + Vector2(1.8, 1.8)], WHITE, 1.5)
		stroke(ci, [c + Vector2(1.8, -1.8), c + Vector2(-1.8, 1.8)], WHITE, 1.5)
	ci.draw_set_transform(Vector2.ZERO, 0.0)

# --- Shape helpers ---------------------------------------------------------

## Filled polygon with an anti-aliased edge (draw_colored_polygon alone
## has jagged edges in the Compatibility renderer).
static func poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	ci.draw_colored_polygon(pts, col)
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, col, 0.6, true)

static func disc(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(20):
		pts.append(c + Vector2.from_angle(TAU * i / 20.0) * r)
	poly(ci, pts, col)

## A thick line through `pts` with round ends and joints.
static func stroke(ci: CanvasItem, pts: Array, col: Color, w: float) -> void:
	ci.draw_polyline(PackedVector2Array(pts), col, w, true)
	for p in pts:
		disc(ci, p, w * 0.5, col)

static func rrect(ci: CanvasItem, r: Rect2, radius: float, col: Color) -> void:
	var pts := PackedVector2Array()
	radius = minf(radius, minf(r.size.x, r.size.y) * 0.5)
	var corners := [r.end - Vector2(radius, radius), Vector2(r.position.x + radius, r.end.y - radius),
		r.position + Vector2(radius, radius), Vector2(r.end.x - radius, r.position.y + radius)]
	for c in range(4):
		for i in range(5):
			pts.append(corners[c] + Vector2.from_angle(c * PI * 0.5 + i * PI / 8.0) * radius)
	poly(ci, pts, col)

## Filled arrowhead with its tip at `tip`, pointing along `dir`.
static func head(ci: CanvasItem, tip: Vector2, dir: Vector2, length: float, half_width: float, col: Color) -> void:
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x)
	var base := tip - d * length
	poly(ci, PackedVector2Array([tip, base + n * half_width, base - n * half_width]), col)

static func arc_pts(c: Vector2, r: float, a0: float, a1: float, steps: int = 16) -> Array:
	var pts := []
	for i in range(steps + 1):
		pts.append(c + Vector2.from_angle(lerpf(a0, a1, float(i) / steps)) * r)
	return pts

static func star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var rad := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2.from_angle(-PI * 0.5 + i * PI / 5.0) * rad)
	poly(ci, pts, col)

# --- Icons -----------------------------------------------------------------

static func _play(ci: CanvasItem) -> void:
	# Dark rim so it still stands out on a green (switched-on) button.
	stroke(ci, [Vector2(6.5, 3.5), Vector2(20.5, 12), Vector2(6.5, 20.5), Vector2(6.5, 3.5)], DARK.lightened(0.1), 2.2)
	poly(ci, PackedVector2Array([Vector2(6.5, 3.5), Vector2(20.5, 12), Vector2(6.5, 20.5)]), GREEN)

static func _stop(ci: CanvasItem) -> void:
	rrect(ci, Rect2(4.5, 4.5, 15, 15), 2.5, RED)

static func _pause(ci: CanvasItem) -> void:
	rrect(ci, Rect2(5.5, 4.5, 4.8, 15), 1.5, YELLOW)
	rrect(ci, Rect2(13.7, 4.5, 4.8, 15), 1.5, YELLOW)

## An open hand: "grab and move things".
static func _hand(ci: CanvasItem) -> void:
	var outline := SKIN.darkened(0.45)
	for pass_i in range(2):
		var col := outline if pass_i == 0 else SKIN
		var grow := 1.1 if pass_i == 0 else 0.0
		stroke(ci, [Vector2(8.2, 13), Vector2(8.2, 6)], col, 3.0 + grow)
		stroke(ci, [Vector2(11.4, 12), Vector2(11.4, 3.8)], col, 3.0 + grow)
		stroke(ci, [Vector2(14.6, 12), Vector2(14.6, 4.8)], col, 3.0 + grow)
		stroke(ci, [Vector2(17.6, 13), Vector2(17.6, 7.4)], col, 2.8 + grow)
		stroke(ci, [Vector2(8.5, 17), Vector2(4.4, 12.2)], col, 3.0 + grow)
		rrect(ci, Rect2(6.7 - grow * 0.5, 10.5 - grow * 0.5, 12.6 + grow, 10.5 + grow), 4.0, col)

## A yellow pencil, point down-left: "draw track".
static func _pencil(ci: CanvasItem) -> void:
	var d := Vector2(1, -1).normalized()
	var n := Vector2(-d.y, d.x)
	var tip := Vector2(3.5, 20.5)
	var cone := tip + d * 5.0
	var back := tip + d * 21.0
	var hw := 2.9
	poly(ci, PackedVector2Array([cone + n * hw, back + n * hw, back - n * hw, cone - n * hw]), YELLOW)
	poly(ci, PackedVector2Array([cone + n * hw * 0.35, back + n * hw * 0.35, back, cone]), YELLOW.darkened(0.15))
	poly(ci, PackedVector2Array([tip, cone + n * hw, cone - n * hw]), Color(0.96, 0.8, 0.6))
	poly(ci, PackedVector2Array([tip, tip + d * 2.0 + n * hw * 0.4, tip + d * 2.0 - n * hw * 0.4]), DARK)
	var band := back - d * 3.2
	poly(ci, PackedVector2Array([band + n * hw, back + n * hw, back - n * hw, band - n * hw]), PINK)
	poly(ci, PackedVector2Array([band + n * hw, band + d * 0.9 + n * hw, band + d * 0.9 - n * hw, band - n * hw]), Color(0.75, 0.77, 0.8))

## A pink rubber rubbing a line out: "erase".
static func _eraser(ci: CanvasItem) -> void:
	stroke(ci, [Vector2(3.5, 21), Vector2(20.5, 21)], WHITE.darkened(0.35), 1.4)
	var xf := Transform2D(-PI / 4.0, Vector2(12.5, 11.5))
	var body := PackedVector2Array([Vector2(-9, -4.2), Vector2(9, -4.2), Vector2(9, 4.2), Vector2(-9, 4.2)])
	poly(ci, xf * body, PINK)
	var sleeve := PackedVector2Array([Vector2(-1, -4.2), Vector2(9, -4.2), Vector2(9, 4.2), Vector2(-1, 4.2)])
	poly(ci, xf * sleeve, BLUE)
	stroke(ci, [xf * Vector2(-1, -4.2), xf * Vector2(-1, 4.2)], WHITE, 0.8)

## A little steam engine from the side: "a train".
static func _train(ci: CanvasItem) -> void:
	var body := RED
	rrect(ci, Rect2(2.5, 10, 13, 7), 1.5, body)
	rrect(ci, Rect2(13, 5, 8, 12), 1.2, body.darkened(0.15))
	rrect(ci, Rect2(12, 3.8, 10, 2.2), 1.0, DARK)
	rrect(ci, Rect2(15, 7, 4, 3.6), 0.8, Color(0.75, 0.9, 1.0))
	rrect(ci, Rect2(4.5, 5.5, 3.4, 5), 0.8, DARK)
	rrect(ci, Rect2(3.8, 4.5, 4.8, 1.8), 0.6, DARK)
	disc(ci, Vector2(9.5, 9.6), 1.6, YELLOW)
	rrect(ci, Rect2(1.5, 16.5, 21, 1.6), 0.6, DARK)
	for x in [5.5, 11.0, 17.5]:
		disc(ci, Vector2(x, 19.2), 2.6, DARK)
		disc(ci, Vector2(x, 19.2), 1.0, Color(0.7, 0.72, 0.75))

static func _menu(ci: CanvasItem) -> void:
	for y in [6.0, 12.0, 18.0]:
		stroke(ci, [Vector2(5, y), Vector2(19, y)], WHITE, 2.8)

## A curly arrow going back: "undo".
static func _undo(ci: CanvasItem) -> void:
	var pts := [Vector2(8, 8.5), Vector2(14, 8.5)]
	pts.append_array(arc_pts(Vector2(14, 14), 5.5, -PI * 0.5, PI * 0.5))
	pts.append(Vector2(8.5, 19.5))
	stroke(ci, pts, YELLOW, 2.8)
	head(ci, Vector2(2.5, 8.5), Vector2(-1, 0), 6.5, 5.0, YELLOW)

## Four corners around a track loop: "show the whole layout".
static func _fit(ci: CanvasItem) -> void:
	ci.draw_arc(Vector2(12, 12), 4.8, 0.0, TAU, 24, GREEN, 2.2, true)
	for c in [Vector2(3, 3), Vector2(21, 3), Vector2(21, 21), Vector2(3, 21)]:
		var sx := 1.0 if c.x < 12 else -1.0
		var sy := 1.0 if c.y < 12 else -1.0
		stroke(ci, [c + Vector2(0, 5.5 * sy), c, c + Vector2(5.5 * sx, 0)], WHITE, 2.4)

## A magic wand and sparkles: "make a ready-made layout".
static func _wand(ci: CanvasItem) -> void:
	stroke(ci, [Vector2(4, 20), Vector2(13.5, 10.5)], Color(0.35, 0.28, 0.5), 3.0)
	stroke(ci, [Vector2(12, 12), Vector2(14.2, 9.8)], WHITE, 3.0)
	star(ci, Vector2(16.5, 7.5), 5.2, YELLOW)
	star(ci, Vector2(6.5, 6), 2.6, YELLOW.lightened(0.3))
	star(ci, Vector2(20, 17), 2.4, PINK)

## A rubbish bin: "throw away".
static func _bin(ci: CanvasItem) -> void:
	var col := RED
	poly(ci, PackedVector2Array([Vector2(5.5, 8), Vector2(18.5, 8), Vector2(17, 21.5), Vector2(7, 21.5)]), col)
	rrect(ci, Rect2(3.5, 5, 17, 2.6), 1.0, col.lightened(0.1))
	rrect(ci, Rect2(9.5, 2.5, 5, 3.2), 1.0, col.lightened(0.1))
	for x in [9.5, 12.0, 14.5]:
		stroke(ci, [Vector2(x, 11), Vector2(x, 18.5)], col.darkened(0.35), 1.1)

## Arrow into (save) or out of (load) a box.
static func _tray_arrow(ci: CanvasItem, into: bool) -> void:
	var col := BLUE if into else GREEN
	stroke(ci, [Vector2(3.5, 14), Vector2(3.5, 20.5), Vector2(20.5, 20.5), Vector2(20.5, 14)], WHITE, 2.4)
	if into:
		stroke(ci, [Vector2(12, 2.5), Vector2(12, 11)], col, 3.2)
		head(ci, Vector2(12, 17.5), Vector2(0, 1), 7.0, 5.5, col)
	else:
		stroke(ci, [Vector2(12, 17), Vector2(12, 9)], col, 3.2)
		head(ci, Vector2(12, 2), Vector2(0, -1), 7.0, 5.5, col)

## Circling arrows around a box: "saves by itself".
static func _autosave(ci: CanvasItem) -> void:
	stroke(ci, arc_pts(Vector2(12, 12), 8.5, PI * 1.1, PI * 1.85, 10), GREEN, 2.4)
	head(ci, Vector2(12, 12) + Vector2.from_angle(PI * 1.95) * 8.5, Vector2.from_angle(PI * 2.45), 4.5, 3.6, GREEN)
	stroke(ci, arc_pts(Vector2(12, 12), 8.5, PI * 0.1, PI * 0.85, 10), GREEN, 2.4)
	head(ci, Vector2(12, 12) + Vector2.from_angle(PI * 0.95) * 8.5, Vector2.from_angle(PI * 1.45), 4.5, 3.6, GREEN)
	stroke(ci, [Vector2(8.5, 11.5), Vector2(8.5, 15.5), Vector2(15.5, 15.5), Vector2(15.5, 11.5)], WHITE, 1.6)
	stroke(ci, [Vector2(12, 7.5), Vector2(12, 11)], BLUE, 1.8)
	head(ci, Vector2(12, 14), Vector2(0, 1), 3.0, 2.4, BLUE)

## Rewind: "put the trains back where they started".
static func _rewind(ci: CanvasItem) -> void:
	poly(ci, PackedVector2Array([Vector2(12, 5), Vector2(12, 19), Vector2(3, 12)]), YELLOW)
	poly(ci, PackedVector2Array([Vector2(21, 5), Vector2(21, 19), Vector2(12, 12)]), YELLOW)

static func _arrow(ci: CanvasItem, dir: float) -> void:
	var c := Vector2(12, 12)
	stroke(ci, [c - Vector2(8.5 * dir, 0), c + Vector2(1.5 * dir, 0)], BLUE, 3.6)
	head(ci, c + Vector2(10 * dir, 0), Vector2(dir, 0), 9.0, 7.0, BLUE)

## A U-turn arrow: "turn the train around".
static func _turn(ci: CanvasItem) -> void:
	var pts := [Vector2(5.5, 21)]
	pts.append_array(arc_pts(Vector2(12, 11), 6.5, PI, TAU))
	pts.append(Vector2(18.5, 14))
	stroke(ci, pts, YELLOW, 3.0)
	head(ci, Vector2(18.5, 21.5), Vector2(0, 1), 6.5, 5.0, YELLOW)

## An eye: "watch this train".
static func _eye(ci: CanvasItem) -> void:
	var top := arc_pts(Vector2(12, 21), 13.0, PI * 1.22, PI * 1.78, 12)
	var bottom := arc_pts(Vector2(12, 3), 13.0, PI * 0.22, PI * 0.78, 12)
	var shape := PackedVector2Array(top)
	shape.append_array(PackedVector2Array(bottom))
	poly(ci, shape, WHITE)
	disc(ci, Vector2(12, 12), 4.4, BLUE.darkened(0.1))
	disc(ci, Vector2(12, 12), 2.0, DARK)
	disc(ci, Vector2(13.3, 10.7), 0.9, WHITE)

static func _check(ci: CanvasItem) -> void:
	stroke(ci, [Vector2(4, 12.5), Vector2(9.5, 18), Vector2(20, 6)], GREEN, 3.6)
