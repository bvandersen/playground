extends RefCounted
class_name DollStyle

## How one doll looks -- plain data, no drawing (DollPainter draws it).
## One PartStyle dictionary per Skeleton.PART_GROUPS entry:
##
##   kind   "line" | "emoji" | "photo" | "none" (hands/feet only);
##          the head uses "face" | "emoji" | "photo"
##   color  fill / line colour
##   width  thickness in doll units (torso/limbs/hands/feet)
##   line   a LineStyles id -- how a "line" part is stroked
##   emoji  the emoji for kind "emoji"
##   image  an ImageLibrary id for kind "photo"
##   face   a FacePainter id for the head's kind "face"
##   zoom, ox, oy   how a photo sits inside the head circle

const SKIN := [
	Color("#f6d2b0"), Color("#e0a878"), Color("#b87a4b"), Color("#7d4f2e"),
	Color("#ffe066"), Color("#8be38b"), Color("#9ec9ff"), Color("#ff9ecf"),
]
const PALETTE := [
	Color("#1d1d24"), Color("#ffffff"), Color("#ff4757"), Color("#ffa502"),
	Color("#ffd32a"), Color("#2ed573"), Color("#1e90ff"), Color("#a55eea"),
	Color("#ff6bcb"), Color("#00d2d3"),
]
const FUN_EMOJI := [
	"🍌", "🌭", "🥒", "🌈", "🔥", "⭐", "💖", "🍕", "🐍", "🦴", "🍩", "🌵",
	"🧦", "🥖", "🍆", "🌽", "🐙", "✨", "💀", "🤡", "🐸", "🍉", "🥓", "💩",
]
const FACE_EMOJI := ["😎", "🤪", "😱", "🥴", "😂", "🤡", "😈", "🥸", "🤖", "👽", "🐸", "🙃"]
const HAND_EMOJI := ["✋", "🖐️", "👍", "🤘", "🥊", "🧤", "✌️", "👊"]
const FOOT_EMOJI := ["👟", "🦶", "👠", "🥾", "🩴", "🛼"]

var parts := {}

func _init() -> void:
	apply_preset("noodle")

static func part(kind: String, color: Color, width: float, line: String = "noodle") -> Dictionary:
	return {
		"kind": kind, "color": color, "width": width, "line": line,
		"emoji": "🍌", "image": "", "face": "smile", "zoom": 1.0, "ox": 0.0, "oy": 0.0,
	}

func get_part(group: String) -> Dictionary:
	return parts[group]

func duplicate_style() -> DollStyle:
	var s := DollStyle.new()
	s.parts = parts.duplicate(true)
	return s

# --- Presets ---------------------------------------------------------------

const PRESETS := ["noodle", "stick", "scribble", "neon", "emoji", "rainbow"]
const PRESET_NAMES := {
	"noodle": "Noodle", "stick": "Stickman", "scribble": "Scribble",
	"neon": "Neon", "emoji": "Emoji", "rainbow": "Rainbow",
}

func apply_preset(preset: String) -> void:
	var head := part("face", SKIN[0], 0.0)
	match preset:
		"stick":
			head = part("face", Color.WHITE, 0.0)
			_set_body(Color("#1d1d24"), 6.0, "stick")
			parts["hands"] = part("none", Color("#1d1d24"), 8.0)
			parts["feet"] = part("none", Color("#1d1d24"), 8.0)
		"scribble":
			head = part("face", Color.WHITE, 0.0)
			head["face"] = "derp"
			_set_body(Color("#1d1d24"), 12.0, "scribble")
			parts["hands"] = part("line", Color("#1d1d24"), 14.0, "scribble")
			parts["feet"] = part("line", Color("#1d1d24"), 16.0, "scribble")
		"neon":
			head = part("face", Color("#1e90ff"), 0.0)
			head["face"] = "cool"
			_set_body(Color("#00ffd5"), 10.0, "neon")
			parts["hands"] = part("line", Color("#ff6bcb"), 14.0, "neon")
			parts["feet"] = part("line", Color("#ff6bcb"), 16.0, "neon")
		"emoji":
			head = part("emoji", SKIN[0], 0.0)
			head["emoji"] = "🤪"
			parts["torso"] = _emoji_part("🍕", 44.0)
			parts["arms"] = _emoji_part("🌭", 26.0)
			parts["legs"] = _emoji_part("🍌", 30.0)
			parts["hands"] = _emoji_part("🖐️", 34.0)
			parts["feet"] = _emoji_part("👟", 38.0)
		"rainbow":
			head = part("face", SKIN[4], 0.0)
			head["face"] = "shock"
			_set_body(Color.WHITE, 20.0, "rainbow")
			parts["hands"] = part("line", Color("#ffd32a"), 20.0, "solid")
			parts["feet"] = part("line", Color("#ff4757"), 22.0, "solid")
		_:
			_set_body(Color("#ff4757"), 22.0, "noodle")
			parts["torso"] = part("line", Color("#1e90ff"), 44.0, "noodle")
			parts["hands"] = part("line", SKIN[0], 18.0, "noodle")
			parts["feet"] = part("line", Color("#1d1d24"), 22.0, "noodle")
	parts["head"] = head

