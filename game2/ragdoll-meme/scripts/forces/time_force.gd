extends Force
class_name TimeForce

## Slow-mo (or fast-forward) for the whole sim. Dragging still follows the
## finger at real speed, which is exactly what makes slow-mo throws funny.

func _init() -> void:
	id = "time"
	display_name = "Speed / slow-mo"
	always_on = true
	params = [param("scale", "Time scale", 0.1, 2.0, 0.05, 1.0)]

func configure(world, p: Dictionary) -> void:
	world.time_scale = float(p["scale"])
