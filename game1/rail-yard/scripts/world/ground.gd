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
const CHUNK := 640.0
const KINDS := ["tuft", "rock", "bush", "tree"] # drawing order

var _grass: ImageTexture
var _items: Array = []
var _layers: Array = [] # one Node2D per kind, holding its chunk meshes

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_grass = _make_grass()
	_generate()
	for _k in KINDS:
		var layer := Node2D.new()
		add_child(layer)
		_layers.append(layer)

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

## Every piece of scenery that could grow, generated once from a fixed
## seed: [kind index into KINDS, position, its picture as a TriBatch].
func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	_items = []
	for _i in range(DECOR_COUNT):
		var ang := rng.randf() * TAU
		var dist := rng.randf() * DECOR_RADIUS # denser towards the middle
		var pos := Vector2(cos(ang), sin(ang)) * dist
		var roll := rng.randf()
		var kind := "tree" if roll < 0.3 else ("bush" if roll < 0.52 else ("rock" if roll < 0.6 else "tuft"))
		var r: float = {"tree": rng.randf_range(12.0, 22.0), "bush": rng.randf_range(5.0, 9.0),
			"rock": rng.randf_range(3.0, 7.0), "tuft": rng.randf_range(4.0, 7.0)}[kind]
		var shade := rng.randf()
		var b := TriBatch.new()
		_paint(b, kind, pos, r, shade)
		_items.append([KINDS.find(kind), pos, b])

## Re-scatters scenery, keeping clear of every track point. The survivors
## are merged into one mesh per CHUNK-sized square and kind, so a frame
## draws only the few chunks on screen, each in a single draw call.
func rebuild(net: TrackNetwork, clear_of: PackedVector2Array = PackedVector2Array()) -> void:
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
	# Stations: their platforms and houses (a point every 15 px or so).
	for p in clear_of:
		var cx := floori(p.x / CELL)
		var cy := floori(p.y / CELL)
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				blocked[Vector2i(cx + dx, cy + dy)] = true
	var kept := _items.filter(func(it): return not blocked.has(Vector2i(floori(it[1].x / CELL), floori(it[1].y / CELL))))
	# Same (unstable) sort as ever, so overlapping pieces stack as before.
	kept.sort_custom(func(p, q): return p[0] < q[0])
	var chunks: Array = []
	for _k in KINDS:
		chunks.append({})
	for it in kept:
		var pos: Vector2 = it[1]
		var key := Vector2i(floori(pos.x / CHUNK), floori(pos.y / CHUNK))
		var batches: Dictionary = chunks[it[0]]
		if not batches.has(key):
			batches[key] = TriBatch.new()
		batches[key].append(it[2])
	# One layer per kind, trees last so they overlap bushes and rocks.
	for k in range(KINDS.size()):
		var layer: Node2D = _layers[k]
		for c in layer.get_children():
			c.queue_free()
		for b in chunks[k].values():
			var chunk := _Chunk.new()
			chunk.mesh = b.to_mesh()
			layer.add_child(chunk)

func _draw() -> void:
	if _grass != null:
		draw_texture_rect(_grass, Rect2(-EXTENT, -EXTENT, EXTENT * 2.0, EXTENT * 2.0), true)

static func _paint(b: TriBatch, kind: String, pos: Vector2, r: float, sh: float) -> void:
	match kind:
		"tree":
			b.draw_circle(pos + Vector2(r * 0.35, r * 0.45), r * 1.02, Color(0, 0, 0, 0.22))
			var base := Color(0.12, 0.27, 0.12).lerp(Color(0.2, 0.33, 0.12), sh)
			b.draw_circle(pos, r, base)
			b.draw_circle(pos + Vector2(-r * 0.22, -r * 0.2), r * 0.72, base.lightened(0.12))
			b.draw_circle(pos + Vector2(-r * 0.38, -r * 0.36), r * 0.4, base.lightened(0.24))
			b.draw_circle(pos + Vector2(r * 0.3, -r * 0.35), r * 0.3, base.lightened(0.08))
			b.draw_arc(pos, r, 0.0, TAU, 28, base.darkened(0.25), 1.0, true)
		"bush":
			b.draw_circle(pos + Vector2(r * 0.3, r * 0.4), r, Color(0, 0, 0, 0.18))
			var bc := Color(0.24, 0.4, 0.17).lerp(Color(0.33, 0.45, 0.2), sh)
			b.draw_circle(pos, r, bc)
			b.draw_circle(pos + Vector2(-r * 0.3, -r * 0.3), r * 0.5, bc.lightened(0.15))
			b.draw_arc(pos, r, 0.0, TAU, 16, bc.darkened(0.2), 0.8, true)
		"tuft":
			var gc := Color(0.24, 0.36, 0.15).lerp(Color(0.5, 0.58, 0.28), sh)
			for k in range(5):
				var a := -PI * 0.5 + (k - 2) * 0.35 + sh * 0.3
				b.draw_line(pos + Vector2((k - 2) * 1.2, 0.0), pos + Vector2((k - 2) * 1.2, 0.0) + Vector2(cos(a), sin(a)) * r, gc, 1.0, true)
		_:
			b.draw_circle(pos + Vector2(r * 0.3, r * 0.4), r, Color(0, 0, 0, 0.2))
			var rc := Color(0.5, 0.5, 0.48).lerp(Color(0.62, 0.6, 0.55), sh)
			b.draw_circle(pos, r, rc)
			b.draw_circle(pos + Vector2(-r * 0.3, -r * 0.3), r * 0.45, rc.lightened(0.2))

class _Chunk extends Node2D:
	var mesh: ArrayMesh

	func _draw() -> void:
		if mesh != null:
			draw_mesh(mesh, null)
