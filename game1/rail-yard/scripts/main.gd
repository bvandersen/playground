extends Node2D

## Wires the track and road networks, trains, traffic, buildings, views
## and UI together, and owns what none of them should: the Design/Play
## mode, the active design tool, the camera, input routing, undo, and
## save/load. What track *is* lives in TrackNetwork; what a train *does*
## lives in Train, a car in Vehicle -- this is plumbing.

const MODE_DESIGN := "design"
const MODE_PLAY := "play"

const TOOL_SELECT := "select"
const TOOL_DRAW := "draw"
const TOOL_ERASE := "erase"
const TOOL_SMOOTH := "smooth"
const TOOL_TRAIN := "train"
const TOOL_STATION := "station"
const TOOL_ROAD := "road"
const TOOL_BUILD := "build"

## What the Build tool's palette can put down besides BuildingCatalog's
## kinds: a station, or a random car / lorry / bus (VehicleCatalog kinds).
const BUILD_STATION := "station"
const VEHICLE_KINDS := ["car", "truck", "bus"]

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
var roads := RoadNetwork.new()
var trains: Array = []
var stations: Array = []
var vehicles: Array = []
var buildings: Array = []
var crossings: Array = [] # LevelCrossing, found afresh when track or roads change
var track_crossings: Array = [] # TrackCrossing, likewise
var decks: Array = [] # every bridge's Deck (see _find_crossings)
## Bridge kinds to keep across edits and loads: [[pos, kind, upper dir]].
var _kept_kinds: Array = []
var _passing := {} # sound bookkeeping: what's rolling over what (see _feature_sounds)
var build_kind := "house"
var selected_train: Train = null
## Camera follows this train while it's set; any manual pan/zoom lets go.
var follow_train: Train = null

var camera: Camera2D
var ground: Ground
var track_view: TrackView
var road_view: RoadView
var buildings_view: BuildingsView
var vehicles_view: VehiclesView
var bridges_view: BridgesView
var vehicles_high_view: VehiclesView
var trains_high_view: TrainsView
var hills_view: HillsView
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
var _stroke_net: TrackNetwork = null # track or roads, whichever is being drawn
var _drag_car := -1
var _brush_pos := Vector2.ZERO
var _smoothed: Array = [] # pieces the brush has moved this stroke
var _brush_held := 0.0 # s; a short press without moving is a tap, not brushing

func _ready() -> void:
	randomize()
	_load_settings()
	Train.line_of = line_of
	Sfx.muffle = in_tunnel

	ground = Ground.new()
	add_child(ground)
	track_view = TrackView.new()
	track_view.net = net
	add_child(track_view)
	road_view = RoadView.new()
	road_view.main = self
	add_child(road_view)
	buildings_view = BuildingsView.new()
	buildings_view.main = self
	add_child(buildings_view)
	stations_view = StationsView.new()
	stations_view.main = self
	add_child(stations_view)
	people_view = PeopleView.new()
	people_view.main = self
	add_child(people_view)
	vehicles_view = VehiclesView.new()
	vehicles_view.main = self
	add_child(vehicles_view)
	trains_view = TrainsView.new()
	trains_view.main = self
	add_child(trains_view)
	# Bridge decks, then whatever is up on them, then the mountains over
	# everything that goes through a tunnel.
	bridges_view = BridgesView.new()
	bridges_view.main = self
	add_child(bridges_view)
	vehicles_high_view = VehiclesView.new()
	vehicles_high_view.main = self
	vehicles_high_view.high = true
	add_child(vehicles_high_view)
	trains_high_view = TrainsView.new()
	trains_high_view.main = self
	trains_high_view.high = true
	add_child(trains_high_view)
	hills_view = HillsView.new()
	hills_view.main = self
	add_child(hills_view)
	smoke = Smoke.new()
	smoke.mask = in_tunnel
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
	# What's up on a bridge can change with any move or edit; the upper
	# views are cheap, so they simply redraw every frame.
	_update_levels()
	trains_high_view.queue_redraw()
	vehicles_high_view.queue_redraw()
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
	if mode == MODE_PLAY:
		for b in buildings:
			if BuildingCatalog.entry(b.kind).get("smoke", false):
				b.smoke_timer -= delta
				if b.smoke_timer <= 0.0:
					b.smoke_timer = randf_range(0.35, 0.6)
					smoke.puff(b.chimney(), Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)), "steam", randf_range(0.8, 1.1))
	if _autosave_countdown > 0.0:
		_autosave_countdown = maxf(_autosave_countdown - delta, 0.001)
		if _autosave_countdown <= 0.001:
			_flush_autosave()

