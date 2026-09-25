extends RefCounted
class_name TrackCrossing

## Where two tracks cross. Found afresh whenever the track changes (see
## Main._find_crossings); only its `kind` is saved, by position.
##
## `kind` "diamond" is a flat crossing: both lines meet on the level,
## trains clatter over it and wait for each other (Train.plan) without
## giving up and reversing. "a_over" / "b_over" put one line on a bridge
## over the other (a flyover): then trains on different levels pass
## straight over and under each other. Tapping it with the Select tool
## cycles diamond -> a over b -> b over a.

const KINDS := ["diamond", "a_over", "b_over"]

var pos := Vector2.ZERO
var a_seg: TrackSegment
var a_u := 0.0
var a_dir := Vector2.RIGHT
var b_seg: TrackSegment
var b_u := 0.0
var b_dir := Vector2.UP
var kind := "diamond"
var deck: Deck = null

func set_kind(k: String) -> void:
	kind = k if KINDS.has(k) else "diamond"
	deck = null
	if kind == "a_over":
		deck = Deck.make(pos, a_seg, a_u, b_dir, 16.0, 30.0, true)
	elif kind == "b_over":
		deck = Deck.make(pos, b_seg, b_u, a_dir, 16.0, 30.0, true)
	if deck != null:
		deck.id = get_instance_id()

func next_kind() -> String:
	return KINDS[(KINDS.find(kind) + 1) % KINDS.size()]

## Which way the upper line runs (ZERO on a diamond) -- saved, so a
## reload can tell which of the two lines was on top.
func upper_dir() -> Vector2:
	return deck.up_dir if deck != null else Vector2.ZERO

## Puts the line running along `dir` on top.
func set_upper(dir: Vector2) -> void:
	set_kind("a_over" if absf(dir.dot(a_dir)) >= absf(dir.dot(b_dir)) else "b_over")
