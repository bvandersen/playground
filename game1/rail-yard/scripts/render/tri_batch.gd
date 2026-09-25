extends RefCounted
class_name TriBatch

## Collects vector drawing into one flat, vertex-coloured triangle list
## that goes to the GPU as a single mesh -- one draw call -- instead of
## one draw call (and one freshly uploaded vertex buffer) per shape.
##
## Why: in Godot 4.3's Compatibility (WebGL) renderer every draw_circle,
## anti-aliased line and polygon is its own draw call; the scenery, track
## and cars add up to thousands of them per frame, which is what made the
## Web build crawl on phones. The painters didn't have to change: this
## mirrors the subset of CanvasItem's draw_* API they use, reproducing the
## same geometry (including Godot's 1.25-unit anti-aliasing feather), so a
## painter can draw onto a CanvasItem or into a TriBatch unchanged.

## Width of the transparent fringe Godot's anti-aliased lines carry
## (measured from the 4.3 Web renderer: 1.25 local units, caps included).
const AA_FEATHER := 1.25
## Circles get enough segments to stay round at the closest camera zoom
## on a high-DPI phone (~8 screen px per world unit).
const MAX_PX_PER_UNIT := 8.0

var points := PackedVector2Array()
var colors := PackedColorArray()
var _xf := Transform2D.IDENTITY
var _xf_scale := 1.0

static var _unit_fans := {}

func clear() -> void:
	points = PackedVector2Array()
	colors = PackedColorArray()
	_xf = Transform2D.IDENTITY
	_xf_scale = 1.0

func is_empty() -> bool:
	return points.is_empty()

## The triangles as a 2D mesh, or null if nothing was drawn.
func to_mesh() -> ArrayMesh:
	if points.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## Appends another batch's triangles (already in their final positions).
func append(other: TriBatch) -> void:
	points.append_array(other.points)
	colors.append_array(other.colors)

# --- The CanvasItem-compatible part -----------------------------------------

func draw_set_transform(pos: Vector2, rot: float = 0.0, scale: Vector2 = Vector2.ONE) -> void:
	draw_set_transform_matrix(Transform2D(rot, scale, 0.0, pos))

func draw_set_transform_matrix(xf: Transform2D) -> void:
	_xf = xf
	_xf_scale = sqrt(absf(xf.determinant()))

func draw_circle(pos: Vector2, radius: float, color: Color) -> void:
	var fan := _unit_fan(_segments_for(radius * _xf_scale))
	points.append_array((_xf * Transform2D(0.0, Vector2(radius, radius), 0.0, pos)) * fan)
	_fill(color, fan.size())

func draw_rect(rect: Rect2, color: Color, filled: bool = true, width: float = -1.0) -> void:
	if filled:
		_quad(rect.position, rect.position + Vector2(rect.size.x, 0.0), rect.end, rect.position + Vector2(0.0, rect.size.y), color)
		return
	var w := width if width > 0.0 else 1.0
	var r := rect
	draw_rect(Rect2(r.position - Vector2(w, w) * 0.5, Vector2(r.size.x + w, w)), color)
	draw_rect(Rect2(Vector2(r.position.x - w * 0.5, r.end.y - w * 0.5), Vector2(r.size.x + w, w)), color)
	draw_rect(Rect2(Vector2(r.position.x - w * 0.5, r.position.y + w * 0.5), Vector2(w, r.size.y - w)), color)
	draw_rect(Rect2(Vector2(r.end.x - w * 0.5, r.position.y + w * 0.5), Vector2(w, r.size.y - w)), color)

func draw_colored_polygon(pts: PackedVector2Array, color: Color) -> void:
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		return
	var out := PackedVector2Array()
	out.resize(idx.size())
	for i in range(idx.size()):
		out[i] = pts[idx[i]]
	points.append_array(_xf * out)
	_fill(color, idx.size())

func draw_polygon(pts: PackedVector2Array, cols: PackedColorArray) -> void:
	if cols.size() == 1:
		draw_colored_polygon(pts, cols[0])
		return
	var idx := Geometry2D.triangulate_polygon(pts)
	for i in idx:
		points.append(_xf * pts[i])
		colors.append(cols[i])

## Exactly draw_polyline's geometry for two points, built in one go --
## it's by far the most common call, and hot in per-frame drawing.
func draw_line(from: Vector2, to: Vector2, color: Color, width: float = -1.0, antialiased: bool = false) -> void:
	var d := to - from
	if d.length_squared() == 0.0:
		return
	var dir := d.normalized()
	var hw := (width if width > 0.0 else 1.0) * 0.5
	var n := dir.orthogonal() * hw
	var l0 := from + n
	var r0 := from - n
	var l1 := to + n
	var r1 := to - n
	if not antialiased:
		_quad(l0, l1, r1, r0, color)
		return
	var fn := dir.orthogonal() * (hw + AA_FEATHER)
	var fl0 := from + fn
	var fr0 := from - fn
	var fl1 := to + fn
	var fr1 := to - fn
	var o := dir * AA_FEATHER
	points.append_array(_xf * PackedVector2Array([
		l0, l1, r1, l0, r1, r0, # core
		fl0, fl1, l1, fl0, l1, l0, # side fringes
		r0, r1, fr1, r0, fr1, fr0,
		l0, r0, r0 - o, l0, r0 - o, l0 - o, # start cap
		fl0, l0, l0 - o, fl0, l0 - o, fl0 - o,
		r0, fr0, fr0 - o, r0, fr0 - o, r0 - o,
		l1, r1, r1 + o, l1, r1 + o, l1 + o, # end cap
		fl1, l1, l1 + o, fl1, l1 + o, fl1 + o,
		r1, fr1, fr1 + o, r1, fr1 + o, r1 + o,
	]))
	var c := color
	var k := Color(color, 0.0)
	colors.append_array(PackedColorArray([
		c, c, c, c, c, c,
		k, k, c, k, c, c,
		c, c, k, c, k, k,
		c, c, k, c, k, k,
		k, c, k, k, k, k,
		c, k, k, c, k, k,
		c, c, k, c, k, k,
		k, c, k, k, k, k,
		c, k, k, c, k, k,
	]))

