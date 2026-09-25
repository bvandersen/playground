extends RefCounted
class_name PersonArt

## Tiny people seen from straight above, no image assets: a random `look`
## (size, skin, hair and hairstyle, hat, outfit, shoes, bag, maybe a
## balloon) painted as a handful of shapes -- shoulders, arms swinging,
## feet stepping out from under the body, head, hair, hat. They're toy
## scale, not true scale: an adult is about 9 px across the shoulders
## beside an 18 px wide coach, so they read at a glance.
##
## Painted facing +x at unit size, one frame per step of the walk cycle
## plus one standing still. Each frame is baked once into a flat triangle
## list (points + colours) on the look itself; PeopleView then only
## transforms those into one shared mesh per frame -- every person on the
## layout in a single draw call.

const FRAMES := 8 # walk cycle frames; frame FRAMES is standing still
const STRIDE := 7.0 # px walked per full cycle at size 1
## Everyone is drawn this much bigger than PersonArt's unit (painted) size.
const WORLD_SCALE := 1.3

const SKINS := [
	Color(1.0, 0.87, 0.74), Color(0.96, 0.78, 0.62), Color(0.87, 0.66, 0.48),
	Color(0.72, 0.5, 0.33), Color(0.55, 0.36, 0.23), Color(0.4, 0.26, 0.17),
]
const HAIRS := [
	Color(0.08, 0.07, 0.07), Color(0.22, 0.14, 0.09), Color(0.42, 0.26, 0.14),
	Color(0.62, 0.3, 0.14), Color(0.9, 0.76, 0.42), Color(0.97, 0.9, 0.62),
	Color(0.7, 0.7, 0.72), Color(0.93, 0.93, 0.93),
]
const FUN_HAIRS := [Color(0.95, 0.4, 0.7), Color(0.3, 0.6, 0.95), Color(0.5, 0.85, 0.5), Color(0.62, 0.36, 0.85)]
const CLOTHES := [
	Color(0.86, 0.2, 0.2), Color(0.95, 0.5, 0.12), Color(0.98, 0.8, 0.2), Color(0.3, 0.7, 0.3),
	Color(0.15, 0.55, 0.55), Color(0.2, 0.42, 0.85), Color(0.14, 0.2, 0.42), Color(0.52, 0.3, 0.72),
	Color(0.92, 0.46, 0.64), Color(0.95, 0.95, 0.93), Color(0.2, 0.2, 0.22), Color(0.55, 0.4, 0.28),
	Color(0.62, 0.64, 0.66), Color(0.55, 0.7, 0.95), Color(0.7, 0.9, 0.55),
]
const LEGS := [
	Color(0.16, 0.22, 0.38), Color(0.12, 0.12, 0.14), Color(0.4, 0.33, 0.25),
	Color(0.5, 0.52, 0.55), Color(0.3, 0.36, 0.22), Color(0.72, 0.64, 0.5),
]
const SHOES := [Color(0.1, 0.1, 0.1), Color(0.35, 0.2, 0.12), Color(0.92, 0.92, 0.92), Color(0.8, 0.2, 0.2), Color(0.2, 0.4, 0.8)]
const HAIR_STYLES := ["short", "short", "long", "long", "bun", "ponytail", "curly", "bald"]
const KID_HAIR_STYLES := ["short", "long", "ponytail", "pigtails", "pigtails", "curly"]
const HATS := ["cap", "sunhat", "beanie", "bowler"]
const OUTFITS := ["shirt", "shirt", "stripes", "coat", "coat", "dress", "hoodie"]
const BAGS := ["", "", "", "backpack", "backpack", "handbag", "suitcase"]

const DARK := Color(0.1, 0.09, 0.09, 0.85)

## A new random passenger. `size` 1 is an adult of average height.
static func random_look() -> Dictionary:
	var kid := randf() < 0.28
	var old := not kid and randf() < 0.15
	var look := {
		"kid": kid,
		"size": randf_range(0.6, 0.74) if kid else randf_range(0.9, 1.14),
		"skin": _pick(SKINS),
		"hair": _pick(HAIRS.slice(0, 6)) if not old else _pick([HAIRS[6], HAIRS[7]]),
		"style": _pick(KID_HAIR_STYLES if kid else HAIR_STYLES),
		"hat": "",
		"hat_color": _pick(CLOTHES),
		"outfit": _pick(OUTFITS),
		"top": _pick(CLOTHES),
		"accent": _pick(CLOTHES),
		"legs": _pick(LEGS) if not kid or randf() < 0.5 else _pick(CLOTHES),
		"shoes": _pick(SHOES),
		"bag": _pick(BAGS) if not kid else _pick(["", "", "backpack"]),
		"bag_color": _pick(CLOTHES).darkened(0.15),
		"balloon": kid and randf() < 0.3,
		"balloon_color": _pick([Color(0.95, 0.2, 0.25), Color(0.25, 0.55, 0.95), Color(1.0, 0.85, 0.2), Color(0.95, 0.45, 0.75), Color(0.4, 0.85, 0.4)]),
	}
	if randf() < 0.07:
		look["hair"] = _pick(FUN_HAIRS)
	if randf() < (0.4 if old else 0.25):
		look["hat"] = "bowler" if old and randf() < 0.5 else _pick(HATS)
	if look["style"] == "bald" and look["hat"] == "" and randf() < 0.5:
		look["hat"] = "cap"
	return look

