extends RefCounted
class_name Station

## A station: a platform along one side of the track with a little
## station house behind it, and the people who come and go there.
##
## Saved as where it was put down (a point on the track) and which side
## the platform is on; the platform itself follows the track for HALF px
## either way from there (through switches as they're set when it's
## laid out), so it bends round curves with the line. It's re-laid
## whenever the track changes, and removed if its track is gone.
##
## People turn up (in Play) and wait on the platform, shuffling about and
## looking out for trains. A train with seats (WagonCatalog `seats`)
## stops with its seated cars along the platform and calls `serve` every
## tick while it stands there: riders whose trip ends here step out onto
## the platform and walk off, then waiting people walk to the nearest car
## with a free seat and climb aboard. The train leaves once everyone has
## got where they're going.

const HALF := 95.0 # platform half length along the track, px
const STEP := 5.0
const INNER := 17.0 # platform edge's distance from the track centre
const WIDTH := 28.0
const HOUSE_DEPTH := 22.0
const HOUSE_HALF := 22.0
const MIN_LEN := 70.0
const SNAP := 40.0
const MAX_WAITING := 10
const HURRY := 1.3 # people walk faster getting on and off a train
const MIN_DWELL := 2.5 # s a train stands even if nobody gets on or off
const MAX_DWELL := 14.0
const SUN := Vector2(3.5, 4.5)

const COLORS := [
	Color(0.78, 0.22, 0.18), Color(0.2, 0.42, 0.72), Color(0.2, 0.55, 0.32),
	Color(0.9, 0.55, 0.12), Color(0.5, 0.28, 0.62), Color(0.12, 0.55, 0.58),
]

# --- Saved ---------------------------------------------------------------------
var anchor := Vector2.ZERO # platform centre, on the track
var face := Vector2.UP # from the track towards the platform
var color: Color = COLORS[0]
var seed := 0

# --- Runtime -------------------------------------------------------------------
var valid := false
var track := PackedVector2Array() # track centreline samples, STEP apart
var normals := PackedVector2Array() # unit, pointing towards the platform
var center_i := 0
var people: Array = []
var mesh: ArrayMesh # platform, benches, planters, house shadow
var roof_mesh: ArrayMesh # the house roof and lamps, drawn above people

var _spawn_timer := 1.5
var _serving := {} # Train -> true while it stands here

# --- Placement -----------------------------------------------------------------

## Lays the platform out along the track nearest `anchor`. False if there's
## no track there, or not enough of it.
func resolve(net: TrackNetwork) -> bool:
	valid = false
	var hit := net.nearest(anchor, SNAP)
	if hit.is_empty():
		return false
	var seg: TrackSegment = hit["seg"]
	var u: float = hit["u"]
	var fwd: PackedVector2Array = net.walk(seg, false, u, HALF, STEP)["points"]
	var back: PackedVector2Array = net.walk(seg, true, seg.length - u, HALF, STEP)["points"]
	var pts := PackedVector2Array()
	for i in range(back.size() - 1, 0, -1):
		pts.append(back[i])
	center_i = pts.size()
	pts.append_array(fwd)
	if (pts.size() - 1) * STEP < MIN_LEN:
		return false
	var n := pts.size()
	var nrm := PackedVector2Array()
	nrm.resize(n)
	for i in range(n):
		var d := pts[mini(i + 2, n - 1)] - pts[maxi(i - 2, 0)]
		nrm[i] = d.normalized().orthogonal()
	# Keep the platform on the side it was put, whichever way the piece runs.
	if nrm[center_i].dot(face) < 0.0:
		for i in range(n):
			nrm[i] = -nrm[i]
	track = pts
	normals = nrm
	anchor = pts[center_i]
	face = nrm[center_i]
	valid = true
	_build_meshes()
	for p in people:
		if p.state == "wait" and p.path.is_empty():
			p.spot.x = clampf(p.spot.x, 2.0, n - 3.0)
			p.pos = plat(p.spot.x, p.spot.y)
	return true

## A point on the platform: `fi` samples along it, `depth` px back from
## its track-side edge.
func plat(fi: float, depth: float) -> Vector2:
	var n := track.size()
	fi = clampf(fi, 0.0, n - 1.0)
	var i := mini(int(fi), n - 2)
	var t := fi - i
	var p := track[i].lerp(track[i + 1], t)
	var nn := normals[i].lerp(normals[i + 1], t).normalized()
	return p + nn * (INNER + depth)

