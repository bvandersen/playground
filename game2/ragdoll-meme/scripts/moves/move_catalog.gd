extends RefCounted
class_name MoveCatalog

## The one place a Move gets registered. Order here is the order they're
## applied in (later ones bend the pose on top of earlier ones) and the
## order the Moves sheet lists them.

static var _all: Array = []

static func all() -> Array:
	if _all.is_empty():
		_all = [
			StandMove.new(), DanceMove.new(), FlossMove.new(), FlailMove.new(),
			HeadbangMove.new(), WaveMove.new(), WalkMove.new(), JumpMove.new(),
			SpinMove.new(),
		]
	return _all

static func get_move(move_id: String) -> Move:
	for m in all():
		if m.id == move_id:
			return m
	return null
