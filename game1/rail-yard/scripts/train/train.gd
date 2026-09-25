extends RefCounted
class_name Train

## One train: its saved description (where the loco stands, which way it
## faces, its cars) plus everything that makes it move and look alive.
##
## Physics is 1-D along the train's Route: every car is a mass at
## coordinate `s` with velocity `v`, joined to its neighbours by couplers
## that have a little free slack, stretch like a stiff spring when pulled
## and compress like a stiffer buffer when pushed. Only the locomotives
## pull or brake, so starts and stops ripple down the train car by car --
## the "slack action" you see on real freight trains.
##
## Everything else is visual, derived from that 1-D state each frame:
## each car rides on two bogies placed on the track, so its body cuts the
## chord across curves; it sways outward in curves (a damped spring driven
## by v^2 * curvature), bounces over rail joints, pitches under
## acceleration (both shown through its shadow and a tiny scale), and
## locomotives puff smoke in time with their wheels / throttle.

const GAP := 6.0 # coupler length between car bodies, px
const SLACK := 1.4 # free play in each coupler, px
const K_PULL := 900.0
const K_BUFF := 2400.0
const C_COUPLER := 24.0
const C_FREE := 0.8
const K_STOP := 3000.0
const C_STOP := 70.0
const ROLL := 0.04
const A_MAX := 55.0 # px/s^2 at full throttle
const A_BRAKE := 150.0
const A_SOFT := 50.0 # planned deceleration for stopping short of things
const GAIN := 1.6 # speed controller gain when speeding up...
const GAIN_BRAKE := 4.5 # ...and when slowing down, so it tracks the braking curve
const SUBSTEPS := 8
const LOOKAHEAD := 280.0
const PEEK_STEP := 8.0
const BLOCK_RADIUS := 11.0
const REVERSE_WAIT := 1.4 # s stopped at a buffer / behind a train before backing up
const BOGIE := 0.33 # bogie offset from car centre, fraction of car length
const JOINT := 42.0 # rail joint spacing, px
const SWAY_GAIN := 0.02
const MAX_SPEED := 240.0

# --- Saved description -----------------------------------------------------
var anchor := Vector2.ZERO # centre of the lead loco (car 0)
var heading := Vector2.RIGHT # which way car 0 faces
var direction: int = 1 # +1 travel the way car 0 faces, -1 backwards
var speed: float = 90.0 # cruising speed, px/s
var running: bool = true
var livery := Color(0.12, 0.36, 0.2)
var cars: Array = [] # [{type, color, seed}]

# --- Runtime ---------------------------------------------------------------
var route: Route = null
var s: Array = [] # car centres along the route, car 0 highest
var v: Array = []
var world: Array = [] # per car: {center, dir, n, pf, pr, tf, tr, len, width}
var throttle: float = 0.0
var limited := false # braking for a buffer or another train
var _block_timer := 0.0
var _block_wait := REVERSE_WAIT

var sway: Array = []
var sway_v: Array = []
var bounce: Array = []
var bounce_v: Array = []
var pitch: Array = []
var _prev_v: Array = []
var _joint_f: Array = []
var _joint_r: Array = []
var _emit: Array = []

func car_len(i: int) -> float:
	return float(WagonCatalog.entry(cars[i]["type"])["length"])

func car_width(i: int) -> float:
	return float(WagonCatalog.entry(cars[i]["type"])["width"])

func car_mass(i: int) -> float:
	return float(WagonCatalog.entry(cars[i]["type"])["mass"])

func is_powered(i: int) -> bool:
	return bool(WagonCatalog.entry(cars[i]["type"]).get("powered", false))

func has_power() -> bool:
	for i in range(cars.size()):
		if is_powered(i):
			return true
	return false

func is_placed() -> bool:
	return route != null and s.size() == cars.size() and not cars.is_empty()

# --- Placement -------------------------------------------------------------

