extends RefCounted
class_name WagonArt

## Procedural top-down art for every vehicle type -- no image assets.
## Each painter draws one car in its own local frame (the caller has
## already set the canvas transform): x runs along the car towards its
## front, y across it, the car centred on the origin. `seed` makes the
## cargo (coal lumps, logs, which containers) different per car but stable
## frame to frame. Light comes from the top-left, matching the shadows
## TrainsView and Ground cast.

const BRASS := Color(0.8, 0.64, 0.3)
const STEEL_DARK := Color(0.13, 0.13, 0.15)
const WINDOW := Color(0.14, 0.2, 0.28)

var _rr_cache := {}

# --- Shape helpers ---------------------------------------------------------

## A rounded rectangle `w` x `h` centred on (x, y), with an optional
## anti-aliased outline.
func rr(ci: CanvasItem, x: float, y: float, w: float, h: float, r: float, col: Color, outline: Color = Color(0, 0, 0, 0)) -> void:
	r = minf(r, minf(w, h) * 0.5 - 0.15)
	if r < 0.6:
		ci.draw_rect(Rect2(x - w * 0.5, y - h * 0.5, w, h), col)
		if outline.a > 0.0:
			ci.draw_rect(Rect2(x - w * 0.5, y - h * 0.5, w, h), outline, false, 1.0)
		return
	var poly := Transform2D(0.0, Vector2(x, y)) * rr_poly(w, h, r)
	ci.draw_colored_polygon(poly, col)
	if outline.a > 0.0:
		var loop := poly.duplicate()
		loop.append(poly[0])
		ci.draw_polyline(loop, outline, 1.0, true)

func rr_poly(w: float, h: float, r: float) -> PackedVector2Array:
	var key := Vector3(snappedf(w, 0.1), snappedf(h, 0.1), snappedf(r, 0.1))
	if _rr_cache.has(key):
		return _rr_cache[key]
	var hw := w * 0.5
	var hh := h * 0.5
	var centers := [Vector2(hw - r, hh - r), Vector2(-hw + r, hh - r), Vector2(-hw + r, -hh + r), Vector2(hw - r, -hh + r)]
	var pts := PackedVector2Array()
	const STEPS := 4
	for c in range(4):
		for k in range(STEPS + 1):
			var a := c * PI * 0.5 + k * (PI * 0.5) / STEPS
			pts.append(centers[c] + Vector2(cos(a), sin(a)) * r)
	_rr_cache[key] = pts
	return pts

func circle(ci: CanvasItem, p: Vector2, r: float, col: Color, ring: Color = Color(0, 0, 0, 0)) -> void:
	ci.draw_circle(p, r, col)
	ci.draw_arc(p, r, 0.0, TAU, 16, ring if ring.a > 0.0 else col, 0.8, true)

## Shadow footprint every car shares (the plain body outline).
func shadow(ci: CanvasItem, length: float, width: float, col: Color) -> void:
	rr(ci, 0.0, 0.0, length + 1.0, width + 1.0, 3.5, col)

func _lumps(ci: CanvasItem, rng: RandomNumberGenerator, w: float, h: float, base: float, spread: float, count: int, rmin: float, rmax: float) -> void:
	for _i in range(count):
		var p := Vector2(rng.randf_range(-w * 0.5, w * 0.5), rng.randf_range(-h * 0.5, h * 0.5))
		var v := base + rng.randf() * spread
		var r := rng.randf_range(rmin, rmax)
		ci.draw_circle(p, r, Color(v, v, v * 1.05))
		ci.draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.4, Color(v + 0.12, v + 0.12, v + 0.14))

# --- Locomotives -----------------------------------------------------------

