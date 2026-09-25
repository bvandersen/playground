extends StageTool
class_name BoomTool

## Tap anywhere: an explosion flings everything nearby (and shakes the
## camera). Hold and drag for a string of blasts.

var _last := {}

func _init() -> void:
	id = "boom"
	display_name = "Boom"
	emoji = "💥"
	hint = "Tap to blow things up."

func press(world: World, index: int, p: Vector2) -> void:
	world.boom(p)
	_last[index] = p

func drag(world: World, index: int, p: Vector2) -> void:
	if _last.has(index) and (_last[index] as Vector2).distance_to(p) > 140.0:
		world.boom(p, 2600.0, 260.0)
		_last[index] = p

func release(_world: World, index: int, _p: Vector2) -> void:
	_last.erase(index)
