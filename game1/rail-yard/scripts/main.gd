extends Node2D

## Wires the track network, trains, views and UI together, and owns what
## none of them should: the Design/Play mode, the active design tool, the
## camera, input routing, undo, and save/load. What track *is* lives in
## TrackNetwork; what a train *does* lives in Train -- this is plumbing.

const MODE_DESIGN := "design"
const MODE_PLAY := "play"

const TOOL_SELECT := "select"
const TOOL_DRAW := "draw"
const TOOL_ERASE := "erase"
const TOOL_TRAIN := "train"

const STATE_VERSION := 1
const AUTOSAVE_DELAY := 0.8
const SNAP_PX := 26.0 # stroke ends this close (screen px) join existing track
const TAP_PX := 24.0
const DRAG_START_PX := 8.0
const MIN_ZOOM := 0.25
const MAX_ZOOM := 3.0
const UNDO_LIMIT := 40

var mode: String = MODE_DESIGN
var tool: String = TOOL_SELECT
var net := TrackNetwork.new()
var trains: Array = []
var selected_train: Train = null
## Camera follows this train while it's set; any manual pan/zoom lets go.
var follow_train: Train = null

var camera: Camera2D
var ground: Ground
var track_view: TrackView
var trains_view: TrainsView
var smoke: Smoke
var overlay: DrawOverlay
var ui: UIRoot

## Settings (user://settings.json), same meaning as in game2.
var reset_on_stop: bool = true
var autosave_enabled: bool = false
var current_slot: String = ""

var _play_start_state: Dictionary = {}
var _autosave_countdown: float = -1.0
var _undo: Array = []

# Input state. Touches are tracked by index so two fingers pinch-zoom in
# any tool; one finger does whatever the tool does.
var _touches := {}
var _gesture := "" # "", pending, pan, stroke, drag_train, pinch, blocked
var _down_pos := Vector2.ZERO
var _last_pos := Vector2.ZERO
var _mouse_left := false
var _mouse_pan := false
var _pinch := {}
var _stroke := PackedVector2Array()
var _drag_car := -1

func _ready() -> void:
	randomize()
	_load_settings()

	ground = Ground.new()
	add_child(ground)
	track_view = TrackView.new()
	track_view.net = net
	add_child(track_view)
	trains_view = TrainsView.new()
	trains_view.main = self
	add_child(trains_view)
	smoke = Smoke.new()
	add_child(smoke)
	overlay = DrawOverlay.new()
	add_child(overlay)
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()

	var canvas_layer := CanvasLayer.new()
	add_child(canvas_layer)
	ui = UIRoot.new()
	canvas_layer.add_child(ui)
	ui.setup(self)

	if autosave_enabled and SceneStore.has_slot(current_slot):
		load_slot(current_slot)
	else:
		load_demo()
	fit_view.call_deferred()

func _process(delta: float) -> void:
	if follow_train != null:
		if not trains.has(follow_train) or follow_train.world.is_empty():
			follow_train = null
		else:
			var target: Vector2 = follow_train.world[0]["center"]
			camera.position = camera.position.lerp(target, 1.0 - exp(-4.0 * delta))
	if _autosave_countdown > 0.0:
		_autosave_countdown = maxf(_autosave_countdown - delta, 0.001)
		if _autosave_countdown <= 0.001:
			_flush_autosave()

func _physics_process(delta: float) -> void:
	if mode != MODE_PLAY:
		return
	var targets := []
	for t in trains:
		targets.append(t.plan(delta, net, trains))
	for i in range(trains.size()):
		trains[i].simulate(delta, targets[i])
	for t in trains:
		t.update_world()
		t.update_visual(delta, smoke)
	trains_view.queue_redraw()

# --- Modes & tools -------------------------------------------------------

func toggle_mode() -> void:
	set_mode(MODE_PLAY if mode == MODE_DESIGN else MODE_DESIGN)

func set_mode(new_mode: String) -> void:
	if new_mode == mode:
		return
	_cancel_gesture()
	if new_mode == MODE_PLAY:
		_flush_autosave()
		_play_start_state = capture_state()
	mode = new_mode
	if mode == MODE_DESIGN:
		if reset_on_stop and not _play_start_state.is_empty():
			var keep := trains.find(selected_train)
			apply_state(_play_start_state)
			smoke.clear()
			if keep >= 0 and keep < trains.size():
				selected_train = trains[keep]
		else:
			mark_dirty()
	ui.on_mode_changed(mode)
	if mode == MODE_DESIGN:
		ui.on_selection_changed(selected_train)
	trains_view.queue_redraw()

