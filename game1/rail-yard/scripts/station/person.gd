extends RefCounted
class_name Person

## One passenger on a platform: what they look like (PersonArt), where
## they are, where they're walking to, and what they're doing there. The
## Station they belong to decides what happens next (see Station).

const WALK_SPEED := 24.0 # px/s for an adult; kids trot a little faster
const TURN_RATE := 10.0

var look: Dictionary
var pos := Vector2.ZERO
var heading := 0.0 # radians, the way they face
var face := NAN # heading to turn to while standing, if set
var path: Array = [] # Vector2 waypoints still to walk
var walked := 0.0 # px, drives the walk cycle
var moving := false
var speed := WALK_SPEED
var delay := 0.0 # s to wait before setting off
var idle := 0.0 # s until a waiting person fidgets again

## "arrive", "wait", "board", "alight", "leave"
var state := "wait"
var spot := Vector2.ZERO # waiting place as (platform index, depth)
var train = null # the Train they're boarding
var car := -1
var exit_end := false # leaving off the end of the platform, fading out
var alpha := 1.0
var fading := 0.0 # +1 fading in, -1 fading out

func _init(l: Dictionary = {}) -> void:
	look = l if not l.is_empty() else PersonArt.random_look()
	speed = WALK_SPEED * (1.2 if look["kid"] else randf_range(0.85, 1.1))
	if look.get("wheelchair", false):
		speed *= 0.9
	elif look.get("bike", false):
		speed *= 0.95

## Walks along `path`; true once there's nowhere left to go.
func step(delta: float) -> bool:
	moving = false
	if delay > 0.0:
		delay -= delta
		return false
	if path.is_empty():
		if not is_nan(face):
			heading = lerp_angle(heading, face, 1.0 - exp(-TURN_RATE * 0.5 * delta))
		return true
	var target: Vector2 = path[0]
	var d := target - pos
	var dist := d.length()
	var go := speed * delta
	if dist > 0.01:
		heading = lerp_angle(heading, d.angle(), 1.0 - exp(-TURN_RATE * delta))
	if dist <= go:
		pos = target
		walked += dist
		path.pop_front()
	else:
		pos += d / dist * go
		walked += go
	moving = true
	return path.is_empty()

func frame_index() -> int:
	return PersonArt.walk_frame(look, walked) if moving else PersonArt.FRAMES
