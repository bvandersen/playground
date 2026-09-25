extends Force
class_name EarthquakeForce

## The floor shakes (and the camera with it) -- anything standing on it
## gets bounced around.

func _init() -> void:
	id = "quake"
	display_name = "Earthquake"
	params = [
		param("amount", "Magnitude", 0.0, 60.0, 1.0, 14.0),
		param("speed", "Shakes / sec", 1.0, 20.0, 0.5, 7.0),
	]

func configure(world, p: Dictionary) -> void:
	var a: float = p["amount"]
	var t: float = world.sim_time * TAU * float(p["speed"])
	world.floor_offset = sin(t) * a
	world.floor_shift = sin(t * 1.37 + 1.0) * a * 0.8
	world.shake = max(world.shake, a * 0.35)
