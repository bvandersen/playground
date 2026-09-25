class_name Ritual
extends Node2D

## Base of every rite engine (docs/game3.md, "Engine contract"). An engine
## is one self-contained file under scripts/engines/: it gets the recipe,
## a seeded rng and (from Phase 1) the kit -- never Save, Daily,
## Entitlement or the screens.

## Each engine declares `const ENGINE_ID := "breath_sigil"` (not declared
## here: GDScript won't let a subclass redeclare a parent's constant).

signal finished(outcome: String) # "done" | "left"

## Seeded by the host before setup(): same ritual day -> same rite.
var rng := RandomNumberGenerator.new()
## The recipe as given; params are merged over defaults() into `params`.
var recipe: Dictionary = {}
var params: Dictionary = {}

var _ended := false

## Every knob and its default. Recipes override any subset.
static func defaults() -> Dictionary:
	return {}

func setup(r: Dictionary) -> void:
	recipe = r
	# get_script() so the engine's own static defaults() is used.
	params = get_script().defaults()
	params.merge(r.get("params", {}), true)

## Called once, after the fade-in.
func begin() -> void:
	pass

## Past this point, leaving still seals the day.
func payoff_reached() -> bool:
	return false

## A line for `key`: the recipe's own `lines` first, else the engine's pool.
func line(key: String) -> String:
	var own = recipe.get("lines", {}).get(key)
	if own is String:
		return own
	if own is Array and not own.is_empty():
		return str(own[rng.randi() % own.size()])
	return Lines.pick(engine_id(), key, rng.randi())

func engine_id() -> String:
	return get_script().get_script_constant_map().get("ENGINE_ID", "")

func end(outcome: String = "done") -> void:
	if _ended:
		return
	_ended = true
	finished.emit(outcome)

## The user walked away (Android Back); the host decides whether it seals.
func leave() -> void:
	end("left")

func viewport_size() -> Vector2:
	return get_viewport_rect().size
