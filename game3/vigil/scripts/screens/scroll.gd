extends Node2D

## The Enigma Scroll: a ring of 12 glyphs unrolls; a code is 4 of them in
## order. A known code emits `code_accepted`; a wrong one fades away and
## says nothing. Tap outside the ring (or Back) to close.

signal code_accepted(recipe_id: String)
signal closed

const GLYPHS := 12
const CODE_LEN := 4
const GLYPH_PX := 22.0
const UNROLL_S := 1.6

var glyph_strokes: Array = [] # per glyph: Array of PackedVector2Array in -1..1
var entered: Array = []
var ring_r := 150.0
var centre := Vector2.ZERO
var _t := 0.0
var _flash := {} # glyph -> seconds left lit
var _fail_t := 0.0 # >0 while a wrong entry fades

func _ready() -> void:
	var size := get_viewport_rect().size
	centre = size * Vector2(0.5, 0.46)
	ring_r = min(size.x, size.y) * 0.34
	glyph_strokes = make_glyphs(GLYPHS, 108)

## Fixed, procedural glyphs: 2-3 strokes on a 3x3 lattice each, distinct.
static func make_glyphs(count: int, seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out := []
	var seen := {}
	while out.size() < count:
		var strokes := []
		var sig := ""
		for s in rng.randi_range(2, 3):
			var stroke := PackedVector2Array()
			var p := Vector2i(rng.randi_range(0, 2), rng.randi_range(0, 2))
			for n in rng.randi_range(2, 3):
				stroke.append(Vector2(p) - Vector2.ONE)
				var q := p
				while q == p:
					q = Vector2i(rng.randi_range(0, 2), rng.randi_range(0, 2))
				p = q
			stroke.append(Vector2(p) - Vector2.ONE)
			strokes.append(stroke)
			sig += str(stroke)
		if not seen.has(sig):
			seen[sig] = true
			out.append(strokes)
	return out

func glyph_pos(i: int) -> Vector2:
	var a := -PI * 0.5 + TAU * i / GLYPHS
	return centre + Vector2(cos(a), sin(a)) * ring_r * _unroll()

func _unroll() -> float:
	var f: float = clamp(_t / UNROLL_S, 0.0, 1.0)
	return 1.0 - pow(1.0 - f, 3.0)

func _process(delta: float) -> void:
	_t += delta
	for g in _flash.keys():
		_flash[g] -= delta
		if _flash[g] <= 0.0:
			_flash.erase(g)
	if _fail_t > 0.0:
		_fail_t -= delta
		if _fail_t <= 0.0:
			entered.clear()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	get_viewport().set_input_as_handled()
	if _t < UNROLL_S or _fail_t > 0.0:
		return
	var p: Vector2 = event.position
	if p.distance_to(centre) > ring_r + GLYPH_PX * 3.0:
		closed.emit()
		return
	for i in GLYPHS:
		if p.distance_to(glyph_pos(i)) <= GLYPH_PX * 1.4:
			_enter(i)
			return

func _enter(i: int) -> void:
	entered.append(i)
	_flash[i] = 0.6
	if entered.size() < CODE_LEN:
		return
	var id := ScrollCodes.lookup(entered)
	if id != "" and not Registry.get_recipe(id).is_empty():
		code_accepted.emit(id)
	else:
		_fail_t = 1.2

func _draw() -> void:
	var size := get_viewport_rect().size
	var u := _unroll()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.03, 0.94 * u))
	var bone := Color("#d9d1bd")
	var ring := bone
	ring.a = 0.18 * u
	draw_arc(centre, ring_r * u, 0.0, TAU, 180, ring, 1.0, true)
	for i in GLYPHS:
		var c := bone
		c.a = (0.45 + 0.55 * clamp(_flash.get(i, 0.0) / 0.6, 0.0, 1.0)) * u
		var at := glyph_pos(i)
		for stroke in glyph_strokes[i]:
			var pts := PackedVector2Array()
			for v in stroke:
				pts.append(at + v * GLYPH_PX * 0.8)
			draw_polyline(pts, c, 1.8, true)
	# Entered count: small marks at the centre, fading on a wrong code.
	var fade: float = (_fail_t / 1.2) if _fail_t > 0.0 else 1.0
	for k in entered.size():
		var c := bone
		c.a = 0.6 * fade
		draw_circle(centre + Vector2((k - (CODE_LEN - 1) * 0.5) * 16.0, 0), 2.5, c)