func _physics_process(delta: float) -> void:
	var playing := mode == MODE_PLAY
	for c in crossings:
		c.sense(trains, playing)
	# Crossings close together shut together, so nobody waits on the
	# track between them.
	for a in crossings:
		if a.want:
			for b in crossings:
				if b != a and b.pos.distance_to(a.pos) < LevelCrossing.LINK_DIST:
					b.linked = true
	for c in crossings:
		c.animate(delta)
	if not crossings.is_empty() or playing:
		vehicles_view.queue_redraw()
		vehicles_high_view.queue_redraw()
	if not playing:
		return
	for veh in vehicles:
		veh.drive(delta, vehicles, crossings)
	var targets := []
	for t in trains:
		targets.append(t.plan(delta, net, trains, stations))
	for i in range(trains.size()):
		trains[i].simulate(delta, targets[i])
	for t in trains:
		t.update_world()
		t.update_visual(delta, smoke)
	_feature_sounds()
	trains_view.queue_redraw()
	trains_high_view.queue_redraw()

## The sounds of rolling over things: the clatter of a diamond crossing
## under each bogie, the hollow rumble of each car onto a steel bridge,
## and the whoosh of a train or car diving into a tunnel.
func _feature_sounds() -> void:
	# Keys (arrays, slow to hash) are only built for the few things
	# actually over a feature this tick, and the diamonds and tunnels are
	# picked out once rather than per car.
	var seen := {}
	var diamonds := track_crossings.filter(func(tc): return tc.kind == "diamond")
	var tunnels := buildings.filter(func(b): return b.is_tunnel())
	for t in trains:
		for i in range(t.world.size()):
			var w: Dictionary = t.world[i]
			for tc in diamonds:
				for b in ["pf", "pr"]:
					if (w[b] as Vector2).distance_to(tc.pos) < 7.0:
						var key := [t, i, b, tc]
						if not _passing.has(key):
							Sfx.play_at("diamond", tc.pos, 0.0, randf_range(0.92, 1.08))
						seen[key] = true
			if i < t.high.size() and t.high[i]:
				var key_b := [t, i, "bridge"]
				if not _passing.has(key_b):
					Sfx.play_at("bridge", w["center"], 0.0, randf_range(0.9, 1.1))
				seen[key_b] = true
		if not t.world.is_empty():
			var lead: int = 0 if t.direction > 0 else t.world.size() - 1
			if _inside_any(tunnels, t.world[lead]["front"] if t.direction > 0 else t.world[lead]["back"]):
				var key_t := [t, "tunnel"]
				if not _passing.has(key_t):
					Sfx.play_at("tunnel", t.world[lead]["center"])
					t.sound_horn()
				seen[key_t] = true
	for veh in vehicles:
		if _inside_any(tunnels, veh.pos + veh.dir * veh.length() * 0.5):
			var key_v := [veh, "tunnel"]
			if not _passing.has(key_v):
				Sfx.play_at("tunnel", veh.pos, -6.0, randf_range(1.2, 1.4))
			seen[key_v] = true
	_passing = seen

static func _inside_any(tunnels: Array, p: Vector2) -> bool:
	for b in tunnels:
		if b.inside(p):
			return true
	return false

