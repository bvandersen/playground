extends RefCounted
class_name ItemData

## Plain data for one item -- no drawing, no physics of its own. Mirrors
## the CardPhysicsState/CardView split from the other game folder's own
## plan (docs/game.md): a Behavior reads and writes this, an Item (the
## Node2D) only ever reads it to draw itself. `properties` is a free-form
## bag for whatever a future property needs that these named fields
## don't already cover -- see docs/game2.md's extensibility architecture.

var type: String = "sphere"
var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var color: Color = Color(0.95, 0.65, 0.25)
var radius: float = 18.0
var note: float = 440.0
var properties: Dictionary = {}

## JSON-safe form, for saved setups and the Play-start snapshot that
## "reset on stop" restores (see Main.capture_state).
func to_dict() -> Dictionary:
	return {
		"type": type,
		"x": position.x,
		"y": position.y,
		"vx": velocity.x,
		"vy": velocity.y,
		"color": color.to_html(true),
		"radius": radius,
		"note": note,
		"properties": properties.duplicate(true),
	}

static func from_dict(d: Dictionary) -> ItemData:
	var data := ItemData.new()
	data.type = str(d.get("type", data.type))
	data.position = Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
	data.velocity = Vector2(float(d.get("vx", 0.0)), float(d.get("vy", 0.0)))
	data.color = Color.html(str(d.get("color", data.color.to_html(true))))
	data.radius = float(d.get("radius", data.radius))
	data.note = float(d.get("note", data.note))
	var props = d.get("properties", {})
	data.properties = props.duplicate(true) if props is Dictionary else {}
	return data
