extends Node2D
class_name Item

## The view half of one item -- owns an ItemData and draws it, nothing
## else. What an item *does* lives entirely in its `behaviors` array
## (see behaviors/behavior.gd); this node never contains type-specific
## logic, so a second item type is a second ITEM_CATALOG entry, never a
## change here.

## Pixels of arrow per unit of speed: a 220 px/s item gets a ~66 px arrow.
const VECTOR_SCALE := 0.3
const MAX_SPEED := 1000.0
const ARROW_HEAD := 9.0

var data: ItemData
var behaviors: Array = []
var selected: bool = false
## Design mode shows every item's velocity as an arrow; Play hides it.
var show_vector: bool = true

func setup(new_data: ItemData, new_behaviors: Array) -> void:
	data = new_data
	behaviors = new_behaviors
	position = data.position
	queue_redraw()

func _draw() -> void:
	if data == null:
		return
	draw_circle(Vector2.ZERO, data.radius, data.color)
	draw_arc(Vector2.ZERO, data.radius, 0.0, TAU, 24, data.color.darkened(0.35), 2.0)
	if selected:
		draw_arc(Vector2.ZERO, data.radius + 5.0, 0.0, TAU, 32, Color(1, 1, 1, 0.9), 2.0)
	if show_vector:
		_draw_vector()

## A thin line from the item's edge in the direction of travel, length
## proportional to speed, with an arrowhead -- and, on the selected item,
## a grab handle at the tip that drags the vector (see Main).
func _draw_vector() -> void:
	var v := data.velocity
	var arrow_color := data.color.lightened(0.35)
	arrow_color.a = 0.95 if selected else 0.6
	var tip := vector_tip()
	if v.length() > 0.001:
		var dir := v.normalized()
		var start := dir * data.radius
		draw_line(start, tip, arrow_color, 1.5, true)
		var back := tip - dir * ARROW_HEAD
		var side := dir.orthogonal() * (ARROW_HEAD * 0.5)
		draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), arrow_color)
	if selected:
		draw_arc(tip, 7.0, 0.0, TAU, 20, Color(1, 1, 1, 0.9), 1.5)

## Arrow tip, relative to the item's center.
func vector_tip() -> Vector2:
	var v := data.velocity
	if v.length() <= 0.001:
		return Vector2(data.radius, 0.0)
	return v.normalized() * data.radius + v * VECTOR_SCALE

## Inverse of vector_tip(): the velocity whose arrow ends at `local_tip`.
func velocity_for_tip(local_tip: Vector2) -> Vector2:
	var d := local_tip.length()
	if d <= 0.001:
		return Vector2.ZERO
	var speed: float = clamp((d - data.radius) / VECTOR_SCALE, 0.0, MAX_SPEED)
	return local_tip / d * speed

func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()

func set_show_vector(value: bool) -> void:
	show_vector = value
	queue_redraw()

## Fans this hit out to every behavior this item currently carries --
## the point where a single physical event (crossing a wall) becomes
## however many reactions this item's own behavior list says it should
## have (today: exactly one, a tone; a future item could have none, or
## several).
func trigger_wall_hit(axis: String) -> void:
	for b in behaviors:
		b.on_wall_hit(self, axis)
