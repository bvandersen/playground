extends RefCounted
class_name TrackNode

## Where segment ends meet. One port = a dead end (buffer stop), two = a
## plain joint, three or more = a switch. A port is `[TrackSegment, end]`.
## `switch_state` picks which of the reachable branches a train takes (see
## TrackNetwork.candidates) -- it only matters where there's a real choice.

var position := Vector2.ZERO
var ports: Array = []
var switch_state: int = 0