func tangent_at(i: int) -> Vector2:
	return -normals[clampi(i, 0, normals.size() - 1)].orthogonal()

## [sample index, distance] of the track sample closest to `p`.
func nearest_index(p: Vector2) -> Array:
	var best := -1
	var best_d := INF
	for i in range(track.size()):
		var d := track[i].distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return [best, sqrt(best_d)]

## True if `p` is on the platform or the house.
func contains(p: Vector2, pad: float = 0.0) -> bool:
	if not valid:
		return false
	var ni := nearest_index(p)
	var i: int = ni[0]
	var off := p - track[i]
	var depth := off.dot(normals[i]) - INNER
	var along := absf(off.dot(tangent_at(i)))
	if along > STEP + pad:
		return false
	if depth < -pad:
		return false
	if depth <= WIDTH + pad:
		return true
	return depth <= WIDTH + HOUSE_DEPTH + pad and absf(i - center_i) * STEP <= HOUSE_HALF + pad

## Points spread over the platform and house (for clearing scenery and
## checking what's in the way).
func footprint() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, track.size(), 3):
		out.append(plat(i, WIDTH * 0.5))
	out.append(plat(center_i, WIDTH + HOUSE_DEPTH * 0.5))
	out.append(plat(center_i - 3, WIDTH + HOUSE_DEPTH * 0.5))
	out.append(plat(center_i + 3, WIDTH + HOUSE_DEPTH * 0.5))
	return out

## True if a train stands with a car over the station's centre point.
func alongside(t) -> bool:
	return valid and t.car_at(anchor, 2.0) >= 0

# --- People ----------------------------------------------------------------------

## A few people already waiting, so a new station isn't empty.
func populate() -> void:
	for _i in range(randi_range(3, 6)):
		var p := Person.new()
		p.state = "wait"
		p.spot = _free_spot()
		p.pos = plat(p.spot.x, p.spot.y)
		p.heading = _facing_track(p.spot.x) + randf_range(-0.8, 0.8)
		p.face = p.heading
		p.idle = randf_range(0.5, 4.0)
		people.append(p)

func waiting_count() -> int:
	var c := 0
	for p in people:
		if p.state == "wait" or p.state == "arrive":
			c += 1
	return c

func update(delta: float, playing: bool) -> void:
	if not valid:
		return
	if playing:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = randf_range(1.5, 4.5)
			if waiting_count() < MAX_WAITING:
				_spawn_arrival()
	for t in _serving.keys():
		if t.dwelling_at != self:
			_serving.erase(t)
	for p in people.duplicate():
		_update_person(p, delta)

func _update_person(p: Person, delta: float) -> void:
	if p.fading != 0.0:
		p.alpha = clampf(p.alpha + p.fading * delta * 2.2, 0.0, 1.0)
		if p.fading < 0.0 and p.alpha <= 0.0:
			people.erase(p)
			return
		if p.fading > 0.0 and p.alpha >= 1.0:
			p.fading = 0.0
	var done := p.step(delta)
	match p.state:
		"arrive":
			if done:
				p.state = "wait"
				p.face = _facing_track(p.spot.x) + randf_range(-0.6, 0.6)
				p.idle = randf_range(1.0, 4.0)
		"wait":
			if done:
				p.idle -= delta
				if p.idle <= 0.0:
					_fidget(p)
		"board":
			if p.train == null or p.train.dwelling_at != self or p.car >= p.train.cars.size():
				_send_to_spot(p)
			elif done:
				p.train.riders[p.car].append({"look": p.look, "rides": randi_range(1, 3)})
				people.erase(p)
		"alight":
			if done:
				p.state = "leave"
				_set_exit(p)
		"leave":
			if p.exit_end and p.fading == 0.0 and p.path.size() <= 1:
				p.fading = -1.0
			if done:
				people.erase(p)

func _fidget(p: Person) -> void:
	p.idle = randf_range(2.0, 6.0)
	var r := randf()
	if r < 0.45:
		p.face = _facing_track(p.spot.x) + randf_range(-0.5, 0.5)
	elif r < 0.75:
		p.face = randf() * TAU
	else:
		var s := Vector2(clampf(p.spot.x + randf_range(-2.0, 2.0), 2.0, track.size() - 3.0),
			clampf(p.spot.y + randf_range(-3.0, 3.0), 6.5, WIDTH - 8.0))
		if _spot_free(s, p):
			p.spot = s
			p.path = [plat(s.x, s.y)]
			p.face = _facing_track(s.x) + randf_range(-0.5, 0.5)

