extends StageTool
class_name GrabTool

## Drag any joint: it follows the finger exactly and the rest of the body
## hangs off it through its constraints (IK), fighting back with whatever
## moves are on. Let go mid-swing to throw. Also drags magnets.

var _magnet := {}

func _init() -> void:
	id = "grab"
	display_name = "Grab"
	emoji = "✋"
	hint = "Drag any body part. Flick to throw. Use two fingers to puppet."

func press(world: World, index: int, p: Vector2) -> void:
	var hit := world.pick_joint(p)
	if not hit.is_empty():
		world.grabs[index] = {"doll": hit[0], "i": hit[1], "from": hit[0].pos[hit[1]], "to": p}
		world.selected = hit[0]
		return
	var m := world.magnet_near(p)
	if m >= 0:
		_magnet[index] = m

func drag(world: World, index: int, p: Vector2) -> void:
	if world.grabs.has(index):
		world.grabs[index]["to"] = p
	elif _magnet.has(index) and _magnet[index] < world.magnets.size():
		world.magnets[_magnet[index]]["pos"] = p

func release(world: World, index: int, _p: Vector2) -> void:
	world.grabs.erase(index)
	_magnet.erase(index)
