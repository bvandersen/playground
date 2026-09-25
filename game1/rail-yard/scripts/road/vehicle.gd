extends RefCounted
class_name Vehicle

## One car, lorry or bus on the roads.
##
## Saved as its look ({type, color, seed}) plus where it stands and which
## way it faces. At run time it drives along a *lane*: a polyline offset
## LANE px to the right of the road centre, built a few pieces ahead of
## the vehicle. At each junction it picks a random way on (RoadNetwork
## .exits), or turns round at a dead end; the lanes of the two pieces are
## joined with a short Bezier curve, so turning corners and U-turns are one
## smooth path. Front and rear axles both sit on that path and the body on
## the line between them -- the same trick that makes the trains look
## right -- and a towed trailer swings in behind on its hitch.
##
## It cruises at its own speed, slows for corners, keeps its distance
## from anything in its lane ahead (other traffic, crossing paths at a
## junction), and stops at a level crossing while the barriers are down.

const TRIM := 11.0 # lane ends cut back at a junction for the joining curve
const ACCEL := 55.0 # px/s^2
const BRAKE := 170.0
const SOFT_BRAKE := 85.0 # planned deceleration for stopping short of things
const LOOK := 150.0 # how far ahead it looks, px
const LOOK_STEP := 6.0
const KEEP := 8.0 # gap it leaves to whatever is ahead, px
const LOOK_PAD := 3.2 # how close to another vehicle's body counts as hitting it
const STUCK_TIME := 3.0 # s nose-to-nose at a junction before it squeezes past

var look: Dictionary = {} # {type, color, seed}
var anchor := Vector2.ZERO
var heading := Vector2.RIGHT

# --- Runtime -------------------------------------------------------------------
var lane: TrackSegment = null
var s := 0.0 # the body's centre along `lane`
var v := 0.0
var cruise := 70.0
var pos := Vector2.ZERO
var dir := Vector2.RIGHT
var braking := false
var high := false # up on a road bridge (drawn above the railway under it)
var has_trailer := false
var trailer_pos := Vector2.ZERO
var trailer_dir := Vector2.RIGHT
var _t_axle := Vector2.ZERO
var _roads: RoadNetwork = null
var _end_seg: TrackSegment = null # the road piece the lane currently ends on...
var _end_rev := false # ...and which way along it
var blocked_by = null # the vehicle it's waiting behind, if any
var _stuck := 0.0
var _ghost := 0.0 # s left squeezing past `_ignore`
var _ignore = null

# The catalog entry's numbers, looked up once per type rather than on
# every call: drive() and the other vehicles' look-ahead ask for them
# hundreds of times a tick.
var _type := ""
var _len := 0.0
var _wid := 0.0
var _trailer: Dictionary = {}

func _cache() -> void:
	var type: String = look["type"]
	if type == _type:
		return
	var e := VehicleCatalog.entry(type)
	_type = type
	_len = float(e["length"])
	_wid = float(e["width"])
	_trailer = e.get("trailer", {})

func length() -> float:
	_cache()
	return _len

func width() -> float:
	_cache()
	return _wid

func trailer() -> Dictionary:
	_cache()
	return _trailer

func is_placed() -> bool:
	return lane != null

# --- Placement -------------------------------------------------------------

## Puts the vehicle on the road nearest `anchor`, in the lane for driving
## along `heading`. False if there's no road there.
func place(roads: RoadNetwork) -> bool:
	lane = null
	_roads = roads
	var hit := roads.nearest(anchor, 60.0)
	if hit.is_empty():
		return false
	var seg: TrackSegment = hit["seg"]
	var u: float = hit["u"]
	var rev := seg.tangent_at(u).dot(heading) < 0.0
	var along: float = seg.length - u if rev else u
	var back := length() * 0.5 + 30.0
	var from := maxf(along - back, 0.0)
	lane = TrackSegment.new(_lane_points(seg, rev, from))
	_end_seg = seg
	_end_rev = rev
	s = along - from
	v = 0.0
	var e := VehicleCatalog.entry(look["type"])
	var sp: Array = e["speed"]
	cruise = randf_range(sp[0], sp[1])
	_extend()
	_update_pose()
	has_trailer = not trailer().is_empty()
	if has_trailer:
		var tr := trailer()
		var hitch := pos - dir * float(tr["hitch"])
		trailer_dir = dir
		_t_axle = hitch - dir * _trailer_axle()
		trailer_pos = hitch - dir * float(tr["pin"])
	return true

