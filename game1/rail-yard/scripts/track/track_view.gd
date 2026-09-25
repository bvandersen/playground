extends Node2D
class_name TrackView

## Draws a TrackNetwork, layer by layer across *all* pieces (ballast, then
## sleepers, then rails) so crossings and junctions overlap the way real
## track does. Dead ends get a buffer stop; switches show which way
## they're set (green = the way a train will go, red = the other ways).

const GAUGE := 10.0
const SLEEPER_SPACING := 8.5
const BALLAST := Color(0.5, 0.46, 0.4)
const BALLAST_EDGE := Color(0.36, 0.33, 0.28)
const SLEEPER := Color(0.33, 0.24, 0.17)
const RAIL_BASE := Color(0.22, 0.22, 0.24)
const RAIL_TOP := Color(0.78, 0.8, 0.84)

var net: TrackNetwork

## The whole layout is baked into one mesh (see TriBatch) each time it
## changes, so drawing it every frame is a single draw call.
var _b := TriBatch.new()
var _mesh: ArrayMesh

func _draw() -> void:
	if net == null:
		return
	_b.clear()
	for seg in net.segments:
		_b.draw_polyline(seg.points, BALLAST_EDGE, 30.0)
		_round_ends(seg, 15.0, BALLAST_EDGE)
	for seg in net.segments:
		_b.draw_polyline(seg.points, BALLAST, 26.0)
		_round_ends(seg, 13.0, BALLAST)
	for seg in net.segments:
		_draw_sleepers(seg)
	for seg in net.segments:
		_draw_rails(seg)
	for n in net.nodes:
		if n.ports.size() == 1:
			_draw_buffer_stop(n)
		elif net.is_switch(n):
			_draw_switch(n)
	_mesh = _b.to_mesh()
	if _mesh != null:
		draw_mesh(_mesh, null)

func _round_ends(seg: TrackSegment, r: float, col: Color) -> void:
	var node0: TrackNode = seg.nodes[0]
	var node1: TrackNode = seg.nodes[1]
	if node0.ports.size() > 1:
		_b.draw_circle(seg.points[0], r, col)
	if node1.ports.size() > 1:
		_b.draw_circle(seg.points[seg.points.size() - 1], r, col)

func _draw_sleepers(seg: TrackSegment) -> void:
	var u := SLEEPER_SPACING * 0.5
	while u < seg.length:
		var p := seg.point_at(u)
		var n := seg.tangent_at(u).orthogonal() * 10.5
		var shade := SLEEPER.darkened(fmod(u * 0.37, 1.0) * 0.18)
		_b.draw_line(p - n, p + n, shade, 3.2)
		u += SLEEPER_SPACING

func _draw_rails(seg: TrackSegment) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var pts := seg.points
	var count := pts.size()
	for i in range(count):
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, count - 1)]
		var n := (b - a).normalized().orthogonal() * (GAUGE * 0.5)
		left.append(pts[i] + n)
		right.append(pts[i] - n)
	for rail in [left, right]:
		_b.draw_polyline(rail, RAIL_BASE, 2.8, true)
		_b.draw_polyline(rail, RAIL_TOP, 1.1, true)

func _draw_buffer_stop(node: TrackNode) -> void:
	var port: Array = node.ports[0]
	var d := TrackNetwork.port_dir(port)
	var p := node.position - d * 3.0
	_b.draw_set_transform(p, d.angle())
	_b.draw_rect(Rect2(-4.0, -9.0, 5.0, 18.0), Color(0.2, 0.2, 0.2))
	for k in range(3):
		var y := -9.0 + k * 6.0
		_b.draw_rect(Rect2(-3.5, y + 0.5, 4.0, 3.0), Color(0.95, 0.78, 0.15))
		_b.draw_rect(Rect2(-3.5, y + 3.5, 4.0, 2.5), Color(0.85, 0.2, 0.15))
	_b.draw_circle(Vector2(2.0, -GAUGE * 0.5), 1.8, Color(0.12, 0.12, 0.12))
	_b.draw_circle(Vector2(2.0, GAUGE * 0.5), 1.8, Color(0.12, 0.12, 0.12))
	_b.draw_set_transform(Vector2.ZERO, 0.0)

func _draw_switch(node: TrackNode) -> void:
	for p in node.ports:
		var c := net.candidates(node, p)
		if c.size() < 2:
			continue
		var chosen: Array = c[node.switch_state % c.size()]
		for q in c:
			var seg: TrackSegment = q[0]
			var on: bool = q == chosen
			# Past the shared lead-in (TrackNetwork.LEAD), where the branches
			# have actually parted, so each colour sits on its own track.
			var pts := seg.inward_points(q[1], 38.0, 72.0 if on else 54.0)
			if pts.size() >= 2:
				_b.draw_polyline(pts, Color(0, 0, 0, 0.35), 5.0, true)
				_b.draw_polyline(pts, Color(0.35, 0.95, 0.45, 0.95) if on else Color(0.95, 0.3, 0.25, 0.85), 3.0, true)
	_b.draw_circle(node.position, 5.5, Color(0.08, 0.08, 0.1, 0.85))
	_b.draw_arc(node.position, 5.5, 0.0, TAU, 20, Color(1, 1, 1, 0.85), 1.2, true)
	_b.draw_circle(node.position, 2.6, Color(0.35, 0.95, 0.45))
