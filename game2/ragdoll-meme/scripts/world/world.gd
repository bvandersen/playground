extends Node2D
class_name World

## The stage: a fixed 720x1280 (9:16, the size a phone video is) box that
## owns every doll, every prop (pins, balloons, magnets, explosions) and
## the scene-wide knobs Forces set. Main scales and centres it to fit the
## screen; everything inside works in stage units, so physics behaves the
## same on every screen and a recording is always a clean 9:16 frame.

const STAGE_SIZE := Vector2(720, 1280)
const FLOOR_Y := 1190.0
const SUBSTEPS := 3
const ITERATIONS := 7
const PICK_RADIUS := 70.0
const BALLOON_LIFT := 9500.0
const MAGNET_RADIUS := 420.0
const MAX_DOLLS := 8

signal changed # a design edit (look/moves/forces/scene) -- for auto-save
## Something happened that should make a noise: an Sfx event id, how hard
## (0..1), where (stage x, for panning) and a pitch multiplier. World only
## reports; Main hands it to the Sfx autoload.
signal sfx(id: String, strength: float, x: float, pitch: float)

var dolls: Array = []
## force id -> {"enabled": bool, "params": {}}
var forces := {}

# Knobs Forces set in configure() (reset to these defaults every tick).
var gravity := Vector2(0, 2000)
var time_scale := 1.0
var stick_stiffness := 1.0
var bounce := 0.25
var friction := 0.18
var damping := 0.997
var walls_on := false
var floor_offset := 0.0
var floor_shift := 0.0
var shake := 0.0

var paused := false
var sim_time := 0.0
var last_h := 1.0 / 180.0
var _prev_floor_shift := 0.0

## touch index -> {"doll", "i", "from", "to"}
var grabs := {}
## [{"doll", "i", "anchor", "length"}] -- length 0 = nailed in place
var pins: Array = []
## [{"doll", "i", "pos", "prev", "acc", "length", "color"}]
var balloons: Array = []
## [{"pos", "strength"}] -- negative strength repels
var magnets: Array = []
## Pin tool drags in progress: touch index -> {"doll", "i", "end"}
var previews := {}
## Expanding rings left by Boom, purely visual: [{"pos", "age"}]
var booms: Array = []

## Scene look.
var background := {"kind": "gradient", "color": Color("#ffcf5c"), "color2": Color("#ff6f91"), "image": ""}
var floor_color := Color("#3b2f4a")
var caption_top := ""
var caption_bottom := ""
var watermark := true
var show_hint := true

var selected: Doll = null
var recording := false
var base_position := Vector2.ZERO

## Turns what the physics did this frame (impacts, bent joints, flying,
## falling over) into sfx events.
var sounds := SoundEvents.new()

var doll_layer: DrawLayer
var props_layer: DrawLayer
var overlay_layer: DrawLayer

func _ready() -> void:
	reset_design()
	doll_layer = DrawLayer.new(_draw_dolls)
	props_layer = DrawLayer.new(_draw_props)
	overlay_layer = DrawLayer.new(_draw_overlay)
	add_child(doll_layer)
	add_child(props_layer)
	add_child(overlay_layer)

## Back to a blank design: default forces and look, no dolls, no props.
func reset_design() -> void:
	forces = {}
	for f in ForceCatalog.all():
		forces[f.id] = {"enabled": f.default_enabled or f.always_on, "params": f.default_params()}
	background = {"kind": "gradient", "color": Color("#ffcf5c"), "color2": Color("#ff6f91"), "image": ""}
	floor_color = Color("#3b2f4a")
	caption_top = ""
	caption_bottom = ""
	watermark = true
	clear_props()
	dolls.clear()
	selected = null

func bounds_left() -> float:
	return 0.0

func bounds_right() -> float:
	return STAGE_SIZE.x

func floor_y() -> float:
	return FLOOR_Y + floor_offset

# --- Dolls ------------------------------------------------------------------

func add_doll(doll: Doll = null, drop: bool = true) -> Doll:
	if dolls.size() >= MAX_DOLLS:
		return null
	if doll == null:
		doll = Doll.new()
		if not dolls.is_empty():
			doll.style.randomize_style()
	var n := dolls.size()
	var x := STAGE_SIZE.x * 0.5 + (0.0 if n == 0 else (160.0 if n % 2 == 1 else -160.0) * ceilf(n / 2.0) * 0.6)
	x = clamp(x, 100.0, STAGE_SIZE.x - 100.0)
	var y := FLOOR_Y - Skeleton.STAND_HEIGHT * doll.size - (420.0 if drop and n > 0 else 0.0)
	doll.build(Vector2(x, y))
	dolls.append(doll)
	selected = doll
	changed.emit()
	return doll

