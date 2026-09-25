extends TrackNetwork
class_name RoadNetwork

## Roads are the same graph as track (TrackSegments joined at TrackNodes,
## drawn with a finger, smoothed with the same brush, saved the same way),
## with the two differences roads have in real life:
##
## - A road drawn off another one meets it at the angle it was drawn, not
##   tangentially the way a switch must -- so a stroke off the side of a
##   road makes a T-junction. (Carrying on from a dead end still continues
##   it smoothly, and a loop still closes smoothly.)
## - Two roads that cross become a crossroads: both are split where they
##   cross and joined at one node, so traffic can turn there.
##
## Traffic doesn't use switches: at a junction each vehicle picks one of
## `exits`, and turns round at a dead end.

const HALF_WIDTH := 18.0 # asphalt half width, px
const LANE := 8.5 # lane centre's distance from the road centre
const JOIN_CLEAR := 26.0 # crossings this close to a node don't make another junction
const MIN_EXIT_DOT := -0.55 # a turn must leave less than ~123 deg off the way in

## Every way a vehicle arriving at `node` through `arrival` can drive on
## (not straight back the way it came). Empty at a dead end.
func exits(node: TrackNode, arrival: Array) -> Array:
	var t := -TrackNetwork.port_dir(arrival)
	var out := []
	for q in node.ports:
		if q == arrival:
			continue
		if TrackNetwork.port_dir(q).dot(t) > MIN_EXIT_DOT:
			out.append(q)
	return out

## A road stroke: laid like track, then fused with every road it crosses.
func add_road(raw: PackedVector2Array, snap: float) -> TrackSegment:
	var seg := add_stroke(raw, snap)
	if seg == null:
		return null
	for _guard in range(64):
		if not _fuse_one_crossing():
			break
	return seg

## Leaving a dead end straight on carries the road on; anything else
## joins at the angle it was drawn.
func _best_dir(node: TrackNode, want: Vector2, leaving: bool) -> Vector2:
	if node.ports.size() == 1:
		var d := -TrackNetwork.port_dir(node.ports[0]) if leaving else TrackNetwork.port_dir(node.ports[0])
		if d.dot(want) > 0.5:
			return d
	return want

## Finds one place where two road pieces cross away from any junction,
## splits both there and joins them into a crossroads. False if none.
func _fuse_one_crossing() -> bool:
	for i in range(segments.size()):
		var a: TrackSegment = segments[i]
		var ra := _rect(a)
		for j in range(i + 1, segments.size()):
			var b: TrackSegment = segments[j]
			if not ra.intersects(_rect(b)):
				continue
			for hit in TrackNetwork.crossings(a, b):
				var p: Vector2 = hit[0]
				if _near_node(p, a) or _near_node(p, b):
					continue
				var na := split(a, hit[1])
				var nb := split(b, hit[2])
				for port in nb.ports:
					(port[0] as TrackSegment).nodes[port[1]] = na
					na.ports.append(port)
				nodes.erase(nb)
				na.position = p
				return true
	return false

func _near_node(p: Vector2, seg: TrackSegment) -> bool:
	return p.distance_to(seg.points[0]) < JOIN_CLEAR or p.distance_to(seg.points[seg.points.size() - 1]) < JOIN_CLEAR

static func _rect(seg: TrackSegment) -> Rect2:
	var r := Rect2(seg.points[0], Vector2.ZERO)
	for p in seg.points:
		r = r.expand(p)
	return r.grow(2.0)
