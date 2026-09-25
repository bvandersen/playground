extends RefCounted
class_name PersonArt

## Tiny people seen from straight above, no image assets: a random `look`
## (size, skin, hair and hairstyle, hat, outfit, shoes, bag, maybe a
## balloon, a dog on a lead, a bike or a wheelchair) painted as a handful of shapes -- shoulders, arms swinging,
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

## How often someone turns up with a dog, a bike or in a wheelchair, as
## near to the real US odds as the data goes:
## - Wheelchair: ~3.6 million Americans 15+ use one (Census SIPP), about
##   1.5% of adults, and people over 65 are about four times likelier
##   than younger adults. Children rarely do.
## - Bike: 1% of all US trips are by bike (2022 NHTS).
## - Dog: walking the dog is ~3% of walking trips (NHTS), and walking is
##   ~10% of all trips, so ~0.3% of trips are with a dog on a lead.
const WHEELCHAIR_KID := 0.002
const WHEELCHAIR_ADULT := 0.01
const WHEELCHAIR_OLD := 0.04
const BIKE := 0.01
const DOG := 0.003

## Dog coats.
const D_BLACK := Color(0.13, 0.12, 0.11)
const D_CHOC := Color(0.4, 0.25, 0.15)
const D_YELLOW := Color(0.92, 0.8, 0.56)
const D_GOLD := Color(0.86, 0.6, 0.3)
const D_TAN := Color(0.74, 0.52, 0.3)
const D_RED := Color(0.72, 0.38, 0.18)
const D_FAWN := Color(0.84, 0.68, 0.48)
const D_CREAM := Color(0.95, 0.9, 0.78)
const D_WHITE := Color(0.96, 0.95, 0.92)
const D_GREY := Color(0.56, 0.56, 0.6)
const D_BRINDLE := Color(0.36, 0.27, 0.19)
const D_BLUE := Color(0.42, 0.45, 0.5)

