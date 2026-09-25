extends SceneTree

var main
var frame := 0

func _initialize() -> void:
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)

func _process(delta: float) -> bool:
	frame += 1
	if frame == 5:
		print("stations: ", main.stations.size(), " people: ", main.stations.map(func(s): return s.people.size()))
		for st in main.stations:
			print(" station track samples ", st.track.size(), " anchor ", st.anchor)
		for t in main.trains:
			print(" train seats=", t.has_seats(), " riders=", t.rider_count())
		main.set_mode(main.MODE_PLAY)
	if frame > 5 and frame % 120 == 0:
		var t = main.trains[0]
		var line := "t=%.0fs v=%.1f dwell=%s stop=%s riders=%d" % [frame / 60.0, t._avg_v(), t.dwelling_at != null, t._stop_station != null, t.rider_count()]
		for st in main.stations:
			var states := {}
			for p in st.people:
				states[p.state] = states.get(p.state, 0) + 1
			line += " | " + str(states)
		line += " | t2 v=%.1f" % main.trains[1]._avg_v()
		print(line)
	return frame > 60 * 90
