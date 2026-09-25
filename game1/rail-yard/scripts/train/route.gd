extends RefCounted
class_name Route

## The stretch of track one train is currently on, as a chain of oriented
## segments with a single continuous coordinate `s` along it. Every car
## position is just an `s`; the route grows at whichever end the train
## approaches (choosing branches at switches as they're set at that
## moment) and drops pieces the train has fully left. Because `s` never
## gets re-based, physics can treat the whole train as points on a line
## no matter how many switches it crosses.

var net: TrackNetwork
var elems: Array = [] # [TrackSegment, rev: bool]; rev = travelled end 1 -> 0
var start_s: float = 0.0
var end_s: float = 0.0
## True when the route could not be extended past that end: a buffer stop.
var dead_front := false
var dead_back := false

func _init(network: TrackNetwork, seg: TrackSegment, rev: bool) -> void:
	net = network
	elems = [[seg, rev]]
	start_s = 0.0
	end_s = seg.length

## [element index, distance into that element].
func _locate(s: float) -> Array:
	var acc := start_s
	var last := elems.size() - 1
	for i in range(elems.size()):
		var l: float = elems[i][0].length
		if s <= acc + l or i == last:
			return [i, s - acc]
		acc += l
	return [last, 0.0]

## [position, unit tangent in the route's forward direction]. Beyond either
## end it extrapolates straight, so a car pressed into a buffer stays sane.
func sample(s: float) -> Array:
	var cs := clampf(s, start_s, end_s)
	var loc := _locate(cs)
	var e: Array = elems[loc[0]]
	var seg: TrackSegment = e[0]
	var u: float = seg.length - loc[1] if e[1] else loc[1]
	var t := seg.tangent_at(u)
	if e[1]:
		t = -t
	var p := seg.point_at(u)
	if s != cs:
		p += t * (s - cs)
	return [p, t]

func position(s: float) -> Vector2:
	return sample(s)[0]

## A cursor for TrackNetwork.walk starting at `s`, facing forward or back.
func cursor(s: float, forward: bool) -> Array:
	var loc := _locate(clampf(s, start_s, end_s))
	var e: Array = elems[loc[0]]
	var seg: TrackSegment = e[0]
	if forward:
		return [seg, e[1], loc[1]]
	return [seg, not e[1], seg.length - loc[1]]

## Grows the route until it covers [lo, hi] or hits a dead end.
func ensure(lo: float, hi: float) -> void:
	var guard := 0
	while end_s < hi and guard < 32 and _extend_front():
		guard += 1
	guard = 0
	while start_s > lo and guard < 32 and _extend_back():
		guard += 1
	dead_front = end_s < hi
	dead_back = start_s > lo

## Drops pieces entirely outside [lo, hi].
func trim(lo: float, hi: float) -> void:
	while elems.size() > 1 and start_s + elems[0][0].length < lo:
		start_s += elems[0][0].length
		elems.pop_front()
	while elems.size() > 1 and end_s - elems[elems.size() - 1][0].length > hi:
		end_s -= elems[elems.size() - 1][0].length
		elems.pop_back()

func _extend_front() -> bool:
	var last: Array = elems[elems.size() - 1]
	var q = net.next_port(last[0], 0 if last[1] else 1)
	if q == null:
		return false
	elems.append([q[0], q[1] == 1])
	end_s += q[0].length
	return true

func _extend_back() -> bool:
	var first: Array = elems[0]
	var q = net.next_port(first[0], 1 if first[1] else 0)
	if q == null:
		return false
	elems.push_front([q[0], q[1] == 0])
	start_s -= q[0].length
	return true
