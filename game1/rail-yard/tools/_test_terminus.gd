extends SceneTree

var main
var frame := 0
var dwells := 0
var was := false

func _initialize() -> void:
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)

func _process(delta: float) -> bool:
	frame += 1
	if frame == 3:
		main.clear_all()
		var line := PackedVector2Array()
		for i in range(0, 121):
			line.append(Vector2(i * 10.0, 0.0))
		main.net.add_stroke(line, 20.0)
		main._on_tracks_changed()
		main.camera.zoom = Vector2.ONE
		# Station tool: beside the track near the right-hand buffer, below it.
		main.place_station_at(Vector2(1080, 30))
		print("stations after place: ", main.stations.size(), " face=", main.stations[0].face if main.stations.size() > 0 else null)
		main.place_station_at(Vector2(1060, 30))
		print("overlapping second refused: ", main.stations.size() == 1)
		main.place_station_at(Vector2(1000, -30))
		print("opposite side ok: ", main.stations.size() == 2)
		var st2 = main.stations[1]
		print("station_at hit: ", main.station_at(st2.plat(st2.center_i, 10)) == st2)
		main.remove_station(st2)
		print("after erase: ", main.stations.size())
		var state: Dictionary = main.capture_state()
		var js := JSON.stringify(state)
		main.apply_state(JSON.parse_string(js))
		print("roundtrip stations: ", main.stations.size(), " people ", main.stations[0].people.size(), " ", JSON.stringify(state["stations"]))
		var t := Train.new()
		t.anchor = Vector2(300, 0)
		t.heading = Vector2.RIGHT
		t.speed = 90
		for ty in ["diesel", "coach", "coach"]:
			t.cars.append(root.get_node("/root/WagonCatalog").make_car(ty, t.livery))
		print("placed: ", t.place(main.net))
		main.trains.append(t)
		main.set_mode(main.MODE_PLAY)
	if frame > 3:
		var t = main.trains[0]
		var d: bool = t.dwelling_at != null
		if d and not was:
			dwells += 1
			print("dwell #", dwells, " at frame ", frame, " front x=", t.world[0]["front"].x, " dir=", t.direction, " riders=", t.rider_count())
		was = d
	return frame > 60 * 120
