extends StageTool
class_name PinTool

## Tap a joint to nail it where it is; press on a joint and drag away to
## hang it from a rope tied where you let go. Tap a pin to pull it out.

func _init() -> void:
	id = "pin"
	display_name = "Pin"
	emoji = "📌"
	hint = "Tap a body part to nail it. Drag from it to hang it on a rope."

func press(world: World, index: int, p: Vector2) -> void:
	for i in world.pins.size():
		if (world.pins[i]["anchor"] as Vector2).distance_to(p) < 40.0:
			world.pins.remove_at(i)
			world.emit_sfx("vanish", 0.8, p.x)
			return
	var hit := world.pick_joint(p)
	if not hit.is_empty():
		world.previews[index] = {"doll": hit[0], "i": hit[1], "end": p}
		world.selected = hit[0]

func drag(world: World, index: int, p: Vector2) -> void:
	if world.previews.has(index):
		world.previews[index]["end"] = p

func release(world: World, index: int, p: Vector2) -> void:
	if not world.previews.has(index):
		return
	var pv: Dictionary = world.previews[index]
	world.previews.erase(index)
	var doll: Doll = pv["doll"]
	var i: int = pv["i"]
	var anchor := p if doll.pos[i].distance_to(p) > 40.0 else doll.pos[i]
	world.add_pin(doll, i, anchor)
