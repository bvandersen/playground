extends Move
class_name DanceMove

## Club dance: hips sway on the half-beat, knees bounce on every beat, arms
## pump up alternately.

func _init() -> void:
	id = "dance"
	display_name = "Dance"
	params = [
		param("amount", "Amount", 0.0, 1.0, 0.05, 0.8),
		param("bpm", "Tempo (BPM)", 60.0, 200.0, 1.0, 118.0),
	]

func pose(ctx: Dictionary, offs: PackedVector2Array, p: Dictionary) -> void:
	var a: float = p["amount"]
	var beat: float = ctx["t"] * TAU * float(p["bpm"]) / 60.0
	var sway := sin(beat * 0.5)
	ctx["dx"] += sway * 28.0 * a
	ctx["angle"] += sway * 0.14 * a
	ctx["lift"] -= abs(sin(beat)) * 26.0 * a
	var up_l := 0.5 + 0.5 * sin(beat)
	var up_r := 1.0 - up_l
	bend(offs, Skeleton.L_ELBOW, Vector2(-70, -150), a)
	bend(offs, Skeleton.L_HAND, Vector2(-60 - 20 * up_l, -170 - 70 * up_l), a)
	bend(offs, Skeleton.R_ELBOW, Vector2(70, -150), a)
	bend(offs, Skeleton.R_HAND, Vector2(60 + 20 * up_r, -170 - 70 * up_r), a)
	bend(offs, Skeleton.L_KNEE, Vector2(-38, 82), a)
	bend(offs, Skeleton.R_KNEE, Vector2(38, 82), a)
	ctx["muscle_boost"] += 0.2 * a
