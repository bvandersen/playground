extends SceneTree

## Headless check of the road / build editing paths.
var main
var frame := 0

func _initialize() -> void:
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)

func _process(_delta: float) -> bool:
	frame += 1
	if frame != 5:
		return frame > 6
	main.clear_all()
	main.camera.zoom = Vector2.ONE
	# Two crossing roads -> one crossroads.
	main.roads.add_road(TrackNetwork._resample(PackedVector2Array([Vector2(-300, 0), Vector2(300, 0)]), 8.0), 20.0)
	main.roads.add_road(TrackNetwork._resample(PackedVector2Array([Vector2(0, -300), Vector2(0, 300)]), 8.0), 20.0)
	# A branch starting on the side of a road -> T junction.
	main.roads.add_road(TrackNetwork._resample(PackedVector2Array([Vector2(150, 0), Vector2(150, 250)]), 8.0), 20.0)
	# Track across a road -> level crossing.
	main.net.add_stroke(TrackNetwork._resample(PackedVector2Array([Vector2(-200, -250), Vector2(-200, 250)]), 8.0), 20.0)
	main._on_tracks_changed()
	var deg := []
	for n in main.roads.nodes:
		deg.append(n.ports.size())
	deg.sort()
	print("road node degrees ", deg, " segments ", main.roads.segments.size(), " crossings ", main.crossings.size())
	var spots := [["house", Vector2(80, 50)], ["shop", Vector2(80, -50)], ["factory", Vector2(-100, -120)],
		["pond", Vector2(-100, 150)], ["tree", Vector2(250, 150)], ["flats", Vector2(80, 160)]]
	for it in spots:
		main.place_building_at(it[1], it[0])
	print("buildings placed: ", main.buildings.map(func(b): return b.kind))
	main.place_building_at(Vector2(0, 0), "house")
	print("on the road refused: ", main.buildings.size())
	for kind in ["car", "truck", "bus"]:
		main.place_vehicle_at(Vector2(-100 + main.vehicles.size() * 60, 10), root.get_node("VehicleCatalog").make(kind))
	print("vehicles: ", main.vehicles.map(func(v): return v.look["type"]))
	var st: Dictionary = JSON.parse_string(JSON.stringify(main.capture_state()))
	main.apply_state(st)
	print("after round trip: roads ", main.roads.segments.size(), " buildings ", main.buildings.size(), " vehicles ", main.vehicles.size(), " crossings ", main.crossings.size())
	main._tap(main.buildings[0].pos)
	main.set_tool(main.TOOL_ERASE)
	var n0: int = main.buildings.size()
	main._tap(main.buildings[0].pos)
	print("erase building: ", n0, " -> ", main.buildings.size())
	main._tap(Vector2(-250, 0))
	print("erase road piece: segments ", main.roads.segments.size())
	main.undo()
	print("undo: segments ", main.roads.segments.size())
	# Drawing a road over a house clears it.
	var nb: int = main.buildings.size()
	var at: Vector2 = main.buildings[0].pos
	main.roads.add_road(TrackNetwork._resample(PackedVector2Array([at + Vector2(-400, 0), at + Vector2(400, 0)]), 8.0), 20.0)
	main._on_tracks_changed()
	print("road over buildings: ", nb, " -> ", main.buildings.size())
	# Bridges: cycle the level crossing, keep it through save/load.
	main.set_tool(main.TOOL_SELECT)
	var lc = main.crossings[0]
	main._tap(lc.pos)
	print("tap crossing: ", main.crossings[0].kind, " decks ", main.decks.size())
	main._tap(main.crossings[0].pos)
	print("tap again: ", main.crossings[0].kind)
	var st2: Dictionary = JSON.parse_string(JSON.stringify(main.capture_state()))
	main.apply_state(st2)
	print("after round trip: ", main.crossings[0].kind, " bridges saved ", st2.get("bridges"))
	# Track crossing track -> diamond; flyover survives a round trip with the right line on top.
	main.net.add_stroke(TrackNetwork._resample(PackedVector2Array([Vector2(-300, -150), Vector2(-100, -150)]), 8.0), 20.0)
	main._on_tracks_changed()
	print("track crossings: ", main.track_crossings.map(func(c): return c.kind))
	var tc = main.track_crossings[0]
	main._tap(tc.pos)
	var up: Vector2 = main.track_crossings[0].upper_dir()
	var st3: Dictionary = JSON.parse_string(JSON.stringify(main.capture_state()))
	main.apply_state(st3)
	print("flyover kept: ", main.track_crossings[0].kind != "diamond", " same line on top: ", absf(main.track_crossings[0].upper_dir().dot(up)) > 0.9)
	# A mountain may go over the track.
	var nm: int = main.buildings.size()
	main.place_building_at(Vector2(-200, -50), "mountain")
	print("mountain over track placed: ", main.buildings.size() - nm, " tunnel at track: ", main.in_tunnel(Vector2(-200, -50)))
	# A figure of eight drawn in one stroke makes a diamond with itself.
	main.clear_all()
	var fig := PackedVector2Array()
	for k in range(0, 200):
		var a := 0.6 + k * TAU / 199.0
		fig.append(Vector2(sin(a) * 200.0, sin(2.0 * a) * 90.0))
	main.net.add_stroke(fig, 20.0)
	main._on_tracks_changed()
	print("figure eight crossings: ", main.track_crossings.size())
	return false
