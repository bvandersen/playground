extends Node2D
class_name BuildingsView

## Draws every building and piece of scenery the player has put down, as
## one mesh baked whenever that set changes: things lying on the ground
## first, then buildings, then trees over the top, each layer back to
## front so nearer roofs overlap further ones.

var main: Node
var _mesh: ArrayMesh

func _draw() -> void:
	var list: Array = main.buildings.filter(func(b): return not b.is_tunnel())
	list.sort_custom(func(a, b): return a.layer() < b.layer() or (a.layer() == b.layer() and a.pos.y < b.pos.y))
	var b := TriBatch.new()
	for bl in list:
		bl.paint(b)
	_mesh = b.to_mesh()
	if _mesh != null:
		draw_mesh(_mesh, null)
