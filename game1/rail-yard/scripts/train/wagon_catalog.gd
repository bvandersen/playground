extends Node

## The one place a vehicle *type* is registered -- same role as game2's
## ItemCatalog. Train physics, drawing and the train sheet's "Add" buttons
## only ever read this table; nothing else names "boxcar" or "steam".
## A new wagon is one entry here plus one painter in WagonArt.
##
## length/width in px, mass in arbitrary units (only ratios matter),
## `powered` cars apply traction, `smoke` picks the exhaust effect and
## `stack_x` where on the car (px ahead of its center) it comes out.
## `livery` cars take the train's livery colour; the rest keep their own.
## `horn` is the Sfx a loco sounds when it sets off (see Sfx), and
## `chuff` locos make a chuff with every exhaust puff.

var art := WagonArt.new()

var CATALOG := {
	"diesel": {
		"name": "Diesel", "length": 62.0, "width": 18.0, "mass": 4.0, "powered": true,
		"smoke": "diesel", "stack_x": -4.0, "livery": true, "horn": "horn",
		"colors": [Color(0.8, 0.2, 0.17), Color(0.16, 0.34, 0.62), Color(0.93, 0.6, 0.12), Color(0.2, 0.46, 0.3)],
		"paint": art.diesel,
	},
	"steam": {
		"name": "Steam", "length": 58.0, "width": 18.0, "mass": 4.5, "powered": true,
		"smoke": "steam", "stack_x": 20.0, "livery": true, "horn": "whistle", "chuff": true,
		"colors": [Color(0.12, 0.36, 0.2), Color(0.5, 0.1, 0.1), Color(0.12, 0.2, 0.42)],
		"paint": art.steam,
	},
	"tender": {
		"name": "Tender", "length": 34.0, "width": 18.0, "mass": 2.6, "livery": true,
		"colors": [Color(0.12, 0.36, 0.2)],
		"paint": art.tender,
	},
	"coach": {
		"name": "Coach", "length": 72.0, "width": 18.0, "mass": 2.0, "livery": true,
		"colors": [Color(0.12, 0.36, 0.2), Color(0.5, 0.1, 0.1), Color(0.16, 0.34, 0.62)],
		"paint": art.coach,
	},
	"boxcar": {
		"name": "Boxcar", "length": 54.0, "width": 18.0, "mass": 2.0,
		"colors": [Color(0.55, 0.2, 0.14), Color(0.36, 0.27, 0.2), Color(0.2, 0.3, 0.46), Color(0.62, 0.46, 0.16)],
		"paint": art.boxcar,
	},
	"tanker": {
		"name": "Tanker", "length": 50.0, "width": 18.0, "mass": 2.5,
		"colors": [Color(0.14, 0.14, 0.15), Color(0.84, 0.84, 0.8), Color(0.9, 0.55, 0.12)],
		"paint": art.tanker,
	},
	"hopper": {
		"name": "Hopper", "length": 46.0, "width": 18.0, "mass": 2.9,
		"colors": [Color(0.32, 0.32, 0.34), Color(0.46, 0.26, 0.15), Color(0.24, 0.34, 0.3)],
		"paint": art.hopper,
	},
	"logs": {
		"name": "Logs", "length": 58.0, "width": 18.0, "mass": 2.3,
		"colors": [Color(0.36, 0.25, 0.16)],
		"paint": art.logs,
	},
	"container": {
		"name": "Container", "length": 60.0, "width": 18.0, "mass": 2.1,
		"colors": [Color(0.78, 0.2, 0.15), Color(0.15, 0.44, 0.7), Color(0.2, 0.58, 0.34), Color(0.9, 0.7, 0.12), Color(0.58, 0.58, 0.6)],
		"paint": art.container,
	},
	"caboose": {
		"name": "Caboose", "length": 38.0, "width": 18.0, "mass": 1.4,
		"colors": [Color(0.78, 0.16, 0.12)],
		"paint": art.caboose,
	},
}

## Ready-made trains for "+Train" -- picked at random.
const PRESETS := [
	["steam", "tender", "coach", "coach", "coach"],
	["diesel", "boxcar", "tanker", "hopper", "logs", "container", "caboose"],
	["diesel", "diesel", "hopper", "hopper", "hopper", "hopper", "hopper"],
	["steam", "tender", "boxcar", "logs", "logs", "tanker", "caboose"],
	["diesel", "container", "container", "container", "container"],
]

const LIVERIES := [
	Color(0.12, 0.36, 0.2), Color(0.5, 0.1, 0.1), Color(0.16, 0.34, 0.62), Color(0.8, 0.2, 0.17),
	Color(0.93, 0.6, 0.12), Color(0.1, 0.1, 0.12), Color(0.45, 0.2, 0.5), Color(0.82, 0.8, 0.74),
]

func types() -> Array:
	return CATALOG.keys()

func has_type(type: String) -> bool:
	return CATALOG.has(type)

func entry(type: String) -> Dictionary:
	return CATALOG.get(type, CATALOG["boxcar"])

func display_name(type: String) -> String:
	return entry(type)["name"]

## A fresh car of `type`: {type, color, seed}. `livery` colours it if the
## type takes one.
func make_car(type: String, livery: Color) -> Dictionary:
	var e := entry(type)
	var colors: Array = e["colors"]
	var c: Color = livery if e.get("livery", false) else colors[randi() % colors.size()]
	return {"type": type, "color": c, "seed": randi() % 100000}

func paint(type: String, ci, car: Dictionary) -> void:
	var e := entry(type)
	var painter: Callable = e["paint"]
	painter.call(ci, float(e["length"]), float(e["width"]), car["color"], int(car["seed"]))

# --- Baked meshes --------------------------------------------------------------
# A car's picture only depends on its type, colour and seed, so each one is
# painted into a TriBatch once and reused every frame as a single mesh
# (see TriBatch for why that matters on the Web build).

const MESH_CACHE_LIMIT := 256

var _meshes := {}

## `car` painted in its own frame (centred, x towards the front).
func car_mesh(car: Dictionary) -> ArrayMesh:
	var key := "car|%s|%s|%d" % [car["type"], (car["color"] as Color).to_html(), int(car["seed"])]
	return _cached(key, func(b: TriBatch): paint(car["type"], b, car))

## The plain body outline every car casts as its shadow.
func shadow_mesh(length: float, width: float) -> ArrayMesh:
	return _cached("shadow|%s|%s" % [length, width], func(b: TriBatch): art.shadow(b, length, width, Color(0, 0, 0, 0.3)))

## One bogie (wheel set) in its own frame.
func bogie_mesh(width: float) -> ArrayMesh:
	return _cached("bogie|%s" % width, func(b: TriBatch): art.bogie(b, width))

func _cached(key: String, painter: Callable) -> ArrayMesh:
	if _meshes.has(key):
		return _meshes[key]
	if _meshes.size() >= MESH_CACHE_LIMIT:
		_meshes.clear() # layouts only ever hold a few dozen cars
	var b := TriBatch.new()
	painter.call(b)
	var mesh := b.to_mesh()
	_meshes[key] = mesh
	return mesh
