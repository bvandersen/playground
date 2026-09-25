extends Node

## Autoload Registry: the rite library. Loads every recipe pack in
## data/rites/*.json and maps engine ids to engine scripts. A recipe is
## what the user experiences as "a rite"; an engine is the code that
## performs it (docs/game3.md, "Free and paid: rites are data").

const RITES_DIR := "res://data/rites"
const OPENING_PATH := "res://data/rites/opening.json"
const TIERS := ["free", "deep"]

## Engine id -> script. One line per engine; explicit rather than a folder
## scan so exported builds (where scripts may be remapped) can't miss one.
const ENGINES := {
	"glyph_moment": preload("res://scripts/engines/e05_glyph_moment.gd"),
	"breath_sigil": preload("res://scripts/engines/e17_breath_sigil.gd"),
}

## Capabilities every device has. Phase 1's Senses replaces this check.
const ALWAYS_AVAILABLE := ["touch"]

var recipes: Dictionary = {} # id -> recipe
var opening: Array = [] # curated recipe ids for the first days

func _ready() -> void:
	load_all()

func load_all() -> void:
	recipes.clear()
	var dir := DirAccess.open(RITES_DIR)
	if dir == null:
		push_error("Registry: no %s" % RITES_DIR)
		return
	var files := Array(dir.get_files())
	files.sort()
	for file in files:
		if file.get_extension() != "json" or file == OPENING_PATH.get_file():
			continue
		_load_pack("%s/%s" % [RITES_DIR, file])
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(OPENING_PATH))
	opening = parsed.get("opening", []) if parsed is Dictionary else []
	for id in opening:
		if not recipes.has(id):
			push_error("Registry: opening names unknown recipe %s" % id)

func _load_pack(path: String) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("recipes") is Array:
		push_error("Registry: %s is not a recipe pack" % path)
		return
	for r in parsed["recipes"]:
		var problem := validate(r)
		if problem != "":
			push_error("Registry: %s: %s" % [path, problem])
			continue
		if recipes.has(r["id"]):
			push_error("Registry: duplicate recipe id %s" % r["id"])
			continue
		recipes[r["id"]] = r

## "" when the recipe is usable; otherwise what's wrong. The full schema is
## data/schema/recipe.schema.json -- this is the part the app relies on.
static func validate(r) -> String:
	if not r is Dictionary:
		return "recipe is not an object"
	for field in ["id", "engine", "tier", "title"]:
		if not r.get(field) is String or r[field] == "":
			return "missing %s" % field
	if not ENGINES.has(r["engine"]):
		return "%s: unknown engine %s" % [r["id"], r["engine"]]
	if not r["tier"] in TIERS:
		return "%s: unknown tier %s" % [r["id"], r["tier"]]
	if r.has("params") and not r["params"] is Dictionary:
		return "%s: params must be an object" % r["id"]
	var unknown := []
	var defaults: Dictionary = ENGINES[r["engine"]].defaults()
	for k in r.get("params", {}):
		if not defaults.has(k):
			unknown.append(k)
	if not unknown.is_empty():
		return "%s: unknown params %s" % [r["id"], unknown]
	return ""

func get_recipe(id: String) -> Dictionary:
	return recipes.get(id, {})

func can_perform(r: Dictionary) -> bool:
	for cap in r.get("requires", []):
		if not cap in ALWAYS_AVAILABLE:
			return false
	return true

## Recipes the daily draw may choose from on this device, for this user.
func drawable() -> Array:
	var out := []
	for r in recipes.values():
		if r.get("reviewed", false) and Entitlement.allows(r["tier"]) and can_perform(r):
			out.append(r)
	return out

## A fresh, unstarted engine node for the recipe, seeded.
func instantiate(r: Dictionary, seed: int) -> Ritual:
	var rite: Ritual = ENGINES[r["engine"]].new()
	rite.rng.seed = seed
	rite.setup(r)
	return rite
