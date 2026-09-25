extends Move
class_name WaveMove

## "Hiii!" -- one arm up, hand waving side to side.

func _init() -> void:
	id = "wave"
	display_name = "Wave hello"
	params = [
		param("amount", "Amount", 0.0, 1.0, 0.05, 1.0),
		param("speed", "Speed", 0.3, 4.0, 0.05, 2.2),
	]

func pose(ctx: Dictionary, offs: PackedVector2Array, p: Dictionary) -> void:
	var a: float = p["amount"]
	var s := sin(ctx["t"] * TAU * float(p["speed"]))
	bend(offs, Skeleton.R_ELBOW, Vector2(65, -170), a)
	bend(offs, Skeleton.R_HAND, Vector2(70 + 45 * s, -235), a)
	ctx["muscle_boost"] += 0.25 * a
