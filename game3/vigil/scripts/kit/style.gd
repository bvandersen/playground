class_name Style
extends RefCounted

## A rite's look (docs/game3.md, "Every rite has its own look"): ground,
## ink, how a line is laid down, typeface, grain and the colour the host
## fades through. Every recipe carries its own `style` object; engines
## draw only through this, never with their own colours or fonts, so the
## same engine can look like ink on vellum one day and a dying terminal
## the next. Registry refuses two recipes with the same look.

const GROUNDS := ["void", "radial", "paper", "stars", "crt"]
const STROKES := ["line", "glow", "brush", "hair", "pixel", "nib"]
const FONTS := {
	"cinzel": "res://fonts/Cinzel.ttf",
	"fell": "res://fonts/IMFellEnglish-Italic.ttf",
	"fraktur": "res://fonts/UnifrakturMaguntia.ttf",
	"vt323": "res://fonts/VT323.ttf",
	"major_mono": "res://fonts/MajorMonoDisplay.ttf",
	"cormorant": "res://fonts/CormorantGaramond-Italic.ttf",
}
const CASES := ["as_is", "upper", "lower"]

const GRAIN_FRAMES := 6
const GRAIN_W := 120
const GRAIN_H := 200
const GRAIN_FPS := 24.0
const BAKE_W := 160 # baked grounds (radial, paper), scaled up smoothly
const BAKE_H := 266
const STARS := 150

## Every key and its default. A recipe's `style` overrides any subset.
static func defaults() -> Dictionary:
	return {
		"ground": "void",
		"ground_colors": ["#07070a", "#07070a"], # centre/top, edge/bottom
		"ink": "#d9d1bd",
		"stroke": "line",
		"weight": 1.0, # multiplies every stroke width
		"nib_angle": 35.0, # degrees; the "nib" stroke's pen angle
		"font": "",
		"text_case": "as_is",
		"text_scale": 1.0,
		"tracking": 0, # extra px between letters
		"grain": 0.0, # resting grain opacity
		"grain_color": "#ffffff",
		"fade": "#07070a", # what the host fades through, in and out
	}

## "" when `s` is a usable style object; otherwise what's wrong.
static func validate(s) -> String:
	if not s is Dictionary:
		return "style must be an object"
	var d := defaults()
	for k in s:
		if not d.has(k):
			return "unknown style key %s" % k
	if not str(s.get("ground", "void")) in GROUNDS:
		return "unknown ground %s" % s["ground"]
	if not str(s.get("stroke", "line")) in STROKES:
		return "unknown stroke %s" % s["stroke"]
	if s.get("font", "") != "" and not FONTS.has(s["font"]):
		return "unknown font %s" % s["font"]
	if not str(s.get("text_case", "as_is")) in CASES:
		return "unknown text_case %s" % s["text_case"]
	return ""

## What makes two looks the same to the eye; no two recipes may share one.
static func signature(s: Dictionary) -> String:
	var d := defaults()
	d.merge(s, true)
	return "%s|%s|%s|%s" % [d["ground"], d["stroke"], d["font"], Color(d["ink"]).to_html(false)]

var data: Dictionary = {}
var ink: Color
var grain_color: Color
var fade: Color
var seed := 0
var _font: Font = null
var _ground: CanvasTexture = null
var _grain: Array = [] # of CanvasTexture
var _stars: Array = [] # [position 0..1, size, twinkle phase, twinkle rate]

static func make(s: Dictionary, with_seed: int) -> Style:
	var st := Style.new()
	st.data = defaults()
	st.data.merge(s, true)
	st.seed = with_seed
	st.ink = Color(st.data["ink"])
	st.grain_color = Color(st.data["grain_color"])
	st.fade = Color(st.data["fade"])
	return st

## The look of a recipe (seeded by its id, so a rite always looks like itself).
static func for_recipe(r: Dictionary) -> Style:
	return make(r.get("style", {}), str(r.get("id", "")).hash())

func stroke_kind() -> String:
	return data["stroke"]

# --- ground and grain -------------------------------------------------

