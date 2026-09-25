extends Force
class_name TornadoForce

## A vortex in the middle of the stage: swirls everything around it and
## sucks it upward. Negative spin turns the other way.

func _init() -> void:
	id = "tornado"
	display_name = "Tornado"
	params = [
		param("spin", "Spin", -6000.0, 6000.0, 10.0, 3200.0),
		param("pull", "Suck in", 0.0, 4000.0, 10.0, 1200.0),
		param("lift", "Lift", 0.0, 4000.0, 10.0, 1800.0),
	]

func apply(world, _h: float, p: Dictionary) -> void:
	var c := Vector2(world.STAGE_SIZE.x * 0.5, world.STAGE_SIZE.y * 0.6)
	for doll: Doll in world.dolls:
		for i in Skeleton.COUNT:
			var d: Vector2 = doll.pos[i] - c
			var dist: float = max(d.length(), 40.0)
			var fall: float = clamp(1.0 - dist / 700.0, 0.0, 1.0)
			var tangent := Vector2(-d.y, d.x) / dist
			doll.acc[i] += (tangent * float(p["spin"]) - d / dist * float(p["pull"])) * fall
			doll.acc[i].y -= float(p["lift"]) * fall
