extends SceneTree

## Headless check of the demo town: roads, crossings, buildings, traffic.
var main
var frame := 0
var closed_seen := 0
var min_gap := INF
var danger := 0

func _initialize() -> void:
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		var junc := 0
		for n in main.roads.nodes:
			if n.ports.size() >= 3:
				junc += 1
		print("roads: ", main.roads.segments.size(), " segs, ", junc, " junctions; crossings: ", main.crossings.size())
		print("buildings: ", main.buildings.size(), " vehicles: ", main.vehicles.size(), " trains: ", main.trains.size())
		var kinds := {}
		for b in main.buildings:
			kinds[b.kind] = kinds.get(b.kind, 0) + 1
		print(kinds)
		main.set_mode(main.MODE_PLAY)
	if frame > 5:
		for c in main.crossings:
			if c.closed:
				closed_seen += 1
		# A vehicle on a crossing while a train is on it too?
		for c in main.crossings:
			var train_on := false
			for t in main.trains:
				for w in t.world:
					if (w["center"] as Vector2).distance_to(c.pos) < float(w["len"]) * 0.5 + 12.0:
						train_on = true
			if train_on:
				for v in main.vehicles:
					if v.occupies(c.pos, 6.0):
						danger += 1
		# Any two vehicles overlapping (same lane)?
		for a in main.vehicles:
			for b in main.vehicles:
				if a != b and a.dir.dot(b.dir) > 0.7:
					min_gap = minf(min_gap, a.pos.distance_to(b.pos) - (a.length() + b.length()) * 0.5)
	if frame > 5 and frame % 600 == 0:
		var sp := []
		var stopped := 0
		for v in main.vehicles:
			sp.append(int(v.v))
			if v.v < 1.0:
				stopped += 1
		why()
		print("t=%ds speeds=%s stopped=%d closed-frames=%d min-gap=%.1f danger=%d train v=%.0f/%.0f" % [frame / 60, sp, stopped, closed_seen, min_gap, danger, main.trains[0]._avg_v(), main.trains[1]._avg_v()])
	return frame > 60 * 90

func why() -> void:
	for v in main.vehicles:
		if v.v < 1.0:
			var near_c := false
			for c in main.crossings:
				if c.blocks_road() and c.pos.distance_to(v.pos) < 80.0:
					near_c = true
			print("  stopped ", v.look["type"], " at ", v.pos.round(), " behind ", v.blocked_by.look["type"] if v.blocked_by != null else "-", " crossing=", near_c)
