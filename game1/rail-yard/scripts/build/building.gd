extends RefCounted
class_name Building

## One thing put down with the Build tool: a house, a shop, a factory, a
## pond, some woods... Saved as its kind, where it stands, which way it
## faces, its colour and a seed (so the same garden gets the same tree and
## car on every load). What it looks like is BuildingCatalog's business.

const SUN := Vector2(3.5, 4.5)
const SETBACK := 5.0 # gap between the kerb and the front of the plot

var kind := "house"
var pos := Vector2.ZERO
var angle := 0.0
var color := Color.WHITE
var seed := 0

var smoke_timer := 0.0

func size() -> Vector2:
	return BuildingCatalog.entry(kind)["size"]

func layer() -> int:
	return int(BuildingCatalog.entry(kind)["layer"])

func xform() -> Transform2D:
	return Transform2D(angle, pos)

func paint(ci) -> void:
	BuildingCatalog.paint(ci, kind, xform(), color, seed, SUN)

## True if `p` is on the plot (grown by `pad`).
func contains(p: Vector2, pad: float = 0.0) -> bool:
	var q := xform().affine_inverse() * p
	var h := size() * 0.5
	return absf(q.x) <= h.x + pad and absf(q.y) <= h.y + pad

## Points spread over the plot, `step` px apart (for clearing scenery and
## checking what's in the way).
func footprint(step: float = 12.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var h := size() * 0.5
	var xf := xform()
	var nx := maxi(int(ceil(h.x * 2.0 / step)), 1)
	var ny := maxi(int(ceil(h.y * 2.0 / step)), 1)
	for i in range(nx + 1):
		for j in range(ny + 1):
			out.append(xf * Vector2(-h.x + h.x * 2.0 * i / nx, -h.y + h.y * 2.0 * j / ny))
	return out

## The factory chimney's top, in the world.
func chimney() -> Vector2:
	var sz := size()
	return xform() * BuildingArt.chimney_at(sz.x, sz.y)

## Turns the plot to face the road nearest `p` (within `reach`) and sets it
## back from the kerb, on the side of the road `p` is on. False if there's
## no road that near.
func face_road(roads: RoadNetwork, p: Vector2, reach: float) -> bool:
	var hit := roads.nearest(p, reach)
	if hit.is_empty():
		return false
	var seg: TrackSegment = hit["seg"]
	var t := seg.tangent_at(hit["u"])
	var n := t.orthogonal()
	if n.dot(p - (hit["pos"] as Vector2)) < 0.0:
		n = -n
	# The plot's front (+y) looks back at the road.
	angle = atan2(n.x, -n.y)
	pos = (hit["pos"] as Vector2) + n * (RoadNetwork.HALF_WIDTH + 2.5 + SETBACK + size().y * 0.5)
	return true

func to_dict() -> Dictionary:
	return {
		"kind": kind, "x": snappedf(pos.x, 0.01), "y": snappedf(pos.y, 0.01),
		"a": snappedf(angle, 0.0001), "color": color.to_html(false), "seed": seed,
	}

static func from_dict(d: Dictionary) -> Building:
	var kind := str(d.get("kind", ""))
	if not BuildingCatalog.has_kind(kind):
		return null
	var b := Building.new()
	b.kind = kind
	b.pos = Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
	b.angle = float(d.get("a", 0.0))
	b.color = Color.html(str(d.get("color", "ffffff")))
	b.seed = int(d.get("seed", 0))
	return b

static func make(kind: String, at: Vector2) -> Building:
	var b := Building.new()
	b.kind = kind
	b.pos = at
	var colors: Array = BuildingCatalog.entry(kind)["colors"]
	b.color = colors[randi() % colors.size()]
	b.seed = randi() % 100000
	return b