func remove_doll(doll: Doll) -> void:
	dolls.erase(doll)
	pins = pins.filter(func(p): return p["doll"] != doll)
	balloons = balloons.filter(func(b): return b["doll"] != doll)
	for k in grabs.keys():
		if grabs[k]["doll"] == doll:
			grabs.erase(k)
	for k in previews.keys():
		if previews[k]["doll"] == doll:
			previews.erase(k)
	if selected == doll:
		selected = null if dolls.is_empty() else dolls[dolls.size() - 1]
	changed.emit()

func duplicate_doll(doll: Doll) -> Doll:
	var copy := Doll.new()
	copy.style = doll.style.duplicate_style()
	copy.size = doll.size
	copy.head_radius = doll.head_radius
	copy.muscle = doll.muscle
	copy.moves = doll.moves.duplicate(true)
	return add_doll(copy)

## Stand every doll back up where it started and drop all props.
func reset_scene() -> void:
	clear_props()
	var keep := dolls.duplicate()
	dolls.clear()
	for d in keep:
		add_doll(d, false)

func clear_props() -> void:
	sounds.reset()
	pins.clear()
	balloons.clear()
	magnets.clear()
	booms.clear()
	grabs.clear()
	previews.clear()

## Nearest joint to `p` (stage units) within reach, topmost doll first:
## [doll, index] or [].
func pick_joint(p: Vector2, reach: float = PICK_RADIUS) -> Array:
	var best := []
	var best_d := INF
	for di in range(dolls.size() - 1, -1, -1):
		var doll: Doll = dolls[di]
		for i in Skeleton.COUNT:
			var d := doll.pos[i].distance_to(p) - doll.radius(i) * 0.6
			if d < reach and d < best_d:
				best_d = d
				best = [doll, i]
	return best

# --- Stepping ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_configure_forces()
	var h := delta / SUBSTEPS * time_scale
	for k in SUBSTEPS:
		var f := float(k + 1) / SUBSTEPS
		for g in grabs.values():
			g["target"] = (g["from"] as Vector2).lerp(g["to"], f)
		step(h)
	for g in grabs.values():
		g["from"] = g["to"]
	sounds.after_frame(self, delta)
	for b in booms:
		b["age"] += delta
	booms = booms.filter(func(b): return b["age"] < 0.6)
	shake = maxf(shake - delta * 60.0, 0.0)
	var jitter := Vector2.ZERO
	if shake > 0.1:
		jitter = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	position = base_position + jitter * scale.x
	doll_layer.queue_redraw()
	props_layer.queue_redraw()
	overlay_layer.queue_redraw()
	queue_redraw()

func _configure_forces() -> void:
	gravity = Vector2(0, 2000)
	time_scale = 1.0
	stick_stiffness = 1.0
	bounce = 0.25
	friction = 0.18
	damping = 0.997
	walls_on = false
	floor_offset = 0.0
	floor_shift = 0.0
	for f in ForceCatalog.all():
		var state: Dictionary = forces[f.id]
		if state["enabled"] or f.always_on:
			f.configure(self, state["params"])