func set_tool(new_tool: String) -> void:
	_cancel_gesture()
	tool = new_tool
	ui.on_tool_changed(tool)

# --- Scene state ---------------------------------------------------------

func capture_state() -> Dictionary:
	return {
		"version": STATE_VERSION,
		"tracks": net.to_dict(),
		"trains": trains.map(func(t): return t.to_dict()),
	}

func apply_state(state: Dictionary) -> void:
	_cancel_gesture()
	net.from_dict(state.get("tracks", {}))
	trains.clear()
	selected_train = null
	for td in state.get("trains", []):
		if td is Dictionary:
			var t := Train.from_dict(td)
			if not t.cars.is_empty() and t.place(net):
				trains.append(t)
	_redraw_world()
	ui.on_selection_changed(null)

func _redraw_world() -> void:
	track_view.queue_redraw()
	ground.rebuild(net)
	trains_view.queue_redraw()

func push_undo() -> void:
	_undo.append(capture_state())
	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()
	ui.on_undo_changed(_undo.size())

func undo() -> void:
	if _undo.is_empty() or mode != MODE_DESIGN:
		return
	apply_state(_undo.pop_back())
	ui.on_undo_changed(_undo.size())
	mark_dirty()

func save_slot(slot_name: String) -> bool:
	var clean := SceneStore.sanitize_name(slot_name)
	if clean == "" or not SceneStore.save_slot(clean, capture_state()):
		return false
	current_slot = clean
	_autosave_countdown = -1.0
	save_settings()
	return true

func load_slot(slot_name: String) -> bool:
	var state := SceneStore.load_slot(slot_name)
	if state.is_empty():
		return false
	if mode == MODE_PLAY:
		set_mode(MODE_DESIGN)
	_play_start_state = {}
	apply_state(state)
	current_slot = SceneStore.sanitize_name(slot_name)
	_autosave_countdown = -1.0
	save_settings()
	fit_view()
	return true

func delete_slot(slot_name: String) -> void:
	SceneStore.delete_slot(slot_name)
	if SceneStore.sanitize_name(slot_name) == current_slot:
		current_slot = ""
	save_settings()

func mark_dirty() -> void:
	if autosave_enabled and current_slot != "":
		_autosave_countdown = AUTOSAVE_DELAY

func _flush_autosave() -> void:
	if _autosave_countdown <= 0.0:
		return
	_autosave_countdown = -1.0
	if autosave_enabled and current_slot != "" and mode == MODE_DESIGN:
		SceneStore.save_slot(current_slot, capture_state())

func _load_settings() -> void:
	var st := SceneStore.load_settings()
	reset_on_stop = bool(st.get("reset_on_stop", reset_on_stop))
	autosave_enabled = bool(st.get("autosave", autosave_enabled))
	current_slot = str(st.get("current_slot", current_slot))

func save_settings() -> void:
	SceneStore.save_settings({
		"reset_on_stop": reset_on_stop,
		"autosave": autosave_enabled,
		"current_slot": current_slot,
	})

# --- Layouts -------------------------------------------------------------

