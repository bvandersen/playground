extends SceneTree

var main
var frame := 0
var out_dir := OS.get_environment("SHOT_DIR")

func _initialize() -> void:
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)

func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir + "/" + name + ".png")

func _process(delta: float) -> bool:
	frame += 1
	if frame == 10:
		_shot("fit")
		main.set_mode(main.MODE_PLAY)
	var t = main.trains[0]
	if frame > 10:
		main.camera.zoom = Vector2(3, 3)
		main.camera.position = main.stations[0].plat(main.stations[0].center_i, 10.0)
	if frame == 200:
		_shot("waiting")
	if t.dwelling_at != null and main.has_meta("d") == false:
		main.set_meta("d", frame)
	if main.has_meta("d"):
		var d: int = main.get_meta("d")
		if frame == d + 40:
			_shot("alight")
		if frame == d + 200:
			_shot("board")
			return true
	return frame > 5000