func diesel(ci: CanvasItem, l: float, w: float, col: Color, _seed: int) -> void:
	var hl := l * 0.5
	var hw := w * 0.5
	var edge := col.darkened(0.55)
	# Walkway frame, then long hood, cab and short nose on top.
	rr(ci, 0.0, 0.0, l, w, 3.0, Color(0.2, 0.2, 0.22), edge)
	var hood_len := l - 24.0
	rr(ci, -hl + 2.0 + hood_len * 0.5, 0.0, hood_len, w - 6.0, 2.5, col, edge)
	ci.draw_line(Vector2(-hl + 3.0, -hw + 4.2), Vector2(-hl + 1.0 + hood_len, -hw + 4.2), col.lightened(0.3), 1.2, true)
	for k in range(1, 5):
		var x := -hl + 2.0 + hood_len * k / 5.0
		ci.draw_line(Vector2(x, -hw + 3.6), Vector2(x, hw - 3.6), col.darkened(0.25), 0.8)
	for fx in [-hl + 9.0, -hl + 19.0]:
		circle(ci, Vector2(fx, 0.0), 3.6, Color(0.1, 0.1, 0.12), col.darkened(0.4))
		ci.draw_line(Vector2(fx - 3.0, 0.0), Vector2(fx + 3.0, 0.0), Color(0.3, 0.3, 0.32), 0.7)
		ci.draw_line(Vector2(fx, -3.0), Vector2(fx, 3.0), Color(0.3, 0.3, 0.32), 0.7)
	rr(ci, -4.0, 0.0, 5.0, 3.2, 1.0, Color(0.07, 0.07, 0.08))
	var cab_x := hl - 10.5
	rr(ci, cab_x, 0.0, 12.0, w - 1.5, 2.5, col.lightened(0.12), edge)
	ci.draw_line(Vector2(cab_x - 5.0, -hw + 2.2), Vector2(cab_x + 5.0, -hw + 2.2), col.lightened(0.45), 1.0, true)
	rr(ci, cab_x + 4.3, 0.0, 2.0, w - 5.0, 0.8, WINDOW)
	circle(ci, Vector2(cab_x - 2.0, 0.0), 1.3, Color(0.95, 0.35, 0.2))
	rr(ci, hl - 2.2, 0.0, 4.0, w - 6.0, 1.5, col, edge)
	# Safety stripes on both ends, headlights at the front.
	rr(ci, hl - 0.8, 0.0, 1.6, w - 2.0, 0.6, Color(0.98, 0.8, 0.15))
	rr(ci, -hl + 0.8, 0.0, 1.6, w - 2.0, 0.6, Color(0.98, 0.8, 0.15))
	circle(ci, Vector2(hl - 0.6, -hw + 3.0), 1.1, Color(1.0, 0.98, 0.85))
	circle(ci, Vector2(hl - 0.6, hw - 3.0), 1.1, Color(1.0, 0.98, 0.85))

