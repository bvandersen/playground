extends Node2D
class_name RoadView

## Draws the roads in layers across every piece, like TrackView: pavement
## edge, asphalt (with round patches filling junctions and a turning
## circle at each dead end), then the white lines -- a dashed centre line
## and solid edge lines that stop short of junctions. Where a road crosses
## the track it lays a level crossing over the top: rubber panels, the
## rails running through, and stop lines. Baked into one mesh whenever
## the roads or the track change.

const KERB := Color(0.6, 0.6, 0.57)
const ASPHALT := Color(0.29, 0.3, 0.32)
const LINE := Color(0.93, 0.93, 0.9, 0.9)
const DASH := 9.0
const JUNCTION_CLEAR := 30.0

var main: Node
var _b := TriBatch.new()
var _mesh: ArrayMesh

func _draw() -> void:
	var roads: RoadNetwork = main.roads
	_b.clear()
	var hw := RoadNetwork.HALF_WIDTH
	for seg in roads.segments:
		_b.draw_polyline(seg.points, KERB, hw * 2.0 + 5.0)
	for n in roads.nodes:
		_b.draw_circle(n.position, (hw + 9.0 if n.ports.size() == 1 else hw) + 2.5, KERB)
	for seg in roads.segments:
		_b.draw_polyline(seg.points, ASPHALT, hw * 2.0)
	for n in roads.nodes:
		_b.draw_circle(n.position, hw + 9.0 if n.ports.size() == 1 else hw, ASPHALT)
	for seg in roads.segments:
		_draw_lines(seg)
	for c in main.crossings:
		_draw_crossing(c)
	_mesh = _b.to_mesh()
	if _mesh != null:
		draw_mesh(_mesh, null)

## How far in from `end` the lines keep clear (junctions and dead ends).
func _clear_at(seg: TrackSegment, end: int) -> float:
	var n: TrackNode = seg.nodes[end]
	if n == null:
		return 0.0
	if n.ports.size() == 1:
		return RoadNetwork.HALF_WIDTH + 4.0
	if n.ports.size() >= 3:
		return JUNCTION_CLEAR
	return 0.0

func _draw_lines(seg: TrackSegment) -> void:
	var u0 := _clear_at(seg, 0)
	var u1 := seg.length - _clear_at(seg, 1)
	if u1 - u0 < 6.0:
		return
	var edge := RoadNetwork.HALF_WIDTH - 3.0
	var crossings: Array = main.crossings
	for side in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		var u := u0
		while u <= u1:
			var p := seg.point_at(u)
			if _near_crossing(p, crossings):
				if pts.size() >= 2:
					_b.draw_polyline(pts, LINE, 1.1)
				pts = PackedVector2Array()
			else:
				pts.append(p + seg.tangent_at(u).orthogonal() * edge * side)
			u += 5.0
		if pts.size() >= 2:
			_b.draw_polyline(pts, LINE, 1.1)
	var u := u0 + 3.0
	while u + DASH <= u1:
		var a := seg.point_at(u)
		var b := seg.point_at(u + DASH)
		if not _near_crossing(a, crossings) and not _near_crossing(b, crossings):
			_b.draw_line(a, b, LINE, 1.4)
		u += DASH * 2.0

func _near_crossing(p: Vector2, crossings: Array) -> bool:
	for c in crossings:
		if p.distance_to(c.pos) < c.half_span() + 3.0:
			return true
	return false

func _draw_crossing(c: LevelCrossing) -> void:
	var seg: TrackSegment = c.track_seg
	var reach := (RoadNetwork.HALF_WIDTH + 3.0) / maxf(absf(c.road_dir.cross(c.track_dir)), 0.35)
	var pts := PackedVector2Array()
	var u := c.track_u - reach
	while u <= c.track_u + reach:
		pts.append(seg.point_at(u))
		u += 3.0
	if pts.size() < 2:
		return
	_b.draw_polyline(pts, Color(0.22, 0.22, 0.23), 25.0)
	_b.draw_polyline(pts, Color(0.36, 0.36, 0.37), 21.0)
	# Panel joints across the crossing.
	for i in range(0, pts.size() - 1, 3):
		var n := (pts[mini(i + 1, pts.size() - 1)] - pts[i]).normalized().orthogonal()
		_b.draw_line(pts[i] - n * 10.5, pts[i] + n * 10.5, Color(0.28, 0.28, 0.29), 0.6)
	for side in [-1.0, 1.0]:
		var rail := PackedVector2Array()
		for i in range(pts.size()):
			var a := pts[maxi(i - 1, 0)]
			var b := pts[mini(i + 1, pts.size() - 1)]
			rail.append(pts[i] + (b - a).normalized().orthogonal() * TrackView.GAUGE * 0.5 * side)
		_b.draw_polyline(rail, TrackView.RAIL_BASE, 2.8)
		_b.draw_polyline(rail, TrackView.RAIL_TOP, 1.1)
	# Stop lines across the lane leading up to the track on both sides.
	for side in [-1.0, 1.0]:
		var towards: Vector2 = -c.road_dir * side
		var right := Vector2(-towards.y, towards.x)
		var at: Vector2 = c.pos - towards * (c.zone() + 2.0)
		_b.draw_line(at + right * 1.0, at + right * (RoadNetwork.HALF_WIDTH - 2.0), LINE, 2.2)
		# A white X painted in the approach lane.
		var x: Vector2 = at - towards * 14.0 + right * RoadNetwork.LANE
		_b.draw_line(x - towards * 4.0 - right * 3.0, x + towards * 4.0 + right * 3.0, LINE, 1.2)
		_b.draw_line(x - towards * 4.0 + right * 3.0, x + towards * 4.0 - right * 3.0, LINE, 1.2)
