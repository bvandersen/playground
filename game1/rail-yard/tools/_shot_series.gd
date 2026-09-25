extends SceneTree

## A series of Play-mode screenshots of one spot (run under xvfb-run):
## SHOT_AT="x,y,zoom", SHOT_NAME, one shot every SHOT_EVERY frames.
var main
var frame := 0
var out_dir := OS.get_environment("SHOT_DIR")
var at := OS.get_environment("SHOT_AT").split(",")
var shot_name := OS.get_environment("SHOT_NAME")
var every := int(OS.get_environment("SHOT_EVERY")) if OS.get_environment("SHOT_EVERY") != "" else 90
var count := int(OS.get_environment("SHOT_COUNT")) if OS.get_environment("SHOT_COUNT") != "" else 12

func _initialize() -> void:
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		main.set_mode(main.MODE_PLAY)
	main.camera.position = Vector2(float(at[0]), float(at[1]))
	main.camera.zoom = Vector2(float(at[2]), float(at[2]))
	if frame > 5 and frame % every == 0:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("%s/%s_%02d.png" % [out_dir, shot_name, frame / every])
	return frame >= every * count
