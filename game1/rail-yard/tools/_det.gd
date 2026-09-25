extends SceneTree

## Seeded run of the demo in play mode; prints a digest of where every
## vehicle and car is. Run it before and after a refactor that should not
## change behaviour: the digests must match.
var main
var frame := 0
func _initialize() -> void:
	seed(12345)
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)

func _process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		main.propagate_call("set_process", [false])
		main.propagate_call("set_physics_process", [false])
		root.get_node("Sfx").enabled = false
		seed(777)
		main.load_demo()
	if frame == 3:
		main.set_mode(main.MODE_PLAY)
	if frame > 3:
		var d := 1.0 / 60.0
		main._process(d)
		main._physics_process(d)
	if frame % 1000 == 3 or frame == 3003:
		var parts := []
		for v in main.vehicles:
			parts.append("%.4f,%.4f,%.4f" % [v.pos.x, v.pos.y, v.v])
		for t in main.trains:
			for w in t.world:
				parts.append("%.4f,%.4f" % [w["center"].x, w["center"].y])
		var txt := ";".join(parts)
		print("tick ", frame - 3, " digest ", txt.md5_text(), " ", parts.slice(0, 2))
	return frame >= 3003
