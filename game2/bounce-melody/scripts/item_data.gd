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