## Breeds, weighted by roughly how many of America's ~90 million dogs
## they are: about half are mixed breeds; the rest follow the AKC's 2025
## popularity ranking plus the pit bull types (not AKC-registered, but
## among the commonest dogs in US homes and shelters). `len` is nose to
## tail at 1 = a Labrador, `wide` how stocky, `marks` a coat pattern.
const DOG_BREEDS := [
	{"breed": "mixed", "w": 50.0},
	{"breed": "labrador", "w": 7.0, "len": 1.0, "wide": 1.0, "coat": [D_YELLOW, D_BLACK, D_CHOC], "ears": "floppy", "snout": 1.0, "tail": "long"},
	{"breed": "golden retriever", "w": 4.5, "len": 1.0, "wide": 1.0, "coat": [D_GOLD, D_YELLOW], "ears": "floppy", "snout": 1.0, "tail": "plume", "fluffy": true},
	{"breed": "german shepherd", "w": 4.5, "len": 1.05, "wide": 0.95, "coat": [D_TAN], "ears": "pointy", "snout": 1.15, "tail": "plume", "marks": "saddle"},
	{"breed": "french bulldog", "w": 4.5, "len": 0.5, "wide": 1.35, "coat": [D_FAWN, D_BRINDLE, D_CREAM], "ears": "bat", "snout": 0.3, "tail": "stub", "marks": "mask"},
	{"breed": "pit bull", "w": 4.0, "len": 0.85, "wide": 1.25, "coat": [D_BLUE, D_BRINDLE, D_FAWN, D_WHITE, D_BLACK], "ears": "folded", "snout": 0.8, "tail": "long"},
	{"breed": "dachshund", "w": 3.5, "len": 0.62, "wide": 0.7, "coat": [D_RED, D_BLACK], "ears": "floppy", "snout": 1.2, "tail": "long", "marks": "tan_points"},
	{"breed": "chihuahua", "w": 3.5, "len": 0.36, "wide": 0.9, "coat": [D_FAWN, D_CREAM, D_BLACK], "ears": "bat", "snout": 0.5, "tail": "curl"},
	{"breed": "poodle", "w": 3.0, "len": 0.8, "wide": 0.9, "coat": [D_WHITE, D_BLACK, D_CREAM, D_CHOC], "ears": "floppy", "snout": 1.1, "tail": "pom", "fluffy": true},
	{"breed": "beagle", "w": 3.0, "len": 0.62, "wide": 1.0, "coat": [D_TAN], "ears": "floppy", "snout": 0.9, "tail": "long", "marks": "tricolor"},
	{"breed": "yorkshire terrier", "w": 2.5, "len": 0.34, "wide": 0.95, "coat": [D_TAN], "ears": "pointy", "snout": 0.6, "tail": "stub", "marks": "yorkie", "fluffy": true},
	{"breed": "shih tzu", "w": 2.5, "len": 0.42, "wide": 1.1, "coat": [D_WHITE, D_GOLD, D_CREAM], "ears": "floppy", "snout": 0.3, "tail": "curl", "fluffy": true, "marks": "patches"},
	{"breed": "siberian husky", "w": 2.0, "len": 0.92, "wide": 1.0, "coat": [D_GREY, D_BLACK, D_RED], "ears": "pointy", "snout": 1.0, "tail": "curl", "marks": "husky", "fluffy": true},
	{"breed": "rottweiler", "w": 2.0, "len": 1.0, "wide": 1.2, "coat": [D_BLACK], "ears": "folded", "snout": 0.85, "tail": "stub", "marks": "tan_points"},
	{"breed": "boxer", "w": 1.5, "len": 0.9, "wide": 1.05, "coat": [D_FAWN, D_BRINDLE], "ears": "folded", "snout": 0.45, "tail": "stub", "marks": "mask"},
	{"breed": "corgi", "w": 1.0, "len": 0.58, "wide": 1.05, "coat": [D_RED, D_TAN], "ears": "pointy", "snout": 0.9, "tail": "stub", "marks": "blaze"},
	{"breed": "bulldog", "w": 1.0, "len": 0.66, "wide": 1.45, "coat": [D_WHITE, D_FAWN, D_BRINDLE], "ears": "folded", "snout": 0.25, "tail": "stub", "marks": "patches"},
]
const DOG_LEN := 11.0 # a Labrador nose to tail, at person size 1
const LEADS := [Color(0.85, 0.15, 0.2), Color(0.15, 0.35, 0.8), Color(0.1, 0.1, 0.1), Color(0.2, 0.6, 0.3), Color(0.95, 0.55, 0.1)]

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
	var chair := WHEELCHAIR_KID if kid else (WHEELCHAIR_OLD if old else WHEELCHAIR_ADULT)
	look["wheelchair"] = randf() < chair
	look["bike"] = not look["wheelchair"] and randf() < BIKE
	look["dog"] = random_dog() if randf() < DOG else {}
	look["gear_color"] = _pick(CLOTHES)
	if look["wheelchair"] or look["bike"]:
		if look["bag"] == "suitcase":
			look["bag"] = "backpack"
		if look["bike"]:
			look["balloon"] = false
	if not look["dog"].is_empty() and look["bag"] == "handbag":
		look["bag"] = ""
	return look