## True if `p` is inside a mountain (so in a tunnel, if it's on a line).
func in_tunnel(p: Vector2) -> bool:
	for b in buildings:
		if b.is_tunnel() and b.inside(p):
			return true
	return false

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
		"roads": roads.to_dict(),
		"vehicles": vehicles.map(func(v): return v.to_dict()),
		"buildings": buildings.map(func(b): return b.to_dict()),
		"bridges": _bridge_list(),
	}

## Every crossing that isn't the plain default, for saving.
func _bridge_list() -> Array:
	var out := []
	for c in crossings + track_crossings:
		if c.kind != c.KINDS[0]:
			var d := {"x": snappedf(c.pos.x, 0.01), "y": snappedf(c.pos.y, 0.01), "kind": c.kind}
			if c is TrackCrossing:
				var u: Vector2 = c.upper_dir()
				d["ux"] = snappedf(u.x, 0.0001)
				d["uy"] = snappedf(u.y, 0.0001)
			out.append(d)
	return out

func apply_state(state: Dictionary) -> void:
	_cancel_gesture()
	net.from_dict(state.get("tracks", {}))
	roads.from_dict(state.get("roads", {}))
	buildings.clear()
	for bd in state.get("buildings", []):
		if bd is Dictionary:
			var b := Building.from_dict(bd)
			if b != null:
				buildings.append(b)
	vehicles.clear()
	for vd in state.get("vehicles", []):
		if vd is Dictionary:
			var veh := Vehicle.from_dict(vd)
			if veh != null and veh.place(roads):
				vehicles.append(veh)
	stations.clear()
	for sd in state.get("stations", []):
		if sd is Dictionary:
			var st := Station.from_dict(sd)
			if st.resolve(net):
				st.populate()
				stations.append(st)
	_kept_kinds = []
	crossings.clear()
	track_crossings.clear()
	for bd in state.get("bridges", []):
		if bd is Dictionary:
			_kept_kinds.append([Vector2(float(bd.get("x", 0.0)), float(bd.get("y", 0.0))), str(bd.get("kind", "")),
				Vector2(float(bd.get("ux", 0.0)), float(bd.get("uy", 0.0)))])
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
	_find_crossings()
	track_view.queue_redraw()
	road_view.queue_redraw()
	buildings_view.queue_redraw()
	vehicles_view.queue_redraw()
	vehicles_high_view.queue_redraw()
	trains_high_view.queue_redraw()
	stations_view.queue_redraw()
	people_view.queue_redraw()
	var clear_of := PackedVector2Array()
	for st in stations:
		clear_of.append_array(st.footprint())
	for seg in roads.segments:
		for i in range(0, seg.points.size(), 2):
			clear_of.append(seg.points[i])
	for b in buildings:
		clear_of.append_array(b.footprint(20.0))
	ground.rebuild(net, clear_of)
	trains_view.queue_redraw()

## Every place a road crosses the track, or track crosses track. Each
## keeps the kind (level / bridge) it had before, matched by position.
func _find_crossings() -> void:
	for c in crossings + track_crossings:
		if c.kind != c.KINDS[0]:
			_kept_kinds.append([c.pos, c.kind, c.upper_dir() if c is TrackCrossing else Vector2.ZERO])
	crossings.clear()
	track_crossings.clear()
	for rs in roads.segments:
		for ts in net.segments:
			for hit in TrackNetwork.crossings(rs, ts):
				var c := LevelCrossing.new()
				c.pos = hit[0]
				c.road_dir = rs.tangent_at(hit[1])
				c.track_dir = ts.tangent_at(hit[2])
				c.track_seg = ts
				c.track_u = hit[2]
				c.road_seg = rs
				c.road_u = hit[1]
				crossings.append(c)
	var segs: Array = net.segments
	for i in range(segs.size()):
		for j in range(i, segs.size()):
			var hits: Array = TrackNetwork.self_crossings(segs[i]) if i == j else TrackNetwork.crossings(segs[i], segs[j])
			for hit in hits:
				if net.node_near(hit[0], 30.0) != null:
					continue # branches meeting at a switch, not crossing
				var tc := TrackCrossing.new()
				tc.pos = hit[0]
				tc.a_seg = segs[i]
				tc.a_u = hit[1]
				tc.a_dir = segs[i].tangent_at(hit[1])
				tc.b_seg = segs[j]
				tc.b_u = hit[2]
				tc.b_dir = segs[j].tangent_at(hit[2])
				track_crossings.append(tc)
	for k in _kept_kinds:
		var best = null
		var best_d := 24.0
		for c in crossings + track_crossings:
			var d: float = c.pos.distance_to(k[0])
			if d < best_d:
				best_d = d
				best = c
		if best == null:
			continue
		if best is TrackCrossing and k[1] != "diamond" and (k[2] as Vector2) != Vector2.ZERO:
			best.set_upper(k[2])
		else:
			best.set_kind(k[1])
	_kept_kinds = []
	_refresh_decks()

