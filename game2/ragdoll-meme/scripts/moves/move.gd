extends RefCounted
class_name Move

## A procedural animation layer for one doll -- the per-doll half of the
## catalog pattern (Force is the scene-wide half). A Move never touches
## particles directly: it bends the pose offsets the doll's muscles pull
## toward, and/or sets fields on `ctx` (balance, lean `dx`, `lift`,
## `angle`, `angle_base`, `push_x`, `muscle_boost`) that Doll.apply_muscles
## reads. That keeps every Move combinable with every other one and with
## whatever the player is dragging -- the physics resolves the mix.
##
## Params are declared, not hand-built: the Moves sheet builds a slider
## for each entry of `params`, so a new Move needs no UI code.

var id := ""
var display_name := ""
var default_enabled := false
## [{"id", "name", "min", "max", "step", "default"}]
var params: Array = []

func default_params() -> Dictionary:
	var out := {}
	for p in params:
		out[p["id"]] = p["default"]
	return out

static func param(pid: String, pname: String, min_v: float, max_v: float, step: float, def: float) -> Dictionary:
	return {"id": pid, "name": pname, "min": min_v, "max": max_v, "step": step, "default": def}

func pose(_ctx: Dictionary, _offs: PackedVector2Array, _p: Dictionary) -> void:
	pass

## Blend joint `i` of the pose toward `target` by `amount` (0..1).
static func bend(offs: PackedVector2Array, i: int, target: Vector2, amount: float) -> void:
	offs[i] = offs[i].lerp(target, clamp(amount, 0.0, 1.0))
