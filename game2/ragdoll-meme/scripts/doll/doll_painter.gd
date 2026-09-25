extends RefCounted
class_name DollPainter

## Draws a Doll with its DollStyle onto any CanvasItem. Looks only -- reads
## the doll's particles, never writes them.

const INK := Color("#1d1d24")

static func draw_doll(ci: CanvasItem, doll: Doll, t: float, key: int) -> void:
	var st := doll.style
	var perp := (doll.pos[Skeleton.NECK] - doll.pos[Skeleton.PELVIS]).normalized().orthogonal()
	var torso_w: float = st.get_part("torso")["width"] * doll.size
	var shoulder := perp * minf(torso_w * 0.42, 24.0 * doll.size)
	var hip := perp * minf(torso_w * 0.3, 16.0 * doll.size)

	var legs := [
		PackedVector2Array([doll.pos[Skeleton.PELVIS] + hip, doll.pos[Skeleton.L_KNEE], doll.pos[Skeleton.L_FOOT]]),
		PackedVector2Array([doll.pos[Skeleton.PELVIS] - hip, doll.pos[Skeleton.R_KNEE], doll.pos[Skeleton.R_FOOT]]),
	]
	var arms := [
		PackedVector2Array([doll.pos[Skeleton.NECK] + shoulder, doll.pos[Skeleton.L_ELBOW], doll.pos[Skeleton.L_HAND]]),
		PackedVector2Array([doll.pos[Skeleton.NECK] - shoulder, doll.pos[Skeleton.R_ELBOW], doll.pos[Skeleton.R_HAND]]),
	]
	for i in legs.size():
		_draw_chain(ci, legs[i], st.get_part("legs"), doll.size, t, key * 10 + i)
	_draw_ends(ci, doll, "feet", t, key)
	_draw_chain(ci, PackedVector2Array([doll.pos[Skeleton.NECK], doll.pos[Skeleton.CHEST], doll.pos[Skeleton.PELVIS]]),
		st.get_part("torso"), doll.size, t, key * 10 + 4, true)
	for i in arms.size():
		_draw_chain(ci, arms[i], st.get_part("arms"), doll.size, t, key * 10 + 2 + i)
	_draw_ends(ci, doll, "hands", t, key)
	_draw_head(ci, doll, t, key)

static func _draw_chain(ci: CanvasItem, pts: PackedVector2Array, part: Dictionary, size: float, t: float, key: int, is_torso: bool = false) -> void:
	var w: float = part["width"] * size
	match part["kind"]:
		"emoji":
			var tex := EmojiCache.texture(part["emoji"])
			if is_torso:
				var c := (pts[0] + pts[pts.size() - 1]) * 0.5
				var along := pts[pts.size() - 1] - pts[0]
				var s := maxf(along.length() * 1.2, w * 1.3)
				_stamp(ci, tex, c, along.angle() - PI * 0.5, s, part["color"])
				return
			var p := LineStyles.path(pts, true)
			var total := LineStyles.length_of(p)
			var step := maxf(w * 0.9, 8.0)
			var n := maxi(int(total / step), 1)
			for k in n + 1:
				var sm: Array = LineStyles.sample(p, total * k / n)
				_stamp(ci, tex, sm[0], (sm[1] as Vector2).angle() + PI * 0.5, w * 1.35, part["color"])
		"photo":
			var tex := ImageLibrary.texture(part["image"])
			if tex == null:
				LineStyles.stroke(ci, pts, "solid", Color(0.6, 0.6, 0.6), w, t, key)
				return
			_photo_strip(ci, LineStyles.path(pts, not is_torso), w, tex)
		"none":
			pass
		_:
			LineStyles.stroke(ci, pts, part["line"], part["color"], w, t, key)

## Hands or feet: drawn at the chain's last joint, facing along its bone.
static func _draw_ends(ci: CanvasItem, doll: Doll, group: String, t: float, key: int) -> void:
	var part: Dictionary = doll.style.get_part(group)
	var w: float = part["width"] * doll.size
	var side := -1.0
	for pair in Skeleton.ENDS[group]:
		var at := doll.pos[pair[1]]
		var dir := (at - doll.pos[pair[0]]).normalized()
		match part["kind"]:
			"emoji":
				var ang := dir.angle() + (PI * 0.5 if group == "hands" else -PI * 0.5)
				_stamp(ci, EmojiCache.texture(part["emoji"]), at + dir * w * 0.3, ang, w * 1.4, part["color"], Vector2(-side, 1))
			"photo":
				var tex := ImageLibrary.texture(part["image"])
				if tex != null:
					_photo_disc(ci, at, w * 0.7, dir.angle() - PI * 0.5, tex, part)
			"none":
				pass
			_:
				var line: String = part["line"]
				if line == "stick" or line == "scribble" or line == "spring" or line == "dashed":
					var tip := at + dir * w * 0.6
					LineStyles.stroke(ci, PackedVector2Array([at, tip]), line, part["color"], maxf(w * 0.4, 3.0), t, key * 10 + 7)
					if group == "feet":
						LineStyles.stroke(ci, PackedVector2Array([tip, tip + dir.orthogonal() * side * w * 0.8]), line, part["color"], maxf(w * 0.4, 3.0), t, key * 10 + 8)
				elif group == "feet":
					var c := at + dir * w * 0.2 - dir.orthogonal() * side * w * 0.25
					_shoe(ci, c, dir, w, side, part["color"], line == "neon")
				else:
					if line != "neon":
						ci.draw_circle(at, w * 0.5 + maxf(2.0, w * 0.12), (part["color"] as Color).darkened(0.6))
					else:
						ci.draw_circle(at, w * 0.9, Color(part["color"], 0.2))
					ci.draw_circle(at, w * 0.5, part["color"])
		side = 1.0

