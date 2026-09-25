extends StageTool
class_name BalloonTool

## Tap a body part to tie a balloon to it. A few on one doll and it floats
## away.

func _init() -> void:
	id = "balloon"
	display_name = "Balloon"
	emoji = "🎈"
	hint = "Tap a body part to tie a balloon on. Add a few to float away."

func press(world: World, _index: int, p: Vector2) -> void:
	var hit := world.pick_joint(p, 110.0)
	if not hit.is_empty():
		world.add_balloon(hit[0], hit[1])
		world.selected = hit[0]
