extends Node2D
class_name PeopleView

## Draws everyone on every platform, then the station roofs and lamps over
## them (so people walking into the station house disappear under its
## roof). Trains are drawn above this, so people climbing aboard vanish
## under the car.
##
## Each person is one baked PersonArt frame; this only moves those
## triangles into place (a native Transform2D * PackedVector2Array) and
## sends every person on the layout as one mesh -- one draw call however
## big the crowd. Someone fading in or out is the exception, drawn on
## their own with a see-through modulate.

const SHADOW_OFFSET := Vector2(1.1, 1.5)
const SHADOW_COLOR := Color(0, 0, 0, 0.22)

var main: Node
var _mesh: ArrayMesh
var _shadow_fan := PackedVector2Array()
var _shadow_cols := PackedColorArray()

func _ready() -> void:
	var b := TriBatch.new()
	PersonArt.ellipse(b, Vector2.ZERO, 3.0, 3.6, SHADOW_COLOR, 12)
	_shadow_fan = b.points
	_shadow_cols = b.colors

func _draw() -> void:
	var shadows := PackedVector2Array()
	var shadow_cols := PackedColorArray()
	var bodies := PackedVector2Array()
	var body_cols := PackedColorArray()
	var faders := []
	for st in main.stations:
		if not st.valid:
			continue
		for p in st.people:
			var sz: float = p.look["size"] * PersonArt.WORLD_SCALE
			var xf := Transform2D(p.heading, Vector2(sz, sz), 0.0, p.pos)
			var f: int = p.frame_index()
			if p.alpha < 0.999:
				faders.append([p, xf, f])
				continue
			shadows.append_array(Transform2D(p.heading, Vector2(sz, sz), 0.0, p.pos + SHADOW_OFFSET * sz) * _shadow_fan)
			shadow_cols.append_array(_shadow_cols)
			var fr: Array = PersonArt.frame(p.look, f)
			bodies.append_array(xf * (fr[0] as PackedVector2Array))
			body_cols.append_array(fr[1])
	shadows.append_array(bodies)
	shadow_cols.append_array(body_cols)
	_mesh = null
	if not shadows.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = shadows
		arrays[Mesh.ARRAY_COLOR] = shadow_cols
		_mesh = ArrayMesh.new()
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		draw_mesh(_mesh, null)
	for fd in faders:
		var p = fd[0]
		draw_mesh(PersonArt.frame_mesh(p.look, fd[2]), null, fd[1], Color(1, 1, 1, p.alpha))
	for st in main.stations:
		if st.valid and st.roof_mesh != null:
			draw_mesh(st.roof_mesh, null)