static func _pick(a: Array):
	return a[randi() % a.size()]

## Walk-cycle frame index for a person who has walked `dist` px.
static func walk_frame(look: Dictionary, dist: float) -> int:
	var cycle := STRIDE * float(look["size"]) * WORLD_SCALE
	return int(fposmod(dist / cycle, 1.0) * FRAMES) % FRAMES

## Frame `f` of `look` as [points, colours], baked on first use.
static func frame(look: Dictionary, f: int) -> Array:
	if not look.has("_frames"):
		var empty := []
		empty.resize(FRAMES + 1)
		look["_frames"] = empty
	var frames: Array = look["_frames"]
	if frames[f] == null:
		var b := TriBatch.new()
		paint(b, look, float(f) / FRAMES, f < FRAMES)
		frames[f] = [b.points, b.colors]
	return frames[f]

## Frame `f` as its own mesh, for a person drawn fading in or out.
static func frame_mesh(look: Dictionary, f: int) -> ArrayMesh:
	var key := "_mesh%d" % f
	if not look.has(key):
		var fr := frame(look, f)
		var b := TriBatch.new()
		b.points = fr[0]
		b.colors = fr[1]
		look[key] = b.to_mesh()
	return look[key]

# --- Painting ------------------------------------------------------------------

static func ellipse(ci, c: Vector2, rx: float, ry: float, col: Color, segs: int = 12) -> void:
	var pts := PackedVector2Array()
	for i in range(segs):
		var a := TAU * i / segs
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)

