extends SceneTree

## Headless: how many triangles each view's baked mesh holds (demo layout).
var main
var frame := 0

func _initialize() -> void:
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)

static func tris(m) -> int:
	if m == null:
		return 0
	var n := 0
	for s in m.get_surface_count():
		n += (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector2Array).size() / 3
	return n

func _process(_d: float) -> bool:
	frame += 1
	if frame < 5:
		return false
	for v in ["track_view", "road_view", "buildings_view", "bridges_view", "hills_view", "people_view", "vehicles_view"]:
		print("%-16s %7d" % [v, tris(main.get(v)._mesh)])
	var st := 0
	for s in main.stations:
		st += tris(s.mesh) + tris(s.roof_mesh)
	print("%-16s %7d" % ["stations", st])
	var g := 0
	for layer in main.ground._layers:
		for c in layer.get_children():
			g += tris(c.mesh)
	print("%-16s %7d (all chunks, culled to screen)" % ["ground", g])
	var kinds := {}
	for b in main.buildings:
		var tb := TriBatch.new()
		b.paint(tb)
		kinds[b.kind] = kinds.get(b.kind, 0) + tb.points.size() / 3
	print(kinds)
	return true