## The lane along `seg` travelling end 0 -> 1 (or back if `rev`), from
## `from` px in: the centreline shifted LANE px to its right.
static func _lane_points(seg: TrackSegment, rev: bool, from: float) -> PackedVector2Array:
	var pts := seg.points.duplicate()
	if rev:
		pts.reverse()
	var n := pts.size()
	var out := PackedVector2Array()
	var acc := 0.0
	for i in range(n):
		if i > 0:
			acc += pts[i].distance_to(pts[i - 1])
		if acc < from and i < n - 2:
			continue
		var t := pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		t = t.normalized() if t.length_squared() > 1e-8 else Vector2.RIGHT
		out.append(pts[i] + Vector2(-t.y, t.x) * RoadNetwork.LANE)
	return out

## Grows the lane ahead until it reaches well past what the vehicle can
## see, choosing a way on at each junction as it gets there.
func _extend() -> void:
	for _guard in range(12):
		if lane.length - s > LOOK + length() + 40.0:
			return
		var end := 0 if _end_rev else 1
		var node: TrackNode = _end_seg.nodes[end]
		var next_seg := _end_seg
		var next_rev := not _end_rev # dead end: turn round, back along the same piece
		var ways := _roads.exits(node, [_end_seg, end]) if node != null else []
		if not ways.is_empty():
			var q: Array = ways[randi() % ways.size()]
			next_seg = q[0]
			next_rev = q[1] == 1
		_join(_lane_points(next_seg, next_rev, 0.0))
		_end_seg = next_seg
		_end_rev = next_rev

## Appends `nxt` to the lane, both ends trimmed back and bridged with a
## cubic Bezier that leaves and arrives along each lane's own direction.
func _join(nxt: PackedVector2Array) -> void:
	var pts := lane.points.duplicate()
	var tip := pts[pts.size() - 1]
	while pts.size() > 2 and pts[pts.size() - 1].distance_to(tip) < TRIM and lane.cum[pts.size() - 1] > s + length():
		pts.remove_at(pts.size() - 1)
	var start := nxt[0]
	var k := 0
	while k < nxt.size() - 2 and nxt[k].distance_to(start) < TRIM:
		k += 1
	nxt = nxt.slice(k)
	var p0 := pts[pts.size() - 1]
	var p3 := nxt[0]
	var t0 := (p0 - pts[pts.size() - 2]).normalized()
	var t3 := (nxt[1] - nxt[0]).normalized()
	var reach := maxf(p0.distance_to(p3) * 0.42, 4.0)
	if t0.dot(t3) < -0.5:
		reach = RoadNetwork.LANE * 1.9 # a U-turn swings out round the end
	var c1 := p0 + t0 * reach
	var c2 := p3 - t3 * reach
	for i in range(1, 8):
		var t := i / 8.0
		var mt := 1.0 - t
		pts.append(p0 * (mt * mt * mt) + c1 * (3.0 * mt * mt * t) + c2 * (3.0 * mt * t * t) + p3 * (t * t * t))
	pts.append_array(nxt)
	lane.set_points(pts)

## Drops lane already driven over, so it doesn't grow forever.
func _rebase() -> void:
	if s < 400.0:
		return
	var cut := s - length() - 60.0
	var i := clampi(lane.cum.bsearch(cut), 1, lane.points.size() - 2)
	var shift: float = lane.cum[i]
	lane.set_points(lane.points.slice(i))
	s -= shift

