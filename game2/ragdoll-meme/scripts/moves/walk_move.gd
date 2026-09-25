extends Move
class_name WalkMove

## A procedural gait: feet cycle through a stride ellipse in opposite phase,
## arms swing against them, and the body is pushed along the ground while a
## foot is down. Turns around at the stage edges.

func _init() -> void:
	id = "walk"
	display_name = "Walk"
	params = [
		param("amount", "Stride", 0.0, 1.0, 0.05, 0.8),
		param("speed", "Speed", 0.2, 3.0, 0.05, 1.0),
	]

func pose(ctx: Dictionary, offs: PackedVector2Array, p: Dictionary) -> void:
	var a: float = p["amount"]
	var sp: float = p["speed"]
	var doll: Doll = ctx["doll"]
	var world = ctx["world"]
	var x := doll.pos[Skeleton.PELVIS].x
	if x < world.bounds_left() + 110.0 * doll.size:
		doll.facing = 1.0
	elif x > world.bounds_right() - 110.0 * doll.size:
		doll.facing = -1.0
	var f := doll.facing
	var ph: float = ctx["t"] * TAU * sp * 1.4
	for side in [0.0, PI]:
		var c := cos(ph + side)
		var s := sin(ph + side)
		var foot := Skeleton.L_FOOT if side == 0.0 else Skeleton.R_FOOT
		var knee := Skeleton.L_KNEE if side == 0.0 else Skeleton.R_KNEE
		var hand := Skeleton.L_HAND if side == 0.0 else Skeleton.R_HAND
		var lift: float = max(0.0, s) * 40.0
		bend(offs, foot, Vector2(f * c * 50.0, 176.0 - lift), a)
		bend(offs, knee, Vector2(f * (c * 25.0 + 18.0), 86.0 - lift * 0.6), a)
		bend(offs, hand, Vector2(-f * c * 45.0, 8.0), a)
	ctx["dx"] += f * 10.0 * a
	ctx["lift"] -= abs(sin(ph)) * 8.0 * a
	ctx["push_x"] += f * 150.0 * sp * a * doll.size
	ctx["feet_free"] = true
	ctx["muscle_boost"] += 0.2 * a
