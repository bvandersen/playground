extends Force
class_name GravityForce

func _init() -> void:
	id = "gravity"
	display_name = "Gravity"
	always_on = true
	params = [
		param("g", "Strength (g)", -1.0, 3.0, 0.05, 1.0),
		param("tilt", "Tilt°", -90.0, 90.0, 1.0, 0.0),
	]

func configure(world, p: Dictionary) -> void:
	world.gravity = Vector2(0, 2000.0 * float(p["g"])).rotated(deg_to_rad(float(p["tilt"])))