func draw_ground(ci: CanvasItem, size: Vector2, t: float) -> void:
	var cols: Array = data["ground_colors"]
	var a := Color(cols[0])
	var b := Color(cols[1])
	match str(data["ground"]):
		"void":
			ci.draw_rect(Rect2(Vector2.ZERO, size), a)
		"radial", "paper":
			if _ground == null:
				_ground = _canvas_tex(_bake_ground(a, b), CanvasItem.TEXTURE_FILTER_LINEAR)
			ci.draw_texture_rect(_ground, Rect2(Vector2.ZERO, size), false)
		"stars":
			_draw_stars(ci, size, t, a, b)
		"crt":
			ci.draw_rect(Rect2(Vector2.ZERO, size), a)
			var roll := fmod(t * 38.0, size.y + 160.0) - 80.0
			ci.draw_rect(Rect2(0, roll, size.x, 80), Color(ink, 0.035))
			var y := 0.0
			while y < size.y:
				ci.draw_rect(Rect2(0, y, size.x, 1), Color(b, 0.55))
				y += 3.0

## Film grain in the style's grain colour. amount < 0 -> the resting grain.
func draw_grain(ci: CanvasItem, size: Vector2, t: float, amount: float = -1.0) -> void:
	var a := float(data["grain"]) if amount < 0.0 else amount
	if a <= 0.001:
		return
	if _grain.is_empty():
		var g := RandomNumberGenerator.new()
		g.seed = seed
		for i in GRAIN_FRAMES:
			_grain.append(_canvas_tex(_grain_frame(g), CanvasItem.TEXTURE_FILTER_NEAREST))
	# Frames in a scrambled but fixed order, so it never visibly loops.
	var f := int(t * GRAIN_FPS)
	var i := posmod(f * 7 + (f >> 2) * 3, GRAIN_FRAMES)
	ci.draw_texture_rect(_grain[i], Rect2(Vector2.ZERO, size), false, Color(grain_color, a))

func _grain_frame(g: RandomNumberGenerator) -> Image:
	var bytes := PackedByteArray()
	bytes.resize(GRAIN_W * GRAIN_H * 2)
	for i in GRAIN_W * GRAIN_H:
		bytes[i * 2] = 255
		bytes[i * 2 + 1] = g.randi() & 0xff
	return Image.create_from_data(GRAIN_W, GRAIN_H, false, Image.FORMAT_LA8, bytes)

## radial: a to b from the centre out. paper: a and b mottled, with
## fibres and a darker edge, like old stock.
func _bake_ground(a: Color, b: Color) -> Image:
	var img := Image.create(BAKE_W, BAKE_H, false, Image.FORMAT_RGB8)
	var paper := str(data["ground"]) == "paper"
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = 0.035
	n.fractal_octaves = 4
	var centre := Vector2(BAKE_W, BAKE_H) * 0.5
	var reach := centre.length()
	for y in BAKE_H:
		for x in BAKE_W:
			var d := Vector2(x, y).distance_to(centre) / reach
			var c: Color
			if paper:
				var m := 0.5 + 0.5 * n.get_noise_2d(x, y * 0.8)
				c = a.lerp(b, clampf(m * 0.8 + pow(d, 2.2) * 0.7, 0.0, 1.0))
			else:
				c = a.lerp(b, smoothstep(0.0, 1.0, d * 1.15))
			img.set_pixel(x, y, c)
	if paper:
		var g := RandomNumberGenerator.new()
		g.seed = seed + 1
		for k in 70: # fibres: short, faint, mostly horizontal
			var p := Vector2(g.randf() * BAKE_W, g.randf() * BAKE_H)
			var dir := Vector2.from_angle(g.randf_range(-0.5, 0.5))
			var shade := b.darkened(0.12)
			for s in g.randi_range(4, 14):
				var q := (p + dir * s).floor()
				if q.x >= 0 and q.y >= 0 and q.x < BAKE_W and q.y < BAKE_H:
					img.set_pixelv(Vector2i(q), img.get_pixelv(Vector2i(q)).lerp(shade, 0.35))
	return img

