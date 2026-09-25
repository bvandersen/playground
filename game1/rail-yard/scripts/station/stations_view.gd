extends Node2D
class_name StationsView

## Draws every station's platform (benches, planters and the house's
## shadow included) under the people. Each station bakes its own mesh
## when it's laid out, so this is one draw call per station.

var main: Node

func _draw() -> void:
	for st in main.stations:
		if st.valid and st.mesh != null:
			draw_mesh(st.mesh, null)
