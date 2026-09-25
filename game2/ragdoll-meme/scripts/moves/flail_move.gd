extends Move
class_name FlailMove

## Inflatable tube man: arms and head whip around on smooth noise, the torso
## wobbles. Crank "Chaos" for full car-dealership energy.

var _noise := FastNoiseLite.new()

func _init() -> void:
	id = "flail"
	display_name = "Tube man flail"
	params = [
		param("amount", "Chaos", 0.0, 1.0, 0.05, 0.8),
		param("speed", "Speed", 0.2, 3.0, 0.05, 1.0),
	]
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.9

func pose(ctx: Dictionary, offs: PackedVector2Array, p: Dictionary) -> void:
	var a: float = p["amount"]
	var t: float = ctx["t"] * float(p["speed"])
	var sd: float = ctx["doll"].noise_seed
	var n := func(k: float) -> float: return _noise.get_noise_2d(t * 1.7, sd + k * 37.0)
	for side in [-1.0, 1.0]:
		var elbow := Skeleton.L_ELBOW if side < 0 else Skeleton.R_ELBOW
		var hand := Skeleton.L_HAND if side < 0 else Skeleton.R_HAND
		var k := 1.0 if side < 0 else 5.0
		var up: float = -PI * 0.5 + side * (0.4 + n.call(k) * 2.2)
		var elbow_pos := offs[Skeleton.NECK] + Vector2.from_angle(up) * 75.0
		var fore: float = up + n.call(k + 2.0) * 2.6
		bend(offs, elbow, elbow_pos, a)
		bend(offs, hand, elbow_pos + Vector2.from_angle(fore) * 70.0, a)
	ctx["angle"] += n.call(9.0) * 0.7 * a
	offs[Skeleton.HEAD] += Vector2(n.call(11.0) * 40.0, abs(n.call(12.0)) * 18.0) * a
	ctx["muscle_boost"] += 0.25 * a
