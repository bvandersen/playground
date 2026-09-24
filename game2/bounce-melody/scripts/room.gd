extends Node2D
class_name Room

## The box every item bounces inside. `width`/`height` are the *live*
## size (what items actually collide against right now); `base_width`/
## `base_height` are the designer's configured size, which a
## SineSizeRoomBehavior oscillates `width`/`height` around during Play
## mode. Design mode always shows -- and collides against -- the base
## size, never the animated one, so what's being designed stays
## predictable (see docs/game2.md, Phase 3) -- unless the scene was
## frozen on stop (Main.reset_on_stop off), in which case the live size and
## `elapsed` are kept so the next Play resumes exactly where it paused.

var width: float = 480.0
var height: float = 760.0
var base_width: float = 480.0
var base_height: float = 760.0
var behaviors: Array = []
var elapsed: float = 0.0

## Per-axis sine-wave settings -- the room's behavior list is rebuilt from
## this (rebuild_behaviors), so it's the one thing saved/restored.
var waves := {
	"width": {"enabled": false, "amplitude": 80.0, "period": 6.0},
	"height": {"enabled": false, "amplitude": 80.0, "period": 6.0},
}

const WALL_COLOR := Color(0.4, 0.48, 0.62)
const FLOOR_COLOR := Color(0.11, 0.14, 0.21)

func _draw() -> void:
	var half := Vector2(width, height) / 2.0
	draw_rect(Rect2(-half, Vector2(width, height)), FLOOR_COLOR, true)
	draw_rect(Rect2(-half, Vector2(width, height)), WALL_COLOR, false, 3.0)

## Advances every RoomBehavior this room carries -- called only while the
## simulation is running (Play mode). Design mode never calls this, so
## the room stays exactly at its configured base size while being edited.
func tick(delta: float) -> void:
	elapsed += delta
	for b in behaviors:
		b.tick(self, delta, elapsed)
	queue_redraw()

func reset_to_base() -> void:
	width = base_width
	height = base_height
	elapsed = 0.0
	queue_redraw()

func set_base_size(new_width: float, new_height: float) -> void:
	base_width = new_width
	base_height = new_height
	width = new_width
	height = new_height
	queue_redraw()

## Rebuilds the room's behavior list from `waves` -- simplest correct way
## to keep "0, 1, or 2 SineSizeRoomBehaviors attached" in sync with two
## independent toggles, and cheap enough (at most two objects) to just do
## on every change.
func rebuild_behaviors() -> void:
	behaviors.clear()
	for axis in ["width", "height"]:
		var w: Dictionary = waves[axis]
		if w["enabled"]:
			var b := SineSizeRoomBehavior.new()
			b.axis = axis
			b.amplitude = w["amplitude"]
			b.period = w["period"]
			behaviors.append(b)

func to_dict() -> Dictionary:
	return {"base_width": base_width, "base_height": base_height, "waves": waves.duplicate(true)}

func from_dict(d: Dictionary) -> void:
	set_base_size(float(d.get("base_width", base_width)), float(d.get("base_height", base_height)))
	var saved_waves = d.get("waves", {})
	for axis in ["width", "height"]:
		var w = saved_waves.get(axis, {}) if saved_waves is Dictionary else {}
		waves[axis]["enabled"] = bool(w.get("enabled", false))
		waves[axis]["amplitude"] = float(w.get("amplitude", waves[axis]["amplitude"]))
		waves[axis]["period"] = float(w.get("period", waves[axis]["period"]))
	elapsed = 0.0
	rebuild_behaviors()
