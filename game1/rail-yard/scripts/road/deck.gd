extends RefCounted
class_name Deck

## The upper deck of a bridge where two lines cross: a road over the
## railway, the railway over a road, or one track flying over another.
## Everything that decides what's up and what's down asks this.
##
## Near the crossing the lines are close enough to straight that "which
## line is this on" is answered by direction: something heading along the
## upper line is up, along the lower line is down.

const REACH := 70.0 # beyond this from the crossing, nothing is on either level

var id := 1
var pos := Vector2.ZERO
var up_dir := Vector2.RIGHT # the upper line's direction at the crossing
var low_dir := Vector2.UP
var up_seg: TrackSegment
var up_u := 0.0
var half := 30.0 # half the deck's length along the upper line
var width := 30.0 # deck width
var rail := false # the upper line is track (else a road)

## `lower_half`: half the width of whatever passes underneath.
static func make(at: Vector2, seg: TrackSegment, u: float, low: Vector2, lower_half: float, deck_width: float, is_rail: bool) -> Deck:
	var d := Deck.new()
	d.pos = at
	d.up_seg = seg
	d.up_u = u
	d.up_dir = seg.tangent_at(u)
	d.low_dir = low
	d.half = lower_half / maxf(absf(d.up_dir.cross(low)), 0.35) + 10.0
	d.width = deck_width
	d.rail = is_rail
	return d

func _upper(dir: Vector2) -> bool:
	return absf(dir.dot(up_dir)) >= absf(dir.dot(low_dir))

## +id if something at `p` heading `dir` is on the upper line near this
## bridge, -id on the lower line, 0 if it's nowhere near.
func line_of(p: Vector2, dir: Vector2) -> int:
	if p.distance_squared_to(pos) > (half + REACH) * (half + REACH):
		return 0
	return id if _upper(dir) else -id

## True if a body `length` long at `p` heading `dir` overlaps the deck
## (so it's drawn above what passes underneath).
func carries(p: Vector2, dir: Vector2, length: float) -> bool:
	var q := p - pos
	return _upper(dir) and absf(q.dot(up_dir)) < half + length * 0.5 and absf(q.cross(up_dir)) < width * 0.5 + 6.0
