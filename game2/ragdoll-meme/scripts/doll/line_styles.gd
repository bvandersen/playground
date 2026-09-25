extends RefCounted
class_name LineStyles

## Every way a "line" body part can be stroked. Adding a style is one
## NAMES entry plus one branch in stroke() -- the Look sheet lists NAMES,
## DollPainter only ever calls stroke().

const NAMES := {
	"noodle": "Noodle", "solid": "Solid", "stick": "Stick", "scribble": "Scribble",
	"dashed": "Dashed", "spring": "Spring", "beads": "Beads", "rainbow": "Rainbow",
	"neon": "Neon",
}
## Styles drawn through a smooth curve rather than straight bones.
const SMOOTH := ["noodle", "rainbow", "neon", "beads", "scribble"]

static func ids() -> Array:
	return NAMES.keys()

## Sample `pts` into a dense path: a Catmull-Rom curve through them for
## smooth styles, straight subdivided bones otherwise.
static func path(pts: PackedVector2Array, smooth: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	if n < 2:
		return pts
	var steps := 8
	for i in n - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, n - 1)]
		for s in steps:
			var t := float(s) / steps
			if smooth:
				out.append(_catmull(p0, p1, p2, p3, t))
			else:
				out.append(p1.lerp(p2, t))
	out.append(pts[n - 1])
	return out

static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

static func length_of(p: PackedVector2Array) -> float:
	var total := 0.0
	for i in p.size() - 1:
		total += p[i].distance_to(p[i + 1])
	return total

## Point and direction at distance `d` along `p`.
static func sample(p: PackedVector2Array, d: float) -> Array:
	var acc := 0.0
	for i in p.size() - 1:
		var seg := p[i].distance_to(p[i + 1])
		if acc + seg >= d or i == p.size() - 2:
			var t: float = 0.0 if seg < 0.0001 else clamp((d - acc) / seg, 0.0, 1.0)
			return [p[i].lerp(p[i + 1], t), (p[i + 1] - p[i]).normalized()]
		acc += seg
	return [p[p.size() - 1], Vector2.DOWN]

static func _round_line(ci: CanvasItem, p: PackedVector2Array, color: Color, w: float, joints: PackedVector2Array) -> void:
	if w <= 2.5:
		ci.draw_polyline(p, color, max(w, 1.0), true)
		return
	ci.draw_polyline(p, color, w, true)
	for j in joints:
		ci.draw_circle(j, w * 0.5, color)

## Stroke the bone chain `pts` (2-3 joints) in `style`. `t` is the clock for
## animated styles, `key` keeps scribble jitter stable per limb.
static func stroke(ci: CanvasItem, pts: PackedVector2Array, style: String, color: Color, w: float, t: float, key: int) -> void:
	var p := path(pts, style in SMOOTH)
	match style:
		"solid", "stick":
			_round_line(ci, p, color, w, pts)
		"noodle":
			var outline := color.darkened(0.6)
			_round_line(ci, p, outline, w + max(4.0, w * 0.28), PackedVector2Array([p[0], p[p.size() - 1]]))
			_round_line(ci, p, color, w, PackedVector2Array([p[0], p[p.size() - 1]]))
			var shine := p.duplicate()
			for i in shine.size():
				shine[i] += Vector2(-w * 0.18, -w * 0.18)
			ci.draw_polyline(shine, Color(1, 1, 1, 0.28), max(w * 0.18, 1.5), true)
		"scribble":
			var rng := RandomNumberGenerator.new()
			rng.seed = key * 7919 + int(t * 8.0) # "boiling" lines, 8 redraws a second
			var j := maxf(w * 0.35, 3.0)
			for stroke_i in 3:
				var q := p.duplicate()
				for i in q.size():
					q[i] += Vector2(rng.randf_range(-j, j), rng.randf_range(-j, j))
				ci.draw_polyline(q, color, max(w * 0.3, 2.0), true)
		"dashed":
			var total := length_of(p)
			var dash := maxf(w * 1.6, 8.0)
			var gap := maxf(w * 0.9, 6.0)
			var d := 0.0
			while d < total:
				var a: Vector2 = sample(p, d)[0]
				var b: Vector2 = sample(p, min(d + dash, total))[0]
				ci.draw_line(a, b, color, w, true)
				if w > 2.5:
					ci.draw_circle(a, w * 0.5, color)
					ci.draw_circle(b, w * 0.5, color)
				d += dash + gap
		"spring":
			var total := length_of(p)
			var pitch := maxf(w * 0.7, 6.0)
			var amp := maxf(w * 0.6, 5.0)
			var zig := PackedVector2Array()
			var d := 0.0
			var side := 1.0
			while d <= total:
				var s: Array = sample(p, d)
				var dir: Vector2 = s[1]
				zig.append(s[0] + Vector2(-dir.y, dir.x) * amp * side)
				side = -side
				d += pitch * 0.5
			zig.append(p[p.size() - 1])
			ci.draw_polyline(zig, color, max(w * 0.22, 2.5), true)
		"beads":
			var total := length_of(p)
			var step := maxf(w * 1.05, 6.0)
			var d := 0.0
			var k := 0
			while d <= total:
				var c := color if k % 2 == 0 else color.lightened(0.35)
				var at: Vector2 = sample(p, d)[0]
				ci.draw_circle(at, w * 0.55, color.darkened(0.5))
				ci.draw_circle(at, w * 0.45, c)
				d += step
				k += 1
		"rainbow":
			var d := 0.0
			for i in p.size() - 1:
				var hue := fmod(t * 0.6 + d / 260.0 + key * 0.13, 1.0)
				var c := Color.from_hsv(hue, 0.85, 1.0)
				ci.draw_line(p[i], p[i + 1], c, w, true)
				ci.draw_circle(p[i], w * 0.5, c)
				d += p[i].distance_to(p[i + 1])
			ci.draw_circle(p[p.size() - 1], w * 0.5, Color.from_hsv(fmod(t * 0.6 + d / 260.0 + key * 0.13, 1.0), 0.85, 1.0))
		"neon":
			var pulse := 0.85 + 0.15 * sin(t * 6.0 + key)
			ci.draw_polyline(p, Color(color, 0.12 * pulse), w * 2.8, true)
			ci.draw_polyline(p, Color(color, 0.25 * pulse), w * 1.7, true)
			_round_line(ci, p, color, w, PackedVector2Array([p[0], p[p.size() - 1]]))
			ci.draw_polyline(p, Color(1, 1, 1, 0.85), max(w * 0.3, 1.5), true)
		_:
			_round_line(ci, p, color, w, pts)
