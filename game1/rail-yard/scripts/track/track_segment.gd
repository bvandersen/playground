extends RefCounted
class_name TrackSegment

## One piece of track between two TrackNodes: a smoothed polyline sampled
## every few pixels, plus its cumulative arc length so anything can ask
## "where is the point `u` pixels along this piece?" in O(log n).
## A segment knows nothing about trains -- a Route strings segments
## together, a Train only ever talks to its Route.

var points := PackedVector2Array()
var cum := PackedFloat32Array()
var length: float = 0.0
## TrackNode at end 0 (points[0]) and end 1 (points[-1]). Both can be the
## same node (a single-piece loop).
var nodes: Array = [null, null]

func _init(pts: PackedVector2Array = PackedVector2Array()) -> void:
	set_points(pts)

func set_points(pts: PackedVector2Array) -> void:
	points = pts
	cum = PackedFloat32Array()
	cum.resize(pts.size())
	var acc := 0.0
	for i in range(pts.size()):
		if i > 0:
			acc += pts[i].distance_to(pts[i - 1])
		cum[i] = acc
	length = acc

func point_at(u: float) -> Vector2:
	var n := points.size()
	if n == 0:
		return Vector2.ZERO
	if u <= 0.0:
		return points[0]
	if u >= length:
		return points[n - 1]
	var i := clampi(cum.bsearch(u), 1, n - 1)
	var a: float = cum[i - 1]
	var b: float = cum[i]
	var t := (u - a) / (b - a) if b > a else 0.0
	return points[i - 1].lerp(points[i], t)

## Unit tangent pointing from end 0 towards end 1.
func tangent_at(u: float) -> Vector2:
	var d := point_at(u + 4.0) - point_at(u - 4.0)
	return d.normalized() if d.length_squared() > 1e-8 else Vector2.RIGHT

## Direction a train heads in when it enters this segment through `end`.
func dir_into(end: int) -> Vector2:
	if end == 0:
		return tangent_at(minf(6.0, length * 0.5))
	return -tangent_at(maxf(length - 6.0, length * 0.5))

## Points `d0`..`d1` pixels in from `end`, every `step` -- used to draw
## switch indicators along the first stretch of a branch.
func inward_points(end: int, d0: float, d1: float, step: float = 3.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var d := d0
	d1 = minf(d1, length)
	while d <= d1:
		out.append(point_at(d if end == 0 else length - d))
		d += step
	return out

## Closest point on this segment to `p`: {u, dist, pos}.
func nearest(p: Vector2) -> Dictionary:
	var best_d := INF
	var best_u := 0.0
	var best_pos := Vector2.ZERO
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var ab := b - a
		var l2 := ab.length_squared()
		var t := 0.0 if l2 <= 1e-9 else clampf((p - a).dot(ab) / l2, 0.0, 1.0)
		var q := a + ab * t
		var d := q.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best_pos = q
			best_u = cum[i - 1] + (cum[i] - cum[i - 1]) * t
	return {"u": best_u, "dist": sqrt(best_d), "pos": best_pos}
