extends RefCounted
class_name TrackNetwork

## The whole track layout as a graph: TrackSegments (smoothed polylines)
## joined at TrackNodes. Owns every edit the designer can make (draw a
## stroke, erase a piece) and every question a train asks ("where does the
## track go after this end?"). No drawing here -- TrackView reads this.
##
## Joining rule: a drawn stroke that starts or ends on existing track is
## bent so it leaves/arrives *tangent* to that track (a short straight
## lead-in, then smoothing), so every junction a player draws is one a
## train can actually run through. Starting on the middle of a piece
## splits it there, which is how switches get made.

const SPACING := 5.0 # final point spacing along a segment, px
const ROUGH_SPACING := 14.0 # raw strokes are thinned to this before smoothing
const LEAD := 34.0 # straight lead-in length at a joined end, px
const MIN_STROKE := 40.0
const END_MARGIN := 26.0 # a snap this close to a piece's end joins that end
const MIN_BRANCH_DOT := 0.1 # a branch must leave less than ~84° off the way in

var segments: Array = []
var nodes: Array = []

func clear() -> void:
	segments.clear()
	nodes.clear()

func is_empty() -> bool:
	return segments.is_empty()

static func port_dir(port: Array) -> Vector2:
	return (port[0] as TrackSegment).dir_into(port[1])

# --- Routing ---------------------------------------------------------------

## Ports a train can continue into after arriving at `node` through
## `arrival` -- only those less than ~84° off its heading (no hairpins),
## sorted left-to-right so `switch_state` always means the same branch.
func candidates(node: TrackNode, arrival: Array) -> Array:
	var t := -port_dir(arrival)
	var out := []
	for q in node.ports:
		if q == arrival:
			continue
		if port_dir(q).dot(t) > MIN_BRANCH_DOT:
			out.append(q)
	out.sort_custom(func(a, b): return t.cross(port_dir(a)) < t.cross(port_dir(b)))
	return out

## Where a train leaving `seg` through `end` goes next: `[seg, end]` of the
## port it enters, or null at a dead end.
func next_port(seg: TrackSegment, end: int):
	var node: TrackNode = seg.nodes[end]
	if node == null:
		return null
	var c := candidates(node, [seg, end])
	if c.is_empty():
		return null
	return c[node.switch_state % c.size()]

func is_switch(node: TrackNode) -> bool:
	if node.ports.size() < 3:
		return false
	for p in node.ports:
		if candidates(node, p).size() >= 2:
			return true
	return false

func switch_near(p: Vector2, radius: float) -> TrackNode:
	var best: TrackNode = null
	var best_d := radius
	for n in nodes:
		var d: float = n.position.distance_to(p)
		if d <= best_d and is_switch(n):
			best = n
			best_d = d
	return best

## Follows the track from `u` px along `seg` (travelling end 0 -> 1 unless
## `rev`) for up to `max_dist`, through switches as currently set.
## Returns {points: a point every `step` px, dead: distance to a dead end
## or INF}. This is how a train looks ahead for buffers and other trains.
func walk(seg: TrackSegment, rev: bool, u: float, max_dist: float, step: float) -> Dictionary:
	var pts := PackedVector2Array()
	var travelled := 0.0
	var next_d := 0.0
	for _guard in range(64):
		var remain := maxf(seg.length - u, 0.0)
		while next_d <= travelled + remain and next_d <= max_dist:
			var uu := u + (next_d - travelled)
			pts.append(seg.point_at(seg.length - uu if rev else uu))
			next_d += step
		if next_d > max_dist:
			return {"points": pts, "dead": INF}
		travelled += remain
		var q = next_port(seg, 0 if rev else 1)
		if q == null:
			return {"points": pts, "dead": travelled}
		seg = q[0]
		rev = q[1] == 1
		u = 0.0
	return {"points": pts, "dead": INF}

# --- Queries ---------------------------------------------------------------