## `look` at unit size facing +x, `phase` 0..1 through a stride.
static func paint(ci, look: Dictionary, phase: float, walking: bool) -> void:
	var skin: Color = look["skin"]
	var top: Color = look["top"]
	var hair: Color = look["hair"]
	var outfit: String = look["outfit"]
	var swing := sin(phase * TAU) if walking else 0.0
	var reach := 2.1
	# Left foot (y < 0) steps forward as the right one goes back.
	var feet := [swing * reach, -swing * reach]

	# Suitcase first: it rolls along behind, on the right hand's side.
	var hand_r := Vector2(-feet[1] * 0.6 + 0.2, 3.7)
	if look["bag"] == "suitcase":
		var case_c := Vector2(hand_r.x - 3.4, 4.6)
		ellipse(ci, case_c + Vector2(0.4, 0.5), 2.6, 1.6, Color(0, 0, 0, 0.18), 10)
		ci.draw_rect(Rect2(case_c - Vector2(2.3, 1.3), Vector2(4.6, 2.6)), look["bag_color"])
		ci.draw_rect(Rect2(case_c - Vector2(2.3, 1.3), Vector2(4.6, 0.7)), (look["bag_color"] as Color).lightened(0.25))
		ci.draw_line(case_c + Vector2(2.3, 0.0), hand_r, DARK, 0.5)

	# Legs and shoes peeking out front and back.
	for k in range(2):
		var side := -1.0 if k == 0 else 1.0
		var fx: float = feet[k]
		if outfit != "dress":
			ci.draw_line(Vector2(0.0, side * 1.25), Vector2(fx, side * 1.3), look["legs"], 1.9)
		ellipse(ci, Vector2(fx + 0.55, side * 1.3), 1.15, 0.8, look["shoes"], 8)
	if outfit == "dress":
		ellipse(ci, Vector2(-0.1, 0.0), 2.9, 3.8, top.darkened(0.12))

	# Arms swing opposite to the feet.
	var sleeve := top.darkened(0.08) if outfit != "hoodie" else top.darkened(0.15)
	for k in range(2):
		var side := -1.0 if k == 0 else 1.0
		var hand := Vector2(-float(feet[k]) * 0.6 + 0.2, side * 3.7)
		ci.draw_line(Vector2(0.2, side * 2.9), hand, DARK, 1.9)
		ci.draw_line(Vector2(0.2, side * 2.9), hand, sleeve, 1.4)
		ci.draw_circle(hand, 0.72, skin)
	if look["bag"] == "handbag":
		ellipse(ci, Vector2(-0.4, -4.5), 1.4, 0.9, look["bag_color"], 10)
		ci.draw_line(Vector2(-0.4, -3.8), Vector2(0.2, -3.0), DARK, 0.4)

	# Backpack on the back.
	if look["bag"] == "backpack":
		var bag: Color = look["bag_color"]
		ci.draw_rect(Rect2(-4.3, -2.4, 2.8, 4.8), bag.darkened(0.3))
		ci.draw_rect(Rect2(-4.0, -2.1, 2.3, 4.2), bag)
		ci.draw_rect(Rect2(-4.0, -1.4, 0.9, 2.8), bag.lightened(0.18))

	# Shoulders.
	ellipse(ci, Vector2.ZERO, 2.3, 3.7, DARK, 14)
	ellipse(ci, Vector2.ZERO, 1.95, 3.35, top, 14)
	match outfit:
		"stripes":
			for x in [-1.1, 0.0, 1.1]:
				var h := sqrt(maxf(1.0 - pow(x / 1.95, 2.0), 0.0)) * 3.2
				ci.draw_line(Vector2(x, -h), Vector2(x, h), look["accent"], 0.45)
		"coat":
			ellipse(ci, Vector2(-0.35, 0.0), 1.5, 3.1, top.darkened(0.1), 12)
			ci.draw_line(Vector2(1.9, 0.0), Vector2(0.9, -1.4), top.darkened(0.35), 0.45)
			ci.draw_line(Vector2(1.9, 0.0), Vector2(0.9, 1.4), top.darkened(0.35), 0.45)
		"hoodie":
			ellipse(ci, Vector2(-1.75, 0.0), 1.2, 1.9, top.darkened(0.18), 10)
		"dress":
			ci.draw_line(Vector2(1.5, -1.6), Vector2(1.5, 1.6), look["accent"], 0.5)

	# Head, then hair and hat on top of it.
	var head := Vector2(0.35, 0.0)
	ci.draw_circle(head, 2.2, DARK)
	ci.draw_circle(head, 1.9, skin)
	ci.draw_circle(head + Vector2(1.85, 0.0), 0.36, skin.darkened(0.12)) # nose: which way they face
	match look["style"]:
		"short":
			ellipse(ci, head + Vector2(-0.4, 0.0), 1.55, 1.8, hair)
		"long":
			ellipse(ci, head + Vector2(-1.5, 0.0), 1.6, 2.25, hair)
			ellipse(ci, head + Vector2(-0.3, 0.0), 1.6, 1.9, hair)
		"bun":
			ellipse(ci, head + Vector2(-0.35, 0.0), 1.6, 1.85, hair)
			ci.draw_circle(head + Vector2(-1.3, 0.0), 0.95, hair.darkened(0.12))
		"ponytail":
			ellipse(ci, head + Vector2(-0.4, 0.0), 1.55, 1.85, hair)
			ellipse(ci, head + Vector2(-2.6, 0.0), 1.2, 0.65, hair.darkened(0.08), 10)
		"pigtails":
			ellipse(ci, head + Vector2(-0.4, 0.0), 1.55, 1.85, hair)
			ci.draw_circle(head + Vector2(-0.9, -2.0), 0.8, hair.darkened(0.08))
			ci.draw_circle(head + Vector2(-0.9, 2.0), 0.8, hair.darkened(0.08))
		"curly":
			for i in range(7):
				var a := PI * 0.55 + i * PI * 0.9 / 6.0
				ci.draw_circle(head + Vector2.from_angle(a) * 1.35, 0.95, hair)
			ci.draw_circle(head + Vector2(-0.5, 0.0), 1.3, hair)
		"bald":
			ci.draw_circle(head + Vector2(-0.3, -0.5), 0.55, skin.lightened(0.3))
	var hat_col: Color = look["hat_color"]
	match look["hat"]:
		"cap":
			ci.draw_circle(head + Vector2(-0.1, 0.0), 1.85, hat_col)
			ellipse(ci, head + Vector2(1.75, 0.0), 1.05, 1.45, hat_col.darkened(0.2), 10)
			ci.draw_circle(head + Vector2(-0.1, 0.0), 0.35, hat_col.lightened(0.3))
		"sunhat":
			ci.draw_circle(head, 3.3, hat_col.lightened(0.35))
			ci.draw_arc(head, 3.25, 0.0, TAU, 20, hat_col.lightened(0.15), 0.35)
			ci.draw_circle(head, 1.9, hat_col.lightened(0.2))
			ci.draw_arc(head, 1.95, 0.0, TAU, 16, hat_col.darkened(0.2), 0.5)
		"beanie":
			ci.draw_circle(head + Vector2(-0.1, 0.0), 1.95, hat_col)
			ci.draw_circle(head + Vector2(-0.2, 0.0), 0.75, hat_col.lightened(0.4))
		"bowler":
			ci.draw_circle(head, 2.55, Color(0.12, 0.11, 0.11))
			ci.draw_circle(head, 1.75, Color(0.2, 0.19, 0.19))

	# A kid's balloon floats above everything, on a string from the hand.
	if look["balloon"]:
		var hand := Vector2(-float(feet[1]) * 0.6 + 0.2, 3.7)
		var ball := Vector2(-1.5, 6.4)
		ci.draw_line(hand, ball + Vector2(0.4, -1.9), Color(0.95, 0.95, 0.95, 0.9), 0.3)
		ellipse(ci, ball + Vector2(1.2, 1.6), 2.3, 2.6, Color(0, 0, 0, 0.12), 12)
		ellipse(ci, ball, 2.2, 2.5, look["balloon_color"], 14)
		ci.draw_circle(ball + Vector2(-0.7, -0.8), 0.55, (look["balloon_color"] as Color).lightened(0.55))