## A dog, picked by how common its breed is in the US.
static func random_dog() -> Dictionary:
	var total := 0.0
	for b in DOG_BREEDS:
		total += float(b["w"])
	var r := randf() * total
	var breed: Dictionary = DOG_BREEDS[0]
	for b in DOG_BREEDS:
		r -= float(b["w"])
		if r <= 0.0:
			breed = b
			break
	var dog := {}
	if breed["breed"] == "mixed":
		dog = {
			"breed": "mixed", "len": randf_range(0.4, 1.1), "wide": randf_range(0.85, 1.2),
			"ears": _pick(["floppy", "floppy", "folded", "pointy"]), "snout": randf_range(0.6, 1.1),
			"tail": _pick(["long", "long", "curl", "plume"]), "fluffy": randf() < 0.3,
			"marks": _pick(["", "", "patches", "blaze", "tan_points", "saddle"]),
		}
		var coat: Color = _pick([D_BLACK, D_CHOC, D_TAN, D_GOLD, D_WHITE, D_CREAM, D_BRINDLE, D_GREY, D_RED])
		dog["coat"] = coat.lerp(_pick([D_BLACK, D_TAN, D_WHITE]), randf_range(0.0, 0.25))
	else:
		dog = breed.duplicate()
		dog["coat"] = _pick(breed["coat"])
	dog["lead"] = _pick(LEADS)
	return dog

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
	var chair: bool = look.get("wheelchair", false)
	var bike: bool = look.get("bike", false)
	var dog: Dictionary = look.get("dog", {})

	# Where the hands are: swinging, pushing the wheels or on handlebars.
	var hands := []
	for k in range(2):
		var side := -1.0 if k == 0 else 1.0
		if chair:
			var push := sin(phase * TAU) if walking else -0.6
			hands.append(Vector2(0.1 + push * 1.3, side * 3.6))
		elif bike and k == 1:
			hands.append(Vector2(3.6, 3.8))
		else:
			hands.append(Vector2(-float(feet[k]) * 0.6 + 0.2, side * 3.7))

	# A dog trotting along on the left, on a lead from the left hand.
	if not dog.is_empty():
		var L := DOG_LEN * float(dog["len"])
		var at := Vector2(0.5 + L * 0.3, -(4.6 + L * 0.16 * float(dog["wide"])))
		paint_dog(ci, dog, at, phase, walking)
		var collar := at + Vector2(L * 0.24, 0.0)
		var mid: Vector2 = (hands[0] + collar) * 0.5 + Vector2(-0.4, -0.3)
		ci.draw_polyline(PackedVector2Array([hands[0], mid, collar]), dog["lead"], 0.35)

	# A bike being wheeled along on the right.
	if bike:
		_paint_bike(ci, look["gear_color"], Vector2(0.3, 5.3))

	# A wheelchair under them.
	if chair:
		_paint_wheelchair(ci, look["gear_color"], phase, walking)

	# Suitcase first: it rolls along behind, on the right hand's side.
	var hand_r: Vector2 = hands[1]
	if look["bag"] == "suitcase":
		var case_c := Vector2(hand_r.x - 3.4, 4.6)
		ellipse(ci, case_c + Vector2(0.4, 0.5), 2.6, 1.6, Color(0, 0, 0, 0.18), 10)
		ci.draw_rect(Rect2(case_c - Vector2(2.3, 1.3), Vector2(4.6, 2.6)), look["bag_color"])
		ci.draw_rect(Rect2(case_c - Vector2(2.3, 1.3), Vector2(4.6, 0.7)), (look["bag_color"] as Color).lightened(0.25))
		ci.draw_line(case_c + Vector2(2.3, 0.0), hand_r, DARK, 0.5)

	# Legs and shoes peeking out front and back.
	# Sitting in a wheelchair, the legs reach forward to the footrest.
	for k in range(2):
		var side := -1.0 if k == 0 else 1.0
		var fx: float = feet[k] if not chair else 3.4
		var hip := Vector2(0.0, side * 1.25) if not chair else Vector2(0.4, side * 1.15)
		if outfit != "dress" or chair:
			ci.draw_line(hip, Vector2(fx, side * 1.2), look["legs"], 1.9)
		ellipse(ci, Vector2(fx + 0.55, side * 1.2), 1.15, 0.8, look["shoes"], 8)
	if outfit == "dress":
		if chair:
			ellipse(ci, Vector2(1.1, 0.0), 2.9, 3.0, top.darkened(0.12))
		else:
			ellipse(ci, Vector2(-0.1, 0.0), 2.9, 3.8, top.darkened(0.12))

	# Arms swing opposite to the feet.
	var sleeve := top.darkened(0.08) if outfit != "hoodie" else top.darkened(0.15)
	for k in range(2):
		var side := -1.0 if k == 0 else 1.0
		var hand: Vector2 = hands[k]
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
		var hand: Vector2 = hands[1]
		var ball := Vector2(-1.5, 6.4)
		ci.draw_line(hand, ball + Vector2(0.4, -1.9), Color(0.95, 0.95, 0.95, 0.9), 0.3)
		ellipse(ci, ball + Vector2(1.2, 1.6), 2.3, 2.6, Color(0, 0, 0, 0.12), 12)
		ellipse(ci, ball, 2.2, 2.5, look["balloon_color"], 14)
		ci.draw_circle(ball + Vector2(-0.7, -0.8), 0.55, (look["balloon_color"] as Color).lightened(0.55))