func _refresh_decks() -> void:
	decks.clear()
	for c in crossings + track_crossings:
		if c.deck != null:
			decks.append(c.deck)
	_update_levels()
	bridges_view.queue_redraw()
	hills_view.queue_redraw()

## Which line (and so which level) something at `p` heading `dir` is on
## near a bridge: +id upper, -id lower, 0 nowhere near one (Deck.line_of).
func line_of(p: Vector2, dir: Vector2) -> int:
	for d in decks:
		var l: int = d.line_of(p, dir)
		if l != 0:
			return l
	return 0

## Marks every train car and vehicle that's up on a bridge deck, so the
## views draw it above what passes underneath.
func _update_levels() -> void:
	for t in trains:
		var high := []
		for w in t.world:
			var up := false
			for d in decks:
				if d.rail and d.carries(w["center"], w["dir"], w["len"]):
					up = true
					break
			high.append(up)
		t.high = high
	for veh in vehicles:
		var up := false
		for d in decks:
			if not d.rail and d.carries(veh.pos, veh.dir, veh.length() + (40.0 if veh.has_trailer else 0.0)):
				up = true
				break
		if veh.high != up and mode == MODE_PLAY and veh.is_placed():
			Sfx.play_at("joint", veh.pos, 0.0, randf_range(0.9, 1.1))
		veh.high = up