func step(h: float) -> void:
	var vel_scale := h / last_h if last_h > 0.0 else 1.0
	last_h = h
	_mark_held()
	if paused:
		# Pose mode: no time passes, but dragging still bends the body
		# through its constraints -- the purest form of the IK.
		for doll: Doll in dolls:
			for i in Skeleton.COUNT:
				doll.prev[i] = doll.pos[i]
		for it in ITERATIONS:
			_solve_grabs()
			for doll: Doll in dolls:
				doll.solve_sticks(1.0)
			_solve_pins()
			_collide_bounds()
		for doll: Doll in dolls:
			for i in Skeleton.COUNT:
				doll.prev[i] = doll.pos[i]
		return
	sim_time += h
	for doll: Doll in dolls:
		for i in Skeleton.COUNT:
			doll.acc[i] += gravity
	for f in ForceCatalog.all():
		var state: Dictionary = forces[f.id]
		if state["enabled"] and not f.always_on:
			f.apply(self, h, state["params"])
	_apply_balloons()
	_apply_magnets()
	for doll: Doll in dolls:
		doll.apply_muscles(self, h)
	for doll: Doll in dolls:
		doll.integrate(h, vel_scale, damping)
	_integrate_balloons(h, vel_scale)
	for it in ITERATIONS:
		_solve_grabs()
		for doll: Doll in dolls:
			doll.solve_sticks(stick_stiffness)
			doll.solve_foot_locks()
		_solve_pins()
		_collide_bounds()
	_collide_dolls()
	_bounce()
	_solve_balloon_strings()
	var dshift := floor_shift - _prev_floor_shift
	_prev_floor_shift = floor_shift
	for doll: Doll in dolls:
		var fy := floor_y()
		var feet_down := false
		for i in [Skeleton.L_FOOT, Skeleton.R_FOOT, Skeleton.L_KNEE, Skeleton.R_KNEE]:
			if doll.pos[i].y >= fy - doll.radius(i) - 4.0:
				feet_down = true
		doll.grounded = feet_down
		if dshift != 0.0:
			for i in Skeleton.COUNT:
				if doll.pos[i].y >= fy - doll.radius(i) - 2.0:
					doll.pos[i].x += dshift
		doll.head_velocity = (doll.pos[Skeleton.HEAD] - doll.prev[Skeleton.HEAD]) / h * time_scale
		doll.head_speed = doll.head_velocity.length()

func _mark_held() -> void:
	for doll: Doll in dolls:
		for i in Skeleton.COUNT:
			doll.held[i] = 0
	for g in grabs.values():
		g["doll"].held[g["i"]] = 1
	for p in pins:
		if p["length"] <= 0.0:
			p["doll"].held[p["i"]] = 1

func _solve_grabs() -> void:
	for g in grabs.values():
		var target: Vector2 = g.get("target", g["to"])
		g["doll"].pos[g["i"]] = target

func _solve_pins() -> void:
	for p in pins:
		var doll: Doll = p["doll"]
		var i: int = p["i"]
		var anchor: Vector2 = p["anchor"]
		if p["length"] <= 0.0:
			if doll.held[i] and not _is_grabbed(doll, i):
				doll.pos[i] = anchor
			continue
		var d := doll.pos[i] - anchor
		if d.length() > p["length"]:
			doll.pos[i] = anchor + d.normalized() * p["length"]

func _is_grabbed(doll: Doll, i: int) -> bool:
	for g in grabs.values():
		if g["doll"] == doll and g["i"] == i:
			return true
	return false

func _collide_bounds() -> void:
	var fy := floor_y()
	for doll: Doll in dolls:
		for i in Skeleton.COUNT:
			var r := doll.radius(i)
			var p := doll.pos[i]
			# How fast it was going when it hit, from this step's whole
			# travel (before the projection below eats the overshoot).
			if p.y > fy - r:
				sounds.impact(doll, i, (p.y - doll.prev[i].y) / last_h)
				p.y = fy - r
			if walls_on:
				if p.x < r or p.x > STAGE_SIZE.x - r:
					sounds.impact(doll, i, absf(p.x - doll.prev[i].x) / last_h)
				p.x = clamp(p.x, r, STAGE_SIZE.x - r)
				if p.y < r:
					sounds.impact(doll, i, (doll.prev[i].y - p.y) / last_h)
					p.y = r
			doll.pos[i] = p

## Velocity half of the collisions (positions were projected in the
## iterations): reflect what's moving into a surface by `bounce` and bleed
## sideways motion along the floor by `friction`.
func _bounce() -> void:
	var fy := floor_y()
	for doll: Doll in dolls:
		for i in Skeleton.COUNT:
			var r := doll.radius(i)
			var p := doll.pos[i]
			var v := p - doll.prev[i]
			if p.y >= fy - r - 0.5:
				if v.y > 0.0:
					doll.prev[i].y = p.y + v.y * bounce
				doll.prev[i].x = p.x - v.x * (1.0 - friction)
			if walls_on:
				if (p.x <= r + 0.5 and v.x < 0.0) or (p.x >= STAGE_SIZE.x - r - 0.5 and v.x > 0.0):
					doll.prev[i].x = p.x + v.x * bounce
				if p.y <= r + 0.5 and v.y < 0.0:
					doll.prev[i].y = p.y + v.y * bounce