func _update_pose() -> void:
	var wb := length() * 0.3
	var f := lane.point_at(s + wb)
	var r := lane.point_at(s - wb)
	pos = (f + r) * 0.5
	var d := f - r
	if d.length_squared() > 1e-6:
		dir = d.normalized()

func _trailer_axle() -> float:
	var tr := trailer()
	return float(tr["pin"]) + float(tr["length"]) * 0.5 - 9.0

# --- Driving ---------------------------------------------------------------

## One physics tick. `others` is every vehicle, `crossings` every
## LevelCrossing (a closed one is a red light).
func drive(delta: float, others: Array, crossings: Array) -> void:
	if lane == null:
		return
	var half := length() * 0.5
	var front := s + half
	var gap := INF
	var blocker = null
	_ghost = maxf(_ghost - delta, 0.0)
	# Anything in the lane ahead: other traffic, or a crossing with its
	# barriers down. Opposite-lane traffic is ~17 px off to the side, so
	# it never shows up here.
	var near := []
	# Per nearby vehicle: its bounding radius (squared) about its centre,
	# so most probe points are ruled out without the full box test.
	var near_r2 := PackedFloat32Array()
	for o in others:
		if o != self and o.lane != null and o.pos.distance_squared_to(pos) < (LOOK + 80.0) * (LOOK + 80.0):
			if _ghost <= 0.0 or o != _ignore:
				near.append(o)
				near_r2.append(o.reach_sq(LOOK_PAD))
	# Already on a crossing: keep going, through its linked neighbours too,
	# rather than stop on the track between two lines.
	var on_it := []
	var probes: Array = []
	for c in crossings:
		if c.kind != "level":
			continue
		if probes.is_empty():
			probes = [lane.point_at(front), pos, lane.point_at(s - half)]
		var z: float = c.zone()
		for p in probes:
			if p.distance_to(c.pos) < z:
				on_it.append(c)
				break
	var shut := []
	var shut_zone := []
	for c in crossings:
		if c.blocks_road() and c.pos.distance_squared_to(pos) < (LOOK + 60.0) * (LOOK + 60.0):
			var clear := true
			for o in on_it:
				if o.pos.distance_to(c.pos) < LevelCrossing.LINK_DIST:
					clear = false
			if clear:
				shut.append(c)
				shut_zone.append(c.zone())
	if not near.is_empty() or not shut.is_empty():
		var d := 0.0
		var first := true
		while d <= LOOK:
			var p := lane.point_at(front + d)
			for k in range(near.size()):
				var o = near[k]
				if p.distance_squared_to(o.pos) <= near_r2[k] and o.occupies(p, LOOK_PAD):
					gap = d
					blocker = o
					break
			if gap < INF:
				break
			for k in range(shut.size()):
				if p.distance_to(shut[k].pos) < shut_zone[k]:
					if not first:
						gap = d
					else:
						shut.remove_at(k) # already on it: drive on across
						shut_zone.remove_at(k)
					break
			if gap < INF:
				break
			first = false
			d += LOOK_STEP
	var target := cruise
	if not on_it.is_empty():
		target = maxf(cruise, 60.0) # get off the track, bends or not
	if gap < INF:
		target = minf(target, sqrt(2.0 * SOFT_BRAKE * maxf(gap - KEEP, 0.0)))
	# Slow for the bend coming up.
	var t_now := (lane.point_at(front + 4.0) - lane.point_at(front - 4.0)).normalized()
	var t_ahead := (lane.point_at(front + 34.0) - lane.point_at(front + 26.0)).normalized()
	var bend := absf(t_now.angle_to(t_ahead))
	if on_it.is_empty():
		target = minf(target, cruise * (1.0 - 0.55 * clampf(bend / 1.4, 0.0, 1.0)))
	braking = target < v - 3.0 or (v < 2.0 and target < 2.0)
	v += clampf(target - v, -BRAKE * delta, ACCEL * delta)
	# Only a vehicle across our path, or one waiting on us in turn (two
	# merging into the same lane), can be a standoff; one ahead going our
	# way is just a queue.
	blocked_by = blocker
	var standoff: bool = blocker != null and (blocker.dir.dot(dir) < 0.5 or blocker.blocked_by == self)
	if v < 1.0 and standoff:
		_stuck += delta
		# Whoever has waited longest (or, tied, the older one) goes first.
		if _stuck > STUCK_TIME or (blocker.blocked_by == self and _stuck > 1.0 and _stuck >= blocker._stuck):
			_stuck = randf_range(-1.5, 0.0)
			_ghost = 1.8
			_ignore = blocker
			Sfx.play_at("beep", pos, 0.0, randf_range(0.9, 1.15))
	else:
		_stuck = maxf(_stuck - delta, 0.0)
	s += v * delta
	_extend()
	_rebase()
	_update_pose()
	if has_trailer:
		var tr := trailer()
		var hitch := pos - dir * float(tr["hitch"])
		var d2 := hitch - _t_axle
		if d2.length_squared() > 1e-6:
			trailer_dir = d2.normalized()
		_t_axle = hitch - trailer_dir * _trailer_axle()
		trailer_pos = hitch - trailer_dir * float(tr["pin"])