## A dog seen from above, facing +x, centred on `at`: four legs trotting
## in diagonal pairs (two steps to each of its person's), body, tail, head,
## ears and snout, and its breed's markings.
static func paint_dog(ci, dog: Dictionary, at: Vector2, phase: float, walking: bool) -> void:
	var L := DOG_LEN * float(dog["len"])
	var wide := float(dog["wide"])
	var coat: Color = dog["coat"]
	var marks: String = dog.get("marks", "")
	var fluffy: bool = dog.get("fluffy", false)
	var dark := coat.darkened(0.45)
	var bl := L * 0.3 # body half length
	var bw := L * 0.12 * wide # body half width
	var gait := sin(phase * TAU * 2.0) if walking else 0.0
	var head := at + Vector2(bl + L * 0.07, 0.0)
	var hr := L * 0.11 * clampf(0.75 + wide * 0.25, 0.9, 1.2)
	var paw_col := coat if marks != "tan_points" else D_TAN
	ellipse(ci, at + Vector2(0.5, 0.7), bl + 0.4, bw + 0.4, Color(0, 0, 0, 0.16), 12)
	# Legs, front-left with back-right.
	for k in range(4):
		var front := k < 2
		var side := -1.0 if k % 2 == 0 else 1.0
		var ph := gait * (1.0 if (front == (side < 0.0)) else -1.0)
		var base := at + Vector2((bl * 0.62) * (1.0 if front else -1.0), side * bw * 0.85)
		var paw := base + Vector2(ph * L * 0.07 + L * 0.02, side * 0.25)
		ellipse(ci, paw, maxf(L * 0.045, 0.35), maxf(L * 0.035, 0.3), paw_col.darkened(0.1), 8)
	# Tail.
	var wag := sin(phase * TAU * 2.0 + 1.0) * 0.5 if walking else 0.15
	var tail_root := at - Vector2(bl * 0.95, 0.0)
	var tail_dir := Vector2.from_angle(PI + wag)
	match dog.get("tail", "long"):
		"long":
			ci.draw_line(tail_root, tail_root + tail_dir * L * 0.3, coat.darkened(0.08), maxf(L * 0.05, 0.35))
		"plume":
			var tip := tail_root + tail_dir * L * 0.3
			ellipse(ci, (tail_root + tip) * 0.5, L * 0.16, L * 0.06, coat.lightened(0.06), 10)
		"curl":
			ci.draw_circle(tail_root + Vector2(L * 0.04, wag * L * 0.05), L * 0.08, coat.lightened(0.08))
			ci.draw_circle(tail_root + Vector2(L * 0.04, wag * L * 0.05), L * 0.04, coat.darkened(0.12))
		"pom":
			ci.draw_line(tail_root, tail_root + tail_dir * L * 0.14, coat, maxf(L * 0.03, 0.3))
			ci.draw_circle(tail_root + tail_dir * L * 0.16, L * 0.07, coat.lightened(0.1))
		"stub":
			ci.draw_circle(tail_root, maxf(L * 0.035, 0.3), coat.darkened(0.08))
	# Body.
	ellipse(ci, at, bl + 0.25, bw + 0.25, coat.darkened(0.5), 16)
	ellipse(ci, at, bl, bw, coat, 16)
	if fluffy:
		for i in range(5):
			var x := lerpf(-bl * 0.7, bl * 0.7, i / 4.0)
			ci.draw_circle(at + Vector2(x, -bw * 0.55), bw * 0.5, coat.lightened(0.07))
			ci.draw_circle(at + Vector2(x, bw * 0.55), bw * 0.5, coat.lightened(0.07))
	match marks:
		"saddle":
			ellipse(ci, at + Vector2(-bl * 0.15, 0.0), bl * 0.6, bw * 0.75, D_BLACK, 14)
		"tricolor":
			ellipse(ci, at + Vector2(-bl * 0.1, 0.0), bl * 0.6, bw * 0.75, D_BLACK, 14)
			ci.draw_circle(tail_root + tail_dir * L * 0.3, maxf(L * 0.04, 0.3), D_WHITE)
		"husky":
			ellipse(ci, at, bl * 0.85, bw * 0.7, coat.darkened(0.25), 14)
		"patches":
			ci.draw_circle(at + Vector2(-bl * 0.4, bw * 0.3), bw * 0.55, coat.darkened(0.55) if coat.v > 0.8 else D_WHITE)
			ci.draw_circle(at + Vector2(bl * 0.25, -bw * 0.35), bw * 0.4, coat.darkened(0.55) if coat.v > 0.8 else D_WHITE)
		"yorkie":
			ellipse(ci, at + Vector2(-bl * 0.1, 0.0), bl * 0.85, bw * 0.8, D_BLUE.darkened(0.2), 14)
		"blaze":
			ellipse(ci, at + Vector2(bl * 0.7, 0.0), bl * 0.3, bw * 0.55, D_WHITE, 10)
	# Head, ears, snout.
	var ear_col := coat.darkened(0.15)
	if marks == "husky" or marks == "saddle" or marks == "tricolor":
		ear_col = coat.darkened(0.3) if marks == "husky" else D_BLACK
	if marks == "yorkie":
		ear_col = D_TAN
	match dog.get("ears", "floppy"):
		"floppy":
			for sd in [-1.0, 1.0]:
				ellipse(ci, head + Vector2(-hr * 0.15, sd * hr * 0.95), hr * 0.55, hr * 0.38, ear_col, 10)
		"folded":
			for sd in [-1.0, 1.0]:
				ellipse(ci, head + Vector2(hr * 0.1, sd * hr * 0.8), hr * 0.35, hr * 0.28, ear_col, 8)
	ci.draw_circle(head, hr + 0.22, coat.darkened(0.5))
	ci.draw_circle(head, hr, coat if marks != "yorkie" else D_TAN)
	if marks == "husky" or marks == "blaze":
		ci.draw_circle(head + Vector2(hr * 0.3, 0.0), hr * 0.55, D_WHITE)
	match dog.get("ears", "floppy"):
		"pointy", "bat":
			var big := 1.35 if dog.get("ears") == "bat" else 1.0
			for sd in [-1.0, 1.0]:
				var root := head + Vector2(-hr * 0.2, sd * hr * 0.55)
				ci.draw_colored_polygon(PackedVector2Array([
					root + Vector2(hr * 0.35, 0.0), root + Vector2(-hr * 0.35, 0.0),
					root + Vector2(-hr * 0.15, sd * hr * 0.75 * big)]), ear_col)
	var sn := hr * float(dog.get("snout", 1.0))
	var muzzle := D_BLACK.lightened(0.1) if marks == "mask" else (D_TAN if marks == "tan_points" else coat.lightened(0.06))
	if marks == "husky" or marks == "blaze" or marks == "tricolor":
		muzzle = D_WHITE
	ellipse(ci, head + Vector2(hr * 0.7 + sn * 0.3, 0.0), maxf(sn * 0.55, hr * 0.35), hr * 0.5, muzzle, 10)
	ci.draw_circle(head + Vector2(hr * 0.75 + sn * 0.8, 0.0), maxf(hr * 0.16, 0.2), Color(0.08, 0.07, 0.07))
	# Collar.
	ci.draw_line(head + Vector2(-hr * 0.85, -hr * 0.8), head + Vector2(-hr * 0.85, hr * 0.8), dog["lead"], maxf(L * 0.03, 0.3))

