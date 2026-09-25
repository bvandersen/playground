extends RefCounted
class_name BuildingArt

## Procedural top-down art for everything the Build palette puts down --
## houses, flats, shops, the supermarket, the factory and warehouse, a
## farm, trees, woods, ponds and flower meadows. No image assets.
##
## Each painter draws one thing in its own frame: x across its frontage,
## y from back (-) to front (+), the street side being +y, centred on the
## origin, `w` x `d` px. `xf` is the frame's transform (painters that draw
## something in a frame of its own, like a parked car, compose with it).
## `sun` is the world's shadow offset turned into this frame, so shadows
## fall the same way as the trains' however the building is turned, and
## `lit(n)` says how brightly a roof slope facing `n` catches the light.

const GRASS := Color(0.43, 0.56, 0.29)
const HEDGE := Color(0.2, 0.35, 0.15)
const PAVING := Color(0.7, 0.68, 0.63)
const CONCRETE := Color(0.62, 0.61, 0.58)
const ASPHALT := Color(0.33, 0.34, 0.36)
const GLASS := Color(0.5, 0.65, 0.75)
const SHADOW := Color(0, 0, 0, 0.26)

var sun := Vector2(3.5, 4.5)
var _w := WagonArt.new()

func begin(ci, xf: Transform2D, sun_world: Vector2) -> void:
	sun = xf.basis_xform_inv(sun_world)
	ci.draw_set_transform_matrix(xf)

## 0.8..1.15: how bright a surface facing `n` (unit, in this frame) is.
func lit(n: Vector2) -> float:
	return 0.97 + 0.2 * n.dot(-sun.normalized())

## `col` as lit on a surface facing `n` (alpha kept).
func shade(col: Color, n: Vector2) -> Color:
	var f := lit(n)
	return Color(col.r * f, col.g * f, col.b * f, col.a)

func rect(ci, x: float, y: float, w: float, h: float, col: Color) -> void:
	ci.draw_rect(Rect2(x - w * 0.5, y - h * 0.5, w, h), col)

func rr(ci, x: float, y: float, w: float, h: float, r: float, col: Color, outline: Color = Color(0, 0, 0, 0)) -> void:
	_w.rr(ci, x, y, w, h, r, col, outline)

func poly(ci, pts: Array, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), col)

## A block's shadow: its footprint pushed away from the sun, `height`
## scaling how far.
func block_shadow(ci, x: float, y: float, w: float, h: float, height: float) -> void:
	rect(ci, x + sun.x * height * 0.5, y + sun.y * height * 0.5, w + absf(sun.x) * height, h + absf(sun.y) * height, SHADOW)

## A pitched roof over the `w` x `h` rectangle at (x, y): "gable" (ridge
## along x), "side" (ridge along y) or "hip" (sloping on all four sides).
func roof(ci, x: float, y: float, w: float, h: float, col: Color, style: String) -> void:
	var x0 := x - w * 0.5
	var x1 := x + w * 0.5
	var y0 := y - h * 0.5
	var y1 := y + h * 0.5
	var edge := col.darkened(0.45)
	rect(ci, x, y, w + 1.6, h + 1.6, edge)
	match style:
		"gable":
			rect(ci, x, (y0 + y) * 0.5, w, h * 0.5, shade(col, Vector2.UP))
			rect(ci, x, (y + y1) * 0.5, w, h * 0.5, shade(col, Vector2.DOWN))
			for k in range(1, int(h / 3.2)):
				var yy := y0 + k * 3.2
				ci.draw_line(Vector2(x0, yy), Vector2(x1, yy), Color(0, 0, 0, 0.09), 0.5)
			ci.draw_line(Vector2(x0, y), Vector2(x1, y), edge, 1.4)
		"side":
			rect(ci, (x0 + x) * 0.5, y, w * 0.5, h, shade(col, Vector2.LEFT))
			rect(ci, (x + x1) * 0.5, y, w * 0.5, h, shade(col, Vector2.RIGHT))
			for k in range(1, int(w / 3.2)):
				var xx := x0 + k * 3.2
				ci.draw_line(Vector2(xx, y0), Vector2(xx, y1), Color(0, 0, 0, 0.09), 0.5)
			ci.draw_line(Vector2(x, y0), Vector2(x, y1), edge, 1.4)
		_:
			var r := minf(w, h) * 0.5
			var a := Vector2(x0 + r, y) if w >= h else Vector2(x, y0 + r)
			var b := Vector2(x1 - r, y) if w >= h else Vector2(x, y1 - r)
			poly(ci, [Vector2(x0, y0), Vector2(x1, y0), b, a], shade(col, Vector2.UP))
			poly(ci, [Vector2(x0, y1), Vector2(x1, y1), b, a], shade(col, Vector2.DOWN))
			poly(ci, [Vector2(x0, y0), a, Vector2(x0, y1)], shade(col, Vector2.LEFT))
			poly(ci, [Vector2(x1, y0), b, Vector2(x1, y1)], shade(col, Vector2.RIGHT))
			for p in [Vector2(x0, y0), Vector2(x1, y0), Vector2(x0, y1), Vector2(x1, y1)]:
				ci.draw_line(p, a if p.x == x0 else b, edge, 0.8, true)
			ci.draw_line(a, b, edge, 1.4)

