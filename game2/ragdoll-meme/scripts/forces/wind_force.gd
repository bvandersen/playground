extends Force
class_name WindForce

## Gusty wind, with per-joint flutter so limbs flap instead of the whole
## doll sliding as one block.

var _noise := FastNoiseLite.new()

func _init() -> void:
	id = "wind"
	display_name = "Wind"
	params = [
		param("strength", "Strength", -4000.0, 4000.0, 10.0, 1400.0),
		param("gust", "Gustiness", 0.0, 1.0, 0.05, 0.6),
	]
	_noise.frequency = 0.5

func apply(world, _h: float, p: Dictionary) -> void:
	var t: float = world.sim_time
	var s: float = p["strength"]
	var gust: float = p["gust"]
	var base := s * (1.0 + gust * _noise.get_noise_1d(t * 1.3) * 1.6)
	for doll: Doll in world.dolls:
		for i in Skeleton.COUNT:
			var flutter := _noise.get_noise_2d(t * 4.0, i * 13.0 + doll.noise_seed) * gust
			var a := Vector2(base * (1.0 + flutter), absf(base) * flutter * 0.6) * float(Skeleton.DRAG[i])
			doll.acc[i] += a
	for b in world.balloons:
		b["acc"] += Vector2(base * 1.4, 0)