func steam(ci: CanvasItem, l: float, w: float, col: Color, _seed: int) -> void:
	var hl := l * 0.5
	var hw := w * 0.5
	rr(ci, 0.0, 0.0, l, w, 2.5, Color(0.15, 0.15, 0.17), Color(0.05, 0.05, 0.05))
	rr(ci, hl - 1.2, 0.0, 2.4, w, 0.8, Color(0.75, 0.14, 0.1))
	# Boiler: a dark cylinder with a highlight and brass bands.
	var bx0 := -hl + 15.0
	var bx1 := hl - 3.0
	var bw := w - 5.0
	rr(ci, (bx0 + bx1) * 0.5, 0.0, bx1 - bx0, bw, bw * 0.45, Color(0.1, 0.1, 0.11), Color(0.03, 0.03, 0.03))
	ci.draw_line(Vector2(bx0 + 2.0, -bw * 0.22), Vector2(bx1 - 3.0, -bw * 0.22), Color(0.34, 0.36, 0.4), 1.8, true)
	ci.draw_line(Vector2(bx0 + 2.0, -bw * 0.3), Vector2(bx1 - 3.0, -bw * 0.3), Color(0.55, 0.57, 0.6, 0.6), 0.6, true)
	for x in [bx0 + 5.0, bx0 + (bx1 - bx0) * 0.42, bx1 - 11.0]:
		ci.draw_line(Vector2(x, -bw * 0.48), Vector2(x, bw * 0.48), BRASS, 1.0)
	rr(ci, bx1 - 4.0, 0.0, 7.0, bw, 3.0, Color(0.06, 0.06, 0.07))
	circle(ci, Vector2(bx1 - 5.5, 0.0), 3.2, Color(0.04, 0.04, 0.04), Color(0.22, 0.22, 0.24))
	ci.draw_circle(Vector2(bx1 - 5.5, 0.0), 1.8, Color(0.0, 0.0, 0.0))
	circle(ci, Vector2(bx0 + (bx1 - bx0) * 0.55, 0.0), 2.7, BRASS, BRASS.darkened(0.3))
	ci.draw_circle(Vector2(bx0 + (bx1 - bx0) * 0.55 - 0.8, -0.8), 0.9, Color(1.0, 0.9, 0.6))
	circle(ci, Vector2(bx0 + (bx1 - bx0) * 0.25, 0.0), 2.1, Color(0.18, 0.18, 0.2))
	# Cab with a livery roof.
	rr(ci, -hl + 7.5, 0.0, 14.0, w - 0.5, 2.0, col, col.darkened(0.55))
	ci.draw_line(Vector2(-hl + 7.5, -hw + 2.0), Vector2(-hl + 7.5, hw - 2.0), col.lightened(0.35), 1.2, true)
	rr(ci, -hl + 13.5, 0.0, 1.6, w - 4.0, 0.5, col.darkened(0.4))
	circle(ci, Vector2(hl - 0.5, 0.0), 1.2, Color(1.0, 0.95, 0.75))

