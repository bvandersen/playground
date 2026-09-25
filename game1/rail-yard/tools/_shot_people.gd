extends SceneTree

var frame := 0

class Grid extends Node2D:
	var looks := []
	var held := []
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 480, 860), Color(0.78, 0.76, 0.7))
		for i in range(looks.size()):
			var c := Vector2(40 + (i % 6) * 80, 50 + (i / 6) * 80)
			var f := (i * 3) % (PersonArt.FRAMES + 1)
			var fr := PersonArt.frame(looks[i], f)
			var b := TriBatch.new()
			var sz: float = looks[i]["size"] * 7.0
			b.points = Transform2D(-PI * 0.5 + (i % 4) * 0.4, Vector2(sz, sz), 0.0, c) * (fr[0] as PackedVector2Array)
			b.colors = fr[1]
			var m := b.to_mesh()
			held.append(m)
			draw_mesh(m, null)

func _initialize() -> void:
	var g := Grid.new()
	seed(42)
	for i in range(60):
		g.looks.append(PersonArt.random_look())
	root.add_child(g)

func _process(delta: float) -> bool:
	frame += 1
	if frame == 5:
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/people.png")
		return true
	return false
