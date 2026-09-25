extends Move
class_name HeadbangMove

## Metal. The head nods hard on the beat and the upper body rocks with it.

func _init() -> void:
	id = "headbang"
	display_name = "Headbang"
	params = [
		param("amount", "Amount", 0.0, 1.0, 0.05, 0.9),
		param("bpm", "Tempo (BPM)", 60.0, 240.0, 1.0, 150.0),
	]

func pose(ctx: Dictionary, offs: PackedVector2Array, p: Dictionary) -> void:
	var a: float = p["amount"]
	var beat: float = ctx["t"] * TAU * float(p["bpm"]) / 60.0
	var nod: float = pow(0.5 + 0.5 * sin(beat), 3.0)
	offs[Skeleton.HEAD] += Vector2(sin(beat * 0.5) * 12.0, 38.0 * nod) * a
	offs[Skeleton.NECK] += Vector2(0, 12.0 * nod) * a
	ctx["lift"] -= 14.0 * nod * a
	ctx["muscle_boost"] += 0.2 * a