## Closest track point within `max_dist`: {seg, u, dist, pos}, or {}.
func nearest(p: Vector2, max_dist: float) -> Dictionary:
	var best := {}
	var best_d := max_dist
	for seg in segments:
		var hit: Dictionary = seg.nearest(p)
		if hit["dist"] <= best_d:
			best_d = hit["dist"]
			best = hit
			best["seg"] = seg
	return best

func node_near(p: Vector2, max_dist: float) -> TrackNode:
	var best: TrackNode = null
	var best_d := max_dist
	for n in nodes:
		var d: float = n.position.distance_to(p)
		if d <= best_d:
			best = n
			best_d = d
	return best

## Where a stroke end at `p` would attach, without changing anything --
## for the live preview while drawing. Vector2.INF when it wouldn't.
func snap_preview(p: Vector2, snap: float) -> Vector2:
	var n := node_near(p, snap)
	if n != null:
		return n.position
	var hit := nearest(p, snap)
	if hit.is_empty():
		return Vector2.INF
	var seg: TrackSegment = hit["seg"]
	if hit["u"] < END_MARGIN:
		return seg.points[0]
	if hit["u"] > seg.length - END_MARGIN:
		return seg.points[seg.points.size() - 1]
	return hit["pos"]

func bounds() -> Rect2:
	var r := Rect2()
	var first := true
	for seg in segments:
		for p in seg.points:
			if first:
				r = Rect2(p, Vector2.ZERO)
				first = false
			else:
				r = r.expand(p)
	return r

# --- Editing ---------------------------------------------------------------

## Turns a raw finger/mouse stroke into track. Returns the new segment, or
## null if the stroke was too short to be one.
func add_stroke(raw: PackedVector2Array, snap: float) -> TrackSegment:
	if raw.size() < 2 or _polyline_length(raw) < MIN_STROKE:
		return null
	var p_start := raw[0]
	var p_end := raw[raw.size() - 1]

	var n0 := _resolve_end(p_start, snap)
	var free_start := n0 == null
	if free_start:
		n0 = _new_node(p_start)
	var c := _stroke_dir(raw, false)
	var start_lead := false
	if not n0.ports.is_empty():
		c = _best_dir(n0, c, true)
		start_lead = true

	var n1: TrackNode
	var e := _stroke_dir(raw, true)
	var end_lead := false
	if free_start and p_end.distance_to(p_start) <= snap and _polyline_length(raw) > LEAD * 4.0:
		# Closing a loop onto its own start: arrive heading the way it left.
		n1 = n0
		e = c
		end_lead = true
		start_lead = true
	else:
		n1 = _resolve_end(p_end, snap)
		if n1 == null:
			n1 = _new_node(p_end)
		elif not n1.ports.is_empty():
			e = _best_dir(n1, e, false)
			end_lead = true

	var pts := _thin(raw, ROUGH_SPACING)
	var a := n0.position
	var b := n1.position
	if start_lead:
		while pts.size() > 2 and pts[0].distance_to(a) < LEAD * 1.3:
			pts.remove_at(0)
		var head := PackedVector2Array([a, a + c * LEAD * 0.5, a + c * LEAD])
		pts = head + pts
	else:
		pts[0] = a
	if end_lead:
		while pts.size() > 2 and pts[pts.size() - 1].distance_to(b) < LEAD * 1.3:
			pts.remove_at(pts.size() - 1)
		pts.append_array(PackedVector2Array([b - e * LEAD, b - e * LEAD * 0.5, b]))
	else:
		pts[pts.size() - 1] = b

	pts = _resample(_chaikin(pts, 3), SPACING)
	var seg := TrackSegment.new(pts)
	seg.nodes = [n0, n1]
	n0.ports.append([seg, 0])
	n1.ports.append([seg, 1])
	segments.append(seg)
	# Splits can leave plain two-way joints behind; fold them all back.
	for n in nodes.duplicate():
		_try_merge(n)
	return seg