func tender(ci: CanvasItem, l: float, w: float, col: Color, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	rr(ci, 0.0, 0.0, l, w, 2.5, col, col.darkened(0.55))
	rr(ci, 3.0, 0.0, l - 12.0, w - 4.0, 1.5, Color(0.06, 0.06, 0.07))
	_lumps(ci, rng, l - 15.0, w - 7.0, 0.06, 0.14, 26, 1.0, 2.0)
	rr(ci, -l * 0.5 + 4.0, 0.0, 6.0, w - 3.0, 1.5, col.lightened(0.1))
	circle(ci, Vector2(-l * 0.5 + 4.0, 0.0), 1.6, col.darkened(0.4))

# --- Passenger -------------------------------------------------------------

func coach(ci: CanvasItem, l: float, w: float, col: Color, _seed: int) -> void:
	var hl := l * 0.5
	var hw := w * 0.5
	var roof := col.lerp(Color(0.55, 0.56, 0.58), 0.35)
	rr(ci, 0.0, 0.0, l, w, 3.0, col.darkened(0.3), col.darkened(0.6))
	rr(ci, 0.0, 0.0, l - 3.0, w - 3.0, 3.0, roof)
	rr(ci, 0.0, 0.0, l - 8.0, w - 10.0, 2.0, roof.lightened(0.15))
	ci.draw_line(Vector2(-hl + 4.0, -hw + 2.2), Vector2(hl - 4.0, -hw + 2.2), roof.lightened(0.35), 0.8, true)
	var n := int((l - 14.0) / 9.0)
	for k in range(n):
		var x := -hl + 9.0 + k * (l - 18.0) / maxf(n - 1, 1)
		circle(ci, Vector2(x, 0.0), 1.1, roof.darkened(0.35))
	# Gangway bellows at both ends.
	rr(ci, hl - 0.5, 0.0, 2.2, w - 8.0, 0.6, Color(0.1, 0.1, 0.1))
	rr(ci, -hl + 0.5, 0.0, 2.2, w - 8.0, 0.6, Color(0.1, 0.1, 0.1))

func caboose(ci: CanvasItem, l: float, w: float, col: Color, _seed: int) -> void:
	var hl := l * 0.5
	rr(ci, 0.0, 0.0, l, w, 2.0, Color(0.18, 0.17, 0.17), Color(0.05, 0.05, 0.05))
	rr(ci, 0.0, 0.0, l - 8.0, w, 2.0, col, col.darkened(0.55))
	rr(ci, 0.0, 0.0, 11.0, w - 5.0, 1.5, col.lightened(0.2), col.darkened(0.4))
	rr(ci, 0.0, 0.0, 11.0, 1.4, 0.4, WINDOW)
	circle(ci, Vector2(-l * 0.22, 3.0), 1.4, Color(0.1, 0.1, 0.1))
	for sx in [-hl + 1.5, hl - 1.5]:
		ci.draw_line(Vector2(sx, -w * 0.45), Vector2(sx, w * 0.45), Color(0.85, 0.8, 0.3), 0.8)
	circle(ci, Vector2(-hl + 1.0, -w * 0.35), 0.9, Color(1.0, 0.2, 0.15))
	circle(ci, Vector2(-hl + 1.0, w * 0.35), 0.9, Color(1.0, 0.2, 0.15))

# --- Freight ---------------------------------------------------------------

func boxcar(ci: CanvasItem, l: float, w: float, col: Color, _seed: int) -> void:
	var hl := l * 0.5
	var hw := w * 0.5
	rr(ci, 0.0, 0.0, l, w, 1.8, col, col.darkened(0.55))
	for k in range(1, int(l / 4.5)):
		var x := -hl + k * 4.5
		ci.draw_line(Vector2(x, -hw + 1.2), Vector2(x, hw - 1.2), col.darkened(0.18), 0.7)
	ci.draw_line(Vector2(-hl + 1.5, -hw + 1.6), Vector2(hl - 1.5, -hw + 1.6), col.lightened(0.28), 0.9, true)
	rr(ci, 0.0, 0.0, l - 3.0, 2.6, 0.5, Color(0.28, 0.25, 0.22))
	rr(ci, hl - 1.2, 0.0, 1.6, w - 4.0, 0.4, col.darkened(0.35))
	rr(ci, -hl + 1.2, 0.0, 1.6, w - 4.0, 0.4, col.darkened(0.35))

func tanker(ci: CanvasItem, l: float, w: float, col: Color, _seed: int) -> void:
	rr(ci, 0.0, 0.0, l, w - 3.0, 1.5, STEEL_DARK)
	var tl := l - 5.0
	rr(ci, 0.0, 0.0, tl, w, w * 0.5, col, col.darkened(0.55))
	ci.draw_line(Vector2(-tl * 0.44, w * 0.26), Vector2(tl * 0.44, w * 0.26), col.darkened(0.25), 2.2, true)
	ci.draw_line(Vector2(-tl * 0.44, -w * 0.2), Vector2(tl * 0.44, -w * 0.2), col.lightened(0.3), 2.0, true)
	ci.draw_line(Vector2(-tl * 0.4, -w * 0.28), Vector2(tl * 0.4, -w * 0.28), col.lightened(0.6), 0.7, true)
	rr(ci, 0.0, 0.0, 10.0, w - 3.0, 1.0, Color(0.26, 0.26, 0.28))
	circle(ci, Vector2.ZERO, 3.4, col.darkened(0.1), col.darkened(0.5))
	ci.draw_circle(Vector2(-0.9, -0.9), 1.2, col.lightened(0.4))

func hopper(ci: CanvasItem, l: float, w: float, col: Color, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	rr(ci, 0.0, 0.0, l, w, 1.8, col, col.darkened(0.55))
	rr(ci, 0.0, 0.0, l - 5.0, w - 5.0, 1.2, Color(0.05, 0.05, 0.06))
	var count := int((l - 5.0) * (w - 5.0) / 7.0)
	_lumps(ci, rng, l - 7.0, w - 7.0, 0.07, 0.16, count, 1.0, 2.1)
	for x in [-l * 0.18, l * 0.18]:
		ci.draw_line(Vector2(x, -w * 0.5 + 1.5), Vector2(x, w * 0.5 - 1.5), col.darkened(0.2), 1.2)
	ci.draw_line(Vector2(-l * 0.5 + 1.0, -w * 0.5 + 1.0), Vector2(l * 0.5 - 1.0, -w * 0.5 + 1.0), col.lightened(0.3), 0.8, true)

func logs(ci: CanvasItem, l: float, w: float, _col: Color, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var hl := l * 0.5
	rr(ci, 0.0, 0.0, l, w - 2.0, 1.2, Color(0.34, 0.24, 0.15), Color(0.12, 0.08, 0.05))
	for k in range(1, int(l / 3.0)):
		var x := -hl + k * 3.0
		ci.draw_line(Vector2(x, -w * 0.5 + 1.5), Vector2(x, w * 0.5 - 1.5), Color(0.27, 0.19, 0.12), 0.6)
	for y in [-5.6, 0.0, 5.6]:
		var ll := l - rng.randf_range(4.0, 10.0)
		var off := rng.randf_range(-2.0, 2.0)
		var bark := Color(0.4, 0.27, 0.16).darkened(rng.randf_range(0.0, 0.25))
		rr(ci, off, y, ll, 5.0, 2.4, bark, bark.darkened(0.45))
		ci.draw_line(Vector2(off - ll * 0.45, y - 1.1), Vector2(off + ll * 0.45, y - 1.1), bark.lightened(0.25), 0.8, true)
		for ex in [off - ll * 0.5 + 0.8, off + ll * 0.5 - 0.8]:
			circle(ci, Vector2(ex, y), 2.3, Color(0.84, 0.68, 0.46), Color(0.55, 0.4, 0.25))
			ci.draw_arc(Vector2(ex, y), 1.2, 0.0, TAU, 10, Color(0.62, 0.46, 0.28), 0.5, true)
	for x in [-l * 0.3, l * 0.05, l * 0.34]:
		ci.draw_line(Vector2(x, -w * 0.5 + 0.5), Vector2(x, w * 0.5 - 0.5), Color(0.2, 0.2, 0.22), 0.8)
	for x in [-hl + 3.0, -hl * 0.35, hl * 0.35, hl - 3.0]:
		for y in [-w * 0.5 + 0.8, w * 0.5 - 0.8]:
			ci.draw_rect(Rect2(x - 0.9, y - 0.9, 1.8, 1.8), Color(0.12, 0.12, 0.13))

func container(ci: CanvasItem, l: float, w: float, col: Color, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	rr(ci, 0.0, 0.0, l, w - 4.0, 1.0, Color(0.22, 0.22, 0.24), Color(0.08, 0.08, 0.09))
	var boxes := []
	if rng.randf() < 0.5:
		boxes.append([0.0, l - 4.0])
	else:
		var bl := (l - 6.0) * 0.5
		boxes.append([-bl * 0.5 - 1.0, bl])
		boxes.append([bl * 0.5 + 1.0, bl])
	var palette: Array = WagonCatalog.entry("container")["colors"]
	for i in range(boxes.size()):
		var c: Color = col if i == 0 else palette[rng.randi() % palette.size()]
		var bx: float = boxes[i][0]
		var bl: float = boxes[i][1]
		rr(ci, bx, 0.0, bl, w - 1.0, 0.8, c, c.darkened(0.5))
		var n := int(bl / 2.6)
		for k in range(1, n):
			var x := bx - bl * 0.5 + k * bl / n
			ci.draw_line(Vector2(x, -w * 0.5 + 1.2), Vector2(x, w * 0.5 - 1.2), c.darkened(0.16), 0.6)
		ci.draw_line(Vector2(bx - bl * 0.5 + 1.0, -w * 0.5 + 1.3), Vector2(bx + bl * 0.5 - 1.0, -w * 0.5 + 1.3), c.lightened(0.3), 0.8, true)
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var p := Vector2(bx + corner.x * (bl * 0.5 - 1.0), corner.y * (w * 0.5 - 1.5))
			ci.draw_rect(Rect2(p - Vector2(0.8, 0.8), Vector2(1.6, 1.6)), c.darkened(0.5))
