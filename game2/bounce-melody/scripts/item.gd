extends Node2D
class_name Item

## The view half of one item -- owns an ItemData and draws it, nothing
## else. What an item *does* lives entirely in its `behaviors` array
## (see behaviors/behavior.gd); this node never contains type-specific
## logic, so a second item type is a second ITEM_CATALOG entry, never a
## change here.

var data: ItemData
var behaviors: Array = []
var selected: bool = false

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

func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()

## Fans this hit out to every behavior this item currently carries --
## the point where a single physical event (crossing a wall) becomes
## however many reactions this item's own behavior list says it should
## have (today: exactly one, a tone; a future item could have none, or
## several).
func trigger_wall_hit(axis: String) -> void:
	for b in behaviors:
		b.on_wall_hit(self, axis)
