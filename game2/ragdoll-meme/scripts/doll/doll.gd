extends RefCounted
class_name Doll

## One ragdoll's body: a handful of Verlet particles (Skeleton's joints)
## held together by sticks, plus the "muscles" that pull them toward a
## procedurally animated pose. No drawing here -- DollView/DollPainter
## draw it -- and no scene-wide forces (Force subclasses push on it).
##
## Why Verlet and not RigidBody2D + joints: dragging one joint and having
## the rest of the chain follow *is* position-based IK in a Verlet body
## (pin the grabbed particle, let the stick constraints drag the rest),
## throwing is free (velocity is just pos - prev), and bending rubber limbs
## is one stiffness number. A physics-engine joint chain fights all three.

var pos := PackedVector2Array()
var prev := PackedVector2Array()
var acc := PackedVector2Array()
## 0 = held in place (grabbed or nailed) this step, else 1 / mass.
var inv_mass := PackedFloat32Array()
var held := PackedInt32Array()
var rest := PackedVector2Array()
var sticks: Array = [] # [a, b, rest_len, stiffness, visible]

const MUSCLE_DAMP := 0.7

var style := DollStyle.new()
var size := 1.0 # overall scale
var head_radius := Skeleton.DEFAULT_HEAD_RADIUS
## 0 = pure floppy ragdoll, 1 = limbs snap to the animated pose.
var muscle := 0.45
## move id -> {"enabled": bool, "params": {param id -> value}}
var moves := {}

var time := 0.0
var grounded := false
var facing := 1.0
var jump_timer := 0.0
var noise_seed := 0
## Where each standing foot is planted (x), NAN when it isn't: while
## balancing, a foot on the ground stays put until it's lifted, walked, or
## the body is dragged too far from it.
var foot_lock := {Skeleton.L_FOOT: NAN, Skeleton.R_FOOT: NAN}
## Updated by World each step, read by the drawn face (panic, eye direction).
var head_velocity := Vector2.ZERO
var head_speed := 0.0

func _init() -> void:
	noise_seed = randi() % 10000
	for m in MoveCatalog.all():
		moves[m.id] = {"enabled": m.default_enabled, "params": m.default_params()}
	build(Vector2(360, 900))

## (Re)build the body standing with its pelvis at `pelvis_pos` -- used on
## spawn and whenever head size or scale changes (which change the rest
## lengths).
func build(pelvis_pos: Vector2) -> void:
	rest = Skeleton.rest_pose(head_radius)
	pos.resize(Skeleton.COUNT)
	prev.resize(Skeleton.COUNT)
	acc.resize(Skeleton.COUNT)
	inv_mass.resize(Skeleton.COUNT)
	held.resize(Skeleton.COUNT)
	for i in Skeleton.COUNT:
		pos[i] = pelvis_pos + rest[i] * size
		prev[i] = pos[i]
		acc[i] = Vector2.ZERO
		held[i] = 0
		inv_mass[i] = 1.0 / Skeleton.MASS[i]
	sticks.clear()
	for b in Skeleton.BONES:
		sticks.append([b[0], b[1], rest[b[0]].distance_to(rest[b[1]]) * size, 1.0, true])
	for b in Skeleton.BRACES:
		sticks.append([b[0], b[1], rest[b[0]].distance_to(rest[b[1]]) * size, b[2], false])

## Rebuild in place keeping where the doll currently is.
func rebuild_keep_place() -> void:
	var here := pos[Skeleton.PELVIS]
	var vel := pos[Skeleton.PELVIS] - prev[Skeleton.PELVIS]
	build(here)
	for i in Skeleton.COUNT:
		prev[i] = pos[i] - vel

func radius(i: int) -> float:
	return Skeleton.joint_radius(i, head_radius) * size

func center() -> Vector2:
	return pos[Skeleton.CHEST]

func torso_angle() -> float:
	var d := pos[Skeleton.NECK] - pos[Skeleton.PELVIS]
	return atan2(d.x, -d.y)