func _draw_stars(ci: CanvasItem, size: Vector2, t: float, top: Color, bottom: Color) -> void:
	var bands := 24
	for i in bands:
		var y0 := size.y * i / bands
		ci.draw_rect(Rect2(0, y0, size.x, size.y / bands + 1.0), top.lerp(bottom, float(i) / (bands - 1)))
	if _stars.is_empty():
		var g := RandomNumberGenerator.new()
		g.seed = seed
		for i in STARS:
			_stars.append([Vector2(g.randf(), g.randf()), g.randf_range(0.5, 1.6) * (2.2 if g.randf() < 0.05 else 1.0),
				g.randf() * TAU, g.randf_range(0.3, 1.4)])
	# The whole sky turns, very slowly, about a point below the screen.
	var pole := Vector2(size.x * 0.5, size.y * 1.3)
	for s in _stars:
		var p: Vector2 = (s[0] * Vector2(size.x, size.y) * 1.6 - size * 0.3)
		p = pole + (p - pole).rotated(t * 0.006)
		var tw := 0.35 + 0.45 * (0.5 + 0.5 * sin(t * float(s[3]) + float(s[2])))
		ci.draw_circle(p, float(s[1]), Color(ink, tw * 0.8), true, -1.0, true)

static func _canvas_tex(img: Image, filter: int) -> CanvasTexture:
	var ct := CanvasTexture.new()
	ct.diffuse_texture = ImageTexture.create_from_image(img)
	ct.texture_filter = filter
	return ct

# --- lines -------------------------------------------------------------

## Draws the polyline `pts` in this style's hand. `w` is the engine's base
## width (before the style's weight); `col` defaults to the ink.
func stroke(ci: CanvasItem, pts: PackedVector2Array, w: float, col: Color = ink) -> void:
	if pts.size() < 2:
		return
	w *= float(data["weight"])
	match str(data["stroke"]):
		"line":
			ci.draw_polyline(pts, col, w, true)
		"glow":
			ci.draw_polyline(pts, Color(col, col.a * 0.05), w * 8.0, true)
			ci.draw_polyline(pts, Color(col, col.a * 0.12), w * 3.5, true)
			ci.draw_polyline(pts, col.lightened(0.35), w, true)
		"hair":
			ci.draw_polyline(pts, Color(col, col.a * 0.85), maxf(1.0, w * 0.45), true)
			_beads(ci, pts, w, col)
		"brush":
			_brush(ci, pts, w, col)
		"nib":
			_nib(ci, pts, w, col)
		"pixel":
			_pixels(ci, pts, w, col)

## One mark (a dissolving speck, a point) in this style's hand.
func dot(ci: CanvasItem, pos: Vector2, w: float, col: Color = ink) -> void:
	w *= float(data["weight"])
	match str(data["stroke"]):
		"pixel":
			var cell := _cell(w)
			ci.draw_rect(Rect2((pos / cell).floor() * cell, Vector2(cell, cell)), col)
		"brush", "hair", "glow":
			ci.draw_circle(pos, w * 0.5, col, true, -1.0, true)
		_:
			ci.draw_rect(Rect2(pos - Vector2(w, w) * 0.5, Vector2(w, w)), col)

static func circle(centre: Vector2, r: float, n: int = 160) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(centre + Vector2.from_angle(TAU * i / n) * r)
	return pts

## Star charts: a bead wherever a long segment starts or ends.
func _beads(ci: CanvasItem, pts: PackedVector2Array, w: float, col: Color) -> void:
	for i in pts.size():
		var long := (i > 0 and pts[i].distance_to(pts[i - 1]) > 14.0) \
			or (i < pts.size() - 1 and pts[i].distance_to(pts[i + 1]) > 14.0)
		if long or i == 0 or i == pts.size() - 1:
			ci.draw_circle(pts[i], maxf(1.6, w * 0.9), col, true, -1.0, true)

