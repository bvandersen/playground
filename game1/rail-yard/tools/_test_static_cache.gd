extends SceneTree

## Needs a real renderer:
##   xvfb-run -a -s "-screen 0 480x860x24" godot4 --rendering-driver opengl3 \
##     --resolution 480x860 --path . -s tools/_test_static_cache.gd
##
## The same frozen frame drawn with StaticCache on and off, across camera
## moves, zooms, a rotation, a road edit, a window resize, clearing the layout
## and loading the demo again (which
## changes the stretch transform), must match pixel for pixel. For scale,
## it also prints how many pixels a quarter-pixel camera nudge changes.
var main
var frame := 0
var shots := []
var fails := 0
const VIEWS := [
	[Vector2(0, 0), 1.0, 0.0], [Vector2(137.3, -58.6), 2.37, 0.0],
	[Vector2(-300, 200), 0.41, 0.0], [Vector2(40.5, 12.25), 5.0, 0.0],
	[Vector2(0, 0), 1.3, 0.5], [Vector2(0, 0), 1.0, 0.0], [Vector2(20, 30), 1.6, 0.0],
	[Vector2(0, 0), 0.8, 0.0], [Vector2(-60, 90), 1.2, 0.0],
]
const NUDGE := 0.25 # screen px

func _initialize() -> void:
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)

## Pixels that differ at all, in any channel.
static func _differ(a: Image, b: Image) -> int:
	var n := 0
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if maxf(maxf(absf(ca.r - cb.r), absf(ca.g - cb.g)), absf(ca.b - cb.b)) > 0.0:
				n += 1
	return n

func _process(_d: float) -> bool:
	frame += 1
	if frame == 30:
		main.set_mode(main.MODE_PLAY)
	if frame == 90:
		paused = true # freeze trains, traffic, smoke, people
	if frame < 100:
		return false
	var k := (frame - 100) % 12
	var vi := (frame - 100) / 12
	if vi >= VIEWS.size():
		print("static cache pixel test: ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
		return true
	var v: Array = VIEWS[vi]
	if k == 0:
		if vi == 5:
			# An edit: drop a road piece, which redraws the road layer.
			main.roads.segments.pop_back()
			main.road_view.queue_redraw()
		if vi == 6:
			root.size = Vector2i(420, 780)
		if vi == 7:
			main.clear_all() # rebuilds every layer, scenery chunks included
		if vi == 8:
			main.load_demo()
		main.camera.position = v[0]
		main.camera.zoom = Vector2(v[1], v[1])
		main.camera.rotation = v[2]
		main.camera.ignore_rotation = v[2] == 0.0
		main.static_cache.enabled = true
	elif k == 1: # the first frame drawn after the change: no lag allowed
		shots = [root.get_texture().get_image()]
		main.static_cache.enabled = false
	elif k == 6:
		shots.append(root.get_texture().get_image())
		main.camera.position += Vector2(NUDGE, NUDGE) / v[1]
	elif k == 9:
		var cached := _differ(shots[0], shots[1])
		var nudged := _differ(shots[1], root.get_texture().get_image())
		var ok := cached == 0
		print("view %d %s zoom %.2f rot %.1f: cache vs direct %d px, direct vs %.2f px nudge %d px -> %s" % [vi, v[0], v[1], v[2], cached, NUDGE, nudged, "ok" if ok else "FAIL"])
		if not ok:
			fails += 1
	return false