func _collide_dolls() -> void:
	for a in dolls.size():
		for b in range(a + 1, dolls.size()):
			var da: Doll = dolls[a]
			var db: Doll = dolls[b]
			for i in Skeleton.COUNT:
				var ra := da.radius(i)
				for j in Skeleton.COUNT:
					var rr := ra + db.radius(j)
					var d := db.pos[j] - da.pos[i]
					var dsq := d.length_squared()
					if dsq >= rr * rr or dsq < 0.0001:
						continue
					var dist := sqrt(dsq)
					var wa := 0.0 if da.held[i] else da.inv_mass[i]
					var wb := 0.0 if db.held[j] else db.inv_mass[j]
					if wa + wb <= 0.0:
						continue
					var corr := d / dist * (rr - dist) / (wa + wb)
					var rel := (da.pos[i] - da.prev[i]) - (db.pos[j] - db.prev[j])
					sounds.collide(da, i, db, j, absf(rel.dot(d / dist)) / last_h)
					da.pos[i] -= corr * wa
					db.pos[j] += corr * wb

# --- Props ------------------------------------------------------------------

func add_pin(doll: Doll, i: int, anchor: Vector2) -> void:
	var length := doll.pos[i].distance_to(anchor)
	pins.append({"doll": doll, "i": i, "anchor": anchor, "length": 0.0 if length < 24.0 else length})
	emit_sfx("pin" if length < 24.0 else "rope", 1.0, anchor.x)

func add_balloon(doll: Doll, i: int) -> void:
	var colors := [Color("#ff4757"), Color("#1e90ff"), Color("#ffd32a"), Color("#2ed573"), Color("#ff6bcb"), Color("#a55eea")]
	var start := doll.pos[i] + Vector2(randf_range(-30, 30), -150)
	balloons.append({
		"doll": doll, "i": i, "pos": start, "prev": start, "acc": Vector2.ZERO,
		"length": 150.0, "color": colors[randi() % colors.size()],
	})
	emit_sfx("balloon_tie", 1.0, start.x)

func add_magnet(p: Vector2) -> void:
	magnets.append({"pos": p, "strength": 9000.0})
	emit_sfx("magnet", 1.0, p.x)

func boom(p: Vector2, strength: float = 4200.0, radius: float = 360.0) -> void:
	booms.append({"pos": p, "age": 0.0})
	shake = maxf(shake, 18.0)
	emit_sfx("boom", strength / 4200.0, p.x, randf_range(0.9, 1.1))
	var h := last_h
	for doll: Doll in dolls:
		for i in Skeleton.COUNT:
			var d := doll.pos[i] - p
			var dist := d.length()
			if dist > radius:
				continue
			var dir := d / dist if dist > 0.01 else Vector2.UP
			var dv := dir * strength * (1.0 - dist / radius) + Vector2(0, -strength * 0.25)
			doll.prev[i] -= dv * h
	# Balloons caught in the middle of the blast pop; the rest are flung.
	var popped := balloons.filter(func(b): return (b["pos"] as Vector2).distance_to(p) < radius * 0.45)
	if not popped.is_empty():
		balloons = balloons.filter(func(b): return not popped.has(b))
		emit_sfx("balloon_pop", 1.0, p.x)
	for b in balloons:
		var d: Vector2 = b["pos"] - p
		if d.length() < radius:
			b["prev"] -= d.normalized() * strength * 0.5 * h

## Remove the prop nearest `p` (pin anchor, balloon, magnet). True if one went.
func erase_near(p: Vector2, reach: float = 80.0) -> bool:
	var best_list = null
	var best_i := -1
	var best_d := reach
	for i in pins.size():
		var d: float = (pins[i]["anchor"] as Vector2).distance_to(p)
		if d < best_d:
			best_d = d
			best_list = pins
			best_i = i
	for i in balloons.size():
		var d: float = (balloons[i]["pos"] as Vector2).distance_to(p)
		if d < best_d + 20.0:
			best_d = d
			best_list = balloons
			best_i = i
	for i in magnets.size():
		var d: float = (magnets[i]["pos"] as Vector2).distance_to(p)
		if d < best_d:
			best_d = d
			best_list = magnets
			best_i = i
	if best_list == null:
		# Tapping a doll's joint drops whatever's attached to it.
		var hit := pick_joint(p)
		if hit.is_empty():
			return false
		var pins_before := pins.size()
		var balloons_before := balloons.size()
		pins = pins.filter(func(q): return not (q["doll"] == hit[0] and q["i"] == hit[1]))
		balloons = balloons.filter(func(q): return not (q["doll"] == hit[0] and q["i"] == hit[1]))
		if balloons.size() < balloons_before:
			emit_sfx("balloon_pop", 1.0, p.x)
		elif pins.size() < pins_before:
			emit_sfx("vanish", 1.0, p.x)
		return pins.size() + balloons.size() < pins_before + balloons_before
	emit_sfx("balloon_pop" if best_list == balloons else "vanish", 1.0, p.x)
	best_list.remove_at(best_i)
	return true