func remove_segment(seg: TrackSegment) -> void:
	if not segments.has(seg):
		return
	segments.erase(seg)
	var touched := []
	for end in [0, 1]:
		var n: TrackNode = seg.nodes[end]
		n.ports.erase([seg, end])
		if not touched.has(n):
			touched.append(n)
	for n in touched:
		if n.ports.is_empty():
			nodes.erase(n)
		else:
			_try_merge(n)

## Splits `seg` at `u` px along it and returns the new node there.
func split(seg: TrackSegment, u: float) -> TrackNode:
	var p := seg.point_at(u)
	var i := clampi(seg.cum.bsearch(u), 1, seg.points.size() - 1)
	var a_pts := seg.points.slice(0, i)
	if a_pts[a_pts.size() - 1].distance_to(p) > 0.5:
		a_pts.append(p)
	else:
		a_pts[a_pts.size() - 1] = p
	var b_pts := PackedVector2Array([p])
	var rest := seg.points.slice(i)
	if rest.size() > 0 and rest[0].distance_to(p) <= 0.5:
		rest = rest.slice(1)
	b_pts.append_array(rest)

	var node := _new_node(p)
	var sa := TrackSegment.new(a_pts)
	var sb := TrackSegment.new(b_pts)
	sa.nodes = [seg.nodes[0], node]
	sb.nodes = [node, seg.nodes[1]]
	_replace_port(seg.nodes[0], [seg, 0], [sa, 0])
	_replace_port(seg.nodes[1], [seg, 1], [sb, 1])
	node.ports = [[sa, 1], [sb, 0]]
	segments.erase(seg)
	segments.append(sa)
	segments.append(sb)
	return node

func toggle_switch(node: TrackNode) -> void:
	node.switch_state += 1

# --- Smoothing -------------------------------------------------------------
#
# Relaxing track that's already laid: every point moves towards a
# Gaussian-weighted average of its neighbours along the piece, then a
# second, slightly stronger negative step pushes it back out (Taubin's
# lambda/mu pair), which irons out wiggles without the curve shrinking
# the way plain averaging would pull a loop inwards. Both ends of every
# piece are pinned and the lead-in next to a junction ramps in slowly,
# so node positions and the tangent a train crosses a join on never move.

# 1/LAMBDA + 1/MU ~= 0.03: bends gentler than ~a 30 px-sigma kernel's
# reach (a 150 px-radius loop, say) pass through untouched.
const SMOOTH_LAMBDA := 0.9
const SMOOTH_MU := -0.925
const SMOOTH_SIGMA := 30.0 # px of track a tap-smooth averages over

## Smooths the track under a round brush at `center` by `amount` (0..1),
## strongest in the middle of the brush. The brush is a gentle airbrush --
## call it every frame while it's held. Returns the pieces that moved; call
## `finish_smoothing` on them once the stroke ends.
func smooth_brush(center: Vector2, radius: float, amount: float) -> Array:
	var moved := []
	var r2 := radius * radius
	for seg in segments:
		var w := PackedFloat32Array()
		w.resize(seg.points.size())
		var any := false
		for i in range(seg.points.size()):
			var d2: float = seg.points[i].distance_squared_to(center)
			if d2 < r2:
				var f := 1.0 - d2 / r2
				w[i] = f * f
				any = true
		if any and _relax(seg, w, radius * 0.65, amount):
			moved.append(seg)
	return moved

## Smooths a whole piece in one go (a tap with the Smooth tool).
func smooth_segment(seg: TrackSegment, passes: int = 4) -> bool:
	var w := PackedFloat32Array()
	w.resize(seg.points.size())
	w.fill(1.0)
	var moved := false
	for _k in range(passes):
		moved = _relax(seg, w, SMOOTH_SIGMA) or moved
	if moved:
		finish_smoothing([seg])
	return moved

