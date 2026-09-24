extends "res://scripts/behaviors/room_behavior.gd"
class_name SineSizeRoomBehavior

## "Assign a sine wave to the room width and height to make it auto scale
## over time." One instance per axis (`axis` is "width" or "height"),
## rather than one behavior juggling both -- so a designer can animate
## just one axis, or both with different amplitude/period, by attaching
## zero, one, or two of these to the room.

var axis: String = "width"
var amplitude: float = 0.0
var period: float = 6.0

const MIN_SIZE := 40.0

func tick(room: Room, _delta: float, elapsed: float) -> void:
	if period <= 0.0:
		return
	var base: float = room.base_width if axis == "width" else room.base_height
	var value: float = base + amplitude * sin(TAU * elapsed / period)
	value = max(value, MIN_SIZE)
	if axis == "width":
		room.width = value
	else:
		room.height = value
