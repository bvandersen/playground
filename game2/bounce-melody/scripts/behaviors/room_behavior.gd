extends RefCounted
class_name RoomBehavior

## Same extension-point pattern as Behavior, one level up: a room-wide
## effect the Room ticks every frame in Play mode, rather than code wired
## directly into Room's own resize logic. A second room-level effect
## later (a pulsing background, gravity) is another RoomBehavior, never a
## special case in Room itself.

func tick(_room: Room, _delta: float, _elapsed: float) -> void:
	pass