func _facing_track(fi: float) -> float:
	return (-normals[clampi(int(fi), 0, normals.size() - 1)]).angle()

func _spot_free(s: Vector2, me: Person) -> bool:
	var q := plat(s.x, s.y)
	for o in people:
		if o == me:
			continue
		if o.state == "wait" or o.state == "arrive":
			if plat(o.spot.x, o.spot.y).distance_squared_to(q) < 90.0:
				return false
	return true

## A place on the platform to stand, clear of everyone else if possible.
func _free_spot() -> Vector2:
	var s := Vector2.ZERO
	for _try in range(12):
		s = Vector2(randf_range(3.0, track.size() - 4.0), randf_range(6.5, WIDTH - 8.0))
		if _spot_free(s, null):
			break
	return s

func _send_to_spot(p: Person) -> void:
	p.state = "wait"
	p.train = null
	p.car = -1
	p.spot = _free_spot()
	p.path = [plat(p.spot.x, p.spot.y)]
	p.face = _facing_track(p.spot.x)
	p.idle = randf_range(1.0, 3.0)

## Someone turns up, out of the station house or along the platform.
func _spawn_arrival() -> void:
	var p := Person.new()
	p.state = "arrive"
	p.spot = _free_spot()
	if randf() < 0.65:
		p.pos = plat(center_i, WIDTH + 9.0)
		p.path = [plat(center_i + randf_range(-1.0, 1.0), WIDTH - 3.0), plat(p.spot.x, p.spot.y)]
	else:
		var end := 0 if randf() < 0.5 else track.size() - 1
		var out := tangent_at(end) * (-1.0 if end == 0 else 1.0)
		var mid := randf_range(6.0, WIDTH - 6.0)
		p.pos = plat(end, mid) + out * 22.0
		p.path = [plat(end, mid), plat(p.spot.x, p.spot.y)]
		p.alpha = 0.0
		p.fading = 1.0
	p.heading = (p.path[0] - p.pos).angle()
	people.append(p)

## Off home: through the station house door, or off an end of the platform.
func _set_exit(p: Person) -> void:
	var here := nearest_index(p.pos)[0] as int
	var to_end := mini(here, track.size() - 1 - here) * STEP
	if to_end < 45.0 and randf() < 0.7:
		var end := 0 if here < track.size() / 2 else track.size() - 1
		var out := tangent_at(end) * (-1.0 if end == 0 else 1.0)
		var mid := randf_range(6.0, WIDTH - 6.0)
		p.path = [plat(end, mid), plat(end, mid) + out * 22.0]
		p.exit_end = true
	else:
		var door := center_i + randf_range(-1.0, 1.0)
		p.path = [plat(door, WIDTH - 3.0), plat(door, WIDTH + 9.0)]
		p.exit_end = false

# --- Trains ------------------------------------------------------------------------

## Called every tick while train `t` stands here; true when it may leave.
func serve(t, time: float) -> bool:
	if not valid:
		return true
	if not _serving.has(t):
		_serving[t] = true
		_begin(t)
	var busy := false
	for p in people:
		if p.train == t and (p.state == "board" or p.state == "alight"):
			busy = true
			break
	if time > MAX_DWELL:
		for p in people:
			if p.train == t and p.state == "board":
				_send_to_spot(p)
		busy = false
	if busy or time < MIN_DWELL:
		return false
	_serving.erase(t)
	return true

