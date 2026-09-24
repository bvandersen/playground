extends "res://scripts/behaviors/behavior.gd"
class_name ToneOnWallHitBehavior

## "Each time it hits a wall it plays a tone." Purely reactive -- it owns
## no state of its own, it just asks the shared ToneEngine autoload to
## play this item's own `data.note`. Multiple items at different
## positions (so they reach a wall at different times) is what turns a
## series of these single tones into a melody -- nothing about that
## composition lives here, it falls out of the room ticking every item's
## own ConstantSpeedBounceBehavior independently.

func on_wall_hit(item: Item, _axis: String) -> void:
	ToneEngine.play_tone(item.data.note)
