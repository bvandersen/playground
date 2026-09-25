extends Ritual

## r05 The Glyph of the Moment (docs/game3.md). A bare ground with grain;
## "Look."; then a glyph no one has seen before is shown for exactly
## `show_s` seconds and dissolves into static for good. It is generated from the
## day's seed *and* the clock's microseconds, so not even the same day
## reproduces it, and it is never saved. Strokes run on an n x n lattice
## (straight moves and arcs); shapes that are too simple to be a sigil --
## few nodes, no junction, no curve or diagonal -- are rejected. Ground,
## ink, the hand the strokes are laid in and the colour of the static are
## the recipe's style, not this file's.
## (The sharp tone before the glyph arrives with Phase 1's Synth.)

const ENGINE_ID := "glyph_moment"

const DOT_SPACING := 2.5 # px between the dots the glyph dissolves into
const ARC_POINTS := 14

static func defaults() -> Dictionary:
	return {
		"lattice": 5,
		"strokes": [3, 5],
		"steps": [2, 4],
		"arc_chance": 0.35,
		"symmetry": "none", # "none" | "mirror" | "rotate"
		"min_nodes": 7,
		"min_moves": 6,
		"size": 0.62,
		"look_at": 1.0,
		"look_s": 2.0,
		"glyph_at": 4.0,
		"show_s": 3.0,
		"dissolve_s": 2.5,
		"static_s": 3.0,
		"payoff_hold": 9.0,
		"width": 3.0,
		"static": 0.5, # grain opacity at the height of the static
	}

enum Stage { WAIT, SHOW, DISSOLVE, STATIC, PAYOFF }

var stage := Stage.WAIT
var t := 0.0
var stage_t := 0.0
var running := false

var strokes: Array = [] # of PackedVector2Array, lattice units
var dots: Array = [] # [screen pos, dissolve threshold 0..1, drift]
var static_a := 0.0
var look := Label.new()
var payoff := Label.new()
var payoff_text := ""

func setup(r: Dictionary) -> void:
	super.setup(r)
	static_a = float(style.data["grain"])
	for l in [look, payoff]:
		l.modulate = Color(1, 1, 1, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(l)
	style.dress(look, 22)
	style.dress(payoff, 20)
	payoff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	look.text = line("look")
	payoff_text = line("payoff") # set in _layout(), once it has a width to wrap to

func begin() -> void:
	# The day's seed alone would give everyone on that day's draw the same
	# shape again on a replay; the microseconds make it this moment's only.
	var g := RandomNumberGenerator.new()
	g.seed = hash([rng.randi(), Time.get_ticks_usec(), Time.get_unix_time_from_system()])
	strokes = make_glyph(g, params)
	_layout()
	running = true
	queue_redraw()

func payoff_reached() -> bool:
	return stage >= Stage.DISSOLVE

func _layout() -> void:
	var size := viewport_size()
	look.size = Vector2(size.x, 60)
	look.position = Vector2(0, size.y * 0.5 - 30)
	payoff.size = Vector2(size.x - 96, size.y * 0.5)
	payoff.position = Vector2(48, size.y * 0.25)
	payoff.text = payoff_text
	dots.clear()
	var drng := RandomNumberGenerator.new()
	drng.seed = rng.randi()
	for s in strokes:
		var pts := _to_screen(s)
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var n := maxi(1, int(a.distance_to(b) / DOT_SPACING))
			for k in n:
				var drift := Vector2.from_angle(drng.randf() * TAU) * drng.randf_range(4.0, 26.0)
				dots.append([a.lerp(b, float(k) / n), drng.randf(), drift])

func _process(delta: float) -> void:
	if not running:
		return
	t += delta
	stage_t += delta
	var grain := float(style.data["grain"])
	var full := float(params["static"])
	match stage:
		Stage.WAIT:
			look.modulate.a = _window(t, float(params["look_at"]), float(params["look_s"]), 0.6)
			if t >= float(params["glyph_at"]):
				look.modulate.a = 0.0
				_next(Stage.SHOW) # a hard cut in: no fade
		Stage.SHOW:
			if stage_t >= float(params["show_s"]):
				_next(Stage.DISSOLVE)
		Stage.DISSOLVE:
			var p := clampf(stage_t / float(params["dissolve_s"]), 0.0, 1.0)
			static_a = lerpf(grain, full, smoothstep(0.0, 0.7, p))
			if p >= 1.0:
				strokes.clear() # gone; nothing keeps it
				dots.clear()
				_next(Stage.STATIC)
		Stage.STATIC:
			var p := clampf((stage_t - float(params["static_s"])) / 2.0, 0.0, 1.0)
			static_a = lerpf(full, grain, smoothstep(0.0, 1.0, p))
			if p >= 1.0:
				_next(Stage.PAYOFF)
		Stage.PAYOFF:
			payoff.modulate.a = _window(stage_t, 0.5, float(params["payoff_hold"]), 2.0)
			if stage_t >= float(params["payoff_hold"]) + 4.5:
				running = false
				end("done")
	queue_redraw()

func _next(s: Stage) -> void:
	stage = s
	stage_t = 0.0

## 0 -> 1 -> 0: fades in at `from` over `fade` s, holds, fades out.
static func _window(time: float, from: float, hold: float, fade: float) -> float:
	var x := time - from
	if x <= 0.0 or x >= hold + 2.0 * fade:
		return 0.0
	return minf(1.0, minf(x / fade, (hold + 2.0 * fade - x) / fade))

func _draw() -> void:
	var size := viewport_size()
	style.draw_ground(self, size, t)
	style.draw_grain(self, size, t, static_a)
	var col := style.ink
	var w := float(params["width"])
	match stage:
		Stage.SHOW:
			for s in strokes:
				style.stroke(self, _to_screen(s), w)
		Stage.DISSOLVE:
			var p := clampf(stage_t / float(params["dissolve_s"]), 0.0, 1.0)
			for d in dots:
				var thr: float = d[1] * 0.85
				if p < thr:
					var shake := (p / maxf(thr, 0.01)) * 1.5
					var pos: Vector2 = d[0] + Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake))
					style.dot(self, pos, w, col)
				elif p < thr + 0.15:
					# The dot turns to a speck of static and drifts off.
					var k := (p - thr) / 0.15
					var speck := Color(style.grain_color, rng.randf_range(0.4, 1.0) * (1.0 - k))
					draw_rect(Rect2(d[0] + d[2] * k, Vector2(2, 2)), speck)