func emit_sfx(id: String, strength: float, x: float, pitch: float = 1.0) -> void:
	# Slow-mo plays everything lower.
	sfx.emit(id, strength, x, pitch * clampf(lerpf(1.0, time_scale, 0.6), 0.5, 1.4))

func magnet_near(p: Vector2, reach: float = 70.0) -> int:
	for i in magnets.size():
		if (magnets[i]["pos"] as Vector2).distance_to(p) < reach:
			return i
	return -1

func _apply_balloons() -> void:
	for b in balloons:
		var doll: Doll = b["doll"]
		var i: int = b["i"]
		var d: Vector2 = b["pos"] - doll.pos[i]
		if d.length() > b["length"] * 0.9:
			doll.add_force(i, d.normalized() * BALLOON_LIFT)

func _apply_magnets() -> void:
	for m in magnets:
		var mp: Vector2 = m["pos"]
		for doll: Doll in dolls:
			for i in Skeleton.COUNT:
				var d := mp - doll.pos[i]
				var dist := d.length()
				if dist > MAGNET_RADIUS or dist < 1.0:
					continue
				var fall := 1.0 - dist / MAGNET_RADIUS
				doll.acc[i] += d / dist * float(m["strength"]) * fall * (1.0 if dist > 40.0 else dist / 40.0)

func _integrate_balloons(h: float, vel_scale: float) -> void:
	for b in balloons:
		var v: Vector2 = (b["pos"] - b["prev"]) * vel_scale * 0.985
		b["prev"] = b["pos"]
		var a: Vector2 = b["acc"] + Vector2(0, -900.0) - gravity * 0.15
		b["pos"] += v + a * h * h
		b["acc"] = Vector2.ZERO
		var p: Vector2 = b["pos"]
		if walls_on:
			p.x = clamp(p.x, 40.0, STAGE_SIZE.x - 40.0)
			p.y = maxf(p.y, 50.0)
		b["pos"] = p

func _solve_balloon_strings() -> void:
	for b in balloons:
		var anchor: Vector2 = b["doll"].pos[b["i"]]
		var d: Vector2 = b["pos"] - anchor
		if d.length() > b["length"]:
			b["pos"] = anchor + d.normalized() * b["length"]

# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	# Oversized by a margin so camera shake never shows an edge.
	var m := 80.0
	var r := Rect2(-m, -m, STAGE_SIZE.x + 2 * m, STAGE_SIZE.y + 2 * m)
	match background["kind"]:
		"photo":
			var tex := ImageLibrary.texture(background["image"])
			if tex != null:
				var ts := tex.get_size()
				var sc := maxf(r.size.x / ts.x, r.size.y / ts.y)
				var src := Rect2((ts - r.size / sc) * 0.5, r.size / sc)
				draw_texture_rect_region(tex, r, src)
			else:
				draw_rect(r, background["color"])
		"gradient":
			var c1: Color = background["color"]
			var c2: Color = background["color2"]
			draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
				PackedColorArray([c1, c1, c2, c2]))
		_:
			draw_rect(r, background["color"])
	var fy := floor_y()
	if background["kind"] != "photo":
		draw_rect(Rect2(-m, fy, STAGE_SIZE.x + 2 * m, STAGE_SIZE.y - fy + m), floor_color)
		draw_line(Vector2(-m, fy), Vector2(STAGE_SIZE.x + m, fy), floor_color.darkened(0.4), 4.0)
	else:
		draw_rect(Rect2(-m, fy, STAGE_SIZE.x + 2 * m, 6.0), Color(0, 0, 0, 0.25))

