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
const TOOL_SMOOTH := "smooth"
const TOOL_TRAIN := "train"
const TOOL_STATION := "station"

const STATE_VERSION := 1
const AUTOSAVE_DELAY := 0.8
const SNAP_PX := 26.0 # stroke ends this close (screen px) join existing track
const TAP_PX := 24.0
const DRAG_START_PX := 8.0
const MIN_ZOOM := 0.25
const MAX_ZOOM := 3.0
const UNDO_LIMIT := 40
const BRUSH_PX := 56.0 # smoothing brush radius, screen px
const BRUSH_RATE := 8.0 # how fast the brush irons track out while held, 1/s
const BRUSH_TAP_TIME := 0.25 # s held still before a press brushes instead of tapping

var mode: String = MODE_DESIGN
var tool: String = TOOL_SELECT
var net := TrackNetwork.new()
var trains: Array = []
var stations: Array = []
var selected_train: Train = null
## Camera follows this train while it's set; any manual pan/zoom lets go.
var follow_train: Train = null

var camera: Camera2D
var ground: Ground
var track_view: TrackView
var stations_view: StationsView
var people_view: PeopleView
var trains_view: TrainsView
var smoke: Smoke
var overlay: DrawOverlay
var ui: UIRoot

## Settings (user://settings.json), same meaning as in game2.
var reset_on_stop: bool = true
var sound_enabled: bool = true
var autosave_enabled: bool = false
var current_slot: String = ""

var _play_start_state: Dictionary = {}
var _autosave_countdown: float = -1.0
var _undo: Array = []

# Input state. Touches are tracked by index so two fingers pinch-zoom in
# any tool; one finger does whatever the tool does.
var _touches := {}
var _gesture := "" # "", pending, pan, stroke, smooth, drag_train, pinch, blocked
var _down_pos := Vector2.ZERO
var _last_pos := Vector2.ZERO
var _mouse_left := false
var _mouse_pan := false
var _pinch := {}
var _stroke := PackedVector2Array()
var _drag_car := -1
var _brush_pos := Vector2.ZERO
var _smoothed: Array = [] # pieces the brush has moved this stroke
var _brush_held := 0.0 # s; a short press without moving is a tap, not brushing

func _ready() -> void:
	randomize()
	_load_settings()

	ground = Ground.new()
	add_child(ground)
	track_view = TrackView.new()
	track_view.net = net
	add_child(track_view)
	stations_view = StationsView.new()
	stations_view.main = self
	add_child(stations_view)
	people_view = PeopleView.new()
	people_view.main = self
	add_child(people_view)
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

## Android: the system Back gesture/button steps back out of whatever is
## open (a sheet, then Play) before it leaves the app (project.godot sets
## quit_on_go_back=false so it reaches here). Being sent to the background
## writes any pending auto-save, since Android may kill the app from there.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if ui.close_open_sheet():
				return
			if mode == MODE_PLAY:
				set_mode(MODE_DESIGN)
				return
			_flush_autosave()
			get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			_flush_autosave()

func _process(delta: float) -> void:
	if follow_train != null:
		if not trains.has(follow_train) or follow_train.world.is_empty():
			follow_train = null
		else:
			var target: Vector2 = follow_train.world[0]["center"]
			camera.position = camera.position.lerp(target, 1.0 - exp(-4.0 * delta))
	if _gesture == "smooth":
		_brush_tick(delta)
	for st in stations:
		st.update(delta, mode == MODE_PLAY)
	if not stations.is_empty():
		people_view.queue_redraw()
	if _autosave_countdown > 0.0:
		_autosave_countdown = maxf(_autosave_countdown - delta, 0.001)
		if _autosave_countdown <= 0.001:
			_flush_autosave()

func _physics_process(delta: float) -> void:
	if mode != MODE_PLAY:
		return
	var targets := []
	for t in trains:
		targets.append(t.plan(delta, net, trains, stations))
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
	if mode == MODE_PLAY:
		for t in trains:
			if t.running:
				t.sound_horn()
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
		"stations": stations.map(func(st): return st.to_dict()),
	}