## A bike seen from above, facing +x, centred on `at`: two thin tyres, the
## frame between them, saddle and handlebars.
static func _paint_bike(ci, col: Color, at: Vector2) -> void:
	var tyre := Color(0.12, 0.12, 0.13)
	ellipse(ci, at + Vector2(0.5, 0.8), 6.4, 1.0, Color(0, 0, 0, 0.15), 12)
	for x in [-3.9, 3.9]:
		ellipse(ci, at + Vector2(x, 0.0), 2.6, 0.6, tyre, 12)
		ci.draw_line(at + Vector2(x - 2.2, 0.0), at + Vector2(x + 2.2, 0.0), Color(0.7, 0.7, 0.72), 0.18)
	ci.draw_line(at + Vector2(-3.9, 0.0), at + Vector2(3.3, 0.0), col, 0.95)
	ci.draw_line(at + Vector2(-0.4, 0.0), at + Vector2(-1.4, 0.0), col.darkened(0.2), 0.9)
	ellipse(ci, at + Vector2(-1.3, 0.0), 0.95, 0.5, Color(0.1, 0.1, 0.1), 8)
	ci.draw_line(at + Vector2(3.3, -1.5), at + Vector2(3.3, 1.5), Color(0.25, 0.25, 0.27), 0.55)
	for y in [-1.5, 1.5]:
		ci.draw_circle(at + Vector2(3.3, y), 0.35, Color(0.1, 0.1, 0.1))

