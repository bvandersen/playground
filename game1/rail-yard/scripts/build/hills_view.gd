extends Node2D
class_name HillsView

## Draws the mountains above everything that runs through them, so trains
## and traffic vanish into a tunnel and come out the other side, plus a
## stone portal wherever a track or road goes in: a wall across the line
## at the mountain's edge with a dark arch below it. Baked into one mesh
## whenever the mountains, the track or the roads change.

const STONE := Color(0.64, 0.6, 0.53)

var main: Node
var _mesh: ArrayMesh

func _draw() -> void:
	var b := TriBatch.new()
	for m in main.buildings:
		if not m.is_tunnel():
			continue
		m.paint(b)
		var outline: PackedVector2Array = m.outline()
		for seg in main.net.segments:
			_portals(b, m, outline, seg, 15.0)
		for seg in main.roads.segments:
			_portals(b, m, outline, seg, RoadNetwork.HALF_WIDTH + 2.0)
	_mesh = b.to_mesh()
	if _mesh != null:
		draw_mesh(_mesh, null)

func _portals(b: TriBatch, m, outline: PackedVector2Array, seg: TrackSegment, hw: float) -> void:
	var edge := TrackSegment.new(outline + PackedVector2Array([outline[0]]))
	for hit in TrackNetwork.crossings(seg, edge):
		var p: Vector2 = hit[0]
		var t := seg.tangent_at(hit[1])
		var out := -t if m.inside(p + t * 6.0) else t
		_portal(b, p, out, hw)

## A portal at `p` on the mountain's edge, facing `out` (away from the
## hill), for a line `hw` px half wide.
static func _portal(b: TriBatch, p: Vector2, out: Vector2, hw: float) -> void:
	var n := out.orthogonal()
	var wall := hw + 7.0
	# The dark mouth under the arch, seen past the wall.
	var mouth := PackedVector2Array()
	for i in range(13):
		var a := PI * i / 12.0
		mouth.append(p + out * (4.0 + sin(a) * 6.0) + n * cos(a) * (hw - 3.0))
	b.draw_colored_polygon(mouth, Color(0.06, 0.05, 0.05, 0.9))
	# Wing walls running back into the hill, then the face across the line.
	for side in [-1.0, 1.0]:
		var c: Vector2 = p + n * wall * side
		b.draw_line(c, c - out * 9.0 + n * 5.0 * side, STONE.darkened(0.25), 4.0)
	var face := PackedVector2Array([p + n * wall - out * 1.0, p - n * wall - out * 1.0,
		p - n * wall + out * 4.5, p + n * wall + out * 4.5])
	b.draw_colored_polygon(PackedVector2Array([face[0] + Vector2(3.0, 3.8), face[1] + Vector2(3.0, 3.8),
		face[2] + Vector2(3.0, 3.8), face[3] + Vector2(3.0, 3.8)]), Color(0, 0, 0, 0.25))
	b.draw_colored_polygon(face, STONE)
	b.draw_line(p + n * wall + out * 4.5, p - n * wall + out * 4.5, STONE.darkened(0.3), 1.0)
	b.draw_line(p + n * wall - out * 0.6, p - n * wall - out * 0.6, STONE.lightened(0.2), 0.8)
	var k := -wall + 3.0
	while k < wall:
		b.draw_line(p + n * k - out * 1.0, p + n * k + out * 1.6, STONE.darkened(0.2), 0.5)
		b.draw_line(p + n * (k + 2.0) + out * 1.8, p + n * (k + 2.0) + out * 4.4, STONE.darkened(0.2), 0.5)
		k += 4.5
	# The keystone over the middle of the arch.
	b.draw_colored_polygon(PackedVector2Array([p + n * 1.8 + out * 4.5, p - n * 1.8 + out * 4.5,
		p - n * 1.2 - out * 0.8, p + n * 1.2 - out * 0.8]), STONE.lightened(0.12))
