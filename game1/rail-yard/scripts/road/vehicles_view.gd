extends Node2D
class_name VehiclesView

## Draws all road traffic as one mesh per frame, the way PeopleView draws
## the crowds: every vehicle's baked picture (VehicleCatalog.frame) is only
## moved into place, shadows first, then bodies, then brake lights and
## level-crossing barriers on top -- one draw call however busy the roads.

const SUN := Vector2(2.6, 3.4)

var main: Node
## As with TrainsView: the low view draws everything not up on a road
## bridge (and the level-crossing barriers), the high one the rest.
var high := false
var _mesh: ArrayMesh
var _extra := TriBatch.new()

func _draw() -> void:
	var shadows := PackedVector2Array()
	var shadow_cols := PackedColorArray()
	var bodies := PackedVector2Array()
	var body_cols := PackedColorArray()
	_extra.clear()
	var playing: bool = main.mode == main.MODE_PLAY
	for veh in main.vehicles:
		if not veh.is_placed() or veh.high != high:
			continue
		var parts := [[veh.pos, veh.dir, false]]
		if veh.has_trailer:
			parts.append([veh.trailer_pos, veh.trailer_dir, true]) # a semi's trailer sits over the tractor
		for part in parts:
			var e: Dictionary = VehicleCatalog.entry(veh.look["type"])
			if part[2]:
				e = e["trailer"]
			var xf := Transform2D((part[1] as Vector2).angle(), part[0])
			var sh: Array = VehicleCatalog.shadow_frame(e["length"], e["width"])
			shadows.append_array(Transform2D((part[1] as Vector2).angle(), (part[0] as Vector2) + SUN) * (sh[0] as PackedVector2Array))
			shadow_cols.append_array(sh[1])
			var fr: Array = VehicleCatalog.frame(veh.look, part[2])
			bodies.append_array(xf * (fr[0] as PackedVector2Array))
			body_cols.append_array(fr[1])
		if veh.has_trailer and veh.trailer().get("joint", false):
			# The bendy bus's concertina joint.
			var hitch: Vector2 = veh.pos - veh.dir * float(veh.trailer()["hitch"])
			var d: Vector2 = (veh.dir + veh.trailer_dir).normalized()
			_extra.draw_set_transform(hitch, d.angle())
			_extra.draw_rect(Rect2(-2.2, -7.0, 4.4, 14.0), Color(0.12, 0.12, 0.13))
			for k in range(3):
				_extra.draw_line(Vector2(-1.5 + k * 1.5, -6.5), Vector2(-1.5 + k * 1.5, 6.5), Color(0.3, 0.3, 0.32), 0.5)
			_extra.draw_set_transform(Vector2.ZERO)
		if playing and veh.braking:
			var back: Vector2 = veh.trailer_pos - veh.trailer_dir * float(veh.trailer()["length"]) * 0.5 if veh.has_trailer else veh.pos - veh.dir * veh.length() * 0.5
			var bd: Vector2 = veh.trailer_dir if veh.has_trailer else veh.dir
			var side: Vector2 = Vector2(-bd.y, bd.x) * (veh.width() * 0.5 - 2.0)
			for p in [back + side, back - side]:
				_extra.draw_circle(p - bd * 0.2, 3.4, Color(1.0, 0.1, 0.05, 0.28))
				_extra.draw_circle(p - bd * 0.2, 1.2, Color(1.0, 0.3, 0.25))
	if not high:
		for c in main.crossings:
			c.draw(_extra)
	shadows.append_array(bodies)
	shadow_cols.append_array(body_cols)
	shadows.append_array(_extra.points)
	shadow_cols.append_array(_extra.colors)
	_mesh = null
	if shadows.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = shadows
	arrays[Mesh.ARRAY_COLOR] = shadow_cols
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	draw_mesh(_mesh, null)