func draw_arc(center: Vector2, radius: float, start: float, end: float, point_count: int, color: Color, width: float = -1.0, antialiased: bool = false) -> void:
	if point_count < 2:
		return
	var pts := PackedVector2Array()
	pts.resize(point_count)
	for i in range(point_count):
		var a := start + (end - start) * i / float(point_count - 1)
		pts[i] = center + Vector2(cos(a), sin(a)) * radius
	draw_polyline(pts, color, width, antialiased)

## Same strip Godot 4.3 builds: each point is offset along the average of
## its two neighbouring segment normals (no mitre stretch), and the
## anti-aliased version adds a fringe fading to transparent on both sides
## and past both ends.
func draw_polyline(pts: PackedVector2Array, color: Color, width: float = -1.0, antialiased: bool = false) -> void:
	var n := pts.size()
	if n < 2:
		return
	# Negative width is Godot's hairline; a hairline is ~1 unit wide at zoom 1.
	var hw := (width if width > 0.0 else 1.0) * 0.5
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	left.resize(n)
	right.resize(n)
	var fl := PackedVector2Array()
	var fr := PackedVector2Array()
	if antialiased:
		fl.resize(n)
		fr.resize(n)
	var prev_t := Vector2.ZERO
	for i in range(n):
		var t := prev_t
		if i < n - 1:
			var d := pts[i + 1] - pts[i]
			if d.length_squared() > 0.0:
				t = d.normalized().orthogonal()
			if i == 0 or prev_t == Vector2.ZERO:
				prev_t = t
		var nrm := (t + prev_t).normalized()
		left[i] = pts[i] + nrm * hw
		right[i] = pts[i] - nrm * hw
		if antialiased:
			fl[i] = pts[i] + nrm * (hw + AA_FEATHER)
			fr[i] = pts[i] - nrm * (hw + AA_FEATHER)
		prev_t = t
	var clear := Color(color, 0.0)
	for i in range(n - 1):
		_quad(left[i], left[i + 1], right[i + 1], right[i], color)
		if antialiased:
			_quad2(fl[i], fl[i + 1], left[i + 1], left[i], clear, color)
			_quad2(right[i], right[i + 1], fr[i + 1], fr[i], color, clear)
	if antialiased:
		var d0 := (pts[1] - pts[0]).normalized() * AA_FEATHER
		var d1 := (pts[n - 1] - pts[n - 2]).normalized() * AA_FEATHER
		_cap(fl[0], left[0], right[0], fr[0], -d0, color, clear)
		_cap(fl[n - 1], left[n - 1], right[n - 1], fr[n - 1], d1, color, clear)

# --- Internals ---------------------------------------------------------------

static func _segments_for(screen_radius_units: float) -> int:
	# Keeps the flat-edge sag under ~0.5 screen px at the closest zoom.
	var r_px := screen_radius_units * MAX_PX_PER_UNIT
	return clampi(int(ceil(PI * sqrt(maxf(r_px, 0.0)))), 10, 64)

## A unit circle as a flat triangle list (centre, rim i, rim i+1).
static func _unit_fan(segments: int) -> PackedVector2Array:
	if _unit_fans.has(segments):
		return _unit_fans[segments]
	var out := PackedVector2Array()
	for i in range(segments):
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		out.append(Vector2.ZERO)
		out.append(Vector2(cos(a0), sin(a0)))
		out.append(Vector2(cos(a1), sin(a1)))
	_unit_fans[segments] = out
	return out

func _fill(color: Color, count: int) -> void:
	var cs := PackedColorArray()
	cs.resize(count)
	cs.fill(color)
	colors.append_array(cs)

func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	points.append_array(_xf * PackedVector2Array([a, b, c, a, c, d]))
	_fill(color, 6)

## Quad a-b-c-d whose a/b edge is `ca` and c/d edge is `cb`.
func _quad2(a: Vector2, b: Vector2, c: Vector2, d: Vector2, ca: Color, cb: Color) -> void:
	points.append_array(_xf * PackedVector2Array([a, b, c, a, c, d]))
	colors.append_array(PackedColorArray([ca, ca, cb, ca, cb, cb]))

## The fringe past one end of an anti-aliased line.
func _cap(fl: Vector2, l: Vector2, r: Vector2, fr: Vector2, out: Vector2, color: Color, clear: Color) -> void:
	# Across the core width, then the two corners.
	points.append_array(_xf * PackedVector2Array([l, r, r + out, l, r + out, l + out]))
	colors.append_array(PackedColorArray([color, color, clear, color, clear, clear]))
	points.append_array(_xf * PackedVector2Array([fl, l, l + out, fl, l + out, fl + out]))
	colors.append_array(PackedColorArray([clear, color, clear, clear, clear, clear]))
	points.append_array(_xf * PackedVector2Array([r, fr, fr + out, r, fr + out, r + out]))
	colors.append_array(PackedColorArray([color, clear, clear, color, clear, clear]))
