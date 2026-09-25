extends Node2D
class_name BridgesView

## Draws every bridge deck, between what passes underneath and what goes
## over the top: a concrete road bridge with parapets, or a steel girder
## railway bridge with its own sleepers and rails. Each casts a shadow
## on whatever is below. Baked into one mesh whenever a bridge changes.

const SUN := Vector2(3.5, 4.5)
const CONCRETE := Color(0.74, 0.73, 0.69)
const STEEL := Color(0.3, 0.4, 0.5)

var main: Node
var _mesh: ArrayMesh

func _draw() -> void:
	var b := TriBatch.new()
	for d in main.decks:
		var pts := _deck_points(d)
		if pts.size() < 2:
			continue
		var sh := PackedVector2Array()
		for p in pts:
			sh.append(p + SUN * 2.2)
		b.draw_polyline(sh, Color(0, 0, 0, 0.3), d.width + 2.0)
		if d.rail:
			_rail_deck(b, pts)
		else:
			_road_deck(b, pts)
	_mesh = b.to_mesh()
	if _mesh != null:
		draw_mesh(_mesh, null)

## The upper line's centreline across the deck, a point every 3 px.
static func _deck_points(d: Deck) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var u: float = d.up_u - d.half
	while u <= d.up_u + d.half:
		pts.append(d.up_seg.point_at(u))
		u += 3.0
	return pts

static func _side(pts: PackedVector2Array, off: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(pts.size()):
		var a := pts[maxi(i - 1, 0)]
		var c := pts[mini(i + 1, pts.size() - 1)]
		out.append(pts[i] + (c - a).normalized().orthogonal() * off)
	return out

func _ends(b: TriBatch, pts: PackedVector2Array, half_w: float, col: Color, w: float) -> void:
	for k in [0, pts.size() - 1]:
		var i: int = k
		var a := pts[maxi(i - 1, 0)]
		var c := pts[mini(i + 1, pts.size() - 1)]
		var n := (c - a).normalized().orthogonal() * half_w
		b.draw_line(pts[i] - n, pts[i] + n, col, w)

func _road_deck(b: TriBatch, pts: PackedVector2Array) -> void:
	var hw := RoadNetwork.HALF_WIDTH
	b.draw_polyline(pts, CONCRETE.darkened(0.3), hw * 2.0 + 7.0)
	b.draw_polyline(pts, CONCRETE, hw * 2.0 + 5.0)
	b.draw_polyline(pts, RoadView.ASPHALT, hw * 2.0)
	for side in [-1.0, 1.0]:
		b.draw_polyline(_side(pts, (hw + 1.5) * side), CONCRETE.lightened(0.2), 1.0)
		b.draw_polyline(_side(pts, (hw - 3.0) * side), RoadView.LINE, 1.1)
	for i in range(1, pts.size() - 3, 6):
		b.draw_line(pts[i], pts[i + 3], RoadView.LINE, 1.4)
	# Expansion joints where the deck meets the road either side.
	_ends(b, pts, hw, Color(0.18, 0.18, 0.19), 1.6)

func _rail_deck(b: TriBatch, pts: PackedVector2Array) -> void:
	b.draw_polyline(pts, Color(0.2, 0.21, 0.23), 26.0)
	var u := 0
	while u < pts.size():
		var a := pts[maxi(u - 1, 0)]
		var c := pts[mini(u + 1, pts.size() - 1)]
		var n := (c - a).normalized().orthogonal() * 10.5
		b.draw_line(pts[u] - n, pts[u] + n, TrackView.SLEEPER, 3.0)
		u += 3
	for side in [-1.0, 1.0]:
		var rail := _side(pts, TrackView.GAUGE * 0.5 * side)
		b.draw_polyline(rail, TrackView.RAIL_BASE, 2.8)
		b.draw_polyline(rail, TrackView.RAIL_TOP, 1.1)
	# Girders both sides, with bracing and rivets.
	for side in [-1.0, 1.0]:
		var g := _side(pts, 13.5 * side)
		b.draw_polyline(g, STEEL.darkened(0.35), 4.2)
		b.draw_polyline(g, STEEL, 2.8)
		b.draw_polyline(_side(pts, (13.5 - 0.8) * side), STEEL.lightened(0.3), 0.7)
		for i in range(0, g.size(), 3):
			b.draw_circle(g[i], 0.6, STEEL.darkened(0.45))
	_ends(b, pts, 15.5, STEEL.darkened(0.45), 2.4)
