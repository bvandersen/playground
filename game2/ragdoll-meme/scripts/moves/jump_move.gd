extends Move
class_name JumpMove

## Boing. Every so often, while standing on something, the whole body is
## launched upward (sized from the current gravity so "Height" means the
## same thing on the moon); in the air the knees tuck up.

func _init() -> void:
	id = "jump"
	display_name = "Jump"
	params = [
		param("amount", "Height", 0.1, 1.0, 0.05, 0.6),
		param("rate", "Jumps / sec", 0.2, 3.0, 0.05, 0.8),
	]

func pose(ctx: Dictionary, offs: PackedVector2Array, p: Dictionary) -> void:
	var a: float = p["amount"]
	var doll: Doll = ctx["doll"]
	var h: float = ctx["h"]
	doll.jump_timer += h
	if not ctx["grounded"]:
		bend(offs, Skeleton.L_KNEE, Vector2(-40, 40), 0.8)
		bend(offs, Skeleton.R_KNEE, Vector2(40, 40), 0.8)
		bend(offs, Skeleton.L_FOOT, Vector2(-45, 110), 0.8)
		bend(offs, Skeleton.R_FOOT, Vector2(45, 110), 0.8)
		return
	var period := 1.0 / float(p["rate"])
	if doll.jump_timer < period:
		ctx["lift"] -= clamp(doll.jump_timer / period - 0.7, 0.0, 0.3) * 120.0
		return
	doll.jump_timer = 0.0
	var g: float = abs(ctx["world"].gravity.y) + 200.0
	var v := sqrt(2.0 * g * 600.0 * a * doll.size)
	ctx["world"].emit_sfx("boing", a, doll.center().x, clampf(1.0 / sqrt(doll.size), 0.7, 1.5))
	for i in Skeleton.COUNT:
		if not doll.held[i]:
			doll.set_velocity(i, doll.velocity(i, h) + Vector2(0, -v), h)