## The train has stopped: riders step off, waiting people are sent to cars.
func _begin(t) -> void:
	var doors := [] # [car index, platform sample index, free seats]
	for i in range(t.cars.size()):
		var seats: int = t.car_seats(i)
		if seats <= 0 or i >= t.world.size():
			continue
		var ni := nearest_index(t.world[i]["center"])
		if ni[1] > 9.0 or ni[0] < 1 or ni[0] > track.size() - 2:
			continue
		doors.append([i, ni[0], seats])
	# Each car's door has its own queue: off first, then on.
	for d in doors:
		var delay := 0.3
		var i: int = d[0]
		var j: int = d[1]
		var stay := []
		for r in t.riders[i]:
			r["rides"] -= 1
			if r["rides"] > 0:
				stay.append(r)
				continue
			var p := Person.new(r["look"])
			p.state = "alight"
			p.train = t
			var jj := j + randf_range(-1.5, 1.5)
			p.pos = track[j] + normals[j] * 3.0
			p.path = [plat(jj, 2.5), plat(jj + randf_range(-1.0, 1.0), randf_range(8.0, 14.0))]
			p.heading = normals[j].angle()
			p.delay = delay
			p.speed *= HURRY
			delay += randf_range(0.25, 0.45)
			people.append(p)
		t.riders[i] = stay
		d[2] = maxi(int(d[2]) - stay.size(), 0)
		d.append(delay + 0.3) # when the first person may get on
		d.append(0) # how many are getting on here
	# Nearest waiting people first, to whichever car has room.
	var waiting := people.filter(func(p): return p.state == "wait" or p.state == "arrive")
	while not waiting.is_empty():
		var best_p = null
		var best_d = null
		var best := INF
		for p in waiting:
			for d in doors:
				if d[2] <= 0:
					continue
				var dist: float = p.pos.distance_squared_to(plat(d[1], 2.5))
				if dist < best:
					best = dist
					best_p = p
					best_d = d
		if best_p == null:
			break
		waiting.erase(best_p)
		best_d[2] -= 1
		var j: int = best_d[1]
		var jj := j + randf_range(-1.5, 1.5)
		best_p.state = "board"
		best_p.train = t
		best_p.car = best_d[0]
		best_p.path = [plat(jj, 2.5), track[j] + normals[j] * 2.0]
		best_p.delay = best_d[3] + best_d[4] * randf_range(0.2, 0.35)
		best_d[4] += 1
		best_p.speed *= HURRY

# --- Drawing ---------------------------------------------------------------------

func _band(b: TriBatch, d0: float, d1: float, col: Color, off: Vector2 = Vector2.ZERO) -> void:
	for i in range(track.size() - 1):
		b.draw_colored_polygon(PackedVector2Array([plat(i, d0) + off, plat(i + 1, d0) + off,
			plat(i + 1, d1) + off, plat(i, d1) + off]), col)

