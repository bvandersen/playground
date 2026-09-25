extends Force
class_name BodyForce

## Material knobs: how rubbery limbs are, how bouncy the floor is, how much
## the floor grips, and air resistance.

func _init() -> void:
	id = "body"
	display_name = "Rubber & bounce"
	always_on = true
	params = [
		param("stretch", "Rubber limbs", 0.0, 1.0, 0.05, 0.0),
		param("bounce", "Bounciness", 0.0, 1.2, 0.05, 0.25),
		param("friction", "Floor grip", 0.0, 1.0, 0.05, 0.5),
		param("air", "Air drag", 0.0, 1.0, 0.05, 0.1),
	]

func configure(world, p: Dictionary) -> void:
	# Stretch 1 = barely-there sticks; squared so the low end stays subtle.
	var s: float = p["stretch"]
	world.stick_stiffness = lerp(1.0, 0.012, s * (2.0 - s))
	world.bounce = float(p["bounce"])
	world.friction = float(p["friction"]) * 0.35
	world.damping = 1.0 - float(p["air"]) * 0.03