## Puts the train on the track nearest `anchor`, loco there facing along
## `heading`, cars laid out behind it at rest spacing (shifted off a buffer
## if needed). False if there's no track nearby or the train doesn't fit.
func place(net: TrackNetwork) -> bool:
	route = null
	if cars.is_empty():
		return false
	var hit := net.nearest(anchor, 90.0)
	if hit.is_empty():
		return false
	var seg: TrackSegment = hit["seg"]
	var u: float = hit["u"]
	var rev := seg.tangent_at(u).dot(heading) < 0.0
	route = Route.new(net, seg, rev)
	var n := cars.size()
	s = []
	v = []
	var cur: float = seg.length - u if rev else u
	for i in range(n):
		if i > 0:
			cur -= (car_len(i - 1) + car_len(i)) * 0.5 + GAP
		s.append(cur)
		v.append(0.0)
	var lo: float = _rear_end() - 20.0
	var hi: float = _front_end() + 20.0
	route.ensure(lo, hi)
	if route.dead_back:
		_shift(route.start_s - lo)
		route.ensure(_rear_end() - 20.0, _front_end() + 20.0)
	if route.dead_front:
		_shift(route.end_s - (_front_end() + 20.0))
		route.ensure(_rear_end() - 20.0, _front_end() + 20.0)
		if route.dead_back and route.start_s > _rear_end() - 2.0:
			route = null
			return false
	route.trim(_rear_end() - 60.0, _front_end() + 60.0)
	_reset_visual()
	update_world()
	_sync_anchor()
	return true

## Slides the whole train along its track so car `idx` is as close to
## `p` as it can get -- what dragging a train in Design mode does.
func drag_to(p: Vector2, idx: int) -> void:
	if not is_placed():
		return
	route.ensure(_rear_end() - 100.0, _front_end() + 100.0)
	var sc: float = s[idx]
	var best := sc
	var best_d := INF
	var t := sc - 60.0
	while t <= sc + 60.0:
		var d := route.position(t).distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = t
		t += 1.5
	var ds := best - sc
	if route.dead_front:
		ds = minf(ds, route.end_s - 3.0 - _front_end())
	if route.dead_back:
		ds = maxf(ds, route.start_s + 3.0 - _rear_end())
	_shift(ds)
	for i in range(v.size()):
		v[i] = 0.0
	route.ensure(_rear_end() - 20.0, _front_end() + 20.0)
	route.trim(_rear_end() - 60.0, _front_end() + 60.0)
	update_world()
	_sync_anchor()

## Puts cars back at `old_s` (e.g. undoing a drag that ran into something).
func restore_s(old_s: Array) -> void:
	s = old_s.duplicate()
	route.ensure(_rear_end() - 20.0, _front_end() + 20.0)
	update_world()
	_sync_anchor()

## True if any of this train's cars sits on top of a car of another train.
func overlaps(trains: Array) -> bool:
	for t in trains:
		if t == self:
			continue
		for w in world:
			for p in [w["center"], w["front"], w["back"], w["pf"], w["pr"]]:
				if t.car_at(p, 3.0) >= 0:
					return true
	return false

func _shift(ds: float) -> void:
	for i in range(s.size()):
		s[i] += ds

func _front_end() -> float:
	return s[0] + car_len(0) * 0.5

func _rear_end() -> float:
	var n := s.size()
	return s[n - 1] - car_len(n - 1) * 0.5

func _sync_anchor() -> void:
	if world.is_empty():
		return
	anchor = world[0]["center"]
	heading = world[0]["dir"]

func _reset_visual() -> void:
	var n := cars.size()
	sway = _zeros(n)
	sway_v = _zeros(n)
	bounce = _zeros(n)
	bounce_v = _zeros(n)
	pitch = _zeros(n)
	_prev_v = _zeros(n)
	_emit = _zeros(n)
	_joint_f = []
	_joint_r = []
	for i in range(n):
		var b := car_len(i) * BOGIE
		_joint_f.append(floori((s[i] + b) / JOINT))
		_joint_r.append(floori((s[i] - b) / JOINT))