## A starter layout: an oval with a passing loop on top, a goods spur off
## the bottom and a second spur inside, one passenger and one freight
## train. Built through the same add_stroke a finger uses, so it doubles
## as a check that drawn joins come out smooth.
func load_demo() -> void:
	if mode == MODE_PLAY:
		set_mode(MODE_DESIGN)
	net.clear()
	# Drawn lying down, then stood upright to suit a phone held portrait.
	var rot := Transform2D(PI * 0.5, Vector2.ZERO)
	var oval := PackedVector2Array()
	var half := 220.0
	var r := 150.0
	var x := 0.0
	while x < half:
		oval.append(Vector2(x, r))
		x += 10.0
	for k in range(0, 37):
		var a := PI * 0.5 - k * PI / 36.0
		oval.append(Vector2(half + cos(a) * r, sin(a) * r))
	x = half - 10.0
	while x > -half:
		oval.append(Vector2(x, -r))
		x -= 10.0
	for k in range(0, 37):
		var a := -PI * 0.5 - k * PI / 36.0
		oval.append(Vector2(-half + cos(a) * r, sin(a) * r))
	x = -half + 10.0
	while x <= 0.0:
		oval.append(Vector2(x, r))
		x += 10.0
	net.add_stroke(rot * oval, 20.0)
	# Passing loop above the top straight.
	net.add_stroke(rot * _smooth_path([Vector2(170, -r), Vector2(110, -r - 36), Vector2(40, -r - 48),
		Vector2(-40, -r - 48), Vector2(-110, -r - 36), Vector2(-170, -r)]), 20.0)
	# Goods spur off the bottom straight, out to a buffer stop.
	net.add_stroke(rot * _smooth_path([Vector2(40, r), Vector2(100, r + 22), Vector2(160, r + 46),
		Vector2(230, r + 62), Vector2(310, r + 68)]), 20.0)
	# Siding curving into the middle of the oval.
	net.add_stroke(rot * _smooth_path([Vector2(-170, r), Vector2(-110, r - 22), Vector2(-60, r - 60),
		Vector2(-30, r - 110), Vector2(-20, r - 160)]), 20.0)

	trains.clear()
	selected_train = null
	var specs := [
		[Vector2(-40, -r), Vector2.LEFT, ["steam", "tender", "coach", "coach", "coach"], Color(0.12, 0.36, 0.2), 105.0],
		[Vector2(120, r), Vector2.RIGHT, ["diesel", "boxcar", "tanker", "hopper", "logs", "container", "caboose"], Color(0.8, 0.2, 0.17), 80.0],
	]
	for spec in specs:
		var t := Train.new()
		t.anchor = rot * (spec[0] as Vector2)
		t.heading = rot.basis_xform(spec[1])
		t.livery = spec[3]
		t.speed = spec[4]
		for type in spec[2]:
			t.cars.append(WagonCatalog.make_car(type, t.livery))
		if t.place(net):
			trains.append(t)
	_undo.clear()
	ui.on_undo_changed(0)
	_redraw_world()
	ui.on_selection_changed(null)
	mark_dirty()

