extends StageTool
class_name EraseTool

## Tap a pin, balloon or magnet (or a body part with things tied to it) to
## remove it.

func _init() -> void:
	id = "erase"
	display_name = "Erase"
	emoji = "🧽"
	hint = "Tap a pin, balloon or magnet to remove it."

func press(world: World, _index: int, p: Vector2) -> void:
	world.erase_near(p)
