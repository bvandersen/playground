extends SceneTree

## Headless check of the demo town: roads, crossings, buildings, traffic.
var main
var frame := 0
var closed_seen := 0
var min_gap := INF
var danger := 0
var diamond_hits := 0
var flyover_passes := 0

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
		print("crossing kinds: ", main.crossings.map(func(c): return c.kind), " track crossings: ", main.track_crossings.map(func(c): return c.kind), " decks: ", main.decks.size())
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
		# Two trains' cars on top of each other at a diamond (bad) or a
		# flyover (fine: one is over the other)?
		for tc in main.track_crossings:
			for ta in main.trains:
				for tb in main.trains:
					if ta.get_instance_id() >= tb.get_instance_id():
						continue
					for wa in ta.world:
						for wb in tb.world:
							if (wa["center"] as Vector2).distance_to(tc.pos) < 20.0 and (wb["center"] as Vector2).distance_to(tc.pos) < 20.0:
								if tc.kind == "diamond":
									diamond_hits += 1
								else:
									flyover_passes += 1
		# A vehicle on a crossing while a train is on it too?
		for c in main.crossings:
			if c.kind != "level":
				continue
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
		print("t=%ds speeds=%s stopped=%d closed-frames=%d min-gap=%.1f danger=%d diamond-hits=%d flyover-passes=%d train v=%.0f/%.0f/%.0f" % [frame / 60, sp, stopped, closed_seen, min_gap, danger, diamond_hits, flyover_passes, main.trains[0]._avg_v(), main.trains[1]._avg_v(), main.trains[2]._avg_v()])
	return frame > 60 * 180

func why() -> void:
	for v in main.vehicles:
		if v.v < 1.0:
			var near_c := false
			for c in main.crossings:
				if c.blocks_road() and c.pos.distance_to(v.pos) < 80.0:
					near_c = true
			print("  stopped ", v.look["type"], " at ", v.pos.round(), " behind ", v.blocked_by.look["type"] if v.blocked_by != null else "-", " crossing=", near_c)