func flat_roof(ci, x: float, y: float, w: float, h: float, col: Color) -> void:
	rect(ci, x, y, w, h, col.darkened(0.3))
	rect(ci, x, y, w - 2.4, h - 2.4, col)
	ci.draw_line(Vector2(x - w * 0.5 + 1.2, y - h * 0.5 + 1.6), Vector2(x + w * 0.5 - 1.2, y - h * 0.5 + 1.6), col.darkened(0.12), 0.8)

## A tree crown seen from above, with its shadow: "round", "pine",
## "blossom" or "autumn".
func tree(ci, p: Vector2, r: float, kind: String, sh: float) -> void:
	ci.draw_circle(p + sun * (r / 14.0), r * 1.02, Color(0, 0, 0, 0.24))
	match kind:
		"pine":
			var base := Color(0.1, 0.25, 0.16).lerp(Color(0.14, 0.3, 0.18), sh)
			for layer in range(3):
				var rr_ := r * (1.0 - layer * 0.28)
				var pts := []
				for i in range(16):
					var rad := rr_ if i % 2 == 0 else rr_ * 0.72
					pts.append(p + Vector2.from_angle(i * TAU / 16.0 + layer * 0.2) * rad)
				poly(ci, pts, base.lightened(layer * 0.1))
			ci.draw_circle(p, r * 0.12, Color(0.35, 0.25, 0.15))
		_:
			var base := Color(0.16, 0.33, 0.14).lerp(Color(0.25, 0.4, 0.15), sh)
			if kind == "blossom":
				base = Color(0.93, 0.62, 0.72).lerp(Color(0.98, 0.78, 0.84), sh)
			elif kind == "autumn":
				base = Color(0.85, 0.45, 0.12).lerp(Color(0.8, 0.62, 0.15), sh)
			ci.draw_circle(p, r, base.darkened(0.12))
			ci.draw_circle(p + Vector2(-r * 0.12, -r * 0.12), r * 0.86, base)
			for k in range(5):
				var q := p + Vector2.from_angle(k * 1.3 + sh * 5.0) * r * 0.45
				ci.draw_circle(q, r * 0.38, base.lightened(0.06 + 0.04 * (k % 2)))
			ci.draw_circle(p + Vector2(-r * 0.35, -r * 0.38), r * 0.3, base.lightened(0.2))
			ci.draw_arc(p, r, 0.0, TAU, 28, base.darkened(0.3), 0.9, true)

## A car parked at `at` (in this frame), facing `angle`.
func parked(ci, xf: Transform2D, at: Vector2, angle: float, rng: RandomNumberGenerator) -> void:
	var pool := VehicleCatalog.types_of("car")
	var look := {"type": pool[rng.randi() % pool.size()], "color": VehicleCatalog.CAR_COLORS[rng.randi() % VehicleCatalog.CAR_COLORS.size()], "seed": rng.randi() % 1000}
	var e := VehicleCatalog.entry(look["type"])
	ci.draw_set_transform_matrix(xf * Transform2D(angle, at + sun * 0.5))
	VehicleCatalog.art.rr(ci, 0.0, 0.0, float(e["length"]) + 1.0, float(e["width"]), 3.0, Color(0, 0, 0, 0.25))
	ci.draw_set_transform_matrix(xf * Transform2D(angle, at))
	VehicleCatalog.paint(ci, look)
	ci.draw_set_transform_matrix(xf)

# --- Homes -------------------------------------------------------------------

const ROOFS := [Color(0.72, 0.33, 0.22), Color(0.38, 0.4, 0.45), Color(0.5, 0.3, 0.2), Color(0.6, 0.2, 0.16), Color(0.32, 0.44, 0.34)]