func _draw_dolls(ci: CanvasItem) -> void:
	for di in dolls.size():
		var doll: Doll = dolls[di]
		# A soft contact shadow so the doll reads as standing *on* the floor.
		var fy := floor_y()
		var feet_x := (doll.pos[Skeleton.L_FOOT].x + doll.pos[Skeleton.R_FOOT].x) * 0.5
		var lowest: float = doll.pos[Skeleton.L_FOOT].y
		for i in Skeleton.COUNT:
			lowest = maxf(lowest, doll.pos[i].y)
		var near: float = clamp(1.0 - (fy - lowest) / 500.0, 0.0, 1.0)
		if near > 0.0:
			_ellipse(ci, Vector2(feet_x, fy + 4), 70.0 * doll.size * (0.5 + 0.5 * near), 12.0 * doll.size, Color(0, 0, 0, 0.22 * near))
		DollPainter.draw_doll(ci, doll, sim_time, di + 1)
		if doll == selected and dolls.size() > 1 and not recording:
			var top := doll.pos[Skeleton.HEAD] - Vector2(0, doll.head_radius * doll.size + 26)
			ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-14, -16), top + Vector2(14, -16), top]), Color(1, 1, 1, 0.9))

func _draw_props(ci: CanvasItem) -> void:
	for p in pins:
		var anchor: Vector2 = p["anchor"]
		var at: Vector2 = p["doll"].pos[p["i"]]
		if p["length"] > 0.0:
			ci.draw_line(anchor, at, Color("#6b4f2a"), 4.0, true)
		ci.draw_circle(anchor, 10.0, Color("#1d1d24"))
		ci.draw_circle(anchor, 6.0, Color("#c0c6d0"))
	for b in balloons:
		var at: Vector2 = b["doll"].pos[b["i"]]
		var bp: Vector2 = b["pos"]
		var mid := (at + bp) * 0.5 + Vector2(sin(sim_time * 3.0 + bp.x) * 10.0, 0)
		ci.draw_polyline(LineStyles.path(PackedVector2Array([at, mid, bp + Vector2(0, 46)]), true), Color(1, 1, 1, 0.8), 2.0, true)
		var c: Color = b["color"]
		_ellipse(ci, bp, 38.0, 46.0, c.darkened(0.25))
		_ellipse(ci, bp + Vector2(-2, -2), 35.0, 43.0, c)
		_ellipse(ci, bp + Vector2(-13, -16), 8.0, 12.0, Color(1, 1, 1, 0.45))
		ci.draw_colored_polygon(PackedVector2Array([bp + Vector2(-7, 52), bp + Vector2(7, 52), bp + Vector2(0, 43)]), c.darkened(0.25))
	for m in magnets:
		var mp: Vector2 = m["pos"]
		var attract: bool = m["strength"] > 0.0
		ci.draw_arc(mp, MAGNET_RADIUS, 0, TAU, 64, Color(1, 1, 1, 0.08), 2.0)
		var body := Color("#e8413c") if attract else Color("#3c7be8")
		ci.draw_arc(mp + Vector2(0, -6), 30.0, 0.0, PI, 16, body, 22.0)
		ci.draw_rect(Rect2(mp + Vector2(-41, -26), Vector2(22, 20)), body)
		ci.draw_rect(Rect2(mp + Vector2(19, -26), Vector2(22, 20)), body)
		ci.draw_rect(Rect2(mp + Vector2(-41, -40), Vector2(22, 14)), Color("#d7dde6"))
		ci.draw_rect(Rect2(mp + Vector2(19, -40), Vector2(22, 14)), Color("#d7dde6"))
	for b in booms:
		var k: float = b["age"] / 0.6
		ci.draw_circle(b["pos"], 200.0 * k, Color(1.0, 0.85, 0.3, 0.35 * (1.0 - k)))
		ci.draw_arc(b["pos"], 360.0 * k, 0, TAU, 48, Color(1, 1, 1, 1.0 - k), 10.0 * (1.0 - k) + 1.0)
	for pv in previews.values():
		ci.draw_line(pv["doll"].pos[pv["i"]], pv["end"], Color(1, 1, 1, 0.7), 3.0, true)
		ci.draw_circle(pv["end"], 9.0, Color(1, 1, 1, 0.7))
	for g in grabs.values():
		ci.draw_arc(g["to"], 30.0, 0, TAU, 24, Color(1, 1, 1, 0.5), 3.0, true)