func apply_state(state: Dictionary) -> void:
	_cancel_gesture()
	net.from_dict(state.get("tracks", {}))
	stations.clear()
	for sd in state.get("stations", []):
		if sd is Dictionary:
			var st := Station.from_dict(sd)
			if st.resolve(net):
				st.populate()
				stations.append(st)
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
	stations_view.queue_redraw()
	people_view.queue_redraw()
	var clear_of := PackedVector2Array()
	for st in stations:
		clear_of.append_array(st.footprint())
	ground.rebuild(net, clear_of)
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
	sound_enabled = bool(st.get("sound", sound_enabled))
	Sfx.enabled = sound_enabled
	autosave_enabled = bool(st.get("autosave", autosave_enabled))
	current_slot = str(st.get("current_slot", current_slot))

func save_settings() -> void:
	SceneStore.save_settings({
		"reset_on_stop": reset_on_stop,
		"sound": sound_enabled,
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

	# A station on each long side: outside the oval at the bottom, inside it
	# at the top (the passing loop is outside there).
	stations.clear()
	for at in [[Vector2(-70, r), Vector2(-70, r + 40)], [Vector2(40, -r), Vector2(40, -r + 40)]]:
		var st := Station.make(rot * (at[0] as Vector2), rot.basis_xform((at[1] as Vector2) - (at[0] as Vector2)).normalized())
		if st.resolve(net):
			st.populate()
			stations.append(st)

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
	stations.clear()
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
	Sfx.play_at("couple", t.anchor)
	set_tool(TOOL_SELECT)
	select_train(t)
	mark_dirty()

func remove_train(t: Train) -> void:
	push_undo()
	trains.erase(t)
	if not t.world.is_empty():
		Sfx.play_at("erase", t.world[0]["center"])
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
	Sfx.play_at("couple", t.world[t.world.size() - 1]["center"] if not t.world.is_empty() else t.anchor)
	trains_view.queue_redraw()
	ui.on_selection_changed(t)
	mark_dirty()

func add_car(t: Train, type: String) -> void:
	push_undo()
	t.cars.append(WagonCatalog.make_car(type, t.livery))
	relay_train(t)

func remove_car(t: Train, index: int) -> void:
	if t.cars.size() <= 1:
		ui.show_message("A train needs at least one car -- use the bin instead.")
		return
	push_undo()
	t.cars.remove_at(index)
	if index < t.riders.size():
		t.riders.remove_at(index)
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

# --- Stations ------------------------------------------------------------

## Builds a station beside the track nearest `p`, its platform on the side
## of the track `p` is on.
func place_station_at(p: Vector2) -> void:
	var hit := net.nearest(p, maxf(Station.INNER + Station.WIDTH + 10.0, TAP_PX * 2.0 / camera.zoom.x))
	if hit.is_empty():
		ui.show_message("Tap next to a track to build a station there.")
		return
	var seg: TrackSegment = hit["seg"]
	var towards: Vector2 = p - hit["pos"]
	if towards.length() < 2.0:
		towards = seg.tangent_at(hit["u"]).orthogonal()
	var st := Station.make(hit["pos"], towards.normalized())
	if not st.resolve(net):
		ui.show_message("There isn't enough track there for a platform.")
		return
	if _station_blocked(st):
		ui.show_message("No room for a platform there -- try the other side of the track.")
		return
	push_undo()
	st.populate()
	stations.append(st)
	Sfx.play_at("track", st.anchor)
	_redraw_world()
	mark_dirty()

## True if `st`'s platform or house would sit on other track or another
## station.
func _station_blocked(st: Station) -> bool:
	for q in st.footprint():
		if not net.nearest(q, 24.0).is_empty():
			return true
		for o in stations:
			if o.contains(q, 6.0):
				return true
	return false

func station_at(p: Vector2) -> Station:
	for i in range(stations.size() - 1, -1, -1):
		if stations[i].contains(p, 4.0 / camera.zoom.x):
			return stations[i]
	return null

func remove_station(st: Station) -> void:
	push_undo()
	stations.erase(st)
	Sfx.play_at("erase", st.anchor)
	_redraw_world()
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
	var lost_st := 0
	for st in stations.duplicate():
		if not st.resolve(net):
			stations.erase(st)
			lost_st += 1
	if lost > 0:
		ui.show_message("Removed %d train%s left without track." % [lost, "" if lost == 1 else "s"])
	elif lost_st > 0:
		ui.show_message("Removed %d station%s left without track." % [lost_st, "" if lost_st == 1 else "s"])
	_redraw_world()
	mark_dirty()

func toggle_switch_near(p: Vector2) -> bool:
	var n := net.switch_near(p, TAP_PX * 1.2 / camera.zoom.x)
	if n == null:
		return false
	net.toggle_switch(n)
	Sfx.play_at("switch", n.position)
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
	elif _gesture == "smooth":
		_finish_brush()
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
		TOOL_SMOOTH:
			_gesture = "smooth"
			_brush_pos = w
			_smoothed = []
			_brush_held = 0.0
			push_undo()
			_show_brush()
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
		"smooth":
			_brush_pos = w
			if pos.distance_to(_down_pos) > DRAG_START_PX:
				_brush_held = BRUSH_TAP_TIME
			_show_brush()
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
			Sfx.play_at("track", stroke[stroke.size() - 1])
			_on_tracks_changed()
		"smooth":
			if _brush_held < BRUSH_TAP_TIME:
				# A tap: smooth the whole piece under it.
				overlay.clear()
				var hit := net.nearest(screen_to_world(pos), TAP_PX / camera.zoom.x)
				if not hit.is_empty() and net.smooth_segment(hit["seg"]):
					_on_tracks_changed()
				else:
					_drop_undo()
				return
			_finish_brush()
		"drag_train":
			if pos.distance_to(_down_pos) <= DRAG_START_PX:
				# Just a tap on the train: selection, not an edit.
				_undo.pop_back()
				ui.on_undo_changed(_undo.size())
			ui.on_selection_changed(selected_train)
			mark_dirty()

func _drop_undo() -> void:
	_undo.pop_back()
	ui.on_undo_changed(_undo.size())

func _show_brush() -> void:
	overlay.brush_pos = _brush_pos
	overlay.brush_radius = BRUSH_PX / camera.zoom.x
	overlay.brush_line = 2.0 / camera.zoom.x
	overlay.queue_redraw()

## The smoothing brush is an airbrush: it keeps ironing out the track
## under it for as long as it's held, a little more every frame.
func _brush_tick(delta: float) -> void:
	if _brush_held < BRUSH_TAP_TIME:
		_brush_held += delta
		return
	var amount := 1.0 - exp(-BRUSH_RATE * delta)
	var moved := net.smooth_brush(_brush_pos, BRUSH_PX / camera.zoom.x, amount)
	if moved.is_empty():
		return
	for seg in moved:
		if not _smoothed.has(seg):
			_smoothed.append(seg)
	# Keep trains and platforms sitting on the track as it moves under them.
	for t in trains:
		t.place(net)
	for st in stations:
		st.resolve(net)
	stations_view.queue_redraw()
	track_view.queue_redraw()
	trains_view.queue_redraw()

func _finish_brush() -> void:
	overlay.clear()
	if _smoothed.is_empty():
		_drop_undo()
		return
	net.finish_smoothing(_smoothed)
	_smoothed = []
	_on_tracks_changed()

func _tap(w: Vector2) -> void:
	if mode == MODE_PLAY:
		var hit := train_at(w)
		if not hit.is_empty():
			hit[0].running = not hit[0].running
			if hit[0].running:
				hit[0].sound_horn()
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
			var st := station_at(w)
			if st != null:
				remove_station(st)
				return
			var seg_hit := net.nearest(w, TAP_PX / camera.zoom.x)
			if seg_hit.is_empty():
				return
			push_undo()
			net.remove_segment(seg_hit["seg"])
			Sfx.play_at("erase", seg_hit["pos"])
			_on_tracks_changed()
		TOOL_TRAIN:
			place_train_at(w)
		TOOL_STATION:
			place_station_at(w)
		TOOL_DRAW:
			toggle_switch_near(w)
