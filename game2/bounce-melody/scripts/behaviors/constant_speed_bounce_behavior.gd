extends "res://scripts/behaviors/behavior.gd"
class_name ConstantSpeedBounceBehavior

## The brief, verbatim: "reverses on hitting wall and it never loses
## momentum just constant speed." A plain kinematic mover, not a
## RigidBody2D -- see docs/game2.md, "Constant-speed reflection, not
## RigidBody2D physics." Reflecting by negating exactly one axis of
## `velocity` leaves its magnitude (the speed) mathematically unchanged,
## forever, by construction -- there is nothing here that could drift.

func physics_step(item: Item, delta: float, room: Room) -> void:
	var data := item.data
	data.position += data.velocity * delta

	var half_w := room.width / 2.0
	var half_h := room.height / 2.0
	var r := data.radius

	if data.position.x - r < -half_w:
		data.position.x = -half_w + r
		data.velocity.x = abs(data.velocity.x)
		item.trigger_wall_hit("x")
	elif data.position.x + r > half_w:
		data.position.x = half_w - r
		data.velocity.x = -abs(data.velocity.x)
		item.trigger_wall_hit("x")

	if data.position.y - r < -half_h:
		data.position.y = -half_h + r
		data.velocity.y = abs(data.velocity.y)
		item.trigger_wall_hit("y")
	elif data.position.y + r > half_h:
		data.position.y = half_h - r
		data.velocity.y = -abs(data.velocity.y)
		item.trigger_wall_hit("y")

	item.position = data.position