func add_force(i: int, f: Vector2) -> void:
	acc[i] += f * inv_mass_raw(i)

func inv_mass_raw(i: int) -> float:
	return 1.0 / Skeleton.MASS[i]

func add_accel_all(a: Vector2) -> void:
	for i in Skeleton.COUNT:
		acc[i] += a

func set_velocity(i: int, v: Vector2, h: float) -> void:
	prev[i] = pos[i] - v * h

func velocity(i: int, h: float) -> Vector2:
	return (pos[i] - prev[i]) / h

func move_enabled(id: String) -> bool:
	return moves.has(id) and moves[id]["enabled"]

# --- Stepping ----------------------------------------------------------------

func integrate(h: float, vel_scale: float, damping: float) -> void:
	for i in Skeleton.COUNT:
		var v := (pos[i] - prev[i]) * vel_scale * damping
		prev[i] = pos[i]
		if held[i] == 0:
			pos[i] += v + acc[i] * h * h
		acc[i] = Vector2.ZERO

func _is_planted_foot(i: int, planted: bool) -> bool:
	return planted and (i == Skeleton.L_FOOT or i == Skeleton.R_FOOT) and not is_nan(foot_lock[i])

func _update_foot_locks(planted: bool, floor_y: float) -> void:
	for f in foot_lock:
		var on_floor := pos[f].y >= floor_y - radius(f) - 3.0
		var too_far := absf(pos[Skeleton.PELVIS].x - pos[f].x) > 150.0 * size
		if not planted or not on_floor or too_far or held[f]:
			foot_lock[f] = NAN
		elif is_nan(foot_lock[f]):
			foot_lock[f] = pos[f].x

## Constraint pass: keep locked feet where they were planted.
func solve_foot_locks() -> void:
	for f in foot_lock:
		if not is_nan(foot_lock[f]):
			pos[f].x = foot_lock[f]
			prev[f].x = foot_lock[f]

func solve_sticks(stretch: float) -> void:
	for s in sticks:
		var a: int = s[0]
		var b: int = s[1]
		var wa := 0.0 if held[a] else inv_mass[a]
		var wb := 0.0 if held[b] else inv_mass[b]
		var w := wa + wb
		if w <= 0.0:
			continue
		var d := pos[b] - pos[a]
		var dist := d.length()
		if dist < 0.0001:
			continue
		var k: float = s[3] * (stretch if s[4] else 1.0)
		var corr := d * ((dist - float(s[2])) / dist) * k / w
		pos[a] += corr * wa
		pos[b] -= corr * wb