static func _zeros(n: int) -> Array:
	var a := []
	a.resize(n)
	a.fill(0.0)
	return a

# --- Simulation ------------------------------------------------------------

## Decides this frame's target speed by looking down the track ahead:
## slows to stop short of a buffer stop or another train, and after
## waiting stopped for a moment, reverses (shunting back and forth).
func plan(delta: float, net: TrackNetwork, trains: Array) -> float:
	if not is_placed():
		return 0.0
	route.ensure(_rear_end() - 16.0, _front_end() + 16.0)
	route.trim(_rear_end() - 60.0, _front_end() + 60.0)
	if not running or not has_power() or speed <= 0.0:
		limited = false
		_block_timer = 0.0
		return 0.0
	var lead := 0 if direction > 0 else cars.size() - 1
	var front_s: float = s[lead] + direction * car_len(lead) * 0.5
	var cur := route.cursor(front_s, direction > 0)
	var look: Dictionary = net.walk(cur[0], cur[1], cur[2], LOOKAHEAD, PEEK_STEP)
	var free: float = look["dead"] - 6.0
	var pts: PackedVector2Array = look["points"]
	var by_train := false
	var near := _cars_near(pts, trains, lead)
	for k in range(pts.size()):
		if k * PEEK_STEP >= free:
			break
		if _blocked_at(pts[k], near):
			free = k * PEEK_STEP - 10.0
			by_train = true
			break
	var target := speed
	if free < INF:
		target = minf(target, sqrt(2.0 * A_SOFT * maxf(free, 0.0)))
	limited = target < speed - 0.5
	if limited and target < 2.0 and absf(_avg_v()) < 3.0:
		if _block_timer == 0.0:
			# Nose to nose, both trains would otherwise back off at the same
			# instant and meet again; a random wait lets one go first.
			_block_wait = REVERSE_WAIT + (randf() * 2.5 if by_train else 0.0)
		_block_timer += delta
		if _block_timer > _block_wait:
			direction = -direction
			_block_timer = 0.0
	else:
		_block_timer = 0.0
	return target

## The obstacle points (centre, bogies, ends) of every car -- other than
## our own leading one -- that could be near any of `pts`.
func _cars_near(pts: PackedVector2Array, trains: Array, own_lead: int) -> Array:
	var out := []
	if pts.is_empty():
		return out
	var box := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		box = box.expand(p)
	for t in trains:
		var w: Array = t.world
		for i in range(w.size()):
			if t == self and i == own_lead:
				continue
			var car: Dictionary = w[i]
			# All five points lie within half a car length of the centre.
			if box.grow(car["len"] * 0.5 + BLOCK_RADIUS + 1.0).has_point(car["center"]):
				out.append(PackedVector2Array([car["center"], car["pf"], car["pr"], car["front"], car["back"]]))
	return out

static func _blocked_at(p: Vector2, near: Array) -> bool:
	for car_pts in near:
		for q in car_pts:
			if p.distance_squared_to(q) < BLOCK_RADIUS * BLOCK_RADIUS:
				return true
	return false

func _avg_v() -> float:
	var m := 0.0
	var mv := 0.0
	for i in range(cars.size()):
		var mi := car_mass(i)
		m += mi
		mv += mi * v[i]
	return mv / m if m > 0.0 else 0.0

