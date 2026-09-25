extends RefCounted
class_name SoundEvents

## Listens to the physics and says when something funny-sounding happened
## (World.sfx). The physics reports raw facts while it steps -- "this
## joint hit the floor at 1300 px/s", "these two dolls bumped" -- and once
## per frame they're turned into at most a few events per doll:
##
##   thud / slam / bonk   a body part hits the floor or a wall (bonk = the
##                        head), louder the faster it was going; a hard
##                        landing on the behind is sometimes a fart
##   crack (+ "ow!")      a knee or elbow folds way past natural, or the
##                        neck or spine bends far back
##   stretch              rubber limbs pulled to well past their length
##   scream               a doll flies through the air fast
##   trombone             a doll that was standing falls flat
##   bonk                 two dolls knock into each other
##
## Tools and moves report their own events directly (World.emit_sfx):
## balloon tied on, pin, rope, boom, magnet, erase, jump...
##
## Everything here is tuned against tools/sim_check.gd, which counts the
## events each move and force makes on its own: a doll just dancing or
## walking should be nearly silent, so the sounds mean something.

## Impact speeds (stage px / s) below these make no sound. Feet and knees
## get a higher bar: walking and dancing land them all the time.
const IMPACT_MIN := 480.0
const IMPACT_MIN_LEGS := 900.0
const SLAM_SPEED := 1350.0
const COLLIDE_MIN := 650.0
const SCREAM_SPEED := 1700.0
const STRETCH_RATIO := 1.6

## [a, mid, b, how far (radians) the bend at `mid` may move from its rest
## bend before it cracks].
const JOINTS := [
	[Skeleton.NECK, Skeleton.L_ELBOW, Skeleton.L_HAND, 2.3],
	[Skeleton.NECK, Skeleton.R_ELBOW, Skeleton.R_HAND, 2.3],
	[Skeleton.PELVIS, Skeleton.L_KNEE, Skeleton.L_FOOT, 2.2],
	[Skeleton.PELVIS, Skeleton.R_KNEE, Skeleton.R_FOOT, 2.2],
	[Skeleton.HEAD, Skeleton.NECK, Skeleton.CHEST, 1.5],
	[Skeleton.NECK, Skeleton.CHEST, Skeleton.PELVIS, 1.3],
]
const REARM := 0.5

## Doll -> per-doll state (see _state()).
var _dolls := {}
## Strongest doll-on-doll knock this frame: [speed, x].
var _hit := [0.0, 0.0]
var _hit_cd := 0.0
## Events waiting a moment (an "ow!" just after the crack): [time, id, strength, x, pitch].
var _later: Array = []

## Counts of every event emitted, for sim_check.
var counts := {}

func reset() -> void:
	_dolls.clear()
	_later.clear()
	_hit = [0.0, 0.0]

func impact(doll: Doll, i: int, speed: float) -> void:
	var st := _state(doll)
	var bar := IMPACT_MIN_LEGS if i >= Skeleton.L_KNEE else IMPACT_MIN
	# Compare by how far past its own bar each hit is.
	if speed - bar > float(st["imp"]) - float(st["imp_bar"]):
		st["imp"] = speed
		st["imp_bar"] = bar
		st["imp_i"] = i

func collide(da: Doll, i: int, db: Doll, j: int, speed: float) -> void:
	if speed > _hit[0]:
		_hit = [speed, (da.pos[i].x + db.pos[j].x) * 0.5]

func after_frame(world: World, delta: float) -> void:
	for doll: Doll in world.dolls:
		_doll_frame(world, doll, delta)
	_hit_cd -= delta
	if _hit[0] > COLLIDE_MIN and _hit_cd <= 0.0:
		_emit(world, "bonk", clampf((_hit[0] - COLLIDE_MIN) / 1200.0, 0.2, 1.0), _hit[1])
		_hit_cd = 0.25
	_hit = [0.0, 0.0]
	var now := world.sim_time
	for e in _later.duplicate():
		if now >= e[0] or world.paused:
			_later.erase(e)
			_emit(world, e[1], e[2], e[3], e[4])
	if _dolls.size() > world.dolls.size():
		for d in _dolls.keys():
			if not world.dolls.has(d):
				_dolls.erase(d)