func _build_meshes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var b := TriBatch.new()
	var n := track.size()
	var t := tangent_at(center_i)
	var o := normals[center_i]
	var house := plat(center_i, WIDTH + HOUSE_DEPTH * 0.5)
	# Shadows: the platform's raised edge and the house.
	_band(b, -1.0, WIDTH + 1.0, Color(0, 0, 0, 0.16), SUN * 0.5)
	b.draw_set_transform(house + SUN * 2.2, t.angle())
	b.draw_rect(Rect2(-HOUSE_HALF, -HOUSE_DEPTH * 0.5, HOUSE_HALF * 2.0, HOUSE_DEPTH), Color(0, 0, 0, 0.25))
	b.draw_set_transform(Vector2.ZERO)
	# Kerb, paving slabs, the white coping and the yellow line.
	_band(b, -1.5, WIDTH + 0.8, Color(0.46, 0.45, 0.43))
	for i in range(n - 1):
		for row in range(2):
			var d0 := 0.5 + row * (WIDTH - 1.0) * 0.5
			var d1 := d0 + (WIDTH - 1.0) * 0.5
			var shade := 0.77 + rng.randf_range(-0.035, 0.035) + (0.02 if (i / 2 + row) % 2 == 0 else 0.0)
			b.draw_colored_polygon(PackedVector2Array([plat(i, d0), plat(i + 1, d0), plat(i + 1, d1), plat(i, d1)]),
				Color(shade, shade * 0.97, shade * 0.9))
	_band(b, 0.3, 2.3, Color(0.93, 0.92, 0.88))
	_band(b, 3.4, 4.6, Color(0.98, 0.8, 0.16))
	# Benches and planters along the back.
	for k in [-7, 7]:
		var i: int = center_i + k
		if i < 2 or i > n - 3:
			continue
		var p := plat(i, WIDTH - 4.0)
		b.draw_set_transform(p, tangent_at(i).angle())
		b.draw_rect(Rect2(-6.5, -1.6, 13.0, 3.2), Color(0.3, 0.2, 0.12))
		for x in [-4.5, -1.5, 1.5, 4.5]:
			b.draw_rect(Rect2(x - 1.2, -1.3, 2.4, 2.6), Color(0.62, 0.42, 0.24))
		b.draw_set_transform(Vector2.ZERO)
	for k in [-11, 11]:
		var i: int = center_i + k
		if i < 2 or i > n - 3:
			continue
		var p := plat(i, WIDTH - 3.5)
		b.draw_circle(p, 3.2, Color(0.62, 0.32, 0.2))
		b.draw_circle(p, 2.6, Color(0.24, 0.48, 0.2))
		for a in range(3):
			b.draw_circle(p + Vector2.from_angle(a * TAU / 3.0 + rng.randf()) * 1.3, 0.7,
				[Color(1, 0.4, 0.5), Color(1, 0.9, 0.3), Color(0.95, 0.95, 1)][a])
	mesh = b.to_mesh()

	# The house roof (people walk in under it) and lamp heads. In the
	# house's own frame x runs along the track; `near` is the sign of y on
	# the platform side.
	var r := TriBatch.new()
	r.draw_set_transform(house, t.angle())
	var near := signf((-o).dot(Vector2(-t.y, t.x)))
	var hd := HOUSE_DEPTH * 0.5
	r.draw_rect(Rect2(-HOUSE_HALF - 1.0, -hd - 1.0, HOUSE_HALF * 2.0 + 2.0, HOUSE_DEPTH + 2.0), color.darkened(0.45))
	# The slope facing the platform catches the light; ridge along the middle.
	r.draw_rect(Rect2(-HOUSE_HALF, minf(0.0, near * hd), HOUSE_HALF * 2.0, hd), color.lightened(0.12))
	r.draw_rect(Rect2(-HOUSE_HALF, minf(0.0, -near * hd), HOUSE_HALF * 2.0, hd), color.darkened(0.12))
	for x in range(-18, 20, 4):
		r.draw_line(Vector2(x, -hd), Vector2(x, hd), color.darkened(0.25), 0.5)
	r.draw_line(Vector2(-HOUSE_HALF, 0.0), Vector2(HOUSE_HALF, 0.0), color.darkened(0.4), 1.6)
	r.draw_rect(Rect2(10.0, -near * 6.0 - 2.0, 4.0, 4.0), Color(0.55, 0.3, 0.22))
	r.draw_rect(Rect2(10.6, -near * 6.0 - 1.4, 2.8, 2.8), Color(0.2, 0.18, 0.17))
	# A striped awning over the door, and a clock beside it.
	var y0 := near * hd
	for k in range(6):
		var x := -9.0 + k * 3.0
		var c := color.lightened(0.15) if k % 2 == 0 else Color(0.97, 0.96, 0.92)
		r.draw_colored_polygon(PackedVector2Array([Vector2(x, y0), Vector2(x + 3.0, y0),
			Vector2(x + 3.0, y0 + near * 6.5), Vector2(x, y0 + near * 6.5)]), c)
	r.draw_line(Vector2(-9.0, y0 + near * 6.5), Vector2(9.0, y0 + near * 6.5), color.darkened(0.3), 0.8)
	var clock := Vector2(-15.0, y0 + near * 1.8)
	r.draw_circle(clock, 2.4, Color(0.15, 0.15, 0.16))
	r.draw_circle(clock, 1.9, Color(0.97, 0.96, 0.92))
	r.draw_line(clock, clock + Vector2(0.0, -1.3), Color(0.1, 0.1, 0.1), 0.35)
	r.draw_line(clock, clock + Vector2(0.9, 0.0), Color(0.1, 0.1, 0.1), 0.35)
	r.draw_set_transform(Vector2.ZERO)
	for k in [-17, -3, 3, 17]:
		var i: int = center_i + k
		if i < 1 or i > n - 2:
			continue
		var p := plat(i, WIDTH - 1.5)
		r.draw_circle(p + SUN * 0.8, 2.0, Color(0, 0, 0, 0.18))
		r.draw_circle(p, 5.5, Color(1.0, 0.92, 0.6, 0.12))
		r.draw_circle(p, 2.0, Color(0.16, 0.17, 0.18))
		r.draw_circle(p, 1.3, Color(1.0, 0.94, 0.7))
	roof_mesh = r.to_mesh()

# --- Save / load -------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"x": snappedf(anchor.x, 0.01), "y": snappedf(anchor.y, 0.01),
		"fx": snappedf(face.x, 0.0001), "fy": snappedf(face.y, 0.0001),
		"color": color.to_html(false), "seed": seed,
	}

static func from_dict(d: Dictionary) -> Station:
	var st := Station.new()
	st.anchor = Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
	var f := Vector2(float(d.get("fx", 0.0)), float(d.get("fy", -1.0)))
	st.face = f.normalized() if f.length() > 0.001 else Vector2.UP
	st.color = Color.html(str(d.get("color", "c73a2e")))
	st.seed = int(d.get("seed", 0))
	return st

static func make(at: Vector2, towards: Vector2) -> Station:
	var st := Station.new()
	st.anchor = at
	st.face = towards
	st.color = COLORS[randi() % COLORS.size()]
	st.seed = randi() % 100000
	return st