func house(ci, xf: Transform2D, w: float, d: float, col: Color, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# Garden with a hedge, a path to the front door.
	rect(ci, 0.0, 0.0, w, d, HEDGE)
	rect(ci, 0.0, 0.0, w - 3.0, d - 3.0, GRASS.lightened(rng.randf_range(0.0, 0.08)))
	var bw := w - rng.randf_range(10.0, 14.0)
	var bd := d * rng.randf_range(0.5, 0.58)
	var by := -d * 0.5 + 4.0 + bd * 0.5
	var bx := rng.randf_range(-2.5, 2.5)
	rect(ci, bx, (by + bd * 0.5 + d * 0.5) * 0.5, 4.0, d * 0.5 - (by + bd * 0.5) + 0.5, PAVING)
	if rng.randf() < 0.55:
		# Driveway, maybe with the family car on it.
		var dx := w * 0.5 - 6.5 if bx < 0.0 else -w * 0.5 + 6.5
		rect(ci, dx, d * 0.5 - 9.0, 10.0, 18.0, CONCRETE)
		if rng.randf() < 0.7:
			parked(ci, xf, Vector2(dx, d * 0.5 - 12.0), PI * 0.5, rng)
	if rng.randf() < 0.6:
		tree(ci, Vector2(-bx - w * 0.3, -d * 0.32), rng.randf_range(5.0, 7.0), "round", rng.randf())
	else:
		for k in range(6):
			ci.draw_circle(Vector2(rng.randf_range(-w * 0.4, w * 0.4), rng.randf_range(d * 0.15, d * 0.4)), 1.0,
				[Color(1, 0.4, 0.5), Color(1, 0.9, 0.3), Color(0.95, 0.95, 1), Color(0.7, 0.5, 1.0)][k % 4])
	block_shadow(ci, bx, by, bw, bd, 2.6)
	var style: String = ["gable", "hip", "side"][rng.randi() % 3]
	roof(ci, bx, by, bw, bd, col, style)
	# Chimney and a little porch roof over the door.
	var cx := bx + bw * rng.randf_range(-0.3, 0.3)
	rect(ci, cx + sun.x * 0.4, by - bd * 0.2 + sun.y * 0.4, 3.4, 3.4, SHADOW)
	rect(ci, cx, by - bd * 0.2, 3.2, 3.2, Color(0.55, 0.3, 0.22))
	rect(ci, cx, by - bd * 0.2, 2.0, 2.0, Color(0.15, 0.13, 0.12))
	rect(ci, bx, by + bd * 0.5 + 1.6, 7.0, 3.2, col.darkened(0.2))
	if rng.randf() < 0.4:
		# Solar panels on the sunny slope.
		for k in range(3):
			rect(ci, bx - bw * 0.2 + k * 4.0, by - bd * 0.22, 3.4, 4.4, Color(0.14, 0.2, 0.36))

func flats(ci, _xf: Transform2D, w: float, d: float, col: Color, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	rect(ci, 0.0, 0.0, w, d, PAVING.darkened(0.05))
	rect(ci, 0.0, d * 0.5 - 3.0, w, 6.0, GRASS)
	var bw := w - 6.0
	var bd := d - 12.0
	var by := -3.0
	block_shadow(ci, 0.0, by, bw, bd, 5.5)
	# Balconies along the front, painted in the building's colour.
	for k in range(5):
		var x := -bw * 0.5 + bw * (k + 0.5) / 5.0
		rect(ci, x, by + bd * 0.5 + 1.8, 7.0, 3.6, col.darkened(0.35))
		rect(ci, x, by + bd * 0.5 + 1.6, 6.0, 2.6, col)
	flat_roof(ci, 0.0, by, bw, bd, Color(0.66, 0.65, 0.62))
	# Stairwell, lift housing, air-con units and a hatch on the roof.
	rect(ci, -bw * 0.18 + sun.x * 0.5, by + sun.y * 0.5, 9.0, 8.0, SHADOW)
	rect(ci, -bw * 0.18, by, 9.0, 8.0, Color(0.56, 0.55, 0.52))
	for k in range(rng.randi_range(2, 4)):
		var p := Vector2(rng.randf_range(0.0, bw * 0.4), rng.randf_range(-bd * 0.3, bd * 0.3))
		rect(ci, p.x, p.y, 5.0, 4.0, Color(0.8, 0.8, 0.8))
		ci.draw_circle(p, 1.5, Color(0.35, 0.35, 0.37))
	rect(ci, -bw * 0.38, -bd * 0.2 + by, 3.0, 3.0, Color(0.3, 0.3, 0.32))
	# Door canopy and a bike rack.
	rect(ci, 0.0, by + bd * 0.5 + 2.0, 8.0, 4.0, Color(0.3, 0.3, 0.32))
	for k in range(4):
		ci.draw_line(Vector2(bw * 0.3 + k * 2.2, d * 0.5 - 5.0), Vector2(bw * 0.3 + k * 2.2, d * 0.5 - 1.5), Color(0.2, 0.2, 0.22), 0.6)

# --- Shops -------------------------------------------------------------------

func shop(ci, _xf: Transform2D, w: float, d: float, col: Color, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	rect(ci, 0.0, 0.0, w, d, PAVING)
	var bd := d - 10.0
	var by := -d * 0.5 + bd * 0.5
	block_shadow(ci, 0.0, by, w - 2.0, bd, 3.0)
	flat_roof(ci, 0.0, by, w - 2.0, bd, Color(0.74, 0.7, 0.62))
	rect(ci, -w * 0.2, by - bd * 0.15, 6.0, 4.0, Color(0.82, 0.82, 0.8))
	ci.draw_circle(Vector2(-w * 0.2, by - bd * 0.15), 1.4, Color(0.4, 0.4, 0.42))
	# Striped awning over the shop window, sign above it.
	var y0 := by + bd * 0.5
	var n := int((w - 6.0) / 3.5)
	for k in range(n):
		var x := -w * 0.5 + 3.0 + k * 3.5
		rect(ci, x + 1.75, y0 + 3.0, 3.5, 6.0, col if k % 2 == 0 else Color(0.97, 0.96, 0.92))
	ci.draw_line(Vector2(-w * 0.5 + 3.0, y0 + 6.0), Vector2(-w * 0.5 + 3.0 + n * 3.5, y0 + 6.0), col.darkened(0.35), 0.8)
	rect(ci, 0.0, y0 - 1.2, w * 0.55, 2.4, col.darkened(0.3))
	rect(ci, 0.0, y0 - 1.2, w * 0.5, 1.4, Color(1.0, 0.95, 0.8))
	# Pavement things: planters, a bench, a sandwich board.
	for x in [-w * 0.4, w * 0.4]:
		rr(ci, x, d * 0.5 - 2.5, 5.0, 3.4, 1.0, Color(0.5, 0.33, 0.2))
		ci.draw_circle(Vector2(x, d * 0.5 - 2.5), 1.6, Color(0.3, 0.55, 0.22))
	if rng.randf() < 0.5:
		rect(ci, w * 0.15, d * 0.5 - 2.4, 4.0, 2.2, Color(0.2, 0.2, 0.2))

func market(ci, xf: Transform2D, w: float, d: float, col: Color, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var bd := d * 0.55
	var by := -d * 0.5 + bd * 0.5
	# Car park out front.
	var py0 := by + bd * 0.5
	rect(ci, 0.0, (py0 + d * 0.5) * 0.5, w, d * 0.5 - py0, ASPHALT)
	var bays := int((w - 8.0) / 12.0)
	var row_y := [py0 + 11.0, d * 0.5 - 8.0]
	for k in range(bays + 1):
		var x := -w * 0.5 + 4.0 + k * (w - 8.0) / bays
		ci.draw_line(Vector2(x, py0 + 4.0), Vector2(x, py0 + 18.0), Color(0.9, 0.9, 0.88), 0.7)
		ci.draw_line(Vector2(x, d * 0.5 - 15.0), Vector2(x, d * 0.5 - 1.0), Color(0.9, 0.9, 0.88), 0.7)
	for row in range(2):
		for k in range(bays):
			if rng.randf() < 0.55:
				var x := -w * 0.5 + 4.0 + (k + 0.5) * (w - 8.0) / bays
				parked(ci, xf, Vector2(x, row_y[row]), PI * 0.5 if row == 0 else -PI * 0.5, rng)
	# Trolley shelter and a lamp post or two.
	rect(ci, w * 0.42, py0 + 3.0, 8.0, 3.0, Color(0.55, 0.57, 0.6))
	block_shadow(ci, 0.0, by, w, bd, 4.0)
	flat_roof(ci, 0.0, by, w, bd, Color(0.8, 0.8, 0.78))
	for i in range(3):
		for j in range(2):
			rect(ci, -w * 0.3 + i * w * 0.3, by - bd * 0.2 + j * bd * 0.3, 12.0, 5.0, GLASS)
	# The shop's colours along the front and a big entrance canopy.
	rect(ci, 0.0, by + bd * 0.5 - 2.0, w, 4.0, col)
	rect(ci, 0.0, by + bd * 0.5 - 2.0, w * 0.35, 2.4, Color(1.0, 0.95, 0.75))
	rect(ci, -w * 0.25, by + bd * 0.5 + 2.5, 18.0, 5.0, col.darkened(0.25))

# --- Industry ----------------------------------------------------------------

func factory(ci, _xf: Transform2D, w: float, d: float, col: Color, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	rect(ci, 0.0, 0.0, w, d, CONCRETE)
	for k in range(int(w / 10.0)):
		ci.draw_line(Vector2(-w * 0.5 + k * 10.0, -d * 0.5), Vector2(-w * 0.5 + k * 10.0, d * 0.5), Color(0, 0, 0, 0.05), 0.5)
	# The works hall with a saw-tooth roof: glazed north lights between
	# the metal slopes.
	var hw_ := w * 0.66
	var hd := d * 0.7
	var hx := -w * 0.5 + hw_ * 0.5 + 2.0
	var hy := -d * 0.5 + hd * 0.5 + 2.0
	block_shadow(ci, hx, hy, hw_, hd, 4.0)
	rect(ci, hx, hy, hw_ + 1.6, hd + 1.6, col.darkened(0.5))
	var teeth := int(hd / 9.0)
	for k in range(teeth):
		var y := hy - hd * 0.5 + k * hd / teeth
		var t := hd / teeth
		rect(ci, hx, y + t * 0.35, hw_, t * 0.7, shade(col, Vector2.DOWN))
		rect(ci, hx, y + t * 0.85, hw_, t * 0.3, GLASS.darkened(0.15))
	# Office block, silo tanks, the tall chimney.
	var ox := w * 0.5 - (w - hw_) * 0.5 + 1.0
	block_shadow(ci, ox, d * 0.08, w - hw_ - 8.0, d * 0.4, 3.0)
	flat_roof(ci, ox, d * 0.08, w - hw_ - 8.0, d * 0.4, Color(0.7, 0.66, 0.6))
	for k in range(2):
		var p := Vector2(ox - 6.0 + k * 12.0, -d * 0.3)
		ci.draw_circle(p + sun * 0.8, 5.5, SHADOW)
		ci.draw_circle(p, 5.5, Color(0.75, 0.76, 0.78))
		ci.draw_circle(p + Vector2(-1.4, -1.4), 3.0, Color(0.88, 0.89, 0.9))
		ci.draw_arc(p, 5.5, 0.0, TAU, 20, Color(0.45, 0.45, 0.47), 0.7, true)
	var ch := chimney_at(w, d)
	for k in range(6):
		ci.draw_circle(ch + sun * (0.8 + k * 0.7), 3.6, Color(0, 0, 0, 0.08))
	ci.draw_circle(ch, 4.4, Color(0.6, 0.28, 0.2))
	ci.draw_circle(ch, 3.3, Color(0.7, 0.34, 0.24))
	ci.draw_circle(ch, 2.2, Color(0.1, 0.09, 0.09))
	# Pipes, crates and oil drums in the yard.
	ci.draw_line(Vector2(hx + hw_ * 0.5, -d * 0.3), Vector2(ox - 6.0, -d * 0.3), Color(0.5, 0.5, 0.52), 1.6)
	for k in range(rng.randi_range(3, 6)):
		var p := Vector2(rng.randf_range(-w * 0.45, w * 0.1), rng.randf_range(d * 0.3, d * 0.45))
		if rng.randf() < 0.5:
			rect(ci, p.x, p.y, 5.0, 5.0, Color(0.62, 0.45, 0.25))
			ci.draw_line(p - Vector2(2.5, 0), p + Vector2(2.5, 0), Color(0.45, 0.3, 0.15), 0.5)
		else:
			ci.draw_circle(p, 2.0, [Color(0.2, 0.4, 0.7), Color(0.75, 0.2, 0.15), Color(0.9, 0.7, 0.15)][k % 3])
			ci.draw_circle(p, 0.8, Color(0, 0, 0, 0.3))

## Where the factory's chimney stands in its own frame (smoke comes out
## here -- see Building.chimney).
static func chimney_at(w: float, d: float) -> Vector2:
	return Vector2(w * 0.5 - 9.0, -d * 0.5 + 9.0)

func warehouse(ci, _xf: Transform2D, w: float, d: float, col: Color, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	rect(ci, 0.0, 0.0, w, d, CONCRETE.darkened(0.05))
	var bd := d - 14.0
	var by := -d * 0.5 + bd * 0.5
	block_shadow(ci, 0.0, by, w, bd, 4.5)
	# Shallow metal roof: two slopes, ribbed, with roof lights.
	rect(ci, 0.0, by, w + 1.6, bd + 1.6, col.darkened(0.5))
	rect(ci, 0.0, by - bd * 0.25, w, bd * 0.5, shade(col, Vector2.UP))
	rect(ci, 0.0, by + bd * 0.25, w, bd * 0.5, shade(col, Vector2.DOWN))
	for k in range(1, int(w / 3.0)):
		ci.draw_line(Vector2(-w * 0.5 + k * 3.0, by - bd * 0.5), Vector2(-w * 0.5 + k * 3.0, by + bd * 0.5), Color(0, 0, 0, 0.1), 0.5)
	ci.draw_line(Vector2(-w * 0.5, by), Vector2(w * 0.5, by), col.darkened(0.4), 1.2)
	for k in range(4):
		rect(ci, -w * 0.36 + k * w * 0.24, by - bd * 0.25, 6.0, bd * 0.3, Color(0.78, 0.85, 0.88, 0.8))
	# Loading doors with yellow bumpers, and pallets stacked outside.
	for k in range(4):
		var x := -w * 0.35 + k * w * 0.18
		rect(ci, x, by + bd * 0.5 + 1.0, 10.0, 2.4, Color(0.22, 0.22, 0.24))
		rect(ci, x - 5.5, by + bd * 0.5 + 2.2, 1.4, 2.0, Color(1.0, 0.8, 0.15))
		rect(ci, x + 5.5, by + bd * 0.5 + 2.2, 1.4, 2.0, Color(1.0, 0.8, 0.15))
	for k in range(rng.randi_range(2, 4)):
		var p := Vector2(w * 0.3 + rng.randf_range(-6.0, 12.0), d * 0.5 - 5.0 + rng.randf_range(-2.0, 1.0))
		rect(ci, p.x, p.y, 6.0, 5.0, Color(0.72, 0.56, 0.34))
		rect(ci, p.x, p.y, 5.0, 4.0, [Color(0.3, 0.45, 0.7), Color(0.82, 0.8, 0.72), Color(0.4, 0.6, 0.3)][k % 3])

# --- Countryside -------------------------------------------------------------

func farm(ci, _xf: Transform2D, w: float, d: float, col: Color, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# Hedged field of crops in rows.
	rect(ci, 0.0, 0.0, w, d, HEDGE)
	var crop := rng.randi() % 3
	var soil := Color(0.45, 0.33, 0.2)
	rect(ci, 0.0, 0.0, w - 5.0, d - 5.0, soil)
	var fx0 := -w * 0.5 + 3.0
	var fx1 := w * 0.5 - 3.0
	var y := -d * 0.5 + 5.0
	while y < d * 0.5 - 4.0:
		match crop:
			0: ci.draw_line(Vector2(fx0, y), Vector2(fx1, y), Color(0.86, 0.72, 0.32), 3.2)
			1:
				var x := fx0 + 3.0
				while x < fx1 - 2.0:
					ci.draw_circle(Vector2(x, y), 1.7, Color(0.36, 0.6, 0.28).lightened(rng.randf_range(0.0, 0.15)))
					x += 4.5
			_: ci.draw_line(Vector2(fx0, y), Vector2(fx1, y), Color(0.36, 0.56, 0.24), 2.4)
		y += 5.0
	# Bumpy hedge edge.
	for k in range(int((w + d) * 2.0 / 7.0)):
		var t := float(k) / int((w + d) * 2.0 / 7.0)
		var p := _rect_edge(w - 2.0, d - 2.0, t)
		ci.draw_circle(p, rng.randf_range(2.0, 3.2), HEDGE.lightened(rng.randf_range(0.0, 0.12)))
	# Red barn and hay bales in the corner, a little tractor in the field.
	var bx := w * 0.5 - 20.0
	var by := -d * 0.5 + 16.0
	rect(ci, bx - 4.0, by + 14.0, 30.0, 10.0, Color(0.6, 0.55, 0.45))
	block_shadow(ci, bx, by, 26.0, 20.0, 3.5)
	roof(ci, bx, by, 26.0, 20.0, col, "gable")
	for k in range(3):
		var p := Vector2(bx - 22.0 + k * 6.5, by + 8.0 + (k % 2) * 3.0)
		ci.draw_circle(p + sun * 0.3, 2.8, SHADOW)
		ci.draw_circle(p, 2.8, Color(0.9, 0.78, 0.4))
		ci.draw_arc(p, 1.6, 0.0, TAU, 12, Color(0.72, 0.58, 0.28), 0.5)
	var tp := Vector2(rng.randf_range(-w * 0.3, 0.0), rng.randf_range(-d * 0.1, d * 0.3))
	rect(ci, tp.x + sun.x * 0.3, tp.y + sun.y * 0.3, 9.0, 6.0, SHADOW)
	for p in [Vector2(-2.5, -3.0), Vector2(-2.5, 3.0)]:
		rect(ci, tp.x + p.x, tp.y + p.y, 4.4, 2.2, Color(0.1, 0.1, 0.1))
	rect(ci, tp.x, tp.y, 9.0, 5.0, Color(0.2, 0.5, 0.25))
	rect(ci, tp.x - 1.5, tp.y, 3.4, 4.0, Color(0.55, 0.7, 0.75))

static func _rect_edge(w: float, d: float, t: float) -> Vector2:
	var per := 2.0 * (w + d)
	var s := t * per
	if s < w:
		return Vector2(-w * 0.5 + s, -d * 0.5)
	s -= w
	if s < d:
		return Vector2(w * 0.5, -d * 0.5 + s)
	s -= d
	if s < w:
		return Vector2(w * 0.5 - s, d * 0.5)
	s -= w
	return Vector2(-w * 0.5, d * 0.5 - s)

func one_tree(ci, _xf: Transform2D, w: float, _d: float, _col: Color, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var kinds := ["round", "round", "pine", "blossom", "autumn"]
	tree(ci, Vector2.ZERO, w * 0.5 * rng.randf_range(0.8, 1.0), kinds[rng.randi() % kinds.size()], rng.randf())

func forest(ci, _xf: Transform2D, w: float, d: float, _col: Color, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	ci.draw_circle(Vector2.ZERO, minf(w, d) * 0.45, Color(0.2, 0.33, 0.15, 0.35))
	var trees := []
	for _i in range(rng.randi_range(10, 15)):
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf())
		var p := Vector2(cos(a) * r * (w * 0.5 - 14.0), sin(a) * r * (d * 0.5 - 14.0))
		trees.append([p, rng.randf_range(10.0, 15.0), "pine" if rng.randf() < 0.5 else "round", rng.randf()])
	trees.sort_custom(func(a, b): return a[0].y < b[0].y)
	for t in trees:
		tree(ci, t[0], t[1], t[2], t[3])

func pond(ci, _xf: Transform2D, w: float, d: float, _col: Color, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var ph := rng.randf() * TAU
	var shape := func(k: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in range(40):
			var a := i * TAU / 40.0
			var f := 1.0 + 0.08 * sin(3.0 * a + ph) + 0.05 * sin(5.0 * a + ph * 2.0)
			pts.append(Vector2(cos(a) * (w * 0.5 - 3.0) * k * f, sin(a) * (d * 0.5 - 3.0) * k * f))
		return pts
	ci.draw_colored_polygon(shape.call(1.0), Color(0.55, 0.5, 0.36))
	ci.draw_colored_polygon(shape.call(0.92), Color(0.2, 0.38, 0.5))
	ci.draw_colored_polygon(shape.call(0.8), Color(0.25, 0.46, 0.6))
	ci.draw_colored_polygon(shape.call(0.55), Color(0.28, 0.52, 0.66))
	ci.draw_line(Vector2(-w * 0.2, -d * 0.2), Vector2(w * 0.05, -d * 0.26), Color(1, 1, 1, 0.3), 1.2, true)
	ci.draw_line(Vector2(-w * 0.1, -d * 0.1), Vector2(w * 0.12, -d * 0.14), Color(1, 1, 1, 0.2), 0.8, true)
	# Lily pads, reeds round the edge, and a couple of ducks.
	for k in range(rng.randi_range(4, 7)):
		var a := rng.randf() * TAU
		var p := Vector2(cos(a) * w * 0.3, sin(a) * d * 0.3) * rng.randf_range(0.6, 1.0)
		var r := rng.randf_range(2.0, 3.2)
		ci.draw_colored_polygon(_pad(p, r, rng.randf() * TAU), Color(0.3, 0.55, 0.25))
		if rng.randf() < 0.35:
			ci.draw_circle(p + Vector2(0.6, -0.4), 1.0, Color(1.0, 0.85, 0.9))
	for k in range(rng.randi_range(10, 16)):
		var a := rng.randf() * TAU
		var f := 1.0 + 0.08 * sin(3.0 * a + ph) + 0.05 * sin(5.0 * a + ph * 2.0)
		var p := Vector2(cos(a) * (w * 0.5 - 4.0) * f, sin(a) * (d * 0.5 - 4.0) * f)
		for j in range(3):
			var q := p + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
			ci.draw_line(q, q + Vector2(rng.randf_range(-1.5, 1.5), -rng.randf_range(2.5, 4.5)), Color(0.35, 0.5, 0.2), 0.7)
		ci.draw_circle(p + Vector2(0.0, -3.0), 0.9, Color(0.4, 0.26, 0.14))
	for k in range(2):
		var p := Vector2(rng.randf_range(-w * 0.2, w * 0.2), rng.randf_range(-d * 0.15, d * 0.2))
		var a := rng.randf() * TAU
		var fwd := Vector2.from_angle(a)
		ci.draw_circle(p + Vector2(0.8, 1.0), 2.4, Color(0, 0, 0, 0.18))
		ci.draw_colored_polygon(PackedVector2Array([p - fwd * 3.2 + fwd.orthogonal() * 0.2, p + fwd.orthogonal() * 2.0, p + fwd * 1.2, p - fwd.orthogonal() * 2.0]), Color(0.55, 0.42, 0.28) if k == 0 else Color(0.95, 0.95, 0.92))
		ci.draw_circle(p + fwd * 1.8, 1.3, Color(0.15, 0.4, 0.2) if k == 0 else Color(0.95, 0.95, 0.92))
		ci.draw_circle(p + fwd * 3.2, 0.6, Color(1.0, 0.6, 0.1))

static func _pad(p: Vector2, r: float, a0: float) -> PackedVector2Array:
	var pts := PackedVector2Array([p])
	for i in range(13):
		pts.append(p + Vector2.from_angle(a0 + 0.5 + i * (TAU - 1.0) / 12.0) * r)
	return pts

func flowers(ci, _xf: Transform2D, w: float, d: float, _col: Color, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pts := PackedVector2Array()
	for i in range(28):
		var a := i * TAU / 28.0
		var f := rng.randf_range(0.85, 1.0)
		pts.append(Vector2(cos(a) * w * 0.5 * f, sin(a) * d * 0.5 * f))
	ci.draw_colored_polygon(pts, Color(0.5, 0.64, 0.3))
	var cols := [Color(1.0, 0.4, 0.5), Color(1.0, 0.88, 0.25), Color(0.96, 0.96, 1.0), Color(0.72, 0.5, 1.0), Color(1.0, 0.55, 0.2), Color(0.4, 0.6, 1.0)]
	for k in range(3):
		var p := Vector2(rng.randf_range(-w * 0.3, w * 0.3), rng.randf_range(-d * 0.3, d * 0.3))
		ci.draw_circle(p + sun * 0.4, 4.5, Color(0, 0, 0, 0.18))
		ci.draw_circle(p, 4.5, Color(0.26, 0.42, 0.18))
		ci.draw_circle(p + Vector2(-1.2, -1.2), 2.4, Color(0.34, 0.5, 0.22))
	for _i in range(int(w * d / 30.0)):
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.9
		var p := Vector2(cos(a) * w * 0.5 * r, sin(a) * d * 0.5 * r)
		var c: Color = cols[rng.randi() % cols.size()]
		for j in range(5):
			ci.draw_circle(p + Vector2.from_angle(j * TAU / 5.0) * 0.9, 0.75, c)
		ci.draw_circle(p, 0.5, Color(1.0, 0.85, 0.3) if c != cols[1] else Color(0.6, 0.35, 0.1))

# --- Mountains ---------------------------------------------------------------

## A mountain's outline in its own frame: a lumpy oval inside `w` x `d`,
## the same for the same seed (tunnel portals are put where lines cross it).
static func hill_outline(w: float, d: float, seed: int, scale: float = 1.0) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var ph := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var pts := PackedVector2Array()
	for i in range(48):
		var a := i * TAU / 48.0
		var f := 0.9 + 0.06 * sin(3.0 * a + ph[0]) + 0.035 * sin(5.0 * a + ph[1]) + 0.02 * sin(9.0 * a + ph[2])
		pts.append(Vector2(cos(a) * w * 0.5, sin(a) * d * 0.5) * f * scale)
	return pts

## Rings of rising ground from wooded slopes up to a snowy top, each
## shifted towards the light so the far side falls into shade.
func mountain(ci, _xf: Transform2D, w: float, d: float, _col: Color, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var base := hill_outline(w, d, seed)
	var shadow := PackedVector2Array()
	for p in base:
		shadow.append(p + sun * 3.0)
	ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.3))
	var bands := [Color(0.24, 0.4, 0.2), Color(0.3, 0.46, 0.22), Color(0.42, 0.5, 0.28),
		Color(0.5, 0.46, 0.38), Color(0.6, 0.58, 0.55), Color(0.93, 0.94, 0.97)]
	var peak := -sun.normalized() * minf(w, d) * 0.08
	for k in range(bands.size()):
		var sc := 1.0 - k * 0.15
		var off := peak * (k / float(bands.size() - 1))
		var ring := PackedVector2Array()
		var dark := PackedVector2Array()
		for p in hill_outline(w, d, seed, sc):
			ring.append(p + off)
			dark.append(p + off + sun * 0.5)
		if k > 0:
			ci.draw_colored_polygon(dark, (bands[k - 1] as Color).darkened(0.22))
		ci.draw_colored_polygon(ring, bands[k])
		if k == 0:
			# Woods on the lower slopes, rocks higher up.
			for _i in range(30):
				var a := rng.randf() * TAU
				var r := rng.randf_range(0.72, 0.9)
				var q := Vector2(cos(a) * w * 0.5, sin(a) * d * 0.5) * r * 0.9
				tree(ci, q, rng.randf_range(5.0, 8.0), "pine" if rng.randf() < 0.6 else "round", rng.randf())
		elif k == 3:
			for _i in range(14):
				var a := rng.randf() * TAU
				var q := off + Vector2(cos(a) * w * 0.5, sin(a) * d * 0.5) * 0.5 * rng.randf_range(0.8, 1.05)
				ci.draw_circle(q + sun * 0.3, 2.4, Color(0, 0, 0, 0.18))
				ci.draw_circle(q, 2.2, Color(0.55, 0.53, 0.5))
				ci.draw_circle(q - sun.normalized() * 0.8, 1.0, Color(0.7, 0.68, 0.65))