func _set_body(color: Color, width: float, line: String) -> void:
	parts["torso"] = part("line", color, width * (1.6 if line in ["noodle", "solid", "rainbow"] else 1.0), line)
	parts["arms"] = part("line", color, width, line)
	parts["legs"] = part("line", color, width, line)

func _emoji_part(e: String, width: float) -> Dictionary:
	var p := part("emoji", Color.WHITE, width)
	p["emoji"] = e
	return p

## A random look -- the "surprise me" button. Mixes line styles, emoji and
## colours freely; that clash is most of the joke.
func randomize_style() -> void:
	var r := RandomNumberGenerator.new()
	r.randomize()
	var head := part("face", SKIN[r.randi() % SKIN.size()], 0.0)
	if r.randf() < 0.4:
		head["kind"] = "emoji"
		head["emoji"] = FACE_EMOJI[r.randi() % FACE_EMOJI.size()]
	else:
		head["face"] = FacePainter.FACES[r.randi() % FacePainter.FACES.size()]
	parts["head"] = head
	for g in ["torso", "arms", "legs"]:
		if r.randf() < 0.3:
			parts[g] = _emoji_part(FUN_EMOJI[r.randi() % FUN_EMOJI.size()], r.randf_range(22, 40) * (1.4 if g == "torso" else 1.0))
		else:
			var ids := LineStyles.ids()
			parts[g] = part("line", PALETTE[r.randi() % PALETTE.size()],
				r.randf_range(6, 30) * (1.6 if g == "torso" else 1.0), ids[r.randi() % ids.size()])
	var hand_roll := r.randf()
	if hand_roll < 0.45:
		parts["hands"] = _emoji_part(HAND_EMOJI[r.randi() % HAND_EMOJI.size()], 34.0)
	else:
		parts["hands"] = part("line", PALETTE[r.randi() % PALETTE.size()], r.randf_range(12, 22), parts["arms"]["line"])
	if r.randf() < 0.45:
		parts["feet"] = _emoji_part(FOOT_EMOJI[r.randi() % FOOT_EMOJI.size()], 38.0)
	else:
		parts["feet"] = part("line", PALETTE[r.randi() % PALETTE.size()], r.randf_range(14, 24), parts["legs"]["line"])

## Every ImageLibrary id this style uses (so a load can fetch them).
func image_ids() -> Array:
	var out := []
	for g in parts:
		if parts[g]["kind"] == "photo" and parts[g]["image"] != "":
			out.append(parts[g]["image"])
	return out

# --- Serialization ---------------------------------------------------------

func to_dict() -> Dictionary:
	var out := {}
	for g in parts:
		var p: Dictionary = parts[g].duplicate()
		p["color"] = (p["color"] as Color).to_html()
		out[g] = p
	return out

static func from_dict(d: Dictionary) -> DollStyle:
	var s := DollStyle.new()
	for g in Skeleton.PART_GROUPS:
		if not d.has(g) or not (d[g] is Dictionary):
			continue
		var p: Dictionary = s.parts[g].duplicate()
		for k in d[g]:
			p[k] = d[g][k]
		p["color"] = Color.from_string(str(p["color"]), Color.WHITE)
		for k in ["width", "zoom", "ox", "oy"]:
			p[k] = float(p[k])
		s.parts[g] = p
	return s
