extends Force
class_name WallsForce

## Side walls and ceiling. Off, dolls can be flung clean out of frame
## (the floor always stays).

func _init() -> void:
	id = "walls"
	display_name = "Walls & ceiling"
	default_enabled = true

func configure(world, _p: Dictionary) -> void:
	world.walls_on = true