## Re-spaces the points of smoothed pieces evenly again. Kept out of the
## per-frame brush so resampling doesn't nibble at the whole piece's shape.
func finish_smoothing(segs: Array) -> void:
	for seg in segs:
		if segments.has(seg):
			seg.set_points(_resample(seg.points, SPACING))

## One lambda/mu pass over `seg`, point i moving by weight w[i] (times
## the end pin), then only `amount` of the way there. The pass itself is
## always full strength: tiny lambda and mu steps cancel each other out
## and do nothing. False if nothing moved noticeably.
func _relax(seg: TrackSegment, w: PackedFloat32Array, sigma: float, amount: float = 1.0) -> bool:
	var n := seg.points.size()
	if n < 5:
		return false
	var pin := PackedFloat32Array()
	pin.resize(n)
	var lead0 := _end_lead(seg.nodes[0])
	var lead1 := _end_lead(seg.nodes[1])
	for i in range(n):
		var a := smoothstep(lead0 * 0.6, lead0 * 1.6, seg.cum[i]) if lead0 > 0.0 else 1.0
		var b := smoothstep(lead1 * 0.6, lead1 * 1.6, seg.length - seg.cum[i]) if lead1 > 0.0 else 1.0
		pin[i] = a * b * w[i]
	pin[0] = 0.0
	pin[n - 1] = 0.0
	var reach := maxi(int(ceil(sigma * 2.5 / SPACING)), 1)
	var kernel := PackedFloat32Array()
	for k in range(reach + 1):
		var x := k * SPACING / sigma
		kernel.append(exp(-0.5 * x * x))
	var pts := seg.points
	var mid := _taubin_step(pts, pin, kernel, SMOOTH_LAMBDA)
	var out := _taubin_step(mid, pin, kernel, SMOOTH_MU)
	var max_move := 0.0
	for i in range(n):
		if amount < 1.0:
			out[i] = pts[i].lerp(out[i], amount)
		max_move = maxf(max_move, out[i].distance_squared_to(pts[i]))
	if max_move < 1e-6:
		return false
	seg.set_points(out)
	return true

## How far in from a node the track has to keep its tangent: the lead-in
## at a junction, nothing at a buffer stop.
func _end_lead(node: TrackNode) -> float:
	return LEAD if node != null and node.ports.size() > 1 else 0.0

static func _taubin_step(pts: PackedVector2Array, weight: PackedFloat32Array, kernel: PackedFloat32Array, factor: float) -> PackedVector2Array:
	var n := pts.size()
	var out := pts.duplicate()
	for i in range(1, n - 1):
		if weight[i] <= 0.0:
			continue
		# Window kept symmetric near the ends so it doesn't drag points
		# towards the middle of the piece.
		var reach := mini(kernel.size() - 1, mini(i, n - 1 - i))
		var acc := pts[i] * kernel[0]
		var total: float = kernel[0]
		for k in range(1, reach + 1):
			acc += (pts[i - k] + pts[i + k]) * kernel[k]
			total += 2.0 * kernel[k]
		out[i] = pts[i] + (acc / total - pts[i]) * (factor * weight[i])
	return out

func _new_node(p: Vector2) -> TrackNode:
	var n := TrackNode.new()
	n.position = p
	nodes.append(n)
	return n

func _replace_port(node: TrackNode, old_port: Array, new_port: Array) -> void:
	var i := node.ports.find(old_port)
	if i >= 0:
		node.ports[i] = new_port

## A node or a point on a piece near `p` (splitting the piece there), or
## null for open ground.
func _resolve_end(p: Vector2, snap: float) -> TrackNode:
	var n := node_near(p, snap)
	if n != null and not n.ports.is_empty():
		return n
	var hit := nearest(p, snap)
	if hit.is_empty():
		return null
	var seg: TrackSegment = hit["seg"]
	if hit["u"] < END_MARGIN:
		return seg.nodes[0]
	if hit["u"] > seg.length - END_MARGIN:
		return seg.nodes[1]
	return split(seg, hit["u"])

