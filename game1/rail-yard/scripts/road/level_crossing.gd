extends RefCounted
class_name LevelCrossing

## Where a road crosses the track. Found afresh whenever either changes
## (see Main._find_crossings); nothing about it is saved.
##
## In Play the barriers come down while a train is coming (any car
## getting closer and under WARN_TIME away) or standing on the crossing, the
## red lights flash and the bell rings; road traffic stops short of it
## (Vehicle.drive). Trains never wait for cars: the barriers close early
## enough for anything already on the crossing to clear it.

const WARN_TIME := 3.2 # s before a train arrives that the barriers start down
const MIN_WARN := 150.0 # px: even a crawling train shuts them this far out
const ON_IT := 34.0
const BAR_SPEED := 1.1 # barrier travel per second (0 = up, 1 = down)
const BELL_EVERY := 0.55
const LINK_DIST := 110.0 # crossings nearer than this shut together

var pos := Vector2.ZERO
var road_dir := Vector2.RIGHT # along the road, unit
var track_dir := Vector2.UP # along the track, unit
var track_seg: TrackSegment
var track_u := 0.0

var closed := false
var want := false # a train is coming (this tick)
var linked := false # a crossing next to this one is shutting
var bar := 0.0
var time := 0.0
var _last := {} # Train -> its nearest car's distance last tick
var _bell := 0.0

func blocks_road() -> bool:
	return closed or bar > 0.4

## First half of a tick: is a train coming? (Main then links crossings
## that are close together before `animate`.)
func sense(trains: Array, playing: bool) -> void:
	want = false
	linked = false
	if playing:
		for t in trains:
			var dmin := INF
			for w in t.world:
				dmin = minf(dmin, (w["center"] as Vector2).distance_to(pos) - float(w["len"]) * 0.5)
			var prev: float = _last.get(t, INF)
			_last[t] = dmin
			if dmin < ON_IT or (dmin < maxf(MIN_WARN, absf(t._avg_v()) * WARN_TIME) and dmin < prev - 0.01):
				want = true

func animate(delta: float) -> void:
	closed = want or linked
	bar = move_toward(bar, 1.0 if closed else 0.0, delta * BAR_SPEED)
	time += delta
	if closed:
		_bell -= delta
		if _bell <= 0.0:
			_bell = BELL_EVERY
			Sfx.play_at("bell", pos)
	else:
		_bell = 0.0

## How far along the road from the centre the track's ballast reaches.
func half_span() -> float:
	var sn := absf(road_dir.cross(track_dir))
	return 16.0 / maxf(sn, 0.35)

## Traffic stops before its lane comes this close to the crossing centre.
func zone() -> float:
	return half_span() + 10.0

## Barriers, posts and lights, drawn every frame on top of the road.
func draw(ci) -> void:
	var off := half_span() + 7.0
	var hw := RoadNetwork.HALF_WIDTH
	var flashing := closed or bar > 0.02
	var on := int(time * 2.4) % 2
	for side in [-1.0, 1.0]:
		# Traffic heading towards the track from this side drives on the
		# right, so that half of the road gets the barrier.
		var towards: Vector2 = -road_dir * side # from this side, towards the track
		var right := Vector2(-towards.y, towards.x)
		var pivot: Vector2 = pos - towards * off + right * (hw + 3.0)
		var closed_dir := -right
		var open_dir := -towards
		var a := lerp_angle(open_dir.angle(), closed_dir.angle(), smoothstep(0.0, 1.0, bar))
		var arm := Vector2.from_angle(a)
		var length := hw + 1.0
		ci.draw_line(pivot + Vector2(1.2, 1.6), pivot + arm * length + Vector2(2.5, 3.2), Color(0, 0, 0, 0.25), 2.4)
		var stripes := 6
		for k in range(stripes):
			var p0: Vector2 = pivot + arm * (length * k / stripes)
			var p1: Vector2 = pivot + arm * (length * (k + 1) / stripes)
			ci.draw_line(p0, p1, Color(0.9, 0.12, 0.1) if k % 2 == 0 else Color(0.97, 0.97, 0.95), 2.2)
		ci.draw_circle(pivot + arm * length, 1.3, Color(1.0, 0.25, 0.2) if flashing and on == 1 else Color(0.5, 0.1, 0.1))
		# Post with the twin red lights facing the road.
		ci.draw_circle(pivot + Vector2(1.0, 1.4), 3.4, Color(0, 0, 0, 0.25))
		ci.draw_circle(pivot, 3.2, Color(0.12, 0.12, 0.13))
		for k in [-1.0, 1.0]:
			var lit: bool = flashing and (on == 0) == (k < 0.0)
			var lp: Vector2 = pivot + towards * 0.2 + road_dir.orthogonal() * k * 1.6
			if lit:
				ci.draw_circle(lp, 4.2, Color(1.0, 0.2, 0.15, 0.25))
			ci.draw_circle(lp, 1.2, Color(1.0, 0.25, 0.18) if lit else Color(0.35, 0.08, 0.07))
