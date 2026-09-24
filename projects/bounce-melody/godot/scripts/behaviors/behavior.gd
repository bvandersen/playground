extends RefCounted
class_name Behavior

## The one extension point every item property/behavior grows through
## (PLAN.md's "Extensibility architecture"). A behavior never
## reaches outside the `item`/`room` it's handed -- no globals beyond the
## ToneEngine/ItemCatalog autoloads every behavior is already allowed to
## use. Adding a new property later is a new Behavior subclass appended
## to an item's `behaviors` array, never a new `if` in Item or Room.

## Called every physics frame, for one item, while the room is ticking
## (Play mode only -- see Room.tick).
func physics_step(_item: Item, _delta: float, _room: Room) -> void:
	pass

## Called the instant `item`'s movement crosses a wall on `axis`
## ("x" or "y"), after its position/velocity have already been resolved
## for that bounce.
func on_wall_hit(_item: Item, _axis: String) -> void:
	pass