func _draw_overlay(ci: CanvasItem) -> void:
	_draw_caption(ci, caption_top, 70.0, false)
	_draw_caption(ci, caption_bottom, STAGE_SIZE.y - 60.0, true)
	if watermark:
		var tex := TextArt.texture("made with Ragdoll Meme Maker", 26, 0.0, false)
		if tex != null:
			var s := tex.get_size()
			ci.draw_texture(tex, Vector2(STAGE_SIZE.x - s.x - 18, FLOOR_Y + 14), Color(1, 1, 1, 0.55))
	if show_hint and not recording and not caption_top and not caption_bottom:
		var tex := TextArt.texture("drag me around! then hit REC", 40, 640.0, true)
		if tex != null:
			var s := tex.get_size()
			ci.draw_texture(tex, Vector2((STAGE_SIZE.x - s.x) * 0.5, 180), Color(1, 1, 1, 0.85))

func _draw_caption(ci: CanvasItem, text: String, y: float, from_bottom: bool) -> void:
	if text.strip_edges() == "":
		return
	var tex := TextArt.texture(text, 72, STAGE_SIZE.x - 60.0, true)
	if tex == null:
		return
	var s := tex.get_size()
	var top := y - s.y if from_bottom else y
	ci.draw_texture(tex, Vector2((STAGE_SIZE.x - s.x) * 0.5, top))

static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, color)

# --- Serialization ----------------------------------------------------------

func to_dict() -> Dictionary:
	var ds := []
	for d in dolls:
		ds.append({
			"style": d.style.to_dict(), "size": d.size, "head_radius": d.head_radius,
			"muscle": d.muscle, "moves": d.moves.duplicate(true),
		})
	var bg := background.duplicate()
	bg["color"] = (bg["color"] as Color).to_html()
	bg["color2"] = (bg["color2"] as Color).to_html()
	return {
		"dolls": ds, "forces": forces.duplicate(true), "background": bg,
		"floor_color": floor_color.to_html(), "caption_top": caption_top,
		"caption_bottom": caption_bottom, "watermark": watermark,
	}

func from_dict(d: Dictionary) -> void:
	clear_props()
	dolls.clear()
	selected = null
	if d.get("forces") is Dictionary:
		for id in d["forces"]:
			if forces.has(id) and d["forces"][id] is Dictionary:
				forces[id]["enabled"] = bool(d["forces"][id].get("enabled", false))
				var params: Dictionary = d["forces"][id].get("params", {})
				for k in params:
					if forces[id]["params"].has(k):
						forces[id]["params"][k] = float(params[k])
	if d.get("background") is Dictionary:
		var bg: Dictionary = d["background"]
		background["kind"] = str(bg.get("kind", "gradient"))
		background["color"] = Color.from_string(str(bg.get("color", "")), background["color"])
		background["color2"] = Color.from_string(str(bg.get("color2", "")), background["color2"])
		background["image"] = str(bg.get("image", ""))
	floor_color = Color.from_string(str(d.get("floor_color", "")), floor_color)
	caption_top = str(d.get("caption_top", ""))
	caption_bottom = str(d.get("caption_bottom", ""))
	watermark = bool(d.get("watermark", true))
	for dd in d.get("dolls", []):
		if not (dd is Dictionary):
			continue
		var doll := Doll.new()
		doll.style = DollStyle.from_dict(dd.get("style", {}))
		doll.size = clamp(float(dd.get("size", 1.0)), 0.4, 2.0)
		doll.head_radius = clamp(float(dd.get("head_radius", Skeleton.DEFAULT_HEAD_RADIUS)), 20.0, 140.0)
		doll.muscle = clamp(float(dd.get("muscle", 0.45)), 0.0, 1.0)
		if dd.get("moves") is Dictionary:
			for id in dd["moves"]:
				if doll.moves.has(id) and dd["moves"][id] is Dictionary:
					doll.moves[id]["enabled"] = bool(dd["moves"][id].get("enabled", false))
					var params: Dictionary = dd["moves"][id].get("params", {})
					for k in params:
						if doll.moves[id]["params"].has(k):
							doll.moves[id]["params"][k] = float(params[k])
		add_doll(doll, false)

## Every ImageLibrary id the scene uses.
func image_ids() -> Array:
	var out := []
	for d in dolls:
		out.append_array(d.style.image_ids())
	if background["kind"] == "photo" and background["image"] != "":
		out.append(background["image"])
	return out