## The tangent direction at a join that best matches where the stroke
## wants to go. Leaving `node`: continue straight on from some port's
## track (-port_dir). Arriving: continue into some port (port_dir).
func _best_dir(node: TrackNode, want: Vector2, leaving: bool) -> Vector2:
	var best := want
	var best_dot := -INF
	for q in node.ports:
		var d := -port_dir(q) if leaving else port_dir(q)
		var dot := d.dot(want)
		if dot > best_dot:
			best_dot = dot
			best = d
	return best

func _stroke_dir(raw: PackedVector2Array, at_end: bool) -> Vector2:
	var n := raw.size()
	var origin := raw[n - 1] if at_end else raw[0]
	for k in range(1, n):
		var p := raw[n - 1 - k] if at_end else raw[k]
		if p.distance_to(origin) >= 24.0 or k == n - 1:
			var d := (origin - p) if at_end else (p - origin)
			return d.normalized() if d.length() > 0.01 else Vector2.RIGHT
	return Vector2.RIGHT

## Two pieces meeting smoothly at a node with nothing else there become
## one piece -- keeps the graph small and extending a dead end seamless.
func _try_merge(node: TrackNode) -> void:
	if node.ports.size() != 2:
		return
	var pa: Array = node.ports[0]
	var pb: Array = node.ports[1]
	if pa[0] == pb[0]:
		return
	if port_dir(pa).dot(-port_dir(pb)) < 0.7:
		return
	var sa: TrackSegment = pa[0]
	var sb: TrackSegment = pb[0]
	var a_pts := sa.points.duplicate()
	if pa[1] == 0:
		a_pts.reverse()
	var b_pts := sb.points.duplicate()
	if pb[1] == 1:
		b_pts.reverse()
	var merged := a_pts + b_pts.slice(1)
	var na: TrackNode = sa.nodes[1 - pa[1]]
	var nb: TrackNode = sb.nodes[1 - pb[1]]
	var m := TrackSegment.new(merged)
	m.nodes = [na, nb]
	_replace_port(na, [sa, 1 - pa[1]], [m, 0])
	_replace_port(nb, [sb, 1 - pb[1]], [m, 1])
	segments.erase(sa)
	segments.erase(sb)
	segments.append(m)
	nodes.erase(node)

# --- Geometry helpers ------------------------------------------------------

## Where a piece crosses itself (a figure of eight drawn in one go):
## [[point, u, u], ...] with the two u's where it passes.
static func self_crossings(a: TrackSegment) -> Array:
	var out := []
	var pa := a.points
	for i in range(1, pa.size()):
		for j in range(i + 3, pa.size()):
			var hit = Geometry2D.segment_intersects_segment(pa[i - 1], pa[i], pa[j - 1], pa[j])
			if hit == null:
				continue
			var p: Vector2 = hit
			if not out.is_empty() and (out[out.size() - 1][0] as Vector2).distance_to(p) < 4.0:
				continue
			out.append([p, a.cum[i - 1] + pa[i - 1].distance_to(p), a.cum[j - 1] + pa[j - 1].distance_to(p)])
	return out

## Where two pieces cross: [[point, u along a, u along b], ...]. Used for
## road crossroads and for level crossings between a road and the track.
static func crossings(a: TrackSegment, b: TrackSegment) -> Array:
	var out := []
	var pa := a.points
	var pb := b.points
	for i in range(1, pa.size()):
		var a0 := pa[i - 1]
		var a1 := pa[i]
		var lo := Vector2(minf(a0.x, a1.x), minf(a0.y, a1.y))
		var hi := Vector2(maxf(a0.x, a1.x), maxf(a0.y, a1.y))
		for j in range(1, pb.size()):
			var b0 := pb[j - 1]
			var b1 := pb[j]
			if maxf(b0.x, b1.x) < lo.x or minf(b0.x, b1.x) > hi.x or maxf(b0.y, b1.y) < lo.y or minf(b0.y, b1.y) > hi.y:
				continue
			var hit = Geometry2D.segment_intersects_segment(a0, a1, b0, b1)
			if hit == null:
				continue
			var p: Vector2 = hit
			if not out.is_empty() and (out[out.size() - 1][0] as Vector2).distance_to(p) < 4.0:
				continue
			var ua: float = a.cum[i - 1] + a0.distance_to(p)
			var ub: float = b.cum[j - 1] + b0.distance_to(p)
			out.append([p, ua, ub])
	return out