## Ink from a loaded brush: width swells and thins along the stroke (by
## arc length, so a moving shape doesn't shimmer), tapered where it starts
## and lifts, with a dry second pass beside it.
func _brush(ci: CanvasItem, pts: PackedVector2Array, w: float, col: Color) -> void:
	var s := _resample(pts, 3.0)
	if s.size() < 2:
		return
	var total := 0.0
	for i in s.size() - 1:
		total += s[i].distance_to(s[i + 1])
	var ph := float(seed % 97)
	var along := 0.0
	var widths := PackedFloat32Array()
	for i in s.size():
		if i > 0:
			along += s[i].distance_to(s[i - 1])
		var swell := 0.62 + 0.28 * sin(along * 0.021 + ph) + 0.1 * sin(along * 0.083 + ph * 2.0)
		var taper := minf(1.0, minf(along / 18.0, (total - along) / 26.0))
		widths.append(w * 1.5 * swell * (0.25 + 0.75 * clampf(taper, 0.0, 1.0)))
	_strip(ci, s, widths, col, Vector2.ZERO)
	for i in widths.size():
		widths[i] *= 0.3
	_strip(ci, s, widths, Color(col, col.a * 0.35), Vector2(w * 0.9, -w * 0.6))

## A broad nib held at a fixed angle: thick across it, hairline along it.
func _nib(ci: CanvasItem, pts: PackedVector2Array, w: float, col: Color) -> void:
	var half := Vector2.from_angle(deg_to_rad(float(data["nib_angle"]))) * w * 1.6
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		ci.draw_colored_polygon(PackedVector2Array([a - half, a + half, b + half, b - half]), col)
	ci.draw_polyline(pts, col, 1.0, true) # keeps the hairlines unbroken

func _cell(w: float) -> float:
	return maxf(3.0, roundf(w * 1.7))

## Snapped to a coarse grid, like a screen with too few pixels.
func _pixels(ci: CanvasItem, pts: PackedVector2Array, w: float, col: Color) -> void:
	var cell := _cell(w)
	var cells := {}
	for p in _resample(pts, cell * 0.5):
		cells[Vector2i((p / cell).floor())] = true
	for c in cells:
		ci.draw_rect(Rect2(Vector2(c) * cell - Vector2(cell, cell) * 0.5, Vector2(cell, cell) * 2.0), Color(col, col.a * 0.08))
	for c in cells:
		ci.draw_rect(Rect2(Vector2(c) * cell, Vector2(cell, cell) - Vector2(1, 1)), col)

## A filled strip of varying width along `s` (quads between samples).
static func _strip(ci: CanvasItem, s: PackedVector2Array, widths: PackedFloat32Array, col: Color, shift: Vector2) -> void:
	for i in s.size() - 1:
		var d := (s[i + 1] - s[i]).normalized()
		var nrm := Vector2(-d.y, d.x)
		var a := s[i] + shift
		var b := s[i + 1] + shift
		var wa := nrm * widths[i] * 0.5
		var wb := nrm * widths[i + 1] * 0.5
		ci.draw_colored_polygon(PackedVector2Array([a - wa, a + wa, b + wb, b - wb]), col)
		ci.draw_circle(b, widths[i + 1] * 0.5, col)

static func _resample(pts: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var n := maxi(1, int(a.distance_to(b) / step))
		for k in range(1, n + 1):
			out.append(a.lerp(b, float(k) / n))
	return out

# --- words -------------------------------------------------------------

## Font, size, colour and letter spacing for a label in this style.
func dress(l: Label, font_size: int, col: Color = ink) -> void:
	var f := font()
	if f:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", int(round(font_size * float(data["text_scale"]))))
	l.add_theme_color_override("font_color", col)
	l.uppercase = data["text_case"] == "upper"

## `s` in this style's letter case.
func text(s: String) -> String:
	return s.to_lower() if data["text_case"] == "lower" else s

func font() -> Font:
	if _font == null and str(data["font"]) != "":
		var base = load(FONTS[data["font"]])
		if base is Font:
			var v := FontVariation.new()
			v.base_font = base
			v.spacing_glyph = int(data["tracking"])
			_font = v
	return _font
