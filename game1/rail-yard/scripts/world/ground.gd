extends Node2D
class_name Ground

## The landscape under the track: a seamless procedural grass texture
## tiled over a huge rect, plus scattered trees, bushes and rocks that are
## re-scattered around the track whenever it changes (nothing ever grows
## through a rail). Everything is generated from fixed seeds, so the same
## layout always gets the same scenery.

const EXTENT := 9000.0
const DECOR_RADIUS := 2600.0
const DECOR_COUNT := 900
const CELL := 24.0
const TRACK_CLEARANCE := 22.0

var _grass: ImageTexture
var _decor: Array = [] # [kind, pos, radius, shade]

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_grass = _make_grass()

func _make_grass() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	var detail := FastNoiseLite.new()
	detail.seed = 11
	detail.frequency = 0.25
	var size := 256
	var a := noise.get_seamless_image(size, size)
	var b := detail.get_seamless_image(size, size)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var dark := Color(0.27, 0.4, 0.2)
	var light := Color(0.42, 0.55, 0.28)
	var dry := Color(0.52, 0.55, 0.3)
	for y in range(size):
		for x in range(size):
			var n := a.get_pixel(x, y).r
			var d := b.get_pixel(x, y).r
			var c := dark.lerp(light, n)
			c = c.lerp(dry, clampf((n - 0.62) * 2.2, 0.0, 0.5))
			c = c.darkened((0.5 - d) * 0.16)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

## Re-scatters scenery, keeping clear of every track point.
func rebuild(net: TrackNetwork) -> void:
	var blocked := {}
	var reach := int(ceil((TRACK_CLEARANCE + 14.0) / CELL))
	for seg in net.segments:
		for i in range(0, seg.points.size(), 3):
			var p: Vector2 = seg.points[i]
			var cx := floori(p.x / CELL)
			var cy := floori(p.y / CELL)
			for dy in range(-reach, reach + 1):
				for dx in range(-reach, reach + 1):
					blocked[Vector2i(cx + dx, cy + dy)] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	_decor = []
	for _i in range(DECOR_COUNT):
		var ang := rng.randf() * TAU
		var dist := rng.randf() * DECOR_RADIUS # denser towards the middle
		var pos := Vector2(cos(ang), sin(ang)) * dist
		var roll := rng.randf()
		var kind := "tree" if roll < 0.3 else ("bush" if roll < 0.52 else ("rock" if roll < 0.6 else "tuft"))
		var r: float = {"tree": rng.randf_range(12.0, 22.0), "bush": rng.randf_range(5.0, 9.0),
			"rock": rng.randf_range(3.0, 7.0), "tuft": rng.randf_range(4.0, 7.0)}[kind]
		var shade := rng.randf()
		if blocked.has(Vector2i(floori(pos.x / CELL), floori(pos.y / CELL))):
			continue
		_decor.append([kind, pos, r, shade])
	# Trees last so they overlap bushes and rocks.
	_decor.sort_custom(func(p, q): return _order(p[0]) < _order(q[0]))
	queue_redraw()

static func _order(kind: String) -> int:
	return {"tuft": 0, "rock": 1, "bush": 2, "tree": 3}.get(kind, 0)

func _draw() -> void:
	if _grass != null:
		draw_texture_rect(_grass, Rect2(-EXTENT, -EXTENT, EXTENT * 2.0, EXTENT * 2.0), true)
	for d in _decor:
		var pos: Vector2 = d[1]
		var r: float = d[2]
		var sh: float = d[3]
		match d[0]:
			"tree":
				draw_circle(pos + Vector2(r * 0.35, r * 0.45), r * 1.02, Color(0, 0, 0, 0.22))
				var base := Color(0.12, 0.27, 0.12).lerp(Color(0.2, 0.33, 0.12), sh)
				draw_circle(pos, r, base)
				draw_circle(pos + Vector2(-r * 0.22, -r * 0.2), r * 0.72, base.lightened(0.12))
				draw_circle(pos + Vector2(-r * 0.38, -r * 0.36), r * 0.4, base.lightened(0.24))
				draw_circle(pos + Vector2(r * 0.3, -r * 0.35), r * 0.3, base.lightened(0.08))
				draw_arc(pos, r, 0.0, TAU, 28, base.darkened(0.25), 1.0, true)
			"bush":
				draw_circle(pos + Vector2(r * 0.3, r * 0.4), r, Color(0, 0, 0, 0.18))
				var bc := Color(0.24, 0.4, 0.17).lerp(Color(0.33, 0.45, 0.2), sh)
				draw_circle(pos, r, bc)
				draw_circle(pos + Vector2(-r * 0.3, -r * 0.3), r * 0.5, bc.lightened(0.15))
				draw_arc(pos, r, 0.0, TAU, 16, bc.darkened(0.2), 0.8, true)
			"tuft":
				var gc := Color(0.24, 0.36, 0.15).lerp(Color(0.5, 0.58, 0.28), sh)
				for k in range(5):
					var a := -PI * 0.5 + (k - 2) * 0.35 + sh * 0.3
					draw_line(pos + Vector2((k - 2) * 1.2, 0.0), pos + Vector2((k - 2) * 1.2, 0.0) + Vector2(cos(a), sin(a)) * r, gc, 1.0, true)
			_:
				draw_circle(pos + Vector2(r * 0.3, r * 0.4), r, Color(0, 0, 0, 0.2))
				var rc := Color(0.5, 0.5, 0.48).lerp(Color(0.62, 0.6, 0.55), sh)
				draw_circle(pos, r, rc)
				draw_circle(pos + Vector2(-r * 0.3, -r * 0.3), r * 0.45, rc.lightened(0.2))