## Taps with the Select tool on a crossing cycle what kind it is.
func cycle_crossing_near(p: Vector2) -> bool:
	var best = null
	var best_d := maxf(18.0, TAP_PX * 0.9 / camera.zoom.x)
	for c in crossings + track_crossings:
		var d: float = c.pos.distance_to(p)
		if d < best_d:
			best_d = d
			best = c
	if best == null:
		return false
	push_undo()
	best.set_kind(best.next_kind())
	_refresh_decks()
	road_view.queue_redraw()
	track_view.queue_redraw()
	Sfx.play_at("construct", best.pos)
	var names := {"level": "Level crossing", "road_bridge": "Road bridge over the railway",
		"rail_bridge": "Railway bridge over the road", "diamond": "Diamond crossing: trains take turns",
		"a_over": "Flyover: one line on a bridge", "b_over": "Flyover: the other line on top"}
	ui.show_message(names.get(best.kind, best.kind) + ". Tap again to change it.", 2.5)
	mark_dirty()
	return true

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
## train -- and a little town round it: roads crossing the line, houses,
## flats, shops, a supermarket, a factory and warehouses, a farm, woods
## and a pond, and traffic. Built through the same add_stroke / add_road
## a finger uses, so it doubles as a check that drawn joins come out
## smooth.
func load_demo() -> void:
	if mode == MODE_PLAY:
		set_mode(MODE_DESIGN)
	net.clear()
	roads.clear()
	buildings.clear()
	vehicles.clear()
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
	# A cross-country line straight over the top of it all (in the world's
	# own frame): over the oval on a flyover at one side, across it on a
	# diamond at the other, over the high street on a railway bridge and
	# under the back road.
	net.add_stroke(_smooth_path([Vector2(-500, -205), Vector2(560, -205)]), 20.0)
	crossings.clear()
	track_crossings.clear()
	_kept_kinds = [
		[Vector2(150, -205), "a_over", Vector2.RIGHT], [Vector2(-150, -205), "diamond", Vector2.ZERO],
		[Vector2(380, -205), "rail_bridge", Vector2.ZERO], [Vector2(-420, -205), "road_bridge", Vector2.ZERO],
	]

	# A station on each long side: outside the oval at the bottom, inside it
	# at the top (the passing loop is outside there).
	stations.clear()
	for at in [[Vector2(-70, r), Vector2(-70, r + 40)], [Vector2(40, -r), Vector2(40, -r + 40)]]:
		var st := Station.make(rot * (at[0] as Vector2), rot.basis_xform((at[1] as Vector2) - (at[0] as Vector2)).normalized())
		if st.resolve(net):
			st.populate()
			stations.append(st)

	_load_demo_town()

	trains.clear()
	selected_train = null
	var specs := [
		[Vector2(-40, -r), Vector2.LEFT, ["steam", "tender", "coach", "coach", "coach"], Color(0.12, 0.36, 0.2), 105.0],
		[Vector2(120, r), Vector2.RIGHT, ["diesel", "boxcar", "tanker", "hopper", "logs", "container", "caboose"], Color(0.8, 0.2, 0.17), 80.0],
		# The shuttle on the cross-country line (world (-230, -205), heading east).
		[Vector2(-205, 230), Vector2.UP, ["diesel", "container", "tanker", "container"], Color(0.16, 0.34, 0.62), 70.0],
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

func _load_demo_town() -> void:
	# Main road across the bottom of the oval (three level crossings), a
	# high street down the east side, a cul-de-sac off it, and a back road
	# round the west and north joining the two.
	roads.add_road(_smooth_path([Vector2(-660, 250), Vector2(620, 250)]), 20.0)
	roads.add_road(_smooth_path([Vector2(380, -580), Vector2(380, 580)]), 20.0)
	roads.add_road(_smooth_path([Vector2(380, -250), Vector2(640, -250)]), 20.0)
	roads.add_road(_smooth_path([Vector2(-420, 250), Vector2(-420, -330), Vector2(-400, -420), Vector2(-330, -475),
		Vector2(-240, -490), Vector2(380, -490)]), 20.0)
	var put := [
		# Town: flats and shops round the crossroads, houses up the high street
		# and round the cul-de-sac, the supermarket on the main road.
		["shop", Vector2(300, 290)], ["shop", Vector2(460, 290)], ["shop", Vector2(460, 210)],
		["flats", Vector2(450, 120)], ["flats", Vector2(450, 40)], ["house", Vector2(430, -40)],
		["house", Vector2(430, -100)], ["house", Vector2(430, -160)], ["house", Vector2(430, -320)],
		["house", Vector2(430, -380)], ["house", Vector2(480, -300)], ["house", Vector2(545, -300)],
		["house", Vector2(610, -300)], ["house", Vector2(480, -200)], ["house", Vector2(545, -200)],
		["house", Vector2(330, -120)], ["house", Vector2(330, -40)], ["house", Vector2(330, 40)],
		["house", Vector2(330, 120)], ["house", Vector2(330, 360)], ["house", Vector2(330, 440)],
		["market", Vector2(540, 350)], ["house", Vector2(430, 440)], ["house", Vector2(430, 510)],
		# Industry by the goods spur.
		["factory", Vector2(-455, 350)], ["warehouse", Vector2(-590, 340)], ["warehouse", Vector2(-300, 190)],
		# Houses along the back road.
		["house", Vector2(-470, -60)], ["house", Vector2(-470, 10)], ["house", Vector2(-470, 80)],
		["house", Vector2(-470, 150)], ["house", Vector2(-370, -140)], ["house", Vector2(-370, -60)],
		["shop", Vector2(-470, -140)],
		# Country: a farm, woods, a pond, trees and flowers.
		["farm", Vector2(-580, -270)], ["forest", Vector2(-20, -610)], ["forest", Vector2(560, -560)],
		["pond", Vector2(-290, -300)], ["pond", Vector2(-40, 150)], ["flowers", Vector2(-600, 180)], ["mountain", Vector2(0, -330)],
		["flowers", Vector2(-600, -60)], ["tree", Vector2(250, -300)], ["tree", Vector2(270, -380)],
		["tree", Vector2(60, -150)], ["tree", Vector2(-560, 60)], ["tree", Vector2(240, 420)],
		["tree", Vector2(-80, 330)], ["tree", Vector2(-260, -410)], ["forest", Vector2(-640, 520)],
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for it in put:
		var b := Building.make(it[0], it[1])
		b.seed = rng.randi() % 100000
		var colors: Array = BuildingCatalog.entry(it[0])["colors"]
		b.color = colors[rng.randi() % colors.size()]
		if BuildingCatalog.entry(it[0]).get("faces_road", false):
			b.face_road(roads, it[1], 140.0)
		if not _building_blocked(b, null):
			buildings.append(b)
	var traffic := [
		["sedan", Vector2(-560, 250), Vector2.RIGHT], ["city_bus", Vector2(520, 250), Vector2.LEFT],
		["semi", Vector2(-300, 250), Vector2.LEFT], ["taxi", Vector2(60, 250), Vector2.RIGHT],
		["box_truck", Vector2(380, -120), Vector2.DOWN], ["hatch", Vector2(380, 420), Vector2.UP],
		["school_bus", Vector2(380, -400), Vector2.DOWN], ["police", Vector2(520, -250), Vector2.LEFT],
		["icecream", Vector2(-420, -150), Vector2.UP], ["mixer", Vector2(-420, 100), Vector2.DOWN],
		["double_decker", Vector2(0, -490), Vector2.RIGHT], ["sports", Vector2(200, -490), Vector2.LEFT],
		["pickup", Vector2(100, 250), Vector2.LEFT], ["tanker_truck", Vector2(380, 520), Vector2.UP],
		["suv", Vector2(380, 60), Vector2.UP], ["bendy_bus", Vector2(-120, -490), Vector2.LEFT],
		["van", Vector2(600, 250), Vector2.LEFT], ["mini", Vector2(-520, 250), Vector2.LEFT],
	]
	for it in traffic:
		var veh := Vehicle.new()
		veh.look = VehicleCatalog.make_type(it[0])
		veh.anchor = it[1]
		veh.heading = it[2]
		if veh.place(roads):
			vehicles.append(veh)

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
	roads.clear()
	trains.clear()
	stations.clear()
	vehicles.clear()
	crossings.clear()
	track_crossings.clear()
	buildings.clear()
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

# --- Building, traffic ----------------------------------------------------

## A tap with the Build tool puts down whatever the palette has picked.
func build_at(p: Vector2) -> void:
	if build_kind == BUILD_STATION:
		place_station_at(p)
	elif VEHICLE_KINDS.has(build_kind):
		place_vehicle_at(p, VehicleCatalog.make(build_kind))
	else:
		place_building_at(p, build_kind)

func place_building_at(p: Vector2, kind: String) -> void:
	var b := Building.make(kind, p)
	var e := BuildingCatalog.entry(kind)
	if e.get("faces_road", false):
		var sz: Vector2 = e["size"]
		b.face_road(roads, p, maxf(sz.y + RoadNetwork.HALF_WIDTH + 20.0, TAP_PX * 2.0 / camera.zoom.x))
	if _building_blocked(b, null):
		ui.show_message("No room for that there.")
		return
	push_undo()
	buildings.append(b)
	Sfx.play_at("track", b.pos)
	_redraw_world()
	mark_dirty()

## True if `b` would sit on track, a road, a station or another building
## (`me` is ignored). Scenery may overlap other scenery.
func _building_blocked(b: Building, me) -> bool:
	if b.is_tunnel():
		return _mountain_blocked(b, me)
	var ground_only := b.layer() != 1
	for q in b.footprint():
		if not net.nearest(q, 17.0).is_empty():
			return true
		if not roads.nearest(q, RoadNetwork.HALF_WIDTH + 2.0).is_empty():
			return true
		for st in stations:
			if st.contains(q, 2.0):
				return true
		for o in buildings:
			if o == me or o == b:
				continue
			if o.is_tunnel():
				# Only trees may grow on a mountain.
				if b.layer() != 2 and o.inside(q):
					return true
				continue
			if ground_only and o.layer() != 1:
				continue
			if o.contains(q, -1.0):
				return true
	# Nothing of the other one poking into this one either.
	for o in buildings:
		if o == me or o == b or o.is_tunnel() or (ground_only and o.layer() != 1):
			continue
		for q in o.footprint():
			if b.contains(q, -1.0):
				return true
	return false

## A mountain goes over track and roads (they tunnel through it) and
## trees, but not over stations, buildings, fields or ponds.
func _mountain_blocked(b: Building, me) -> bool:
	for q in b.footprint(16.0):
		if not b.inside(q):
			continue
		for st in stations:
			if st.contains(q, 2.0):
				return true
		for o in buildings:
			if o != me and o != b and not o.is_tunnel() and o.layer() != 2 and o.contains(q):
				return true
	for o in buildings:
		if o != me and o != b and not o.is_tunnel() and o.layer() != 2:
			for q in o.footprint():
				if b.inside(q):
					return true
	return false

func building_at(p: Vector2) -> Building:
	var best: Building = null
	for b in buildings:
		if b.inside(p) and (best == null or b.layer() >= best.layer()):
			best = b
	return best

func remove_building(b: Building) -> void:
	push_undo()
	buildings.erase(b)
	Sfx.play_at("erase", b.pos)
	_redraw_world()
	mark_dirty()

## Puts vehicle `look` on the road nearest `p`, in the lane on the side
## of the road `p` is on.
func place_vehicle_at(p: Vector2, look: Dictionary) -> void:
	var hit := roads.nearest(p, maxf(RoadNetwork.HALF_WIDTH + 8.0, TAP_PX * 2.0 / camera.zoom.x))
	if hit.is_empty():
		ui.show_message("Tap on a road to put a vehicle there." if not roads.is_empty() else "Draw a road first, then put cars on it.")
		return
	var seg: TrackSegment = hit["seg"]
	var t := seg.tangent_at(hit["u"])
	var right := Vector2(-t.y, t.x)
	var veh := Vehicle.new()
	veh.look = look
	veh.anchor = hit["pos"]
	veh.heading = t if right.dot(p - (hit["pos"] as Vector2)) >= 0.0 else -t
	if not veh.place(roads):
		return
	for o in vehicles:
		if o.pos.distance_to(veh.pos) < (o.length() + veh.length()) * 0.5 + 3.0 and o.dir.dot(veh.dir) > 0.0:
			ui.show_message("Another vehicle is in the way there.")
			return
	push_undo()
	vehicles.append(veh)
	Sfx.play_at("beep", veh.pos)
	vehicles_view.queue_redraw()
	mark_dirty()

func vehicle_at(p: Vector2) -> Vehicle:
	for i in range(vehicles.size() - 1, -1, -1):
		if vehicles[i].occupies(p, 4.0 / camera.zoom.x):
			return vehicles[i]
	return null

func remove_vehicle(veh: Vehicle) -> void:
	push_undo()
	vehicles.erase(veh)
	Sfx.play_at("erase", veh.pos)
	vehicles_view.queue_redraw()
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
	var lost_v := 0
	for veh in vehicles.duplicate():
		if not veh.place(roads):
			vehicles.erase(veh)
			lost_v += 1
	var lost_b := 0
	for b in buildings.duplicate():
		if _building_blocked(b, b):
			buildings.erase(b)
			lost_b += 1
	if lost > 0:
		ui.show_message("Removed %d train%s left without track." % [lost, "" if lost == 1 else "s"])
	elif lost_st > 0:
		ui.show_message("Removed %d station%s left without track." % [lost_st, "" if lost_st == 1 else "s"])
	elif lost_b > 0:
		ui.show_message("Cleared %d building%s out of the way." % [lost_b, "" if lost_b == 1 else "s"])
	elif lost_v > 0:
		ui.show_message("Removed %d vehicle%s left without a road." % [lost_v, "" if lost_v == 1 else "s"])
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
		r = roads.bounds()
	elif not roads.is_empty():
		r = r.merge(roads.bounds())
	if net.is_empty() and roads.is_empty():
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
		TOOL_DRAW, TOOL_ROAD:
			_gesture = "stroke"
			_stroke_net = roads if tool == TOOL_ROAD else net
			_stroke = PackedVector2Array([w])
			overlay.road = tool == TOOL_ROAD
			overlay.stroke = _stroke
			overlay.snap_start = _stroke_net.snap_preview(w, SNAP_PX / camera.zoom.x)
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
				overlay.snap_end = _stroke_net.snap_preview(w, SNAP_PX / camera.zoom.x)
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
				if _stroke_net == net:
					toggle_switch_near(screen_to_world(pos))
				return
			push_undo()
			var laid: TrackSegment
			if _stroke_net == roads:
				laid = roads.add_road(stroke, SNAP_PX / camera.zoom.x)
			else:
				laid = net.add_stroke(stroke, SNAP_PX / camera.zoom.x)
			if laid == null:
				_undo.pop_back()
				ui.on_undo_changed(_undo.size())
				return
			Sfx.play_at("track", stroke[stroke.size() - 1])
			_on_tracks_changed()
		"smooth":
			if _brush_held < BRUSH_TAP_TIME:
				# A tap: smooth the whole piece under it.
				overlay.clear()
				var at := screen_to_world(pos)
				var hit := net.nearest(at, TAP_PX / camera.zoom.x)
				var on := net
				var road_hit := roads.nearest(at, TAP_PX / camera.zoom.x)
				if not road_hit.is_empty() and (hit.is_empty() or road_hit["dist"] < hit["dist"]):
					hit = road_hit
					on = roads
				if not hit.is_empty() and on.smooth_segment(hit["seg"]):
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
	var moved_roads := roads.smooth_brush(_brush_pos, BRUSH_PX / camera.zoom.x, amount)
	if moved.is_empty() and moved_roads.is_empty():
		return
	for seg in moved + moved_roads:
		if not _smoothed.has(seg):
			_smoothed.append(seg)
	if not moved_roads.is_empty():
		for veh in vehicles:
			veh.place(roads)
		road_view.queue_redraw()
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
	roads.finish_smoothing(_smoothed)
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
			if not cycle_crossing_near(w) and not toggle_switch_near(w):
				select_train(null)
		TOOL_ERASE:
			var hit := train_at(w)
			if not hit.is_empty():
				remove_train(hit[0])
				return
			var veh := vehicle_at(w)
			if veh != null:
				remove_vehicle(veh)
				return
			var st := station_at(w)
			if st != null:
				remove_station(st)
				return
			var seg_hit := net.nearest(w, TAP_PX / camera.zoom.x)
			var road_hit := roads.nearest(w, maxf(TAP_PX / camera.zoom.x, RoadNetwork.HALF_WIDTH))
			var b := building_at(w)
			if b != null and seg_hit.is_empty() and road_hit.is_empty():
				remove_building(b)
				return
			var on := net
			if not road_hit.is_empty() and (seg_hit.is_empty() or road_hit["dist"] < seg_hit["dist"]):
				seg_hit = road_hit
				on = roads
			if seg_hit.is_empty():
				return
			push_undo()
			on.remove_segment(seg_hit["seg"])
			Sfx.play_at("erase", seg_hit["pos"])
			_on_tracks_changed()
		TOOL_TRAIN:
			place_train_at(w)
		TOOL_STATION:
			place_station_at(w)
		TOOL_BUILD:
			build_at(w)
		TOOL_DRAW:
			toggle_switch_near(w)