static func _shoe(ci: CanvasItem, c: Vector2, dir: Vector2, w: float, side: float, color: Color, glow: bool) -> void:
	var pts := PackedVector2Array()
	var fwd := -dir.orthogonal() * side
	for i in 14:
		var a := TAU * i / 14.0
		pts.append(c + fwd * cos(a) * w * 0.85 + dir * sin(a) * w * 0.45)
	if glow:
		ci.draw_circle(c, w * 1.1, Color(color, 0.2))
	else:
		var outline := PackedVector2Array()
		for i in pts.size():
			outline.append(c + (pts[i] - c) * (1.0 + 4.0 / maxf(w, 4.0)))
		ci.draw_colored_polygon(outline, color.darkened(0.6))
	ci.draw_colored_polygon(pts, color)

static func _draw_head(ci: CanvasItem, doll: Doll, t: float, key: int) -> void:
	var part: Dictionary = doll.style.get_part("head")
	var c := doll.pos[Skeleton.HEAD]
	var r := doll.head_radius * doll.size
	var up := (c - doll.pos[Skeleton.NECK]).normalized()
	var ang := up.angle() + PI * 0.5
	match part["kind"]:
		"emoji":
			_stamp(ci, EmojiCache.texture(part["emoji"]), c, ang, r * 2.35, part["color"])
		"photo":
			var tex := ImageLibrary.texture(part["image"])
			ci.draw_circle(c, r + maxf(2.5, r * 0.06), INK)
			if tex == null:
				ci.draw_circle(c, r, part["color"])
			else:
				_photo_disc(ci, c, r, ang, tex, part)
		_:
			ci.draw_circle(c, r + maxf(2.5, r * 0.06), INK)
			ci.draw_circle(c, r, part["color"])
			ci.draw_circle(c + Vector2(-r * 0.35, -r * 0.4).rotated(ang), r * 0.22, Color(1, 1, 1, 0.25))
			var panic: float = clamp((doll.head_speed - 700.0) / 1300.0, 0.0, 1.0)
			var look := (doll.head_velocity / 900.0).rotated(-ang)
			ci.draw_set_transform(c, ang, Vector2.ONE)
			FacePainter.draw_face(ci, part["face"], r, look, panic, t, key)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _stamp(ci: CanvasItem, tex: Texture2D, at: Vector2, ang: float, s: float, fallback: Color, flip: Vector2 = Vector2.ONE) -> void:
	if tex == null:
		ci.draw_circle(at, s * 0.4, fallback)
		return
	ci.draw_set_transform(at, ang, flip)
	ci.draw_texture_rect(tex, Rect2(-s * 0.5, -s * 0.5, s, s), false)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## A photo cropped to a circle: `zoom`/`ox`/`oy` pick which square of the
## photo shows, and it turns with `ang` (so a face photo tilts with the head).
static func _photo_disc(ci: CanvasItem, c: Vector2, r: float, ang: float, tex: Texture2D, part: Dictionary) -> void:
	var ts := tex.get_size()
	var side := minf(ts.x, ts.y) / maxf(float(part.get("zoom", 1.0)), 0.1)
	var hu := side / (2.0 * ts.x)
	var hv := side / (2.0 * ts.y)
	var cu := 0.5 + float(part.get("ox", 0.0))
	var cv := 0.5 + float(part.get("oy", 0.0))
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		var v := Vector2(cos(a), sin(a))
		pts.append(c + (v * r).rotated(ang))
		uvs.append(Vector2(cu + v.x * hu, cv + v.y * hv))
	ci.draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, tex)

## A photo mapped along a limb like a sleeve, cover-cropped so it isn't
## squashed.
static func _photo_strip(ci: CanvasItem, p: PackedVector2Array, w: float, tex: Texture2D) -> void:
	var total := LineStyles.length_of(p)
	if total < 1.0:
		return
	var ts := tex.get_size()
	var sc := maxf(w / ts.x, total / ts.y)
	var uw := (w / sc) / ts.x
	var vh := (total / sc) / ts.y
	var u0 := 0.5 - uw * 0.5
	var v0 := 0.5 - vh * 0.5
	var hw := w * 0.5
	var d := 0.0
	var white := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	for i in p.size() - 1:
		var a := p[i]
		var b := p[i + 1]
		var seg := a.distance_to(b)
		var na := _normal(p, i) * hw
		var nb := _normal(p, i + 1) * hw
		var va := v0 + vh * d / total
		var vb := v0 + vh * (d + seg) / total
		ci.draw_primitive(PackedVector2Array([a - na, a + na, b + nb, b - nb]), white,
			PackedVector2Array([Vector2(u0, va), Vector2(u0 + uw, va), Vector2(u0 + uw, vb), Vector2(u0, vb)]), tex)
		d += seg

static func _normal(p: PackedVector2Array, i: int) -> Vector2:
	var a := p[maxi(i - 1, 0)]
	var b := p[mini(i + 1, p.size() - 1)]
	return (b - a).normalized().orthogonal()