## Glyph lattice units -> screen, centred.
func _to_screen(s: PackedVector2Array) -> PackedVector2Array:
	var size := viewport_size()
	var n := int(params["lattice"])
	var side := minf(size.x, size.y) * float(params["size"])
	var cell := side / maxf(n - 1, 1)
	var origin := size * 0.5 - Vector2(side, side) * 0.5
	var out := PackedVector2Array()
	for v in s:
		out.append(origin + v * cell)
	return out

# --- the glyph ------------------------------------------------------------

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]

## Strokes (polylines in lattice units) for a glyph that passes the
## "not too simple" test (the last attempt if none does), centred on the
## lattice by its bounding box.
static func make_glyph(g: RandomNumberGenerator, p: Dictionary) -> Array:
	var moves: Array = []
	for attempt in 300:
		moves = _symmetrise(_random_moves(g, p), int(p["lattice"]), str(p["symmetry"]))
		if complex_enough(moves, p):
			break
	var box := Rect2(moves[0]["pts"][0], Vector2.ZERO) if not moves.is_empty() else Rect2()
	for m in moves:
		for v in m["pts"]:
			box = box.expand(v)
	var shift := Vector2(int(p["lattice"]) - 1, int(p["lattice"]) - 1) * 0.5 - box.get_center()
	return moves.map(func(m):
		var pts := PackedVector2Array()
		for v in m["pts"]:
			pts.append(v + shift)
		return pts)

## A move is {a, b: lattice nodes, pts: polyline, kind: "line" | "diag" | "arc"}.
static func _random_moves(g: RandomNumberGenerator, p: Dictionary) -> Array:
	var n := int(p["lattice"])
	var sr: Array = p["strokes"]
	var st: Array = p["steps"]
	var moves := []
	var seen := {}
	for s in g.randi_range(int(sr[0]), int(sr[1])):
		var at := Vector2i(g.randi_range(0, n - 1), g.randi_range(0, n - 1))
		for k in g.randi_range(int(st[0]), int(st[1])):
			var m := {}
			for tries in 12:
				m = _arc(g, at, n) if g.randf() < float(p["arc_chance"]) else _line(g, at, n)
				if not m.is_empty() and not seen.has(_key(m)):
					break
				m = {}
			if m.is_empty():
				break
			seen[_key(m)] = true
			moves.append(m)
			at = m["b"]
	return moves