static func _polyline_length(pts: PackedVector2Array) -> float:
	var l := 0.0
	for i in range(1, pts.size()):
		l += pts[i].distance_to(pts[i - 1])
	return l

## Drops points closer than `spacing` to the last kept one (keeps both ends).
static func _thin(pts: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size() - 1):
		if pts[i].distance_to(out[out.size() - 1]) >= spacing:
			out.append(pts[i])
	var last := pts[pts.size() - 1]
	if out.size() > 1 and out[out.size() - 1].distance_to(last) < spacing * 0.5:
		out[out.size() - 1] = last
	else:
		out.append(last)
	return out

## Corner-cutting smoothing that keeps both end points (and so the
## tangent of the first/last leg, which is what makes joins line up).
static func _chaikin(pts: PackedVector2Array, iterations: int) -> PackedVector2Array:
	for _k in range(iterations):
		if pts.size() < 3:
			return pts
		var out := PackedVector2Array([pts[0]])
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			out.append(a.lerp(b, 0.25))
			out.append(a.lerp(b, 0.75))
		out.append(pts[pts.size() - 1])
		pts = out
	return pts

## Evenly spaced points along a polyline, ends kept exactly.
static func _resample(pts: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])
	var carry := 0.0
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var seg_len := a.distance_to(b)
		var d := spacing - carry
		while d <= seg_len:
			out.append(a.lerp(b, d / seg_len))
			d += spacing
		carry = seg_len - (d - spacing)
	var last := pts[pts.size() - 1]
	if out[out.size() - 1].distance_to(last) < spacing * 0.5 and out.size() > 1:
		out[out.size() - 1] = last
	else:
		out.append(last)
	return out

# --- Save / load -----------------------------------------------------------

func to_dict() -> Dictionary:
	var index := {}
	var node_list := []
	for i in range(nodes.size()):
		var n: TrackNode = nodes[i]
		index[n] = i
		node_list.append({"x": snappedf(n.position.x, 0.01), "y": snappedf(n.position.y, 0.01), "switch": n.switch_state})
	var seg_list := []
	for seg in segments:
		var flat := []
		for p in seg.points:
			flat.append(snappedf(p.x, 0.01))
			flat.append(snappedf(p.y, 0.01))
		seg_list.append({"a": index[seg.nodes[0]], "b": index[seg.nodes[1]], "pts": flat})
	return {"nodes": node_list, "segments": seg_list}

func from_dict(d: Dictionary) -> void:
	clear()
	for nd in d.get("nodes", []):
		var n := _new_node(Vector2(float(nd.get("x", 0.0)), float(nd.get("y", 0.0))))
		n.switch_state = int(nd.get("switch", 0))
	for sd in d.get("segments", []):
		var a := int(sd.get("a", -1))
		var b := int(sd.get("b", -1))
		var flat: Array = sd.get("pts", [])
		if a < 0 or b < 0 or a >= nodes.size() or b >= nodes.size() or flat.size() < 4:
			continue
		var pts := PackedVector2Array()
		for i in range(0, flat.size() - 1, 2):
			pts.append(Vector2(float(flat[i]), float(flat[i + 1])))
		var seg := TrackSegment.new(pts)
		seg.nodes = [nodes[a], nodes[b]]
		nodes[a].ports.append([seg, 0])
		nodes[b].ports.append([seg, 1])
		segments.append(seg)
	for n in nodes.duplicate():
		if n.ports.is_empty():
			nodes.erase(n)
