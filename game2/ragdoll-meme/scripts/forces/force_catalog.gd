extends RefCounted
class_name ForceCatalog

## The one place a scene-wide Force gets registered, in World-sheet order.

static var _all: Array = []

static func all() -> Array:
	if _all.is_empty():
		_all = [
			GravityForce.new(), TimeForce.new(), BodyForce.new(), WindForce.new(),
			TornadoForce.new(), EarthquakeForce.new(), WallsForce.new(),
		]
	return _all