func simulate(delta: float, target: float) -> void:
	if not is_placed():
		return
	var n := cars.size()
	# Per-car constants, looked up once rather than in every substep.
	var masses := []
	var lens := []
	var total := 0.0
	var powered := []
	for i in range(n):
		masses.append(car_mass(i))
		lens.append(car_len(i))
		total += masses[i]
		if is_powered(i):
			powered.append(i)
	var rests := []
	for i in range(n - 1):
		rests.append((lens[i] + lens[i + 1]) * 0.5 + GAP)
	var h := delta / SUBSTEPS
	var f := _zeros(n)
	for _sub in range(SUBSTEPS):
		f.fill(0.0)
		if not powered.is_empty():
			# P-control on the train's mean speed, plus feed-forward for
			# rolling resistance so it settles at exactly `target`.
			var m := 0.0
			var mv := 0.0
			for i in range(n):
				m += masses[i]
				mv += masses[i] * v[i]
			var va := mv / m if m > 0.0 else 0.0
			var err := target * direction - va
			var gain := GAIN if err * direction > 0.0 else GAIN_BRAKE
			var drive := clampf((err * gain + va * ROLL) * total, -A_BRAKE * total, A_MAX * total)
			throttle = drive / (A_MAX * total)
			for i in powered:
				f[i] += drive / powered.size()
		for i in range(n - 1):
			var ext: float = (s[i] - s[i + 1]) - rests[i]
			var rel: float = v[i] - v[i + 1]
			var force := 0.0
			if ext > SLACK:
				force = K_PULL * (ext - SLACK) + C_COUPLER * rel
			elif ext < -SLACK:
				force = K_BUFF * (ext + SLACK) + C_COUPLER * rel
			else:
				force = C_FREE * rel
			f[i] -= force
			f[i + 1] += force
		for i in range(n):
			f[i] -= v[i] * masses[i] * ROLL
		if route.dead_front:
			var pen: float = s[0] + lens[0] * 0.5 - (route.end_s - 2.0)
			if pen > 0.0:
				f[0] -= K_STOP * pen + C_STOP * maxf(v[0], 0.0)
		if route.dead_back:
			var pen_b: float = (route.start_s + 2.0) - (s[n - 1] - lens[n - 1] * 0.5)
			if pen_b > 0.0:
				f[n - 1] += K_STOP * pen_b - C_STOP * minf(v[n - 1], 0.0)
		for i in range(n):
			v[i] += f[i] / masses[i] * h
			s[i] += v[i] * h

# --- Visual state ----------------------------------------------------------

## Car poses from the 1-D state: two bogies on the track per car, the body
## on the chord between them.
func update_world() -> void:
	world = []
	if not is_placed():
		return
	for i in range(cars.size()):
		var l := car_len(i)
		var b := l * BOGIE
		var a: Array = route.sample(s[i] + b)
		var r: Array = route.sample(s[i] - b)
		var pf: Vector2 = a[0]
		var pr: Vector2 = r[0]
		var d := pf - pr
		var dir: Vector2 = d.normalized() if d.length_squared() > 1e-6 else a[1]
		var c := (pf + pr) * 0.5
		world.append({
			"center": c, "dir": dir, "n": dir.orthogonal(),
			"pf": pf, "pr": pr, "tf": a[1], "tr": r[1],
			"front": c + dir * l * 0.5, "back": c - dir * l * 0.5,
			"len": l, "width": car_width(i),
		})