static func _smooth_path(ctrl: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(ctrl.size() - 1):
		var a: Vector2 = ctrl[i]
		var b: Vector2 = ctrl[i + 1]
		var steps := maxi(int(a.distance_to(b) / 8.0), 1)
		for k in range(steps):
			out.append(a.lerp(b, float(k) / steps))
	out.append(ctrl[ctrl.size() - 1])
	return out

func clear_all() -> void:
	if mode == MODE_PLAY:
		set_mode(MODE_DESIGN)
	push_undo()
	net.clear()
	trains.clear()
	select_train(null)
	_redraw_world()
	mark_dirty()

# --- Trains --------------------------------------------------------------

func select_train(t: Train) -> void:
	selected_train = t
	ui.on_selection_changed(t)
	trains_view.queue_redraw()

func train_at(p: Vector2) -> Array:
	var pad := 6.0 / camera.zoom.x
	for i in range(trains.size() - 1, -1, -1):
		var car: int = trains[i].car_at(p, pad)
		if car >= 0:
			return [trains[i], car]
	return []

func place_train_at(p: Vector2) -> void:
	var hit := net.nearest(p, TAP_PX * 2.0 / camera.zoom.x)
	if hit.is_empty():
		ui.show_message("Tap on a track to put a train there.")
		return
	var t := Train.new()
	t.livery = WagonCatalog.LIVERIES[randi() % WagonCatalog.LIVERIES.size()]
	t.speed = randf_range(70.0, 120.0)
	var preset: Array = WagonCatalog.PRESETS[randi() % WagonCatalog.PRESETS.size()]
	for type in preset:
		t.cars.append(WagonCatalog.make_car(type, t.livery))
	var seg: TrackSegment = hit["seg"]
	var u: float = hit["u"]
	t.anchor = hit["pos"]
	# Face the loco towards the longer run of open track, so a train put
	# down near a buffer stop doesn't start out nose-first against it.
	var ahead: float = net.walk(seg, false, u, 600.0, 50.0)["dead"]
	var behind: float = net.walk(seg, true, seg.length - u, 600.0, 50.0)["dead"]
	t.heading = seg.tangent_at(u) * (1.0 if ahead >= behind else -1.0)
	if not t.place(net):
		t.heading = -t.heading
		if not t.place(net):
			ui.show_message("Not enough track there for a whole train.")
			return
	if t.overlaps(trains):
		ui.show_message("Another train is in the way there.")
		return
	push_undo()
	trains.append(t)
	set_tool(TOOL_SELECT)
	select_train(t)
	mark_dirty()

func remove_train(t: Train) -> void:
	push_undo()
	trains.erase(t)
	if selected_train == t:
		select_train(null)
	trains_view.queue_redraw()
	mark_dirty()

## Re-lays `t` after its cars changed; rolls the change back if it no
## longer fits on its track.
func relay_train(t: Train) -> void:
	var idx := trains.find(t)
	var fits := t.place(net)
	if not fits or t.overlaps(trains):
		undo()
		if idx >= 0 and idx < trains.size():
			select_train(trains[idx])
		ui.show_message("That doesn't fit on this track." if not fits else "That would run into another train.")
		return
	trains_view.queue_redraw()
	ui.on_selection_changed(t)
	mark_dirty()

func add_car(t: Train, type: String) -> void:
	push_undo()
	t.cars.append(WagonCatalog.make_car(type, t.livery))
	relay_train(t)

func remove_car(t: Train, index: int) -> void:
	if t.cars.size() <= 1:
		ui.show_message("A train needs at least one car -- use Delete instead.")
		return
	push_undo()
	t.cars.remove_at(index)
	relay_train(t)

func turn_train(t: Train) -> void:
	push_undo()
	t.heading = -t.heading
	relay_train(t)

func set_livery(t: Train, c: Color) -> void:
	t.livery = c
	for car in t.cars:
		if WagonCatalog.entry(car["type"]).get("livery", false):
			car["color"] = c
	trains_view.queue_redraw()
	mark_dirty()

# --- Tracks --------------------------------------------------------------

func _on_tracks_changed() -> void:
	var lost := 0
	for t in trains.duplicate():
		if not t.place(net):
			trains.erase(t)
			lost += 1
			if selected_train == t:
				select_train(null)
	if lost > 0:
		ui.show_message("Removed %d train%s left without track." % [lost, "" if lost == 1 else "s"])
	_redraw_world()
	mark_dirty()

func toggle_switch_near(p: Vector2) -> bool:
	var n := net.switch_near(p, TAP_PX * 1.2 / camera.zoom.x)
	if n == null:
		return false
	net.toggle_switch(n)
	track_view.queue_redraw()
	if mode == MODE_DESIGN:
		mark_dirty()
	return true

# --- Camera --------------------------------------------------------------

func screen_to_world(p: Vector2) -> Vector2:
	return camera.position + (p - get_viewport_rect().size * 0.5) / camera.zoom.x

func _set_zoom_at(z: float, screen_p: Vector2, world_p: Vector2) -> void:
	z = clampf(z, MIN_ZOOM, MAX_ZOOM)
	camera.zoom = Vector2(z, z)
	if follow_train == null:
		camera.position = world_p - (screen_p - get_viewport_rect().size * 0.5) / z

func set_follow(t: Train) -> void:
	follow_train = t
	if t != null:
		ui.show_message("The camera follows this train. Drag the ground to let go.")

func _pan(screen_delta: Vector2) -> void:
	follow_train = null
	camera.position -= screen_delta / camera.zoom.x

func fit_view() -> void:
	var r := net.bounds()
	if net.is_empty():
		camera.position = Vector2.ZERO
		camera.zoom = Vector2.ONE
		return
	r = r.grow(50.0)
	var vp := get_viewport_rect().size
	var top: float = UIRoot.TOP_STRIP_HEIGHT
	var avail := vp - Vector2(0.0, top)
	var z := clampf(minf(avail.x / r.size.x, avail.y / r.size.y), MIN_ZOOM, 1.6)
	camera.zoom = Vector2(z, z)
	camera.position = r.get_center() - Vector2(0.0, top * 0.5) / z

# --- Input ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if ui.is_over_panel(st.position):
				return
			_touches[st.index] = st.position
			if _touches.size() == 1:
				_pointer_down(st.position)
			elif _touches.size() == 2:
				_cancel_gesture()
				_start_pinch()
		else:
			if not _touches.has(st.index):
				return
			_touches.erase(st.index)
			if _gesture == "pinch" or _gesture == "blocked":
				_gesture = "blocked" if not _touches.is_empty() else ""
			else:
				_pointer_up(st.position)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if not _touches.has(sd.index):
			return
		_touches[sd.index] = sd.position
		if _gesture == "pinch":
			_update_pinch()
		elif _gesture != "blocked":
			_pointer_move(sd.position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.device == InputEvent.DEVICE_ID_EMULATION:
			return # the touch itself was already handled above
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					var f := 1.12 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12
					_set_zoom_at(camera.zoom.x * f, mb.position, screen_to_world(mb.position))
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					if ui.is_over_panel(mb.position):
						return
					_mouse_left = true
					_pointer_down(mb.position)
				elif _mouse_left:
					_mouse_left = false
					_pointer_up(mb.position)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_mouse_pan = mb.pressed
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if _mouse_pan:
			_pan(mm.relative)
		elif _mouse_left:
			_pointer_move(mm.position)

func _start_pinch() -> void:
	var ps: Array = _touches.values()
	var a: Vector2 = ps[0]
	var b: Vector2 = ps[1]
	_pinch = {"d0": maxf(a.distance_to(b), 1.0), "z0": camera.zoom.x, "w0": screen_to_world((a + b) * 0.5)}
	_gesture = "pinch"

func _update_pinch() -> void:
	var ps: Array = _touches.values()
	if ps.size() < 2:
		return
	var a: Vector2 = ps[0]
	var b: Vector2 = ps[1]
	_set_zoom_at(_pinch["z0"] * a.distance_to(b) / _pinch["d0"], (a + b) * 0.5, _pinch["w0"])

func _cancel_gesture() -> void:
	if _gesture == "stroke":
		overlay.clear()
	elif _gesture == "drag_train":
		ui.on_selection_changed(selected_train)
		mark_dirty()
	_gesture = ""
	_stroke = PackedVector2Array()

func _pointer_down(pos: Vector2) -> void:
	_down_pos = pos
	_last_pos = pos
	# First tap off a number box being typed into just commits it (see
	# game2's main.gd for why) -- nothing else happens on that tap.
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit:
		focused.release_focus()
		_gesture = "blocked"
		return
	var w := screen_to_world(pos)
	_gesture = "pending"
	if mode != MODE_DESIGN:
		return
	match tool:
		TOOL_DRAW:
			_gesture = "stroke"
			_stroke = PackedVector2Array([w])
			overlay.stroke = _stroke
			overlay.snap_start = net.snap_preview(w, SNAP_PX / camera.zoom.x)
			overlay.snap_end = Vector2.INF
			overlay.queue_redraw()
			ui.dismiss_sheets_for_drag()
		TOOL_SELECT:
			var hit := train_at(w)
			if not hit.is_empty():
				push_undo()
				select_train(hit[0])
				_drag_car = hit[1]
				_gesture = "drag_train"
				ui.dismiss_sheets_for_drag()

func _pointer_move(pos: Vector2) -> void:
	var w := screen_to_world(pos)
	match _gesture:
		"pending":
			if pos.distance_to(_down_pos) > DRAG_START_PX:
				_gesture = "pan"
				_pan(pos - _last_pos)
				_last_pos = pos
		"pan":
			_pan(pos - _last_pos)
			_last_pos = pos
		"stroke":
			if _stroke[_stroke.size() - 1].distance_to(w) >= 3.0 / camera.zoom.x:
				_stroke.append(w)
				overlay.stroke = _stroke
				overlay.snap_end = net.snap_preview(w, SNAP_PX / camera.zoom.x)
				overlay.queue_redraw()
		"drag_train":
			if selected_train != null:
				var before: Array = selected_train.s.duplicate()
				selected_train.drag_to(w, _drag_car)
				if selected_train.overlaps(trains):
					selected_train.restore_s(before)
				trains_view.queue_redraw()

func _pointer_up(pos: Vector2) -> void:
	var g := _gesture
	_gesture = ""
	match g:
		"pending":
			_tap(screen_to_world(pos))
		"stroke":
			overlay.clear()
			var stroke := _stroke
			_stroke = PackedVector2Array()
			if TrackNetwork._polyline_length(stroke) < TrackNetwork.MIN_STROKE:
				toggle_switch_near(screen_to_world(pos))
				return
			push_undo()
			if net.add_stroke(stroke, SNAP_PX / camera.zoom.x) == null:
				_undo.pop_back()
				ui.on_undo_changed(_undo.size())
				return
			_on_tracks_changed()
		"drag_train":
			if pos.distance_to(_down_pos) <= DRAG_START_PX:
				# Just a tap on the train: selection, not an edit.
				_undo.pop_back()
				ui.on_undo_changed(_undo.size())
			ui.on_selection_changed(selected_train)
			mark_dirty()

func _tap(w: Vector2) -> void:
	if mode == MODE_PLAY:
		var hit := train_at(w)
		if not hit.is_empty():
			hit[0].running = not hit[0].running
			trains_view.queue_redraw()
			return
		toggle_switch_near(w)
		return
	match tool:
		TOOL_SELECT:
			if not toggle_switch_near(w):
				select_train(null)
		TOOL_ERASE:
			var hit := train_at(w)
			if not hit.is_empty():
				remove_train(hit[0])
				return
			var seg_hit := net.nearest(w, TAP_PX / camera.zoom.x)
			if seg_hit.is_empty():
				return
			push_undo()
			net.remove_segment(seg_hit["seg"])
			_on_tracks_changed()
		TOOL_TRAIN:
			place_train_at(w)
		TOOL_DRAW:
			toggle_switch_near(w)
