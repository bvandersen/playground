extends Move
class_name FlossMove

## The floss: both arms swing to one side while the hips swing to the
## other, back and forth.

func _init() -> void:
	id = "floss"
	display_name = "Floss"
	params = [
		param("amount", "Amount", 0.0, 1.0, 0.05, 0.9),
		param("speed", "Speed", 0.3, 3.0, 0.05, 1.3),
	]

func pose(ctx: Dictionary, offs: PackedVector2Array, p: Dictionary) -> void:
	var a: float = p["amount"]
	var s := sin(ctx["t"] * TAU * float(p["speed"]))
	ctx["dx"] -= s * 34.0 * a
	ctx["angle"] -= s * 0.1 * a
	bend(offs, Skeleton.L_ELBOW, Vector2(-10 + 60 * s, -70), a)
	bend(offs, Skeleton.L_HAND, Vector2(-15 + 115 * s, -5), a)
	bend(offs, Skeleton.R_ELBOW, Vector2(10 + 60 * s, -70), a)
	bend(offs, Skeleton.R_HAND, Vector2(15 + 115 * s, -5), a)
	ctx["muscle_boost"] += 0.3 * a