static func _key(m: Dictionary) -> String:
	var a: Vector2i = m["a"]
	var b: Vector2i = m["b"]
	var lo := a if a < b else b
	var hi := b if a < b else a
	return "%s%s%s%s" % [m["kind"], lo, hi, m.get("bulge", "")]

static func _inside(v: Vector2i, n: int) -> bool:
	return v.x >= 0 and v.y >= 0 and v.x < n and v.y < n

static func _line(g: RandomNumberGenerator, at: Vector2i, n: int) -> Dictionary:
	var d: Vector2i = DIRS[g.randi() % DIRS.size()]
	var b := at + d * g.randi_range(1, 2)
	if not _inside(b, n):
		return {}
	var kind := "diag" if d.x != 0 and d.y != 0 else "line"
	return {"a": at, "b": b, "kind": kind, "pts": PackedVector2Array([Vector2(at), Vector2(b)])}

## A quarter arc to a diagonal neighbour, or a half circle two cells away.
static func _arc(g: RandomNumberGenerator, at: Vector2i, n: int) -> Dictionary:
	var a := Vector2(at)
	var pts := PackedVector2Array()
	var b: Vector2i
	var bulge := g.randi() % 2
	if g.randf() < 0.5:
		b = at + Vector2i([-1, 1][g.randi() % 2], [-1, 1][g.randi() % 2])
		var c := Vector2(b.x, at.y) if bulge == 0 else Vector2(at.x, b.y)
		var a0 := (a - c).angle()
		var sweep := wrapf((Vector2(b) - c).angle() - a0, -PI, PI)
		for i in ARC_POINTS + 1:
			pts.append(c + Vector2.from_angle(a0 + sweep * i / ARC_POINTS))
	else:
		var d: Vector2i = DIRS[g.randi() % 4]
		b = at + d * 2
		var c := (a + Vector2(b)) * 0.5
		var a0 := (a - c).angle()
		var sweep := PI if bulge == 0 else -PI
		for i in ARC_POINTS + 1:
			pts.append(c + Vector2.from_angle(a0 + sweep * i / ARC_POINTS))
	if not _inside(b, n):
		return {}
	return {"a": at, "b": b, "kind": "arc", "bulge": bulge, "pts": pts}

static func _symmetrise(moves: Array, n: int, mode: String) -> Array:
	if mode == "none":
		return moves
	var out := moves.duplicate()
	var c := Vector2(n - 1, n - 1) * 0.5
	var maps: Array = []
	if mode == "mirror":
		maps = [func(v: Vector2): return Vector2(n - 1 - v.x, v.y)]
	elif mode == "rotate":
		for q in [1, 2, 3]:
			maps.append(func(v: Vector2): return c + (v - c).rotated(PI * 0.5 * q))
	for f in maps:
		for m in moves:
			var pts := PackedVector2Array()
			for v in m["pts"]:
				pts.append(f.call(v))
			out.append({"a": Vector2i((f.call(Vector2(m["a"])) as Vector2).round()),
				"b": Vector2i((f.call(Vector2(m["b"])) as Vector2).round()),
				"kind": m["kind"], "pts": pts})
	return out

## Rejects shapes too plain to be a sigil (and so most letters): enough
## distinct nodes and moves, spread over the lattice, at least one
## junction, at least one arc or diagonal, and all one piece (two pieces
## read as two letters).
static func complex_enough(moves: Array, p: Dictionary) -> bool:
	if moves.size() < int(p["min_moves"]):
		return false
	var degree := {}
	var curved := false
	var lo := Vector2i(999, 999)
	var hi := Vector2i(-1, -1)
	for m in moves:
		curved = curved or m["kind"] != "line"
		for v in [m["a"], m["b"]]:
			degree[v] = degree.get(v, 0) + 1
			lo = Vector2i(mini(lo.x, v.x), mini(lo.y, v.y))
			hi = Vector2i(maxi(hi.x, v.x), maxi(hi.y, v.y))
	if degree.size() < int(p["min_nodes"]) or not curved:
		return false
	if hi.x - lo.x < 2 or hi.y - lo.y < 2:
		return false
	if not degree.values().any(func(d): return d >= 3):
		return false
	return _one_piece(moves, degree.keys())

static func _one_piece(moves: Array, nodes: Array) -> bool:
	var reached := {nodes[0]: true}
	var grew := true
	while grew:
		grew = false
		for m in moves:
			if reached.has(m["a"]) != reached.has(m["b"]):
				reached[m["a"]] = true
				reached[m["b"]] = true
				grew = true
	return reached.size() == nodes.size()