## Pull every joint toward the animated pose. The pose starts as the rest
## pose; each enabled Move bends it (and may set balance/lean/spin/push in
## `ctx`); then the whole pose is placed in a body frame -- the doll's own
## current torso angle when it isn't trying to stand, or upright and lifted
## over its feet when it is (Stand's balance).
func apply_muscles(world, h: float) -> void:
	time += h
	var offs := rest.duplicate()
	var ctx := {
		"t": time, "h": h, "doll": self, "world": world, "grounded": grounded,
		"balance": 0.0, "angle": 0.0, "angle_base": NAN, "dx": 0.0, "lift": 0.0,
		"push_x": 0.0, "muscle_boost": 0.0, "feet_free": false,
	}
	for m in MoveCatalog.all():
		var state: Dictionary = moves[m.id]
		if state["enabled"]:
			m.pose(ctx, offs, state["params"])

	var cur := torso_angle()
	var balance: float = clamp(ctx["balance"], 0.0, 1.0)
	var base: float = 0.0 if is_nan(ctx["angle_base"]) else ctx["angle_base"]
	var angle := cur + float(ctx["angle"])
	var leg_angle := angle
	if balance > 0.0:
		angle = lerp_angle(cur, base + float(ctx["angle"]), balance)
		# A lean or sway bends the body over the feet; the legs themselves
		# stay planted. Rotating them too would swing the feet sideways
		# every frame -- the doll would skate across the stage.
		leg_angle = lerp_angle(cur, base, balance)
	# Hip sway (`dx`) is the pelvis moving over the feet, i.e. the feet
	# moving the other way in the pelvis's frame.
	var dx: float = ctx["dx"]
	for i in [Skeleton.L_FOOT, Skeleton.R_FOOT]:
		offs[i].x -= dx
	for i in [Skeleton.L_KNEE, Skeleton.R_KNEE]:
		offs[i].x -= dx * 0.5

	# Shape: pull each joint toward the pose, placed at the pelvis. These are
	# internal forces -- the net push is removed again -- so a pose the body
	# can't reach (hands higher than the arms are long) makes it strain, not
	# fly. Without this a doll reaching up would lift itself by its own hands.
	# Standing feet are planted: the ground takes a planted foot's pull and
	# pushes the rest of the body the other way instead (a leg that wants
	# its foot lower lifts the body; a foot that wants to be under the hips
	# pulls the hips over it). That's what keeps a standing doll standing
	# on the spot rather than inching along. Only Walk unplants them.
	var planted: bool = balance > 0.0 and grounded and not bool(ctx["feet_free"])
	_update_foot_locks(planted, world.floor_y())
	var k: float = clamp(muscle + float(ctx["muscle_boost"]), 0.0, 1.0) * 0.22
	if k > 0.0:
		var origin := pos[Skeleton.PELVIS]
		var nudge := PackedVector2Array()
		nudge.resize(Skeleton.COUNT)
		var net := Vector2.ZERO
		var free_mass := 0.0
		for i in Skeleton.COUNT:
			if held[i]:
				continue
			var a := leg_angle if i >= Skeleton.L_KNEE else angle
			var target: Vector2 = origin + (offs[i] - offs[Skeleton.PELVIS]).rotated(a) * size
			nudge[i] = (target - pos[i]) * k
			net += nudge[i] * Skeleton.MASS[i]
			if not _is_planted_foot(i, planted):
				free_mass += Skeleton.MASS[i]
		# Internal forces: whatever net push the muscles make is taken back
		# out, so a pose the body can't reach makes it strain, not fly.
		var back := net / free_mass if free_mass > 0.0 else Vector2.ZERO
		for i in Skeleton.COUNT:
			if held[i] or _is_planted_foot(i, planted):
				continue
			var move := nudge[i] - back
			pos[i] += move
			# Only part of a muscle pull becomes momentum: enough that limbs
			# swing and overshoot, not so much that a doll fighting its own
			# pose jitters itself into hops.
			prev[i] += move * MUSCLE_DAMP

	# Balance: the one deliberate cheat. While a foot is down, the whole body
	# is eased toward "standing over its feet" (a gyroscope in the pelvis) --
	# which is what lets a ragdoll get back up at all. Never while airborne.
	if balance > 0.0 and grounded:
		var feet_x := (pos[Skeleton.L_FOOT].x + pos[Skeleton.R_FOOT].x) * 0.5
		var sole: float = maxf(pos[Skeleton.L_FOOT].y, pos[Skeleton.R_FOOT].y)
		var stand := Vector2(feet_x + dx * size,
			sole - (Skeleton.STAND_HEIGHT - float(ctx["lift"])) * size)
		var shift := (stand - pos[Skeleton.PELVIS]) * balance * 0.08
		for i in Skeleton.COUNT:
			if held[i] or i == Skeleton.L_FOOT or i == Skeleton.R_FOOT:
				continue
			var w := 1.0 if i != Skeleton.L_KNEE and i != Skeleton.R_KNEE else 0.5
			# Moved, not pushed (prev moves too): no velocity is added, so
			# balancing can never throw the doll into the air.
			pos[i] += shift * w
			prev[i] += shift * w
	var push: float = ctx["push_x"]
	if push != 0.0 and grounded:
		for i in Skeleton.COUNT:
			if not held[i]:
				pos[i].x += push * h