## True if `p` is within `pad` px of this vehicle's body (or trailer).
func occupies(p: Vector2, pad: float) -> bool:
	_cache()
	if _inside(p, pos, dir, _len, _wid, pad):
		return true
	if has_trailer:
		return _inside(p, trailer_pos, trailer_dir, float(_trailer["length"]), float(_trailer["width"]), pad)
	return false

## Squared radius about `pos` outside which occupies(p, pad) is always
## false: the corner of the body box, or the far corner of the trailer's.
## A little slack is added so rounding never makes it disagree with
## occupies() at the very edge.
func reach_sq(pad: float) -> float:
	_cache()
	var r := Vector2(_len * 0.5 + pad, _wid * 0.5 + pad).length()
	if has_trailer:
		var tl := float(_trailer["length"]) * 0.5 + pad
		var tw := float(_trailer["width"]) * 0.5 + pad
		r = maxf(r, pos.distance_to(trailer_pos) + Vector2(tl, tw).length())
	r += 0.5
	return r * r

static func _inside(p: Vector2, c: Vector2, d: Vector2, l: float, w: float, pad: float) -> bool:
	var q := p - c
	return absf(q.dot(d)) <= l * 0.5 + pad and absf(q.cross(d)) <= w * 0.5 + pad

# --- Save / load -------------------------------------------------------------

func to_dict() -> Dictionary:
	var at := anchor
	var hd := heading
	if lane != null:
		# Where it is now, pulled back from the lane onto the road centre.
		at = pos - Vector2(-dir.y, dir.x) * RoadNetwork.LANE
		hd = dir
	return {
		"type": look["type"], "color": (look["color"] as Color).to_html(false), "seed": look["seed"],
		"x": snappedf(at.x, 0.01), "y": snappedf(at.y, 0.01),
		"hx": snappedf(hd.x, 0.0001), "hy": snappedf(hd.y, 0.0001),
	}

static func from_dict(d: Dictionary) -> Vehicle:
	var type := str(d.get("type", "sedan"))
	if not VehicleCatalog.has_type(type):
		return null
	var veh := Vehicle.new()
	veh.look = {"type": type, "color": Color.html(str(d.get("color", "ffffff"))), "seed": int(d.get("seed", 0))}
	veh.anchor = Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
	var h := Vector2(float(d.get("hx", 1.0)), float(d.get("hy", 0.0)))
	veh.heading = h.normalized() if h.length() > 0.001 else Vector2.RIGHT
	return veh
