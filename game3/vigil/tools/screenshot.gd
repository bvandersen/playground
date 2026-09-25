extends SceneTree

## Saves PNG screenshots of the screens (needs a display -- e.g. xvfb-run):
##   xvfb-run -s "-screen 0 480x800x24" godot --path game3/vigil \
##       --rendering-driver opengl3 -s tools/screenshot.gd -- <out dir>
## Screens: threshold, seal, scroll (after entering two glyphs), and
## every recipe mid-rite as rite-<id>.png (each in its own style).
## `-- <out dir> <id> ...` shoots only those recipes.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if not args.is_empty() else "user://shots"
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame

	var threshold = load("res://scripts/screens/threshold.gd").new()
	root.add_child(threshold)
	await _shot(out, "threshold", 4.6)
	threshold.free()

	var seal = load("res://scripts/screens/seal.gd").new()
	root.add_child(seal)
	await _shot(out, "seal", 7.5)

	var scroll = load("res://scripts/screens/scroll.gd").new()
	root.add_child(scroll)
	await create_timer(2.0).timeout
	scroll._enter(0)
	scroll._enter(6)
	scroll._flash.clear()
	await _shot(out, "scroll", 0.2)
	seal.free()
	scroll.free()

	var registry = root.get_node("Registry")
	var ids: Array = args.slice(1) if args.size() > 1 else registry.recipes.keys()
	ids.sort()
	for id in ids:
		var rite = registry.instantiate(registry.get_recipe(id), 1)
		root.add_child(rite)
		rite.begin()
		await _shot(out, "rite-%s" % id, _moment(rite))
		rite.free()
	quit()

## Seconds into a rite when it shows the most of its look.
func _moment(rite) -> float:
	match rite.engine_id():
		"glyph_moment":
			return float(rite.params["glyph_at"]) + minf(0.4, float(rite.params["show_s"]) * 0.4)
		"breath_sigil":
			return float(rite.rhythm[0]) * 0.8
	return 2.0

func _shot(dir: String, name: String, wait_s: float) -> void:
	await create_timer(wait_s).timeout
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [dir, name])
	print("saved %s/%s.png" % [dir, name])
