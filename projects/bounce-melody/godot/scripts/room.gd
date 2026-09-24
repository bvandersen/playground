extends Node2D
class_name Room

## The box every item bounces inside. `width`/`height` are the *live*
## size (what items actually collide against right now); `base_width`/
## `base_height` are the designer's configured size, which a
## SineSizeRoomBehavior oscillates `width`/`height` around during Play
## mode. Design mode always shows -- and collides against -- the base
## size, never the animated one, so what's being designed stays
## predictable (see PLAN.md, Phase 3).

var width: float = 480.0
var height: float = 760.0
var base_width: float = 480.0
var base_height: float = 760.0
var behaviors: Array = []
var elapsed: float = 0.0

const WALL_COLOR := Color(0.4, 0.48, 0.62)
const FLOOR_COLOR := Color(0.11, 0.14, 0.21)

func _draw() -> void:
	var half := Vector2(width, height) / 2.0
	draw_rect(Rect2(-half, Vector2(width, height)), FLOOR_COLOR, true)
	draw_rect(Rect2(-half, Vector2(width, height)), WALL_COLOR, false, 3.0)

## Advances every RoomBehavior this room carries -- called only while the
## simulation is running (Play mode). Design mode never calls this, so
## the room stays exactly at its configured base size while being edited.
func tick(delta: float) -> void:
	elapsed += delta
	for b in behaviors:
		b.tick(self, delta, elapsed)
	queue_redraw()

func reset_to_base() -> void:
	width = base_width
	height = base_height
	elapsed = 0.0
	queue_redraw()

func set_base_size(new_width: float, new_height: float) -> void:
	base_width = new_width
	base_height = new_height
	width = new_width
	height = new_height
	queue_redraw()