func update_visual(delta: float, smoke: Smoke) -> void:
	for i in range(world.size()):
		var w: Dictionary = world[i]
		var b: float = w["len"] * BOGIE
		var vi: float = v[i]
		# Sway: pushed outward by centripetal acceleration v^2 * curvature.
		var bend: Vector2 = (w["tf"] - w["tr"]) / (2.0 * b)
		var target := clampf(-(bend * vi * vi).dot(w["n"]) * SWAY_GAIN, -3.5, 3.5)
		sway_v[i] += (60.0 * (target - sway[i]) - 7.0 * sway_v[i]) * delta
		sway[i] += sway_v[i] * delta
		# Bounce: a kick every time a bogie rolls over a rail joint.
		var jf := floori((s[i] + b) / JOINT)
		var jr := floori((s[i] - b) / JOINT)
		var kick := 14.0 * minf(absf(vi) / 110.0, 1.6)
		if jf != _joint_f[i]:
			bounce_v[i] += kick
			_joint_f[i] = jf
		if jr != _joint_r[i]:
			bounce_v[i] += kick * 0.8
			_joint_r[i] = jr
		bounce_v[i] += (-380.0 * bounce[i] - 9.0 * bounce_v[i]) * delta
		bounce[i] += bounce_v[i] * delta
		# Pitch: the body tips back when accelerating, forward when braking.
		var acc: float = (vi - _prev_v[i]) / maxf(delta, 0.001)
		_prev_v[i] = vi
		pitch[i] = lerpf(pitch[i], clampf(-acc * 0.03, -2.5, 2.5), 0.15)
		if smoke != null:
			_smoke(i, w, vi, delta, smoke)

func _smoke(i: int, w: Dictionary, vi: float, delta: float, smoke: Smoke) -> void:
	var e := WagonCatalog.entry(cars[i]["type"])
	var kind: String = e.get("smoke", "")
	if kind == "":
		return
	var stack: Vector2 = w["center"] + w["dir"] * float(e.get("stack_x", 0.0))
	var car_vel: Vector2 = w["dir"] * vi
	var effort := clampf(absf(throttle), 0.0, 1.0)
	if kind == "steam":
		# A chuff every 13 px of travel (four per wheel turn), plus a lazy idle.
		_emit[i] += absf(vi) * delta / 13.0 + delta * 0.8
		while _emit[i] >= 1.0:
			_emit[i] -= 1.0
			smoke.puff(stack, car_vel * 0.25, "steam", 0.6 + effort * 0.7)
	else:
		_emit[i] += delta * (2.0 + 22.0 * effort)
		while _emit[i] >= 1.0:
			_emit[i] -= 1.0
			smoke.puff(stack, car_vel * 0.3, "diesel", 0.4 + effort * 0.8)

## Index of the car under `p`, or -1.
func car_at(p: Vector2, pad: float) -> int:
	for i in range(world.size() - 1, -1, -1):
		var w: Dictionary = world[i]
		var local: Vector2 = (p - w["center"]).rotated(-(w["dir"] as Vector2).angle())
		if absf(local.x) <= w["len"] * 0.5 + pad and absf(local.y) <= w["width"] * 0.5 + pad:
			return i
	return -1

# --- Save / load -----------------------------------------------------------

func to_dict() -> Dictionary:
	_sync_anchor()
	var car_list := []
	for c in cars:
		car_list.append({"type": c["type"], "color": (c["color"] as Color).to_html(false), "seed": c["seed"]})
	return {
		"x": snappedf(anchor.x, 0.01), "y": snappedf(anchor.y, 0.01),
		"hx": snappedf(heading.x, 0.0001), "hy": snappedf(heading.y, 0.0001),
		"direction": direction, "speed": speed, "running": running,
		"livery": livery.to_html(false), "cars": car_list,
	}

static func from_dict(d: Dictionary) -> Train:
	var t := Train.new()
	t.anchor = Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
	var h := Vector2(float(d.get("hx", 1.0)), float(d.get("hy", 0.0)))
	t.heading = h.normalized() if h.length() > 0.001 else Vector2.RIGHT
	t.direction = -1 if int(d.get("direction", 1)) < 0 else 1
	t.speed = clampf(float(d.get("speed", 90.0)), 0.0, MAX_SPEED)
	t.running = bool(d.get("running", true))
	t.livery = Color.html(str(d.get("livery", "1e5c33")))
	for c in d.get("cars", []):
		if c is Dictionary and WagonCatalog.has_type(str(c.get("type", ""))):
			t.cars.append({
				"type": str(c["type"]),
				"color": Color.html(str(c.get("color", "808080"))),
				"seed": int(c.get("seed", 0)),
			})
	return t
