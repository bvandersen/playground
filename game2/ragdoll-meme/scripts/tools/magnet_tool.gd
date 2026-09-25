extends StageTool
class_name MagnetTool

## Tap to drop a magnet that pulls every body part in range toward it. Tap
## a magnet to flip it (red pulls, blue pushes); drag it to move it.

var _held := {}

func _init() -> void:
	id = "magnet"
	display_name = "Magnet"
	emoji = "🧲"
	hint = "Tap to place a magnet. Tap it to flip pull/push, drag to move."

func press(world: World, index: int, p: Vector2) -> void:
	var m := world.magnet_near(p)
	if m >= 0:
		_held[index] = {"m": m, "start": p, "moved": false}
		return
	world.add_magnet(p)

func drag(world: World, index: int, p: Vector2) -> void:
	if not _held.has(index):
		return
	var h: Dictionary = _held[index]
	if (h["start"] as Vector2).distance_to(p) > 12.0:
		h["moved"] = true
	if h["m"] < world.magnets.size():
		world.magnets[h["m"]]["pos"] = p

func release(world: World, index: int, p: Vector2) -> void:
	if not _held.has(index):
		return
	var h: Dictionary = _held[index]
	_held.erase(index)
	if not h["moved"] and h["m"] < world.magnets.size():
		world.magnets[h["m"]]["strength"] *= -1.0
		# Higher when it flips to push.
		world.emit_sfx("magnet", 1.0, p.x, 1.4 if world.magnets[h["m"]]["strength"] < 0.0 else 1.0)