func _doll_frame(world: World, doll: Doll, delta: float) -> void:
	var st := _state(doll)
	for k in ["imp_cd", "bend_cd", "scream_cd", "stretch_cd"]:
		st[k] = float(st[k]) - delta
	var x := doll.center().x
	# Smaller dolls have higher voices.
	var pitch := clampf(1.0 / sqrt(doll.size), 0.7, 1.5)

	# Impacts.
	var imp: float = st["imp"]
	if imp > float(st["imp_bar"]) and float(st["imp_cd"]) <= 0.0:
		var i: int = st["imp_i"]
		var strength := clampf((imp - 350.0) / 1600.0, 0.15, 1.0)
		if i == Skeleton.HEAD:
			_emit(world, "bonk", strength, x, pitch)
		elif imp > SLAM_SPEED:
			_emit(world, "slam", strength, x)
			if i == Skeleton.PELVIS and randf() < 0.3:
				_later_emit(world, 0.12, "fart", 1.0, x, pitch)
			elif randf() < 0.3:
				_later_emit(world, 0.15, "ouch", 1.0, x, pitch)
		else:
			_emit(world, "thud", strength, x)
		st["imp_cd"] = 0.12
	st["imp"] = 0.0
	st["imp_bar"] = 0.0

	# Joints bent way past natural.
	var armed: Array = st["armed"]
	for k in JOINTS.size():
		var jd: Array = JOINTS[k]
		# Bent far from both where it rests and where the moves want it.
		var now := _bend(doll.pos, jd)
		var dev := absf(angle_difference(_bend(doll.rest, jd), now))
		if doll.pose.size() == Skeleton.COUNT:
			dev = minf(dev, absf(angle_difference(_bend(doll.pose, jd), now)))
		if armed[k] and dev > float(jd[3]):
			armed[k] = false
			if float(st["bend_cd"]) <= 0.0:
				st["bend_cd"] = 0.35
				var strength := clampf((dev - float(jd[3])) / 0.6 + 0.5, 0.5, 1.0)
				_emit(world, "crack", strength, doll.pos[jd[1]].x)
				if randf() < 0.45:
					_later_emit(world, 0.18, "ouch", 1.0, x, pitch)
		elif not armed[k] and dev < float(jd[3]) - REARM:
			armed[k] = true

	# Rubber limbs pulled way out.
	if float(st["stretch_cd"]) <= 0.0:
		for s in doll.sticks:
			if s[4] and doll.pos[s[0]].distance_to(doll.pos[s[1]]) > float(s[2]) * STRETCH_RATIO:
				_emit(world, "stretch", 1.0, x, randf_range(0.9, 1.3))
				st["stretch_cd"] = 1.0
				break

	# Flying.
	if not doll.grounded and doll.head_speed > SCREAM_SPEED and float(st["scream_cd"]) <= 0.0:
		_emit(world, "scream", 1.0, x, pitch)
		st["scream_cd"] = 2.5

	# Fell flat after standing a while.
	var tilt := absf(doll.torso_angle())
	if tilt < 0.5 and doll.grounded:
		st["upright"] = float(st["upright"]) + delta
	elif tilt > 1.25 and doll.grounded and doll.pos[Skeleton.HEAD].y > world.floor_y() - doll.head_radius * doll.size - 40.0:
		if float(st["upright"]) > 1.0:
			_emit(world, "trombone", 1.0, x)
		st["upright"] = 0.0

func _state(doll: Doll) -> Dictionary:
	if not _dolls.has(doll):
		var armed := []
		armed.resize(JOINTS.size())
		armed.fill(true)
		_dolls[doll] = {
			"imp": 0.0, "imp_bar": 0.0, "imp_i": 0, "imp_cd": 0.0, "bend_cd": 0.0,
			"scream_cd": 0.0, "stretch_cd": 0.0, "upright": 0.0, "armed": armed,
		}
	return _dolls[doll]

## Signed turn at the middle joint of `jd` (0 = straight on).
static func _bend(p: PackedVector2Array, jd: Array) -> float:
	var u: Vector2 = p[jd[1]] - p[jd[0]]
	var v: Vector2 = p[jd[2]] - p[jd[1]]
	if u.length_squared() < 0.01 or v.length_squared() < 0.01:
		return 0.0
	return u.angle_to(v)

func _emit(world: World, id: String, strength: float, x: float, pitch: float = 1.0) -> void:
	counts[id] = int(counts.get(id, 0)) + 1
	world.emit_sfx(id, strength, x, pitch)

func _later_emit(world: World, after: float, id: String, strength: float, x: float, pitch: float) -> void:
	_later.append([world.sim_time + after, id, strength, x, pitch])
