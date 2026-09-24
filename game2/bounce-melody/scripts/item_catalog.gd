extends Node

## The one place a new item *type* gets registered (docs/game2.md's
## "Extensibility architecture"). The add-item UI and Main only ever read
## this table -- neither hardcodes "sphere" or any other type name.
## Adding a second shape later is one more entry here, not a rewrite of
## the code that reads it.

## `behaviors` is a Callable returning a fresh Array of Behavior
## instances -- kept *in* the catalog entry, not switched on `type`
## elsewhere, so this dictionary really is the one place a type is
## registered (see the Standing Rule in docs/game2.md: "never a new `if
## type == ...` anywhere else in the code").
static func _sphere_behaviors() -> Array:
	return [ConstantSpeedBounceBehavior.new(), ToneOnWallHitBehavior.new()]

## A `var`, not a `const`: a GDScript `const` must be a compile-time-
## foldable literal, and a `Callable` bound to `_sphere_behaviors` below
## only exists once this object is constructed -- this is still
## effectively read-only, since nothing outside this file ever assigns
## to it.
var CATALOG := {
	"sphere": {
		"display_name": "Sphere",
		"radius": 18.0,
		"default_color": Color(0.95, 0.65, 0.25),
		"default_note": 440.0,
		"default_speed": 220.0,
		"behaviors": _sphere_behaviors,
	},
}

const DEFAULT_TYPE := "sphere"

func type_list() -> Array:
	return CATALOG.keys()

func display_name(type: String) -> String:
	return CATALOG.get(type, {}).get("display_name", type)

## A fresh, randomly-aimed ItemData for `type` at `pos` -- the random
## initial direction is purely cosmetic (so two items dropped at once
## don't obviously mirror each other); every property it sets is one a
## player can immediately re-tune from the item's own property sheet.
func create_item_data(type: String, pos: Vector2) -> ItemData:
	var entry: Dictionary = CATALOG.get(type, CATALOG[DEFAULT_TYPE])
	var data := ItemData.new()
	data.type = type
	data.position = pos
	data.radius = entry["radius"]
	data.color = entry["default_color"]
	data.note = entry["default_note"]
	var angle := randf() * TAU
	data.velocity = Vector2(cos(angle), sin(angle)) * float(entry["default_speed"])
	return data

## Every item type's default behavior set, built fresh per item -- a
## Behavior instance is never shared between two items, since some (a
## future one, not today's two) could carry per-item state. Calls
## straight through to whatever Callable the catalog entry itself
## registered -- no type-name branching out here.
func make_behaviors(type: String) -> Array:
	var entry: Dictionary = CATALOG.get(type, CATALOG[DEFAULT_TYPE])
	var factory: Callable = entry["behaviors"]
	return factory.call()
