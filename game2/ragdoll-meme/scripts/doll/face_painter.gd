extends RefCounted
class_name FacePainter

## Hand-drawn cartoon faces for a head of kind "face". Drawn in the head's
## own frame (origin at the centre, "up" toward the top of the head), and
## every face reacts to the head's speed: the faster it flies, the wider
## the eyes and the more the mouth becomes a scream.

const FACES := ["smile", "derp", "shock", "cool", "sleepy", "angry"]
const NAMES := {
	"smile": "Smile", "derp": "Derp", "shock": "Shock", "cool": "Cool",
	"sleepy": "Sleepy", "angry": "Angry",
}

const INK := Color("#1d1d24")

## `look` is a unit-ish vector (head-local) the pupils drift toward; `panic`
## is 0..1 from how fast the head is moving.
static func draw_face(ci: CanvasItem, face: String, r: float, look: Vector2, panic: float, t: float, key: int) -> void:
	var eye_y := -r * 0.12
	var eye_dx := r * 0.36
	var eye_r := r * (0.2 + 0.08 * panic)
	var blink := fmod(t + key * 1.37, 4.2) < 0.12 and panic < 0.3
	match face:
		"cool":
			var glass := PackedVector2Array([
				Vector2(-r * 0.78, eye_y - r * 0.2), Vector2(r * 0.78, eye_y - r * 0.2),
				Vector2(r * 0.7, eye_y + r * 0.08), Vector2(r * 0.12, eye_y + r * 0.1),
				Vector2(0, eye_y - r * 0.02), Vector2(-r * 0.12, eye_y + r * 0.1),
				Vector2(-r * 0.7, eye_y + r * 0.08),
			])
			ci.draw_colored_polygon(glass, INK)
			ci.draw_line(Vector2(-r * 0.5, eye_y - r * 0.12), Vector2(-r * 0.3, eye_y - r * 0.12), Color(1, 1, 1, 0.6), max(r * 0.05, 1.5))
		"sleepy":
			for s in [-1.0, 1.0]:
				ci.draw_arc(Vector2(eye_dx * s, eye_y), eye_r, 0.2, PI - 0.2, 8, INK, max(r * 0.07, 2.0), true)
		"derp":
			_eye(ci, Vector2(-eye_dx, eye_y), eye_r * 1.25, Vector2(0.6, 0.3), blink)
			_eye(ci, Vector2(eye_dx, eye_y - r * 0.06), eye_r * 0.8, Vector2(-0.7, -0.4), blink)
		"angry":
			for s in [-1.0, 1.0]:
				_eye(ci, Vector2(eye_dx * s, eye_y), eye_r, look, blink)
				ci.draw_line(Vector2(eye_dx * s * 0.35, eye_y - eye_r * 1.1), Vector2(eye_dx * s * 1.5, eye_y - eye_r * 1.9), INK, max(r * 0.09, 2.0), true)
		_:
			for s in [-1.0, 1.0]:
				_eye(ci, Vector2(eye_dx * s, eye_y), eye_r * (1.3 if face == "shock" else 1.0), look, blink)
	var scream: float = clamp(panic + (0.8 if face == "shock" else 0.0), 0.0, 1.0)
	var mouth_c := Vector2(0, r * 0.42)
	if scream > 0.35:
		var mw := r * (0.18 + 0.2 * scream)
		var mh := r * (0.14 + 0.26 * scream)
		_ellipse(ci, mouth_c + Vector2(0, mh * 0.2), mw, mh, INK)
		_ellipse(ci, mouth_c + Vector2(0, mh * 0.75), mw * 0.6, mh * 0.35, Color("#ff5d73"))
	elif face == "angry":
		ci.draw_arc(mouth_c + Vector2(0, r * 0.22), r * 0.3, -PI + 0.5, -0.5, 10, INK, max(r * 0.08, 2.0), true)
	elif face == "derp":
		ci.draw_arc(mouth_c + Vector2(r * 0.05, -r * 0.05), r * 0.32, 0.25, PI - 0.6, 10, INK, max(r * 0.08, 2.0), true)
		ci.draw_rect(Rect2(mouth_c + Vector2(-r * 0.02, r * 0.2), Vector2(r * 0.16, r * 0.14)), Color.WHITE)
	elif face == "sleepy":
		_ellipse(ci, mouth_c + Vector2(0, r * 0.05), r * 0.1, r * 0.08, INK)
	else:
		ci.draw_arc(mouth_c - Vector2(0, r * 0.12), r * 0.34, 0.35, PI - 0.35, 12, INK, max(r * 0.08, 2.0), true)

static func _eye(ci: CanvasItem, c: Vector2, er: float, look: Vector2, blink: bool) -> void:
	if blink:
		ci.draw_line(c - Vector2(er, 0), c + Vector2(er, 0), INK, max(er * 0.3, 2.0), true)
		return
	ci.draw_circle(c, er, Color.WHITE)
	ci.draw_arc(c, er, 0, TAU, 16, INK, max(er * 0.14, 1.5), true)
	ci.draw_circle(c + look.limit_length(1.0) * er * 0.45, er * 0.45, INK)

static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, color)
