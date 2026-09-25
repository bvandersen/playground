extends RefCounted
class_name Force

## A scene-wide effect -- the World-level half of the catalog pattern (Move
## is the per-doll half). Two hooks:
##
##   configure(world)  sets world knobs once per tick (gravity, time
##                     scale, bounce...) -- for "settings" that are really
##                     just a number the sim reads
##   apply(world, h)   pushes on particles every substep (wind, tornado...)
##
## Declared params become sliders in the World sheet automatically, so a
## new Force is one new file plus one ForceCatalog line, no UI code.

var id := ""
var display_name := ""
var default_enabled := false
## Always-on entries show their sliders without an on/off switch.
var always_on := false
var params: Array = []

func default_params() -> Dictionary:
	var out := {}
	for p in params:
		out[p["id"]] = p["default"]
	return out

static func param(pid: String, pname: String, min_v: float, max_v: float, step: float, def: float) -> Dictionary:
	return {"id": pid, "name": pname, "min": min_v, "max": max_v, "step": step, "default": def}

func configure(_world, _p: Dictionary) -> void:
	pass

func apply(_world, _h: float, _p: Dictionary) -> void:
	pass
