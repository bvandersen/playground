extends SceneTree

## Screenshots of the demo town (run under xvfb-run, not --headless).
var main
var frame := 0
var out_dir := OS.get_environment("SHOT_DIR")

func _initialize() -> void:
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)

func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir + "/" + name + ".png")

func _look(at: Vector2, z: float) -> void:
	main.camera.position = at
	main.camera.zoom = Vector2(z, z)

func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		10: _shot("fit")
		11: _look(Vector2(460, -250), 1.6)
		14: _shot("houses")
		15: _look(Vector2(-400, 300), 1.4)
		18: _shot("industry")
		19: _look(Vector2(480, 300), 1.3)
		22: _shot("shops")
		23: _look(Vector2(-450, -300), 1.2)
		26: _shot("country")
		27:
			main.set_tool(main.TOOL_BUILD)
			_look(Vector2(0, 250), 1.8)
		30: _shot("build_ui")
		31: main.set_mode(main.MODE_PLAY)
	if frame > 31 and frame < 2000:
		for c in main.crossings:
			if c.bar > 0.95 and not main.has_meta("closed"):
				main.set_meta("closed", frame)
				_look(c.pos, 2.4)
	if main.has_meta("closed") and frame == int(main.get_meta("closed")) + 40:
		_shot("crossing")
	if frame == 60 * 25:
		_look(Vector2(380, 250), 2.2)
	if frame == 60 * 25 + 3:
		_shot("junction")
		return true
	return false