## A wheelchair under a seated person facing +x: big wheels either side,
## push rims turning, seat and backrest, handles behind, little casters
## and the footrest in front.
static func _paint_wheelchair(ci, col: Color, phase: float, walking: bool) -> void:
	var metal := Color(0.72, 0.73, 0.76)
	var tyre := Color(0.12, 0.12, 0.13)
	ellipse(ci, Vector2(0.7, 0.8), 4.2, 4.6, Color(0, 0, 0, 0.14), 14)
	# Casters and footrest.
	for sd in [-1.0, 1.0]:
		ci.draw_line(Vector2(1.8, sd * 2.6), Vector2(3.6, sd * 2.2), metal, 0.35)
		ellipse(ci, Vector2(3.8, sd * 2.2), 0.6, 0.3, tyre, 8)
	ci.draw_line(Vector2(3.9, -1.9), Vector2(3.9, 1.9), metal, 0.5)
	# Seat and back.
	ci.draw_rect(Rect2(-2.4, -2.8, 4.4, 5.6), col.darkened(0.35))
	ci.draw_rect(Rect2(-2.8, -2.8, 0.7, 5.6), col.darkened(0.5))
	for sd in [-1.0, 1.0]:
		ci.draw_line(Vector2(-2.5, sd * 2.6), Vector2(-3.8, sd * 2.6), metal, 0.35)
		ci.draw_circle(Vector2(-3.9, sd * 2.6), 0.35, Color(0.1, 0.1, 0.1))
	# Big wheels, seen edge-on from above, with a spoke mark that turns.
	var turn := phase * TAU if walking else 0.7
	for sd in [-1.0, 1.0]:
		ci.draw_rect(Rect2(-2.9, sd * 3.9 - 0.45, 5.4, 0.9), tyre)
		ci.draw_line(Vector2(-2.6, sd * 3.35), Vector2(2.2, sd * 3.35), metal, 0.3)
		var sx := -0.2 + cos(turn) * 2.4
		ci.draw_line(Vector2(sx, sd * 3.5), Vector2(sx, sd * 4.3), col, 0.4)
