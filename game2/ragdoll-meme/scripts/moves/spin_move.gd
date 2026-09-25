extends Move
class_name SpinMove

## Helicopter: the body frame's target angle turns continuously, so a
## standing doll cartwheels on the spot and a flying one windmills.

func _init() -> void:
	id = "spin"
	display_name = "Spin"
	params = [
		param("speed", "Turns / sec", -3.0, 3.0, 0.05, 0.8),
		param("amount", "Force", 0.1, 1.0, 0.05, 0.7),
	]

func pose(ctx: Dictionary, _offs: PackedVector2Array, p: Dictionary) -> void:
	ctx["angle_base"] = ctx["t"] * TAU * float(p["speed"])
	ctx["balance"] = max(float(ctx["balance"]), float(p["amount"]))
