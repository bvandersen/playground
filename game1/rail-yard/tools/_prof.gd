extends SceneTree

## Headless timing of the play-mode demo: script ms per physics tick,
## overall and per part (the x.* parts re-run each step, so they perturb
## the run slightly -- they are for comparing, not exact).
var main
var frame := 0
var acc := {}
var views := ["ground","track_view","road_view","buildings_view","stations_view","people_view","vehicles_view","trains_view","bridges_view","vehicles_high_view","trains_high_view","hills_view","smoke"]
var phase := 0
var t_last := 0
var frame_us := []

func _initialize() -> void:
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)

func _t(key: String, f: Callable) -> void:
	var t0 := Time.get_ticks_usec()
	f.call()
	acc[key] = acc.get(key, 0) + Time.get_ticks_usec() - t0

func _process(_delta: float) -> bool:
	frame += 1
	var now := Time.get_ticks_usec()
	if frame == 10:
		main.set_mode(main.MODE_PLAY)
		main.set_physics_process(false)
		main.set_process(false)
	if frame > 10:
		var d := 1.0 / 60.0
		_t("process", func(): main._process(d))
		_t("physics", func(): main._physics_process(d))
		_t("x.crossings.sense", func():
			for c in main.crossings: c.sense(main.trains, true))
		_t("x.veh.drive", func():
			for v in main.vehicles: v.drive(d, main.vehicles, main.crossings))
		var targets := []
		_t("x.train.plan", func():
			for t in main.trains: targets.append(t.plan(d, main.net, main.trains, main.stations)))
		_t("x.train.sim", func():
			for i in range(main.trains.size()): main.trains[i].simulate(d, targets[i]))
		_t("x.train.world", func():
			for t in main.trains: t.update_world())
		_t("x.train.visual", func():
			for t in main.trains: t.update_visual(d, main.smoke))
		_t("x.feature_sounds", func(): main._feature_sounds())
	if frame > 70 and frame <= 370:
		frame_us.append(now - t_last)
	t_last = now
	if frame == 370:
		var n := 300.0
		var ks := acc.keys()
		ks.sort()
		for k in ks:
			print("%-12s %7.3f ms/frame" % [k, acc[k] / n / 1000.0])
		var tot := 0
		for f in frame_us: tot += f
		print("frame wall  %7.3f ms" % [tot / n / 1000.0])
		print("trains=%d cars=%d vehicles=%d people=%d buildings=%d" % [main.trains.size(), main.trains.reduce(func(a, t): return a + t.cars.size(), 0), main.vehicles.size(), main.stations.reduce(func(a, s): return a + s.people.size() if "people" in s else a, 0), main.buildings.size()])
		return true
	return false
