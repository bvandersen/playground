extends Ritual

## r17 The Sigil of Breath (docs/game3.md). A star polygon inside a circle
## breathes in asymmetric, non-human intervals chosen per day; the phase
## word shows faintly for the first cycles only, then never. At the end the
## ring freezes mid-inhale and holds still before the rite closes.
## (The low drone arrives with Phase 1's Synth.)

const ENGINE_ID := "breath_sigil"

const PHASES := ["in", "hold", "out", "hold"]

static func defaults() -> Dictionary:
	return {
		"shape": [7, 3],
		"rings": 1,
		"rhythm_sets": [[3, 7, 2, 5]],
		"cycles": 6,
		"words_cycles": 2,
		"span": [0.55, 1.0],
		"turn_per_cycle": 0.0,
		"stop_at": 0.6,
		"hold_at_end": 6.0,
		"color": "#d9d1bd",
	}

var rhythm: Array = []
var t := 0.0
var running := false
var frozen_at := -1.0 # time the ring froze, or -1
var breath := 0.0 # 0 = empty, 1 = full
var turn := 0.0
var word := Label.new()
var _last_phase := -1

func setup(r: Dictionary) -> void:
	super.setup(r)
	var sets: Array = params["rhythm_sets"]
	rhythm = sets[rng.randi() % sets.size()]
	word.modulate = Color(1, 1, 1, 0)
	word.add_theme_font_size_override("font_size", 18)
	word.add_theme_color_override("font_color", Color(params["color"]))
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(word)

func begin() -> void:
	running = true

func cycle_length() -> float:
	var total := 0.0
	for s in rhythm:
		total += float(s)
	return max(total, 0.1)

## Seconds until the freeze: all cycles, then part of one last inhale.
func breathing_time() -> float:
	return cycle_length() * int(params["cycles"]) + float(rhythm[0]) * float(params["stop_at"])

func payoff_reached() -> bool:
	return frozen_at >= 0.0

func _process(delta: float) -> void:
	if not running:
		return
	t += delta
	if frozen_at < 0.0 and t >= breathing_time():
		frozen_at = t
		word.modulate.a = 0.0
	if frozen_at >= 0.0:
		if t - frozen_at >= float(params["hold_at_end"]):
			running = false
			end("done")
		return
	_breathe(t)
	queue_redraw()

func _breathe(time: float) -> void:
	var cycle := int(time / cycle_length())
	var into := fmod(time, cycle_length())
	var phase := 0
	while phase < 3 and into >= float(rhythm[phase]):
		into -= float(rhythm[phase])
		phase += 1
	var f: float = into / max(float(rhythm[phase]), 0.001)
	match phase:
		0: breath = _ease(f)
		1: breath = 1.0
		2: breath = 1.0 - _ease(f)
		3: breath = 0.0
	turn = time / cycle_length() * float(params["turn_per_cycle"])

	var show_word: bool = cycle < int(params["words_cycles"])
	if phase != _last_phase:
		_last_phase = phase
		word.text = line(PHASES[phase])
	# Faint, and fading in and out with each phase so it never snaps.
	var a := 0.0
	if show_word:
		a = 0.35 * sin(PI * clamp(f, 0.0, 1.0))
	word.modulate.a = a
	var size := viewport_size()
	word.size = Vector2(size.x, 30)
	word.position = Vector2(0, size.y * 0.5 + max_radius() + 36)

static func _ease(f: float) -> float:
	return 0.5 - 0.5 * cos(PI * clamp(f, 0.0, 1.0))

func max_radius() -> float:
	var size := viewport_size()
	return min(size.x, size.y) * 0.36

func _draw() -> void:
	var size := viewport_size()
	var centre := size * 0.5
	var span: Array = params["span"]
	var r: float = max_radius() * lerp(float(span[0]), float(span[1]), breath)
	var col := Color(params["color"])
	var width := 2.0
	var rings := int(params["rings"])
	for i in rings:
		var rr := r * (1.0 + 0.06 * i)
		var c := col
		c.a = 0.9 - 0.25 * i
		draw_arc(centre, rr, 0.0, TAU, 160, c, width, true)
	var shape: Array = params["shape"]
	draw_star(self, centre, r * 0.97, int(shape[0]), int(shape[1]), turn * TAU, col, width)

## Star polygon {n/k} (a compound one when n and k share a factor).
static func draw_star(ci: CanvasItem, centre: Vector2, radius: float, n: int, k: int, rot: float, col: Color, width: float) -> void:
	if n < 3:
		return
	var pts := PackedVector2Array()
	for i in n:
		var a := rot - PI * 0.5 + TAU * i / n
		pts.append(centre + Vector2(cos(a), sin(a)) * radius)
	var visited := {}
	for start in n:
		if visited.has(start):
			continue
		var stroke := PackedVector2Array()
		var i := start
		while true:
			visited[i] = true
			stroke.append(pts[i])
			i = (i + k) % n
			if i == start:
				stroke.append(pts[i])
				break
		ci.draw_polyline(stroke, col, width, true)
