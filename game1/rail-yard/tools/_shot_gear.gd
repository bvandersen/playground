extends SceneTree

## Headless check of the passenger extras: a grid of people with every
## dog breed, bikes and wheelchairs, in walking and standing frames, plus
## how often random_look actually hands them out.

var frame := 0

class Grid extends Node2D:
	var looks := []
	var held := []
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 960, 900), Color(0.78, 0.76, 0.7))
		for i in range(looks.size()):
			var c := Vector2(70 + (i % 6) * 150, 70 + (i / 6) * 150)
			var f := (i * 3) % (PersonArt.FRAMES + 1)
			var fr := PersonArt.frame(looks[i], f)
			var b := TriBatch.new()
			var sz: float = looks[i]["size"] * 5.0
			b.points = Transform2D(0.0, Vector2(sz, sz), 0.0, c) * (fr[0] as PackedVector2Array)
			b.colors = fr[1]
			var m := b.to_mesh()
			held.append(m)
			draw_mesh(m, null)

func _initialize() -> void:
	seed(7)
	var n := 200000
	var counts := {"wheelchair": 0, "bike": 0, "dog": 0}
	var breeds := {}
	for i in range(n):
		var l := PersonArt.random_look()
		for k in ["wheelchair", "bike"]:
			if l[k]:
				counts[k] += 1
		if not l["dog"].is_empty():
			counts["dog"] += 1
			breeds[l["dog"]["breed"]] = breeds.get(l["dog"]["breed"], 0) + 1
	for k in counts:
		print("%s: %.2f%%" % [k, 100.0 * counts[k] / n])
	print(breeds)
	var g := Grid.new()
	for b in PersonArt.DOG_BREEDS:
		var l := PersonArt.random_look()
		l["dog"] = PersonArt.random_dog()
		if b["breed"] != "mixed":
			l["dog"] = b.duplicate()
			l["dog"]["coat"] = b["coat"][0]
			l["dog"]["lead"] = PersonArt.LEADS[0]
		g.looks.append(l)
	for i in range(13):
		var l := PersonArt.random_look()
		l["bike"] = i < 6
		l["wheelchair"] = i >= 6
		if i == 12:
			l["dog"] = PersonArt.random_dog()
		g.looks.append(l)
	root.add_child(g)

func _process(delta: float) -> bool:
	frame += 1
	if frame == 5:
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/gear.png")
		return true
	return false
