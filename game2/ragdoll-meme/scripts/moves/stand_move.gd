extends Move
class_name StandMove

## Balance: the pose frame turns upright and, while the feet touch the
## ground, lifts the pelvis to standing height over them. Off, the doll
## is a plain ragdoll that crumples (muscles still hold its limbs' shape).

func _init() -> void:
	id = "stand"
	display_name = "Stand up"
	default_enabled = true
	params = [param("strength", "Balance", 0.05, 1.0, 0.05, 0.7)]

func pose(ctx: Dictionary, _offs: PackedVector2Array, p: Dictionary) -> void:
	ctx["balance"] = max(float(ctx["balance"]), float(p["strength"]))
