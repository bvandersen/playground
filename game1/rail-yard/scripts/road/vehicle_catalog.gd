extends Node

## The one place a road vehicle *type* is registered (autoload
## `VehicleCatalog`) -- WagonCatalog's twin for the road. Traffic, drawing
## and the build palette only read this table; a new vehicle is one entry
## here plus one painter in VehicleArt.
##
## `kind` groups types for the palette (car / truck / bus); `length` and
## `width` in px; `speed` the range it likes to cruise at, px/s. A
## `trailer` is towed behind on a hitch `hitch` px behind the vehicle's
## centre, its own centre `pin` px behind the hitch (a semi's trailer
## overhangs the tractor, a bendy bus's rear half follows a concertina
## `joint`).

var art := VehicleArt.new()

const CAR_COLORS := [
	Color(0.8, 0.14, 0.12), Color(0.14, 0.34, 0.7), Color(0.94, 0.94, 0.92), Color(0.12, 0.12, 0.13),
	Color(0.62, 0.64, 0.67), Color(0.2, 0.5, 0.3), Color(0.95, 0.66, 0.12), Color(0.4, 0.22, 0.5),
	Color(0.55, 0.8, 0.9), Color(0.5, 0.3, 0.18), Color(0.85, 0.45, 0.6),
]
const TRUCK_COLORS := [
	Color(0.8, 0.16, 0.12), Color(0.16, 0.36, 0.7), Color(0.94, 0.94, 0.92), Color(0.2, 0.5, 0.3),
	Color(0.95, 0.66, 0.12), Color(0.35, 0.36, 0.4),
]

var CATALOG := {
	"mini": {"name": "Mini", "kind": "car", "length": 19.0, "width": 10.5, "speed": [65.0, 80.0], "colors": CAR_COLORS, "paint": art.mini},
	"hatch": {"name": "Hatchback", "kind": "car", "length": 22.0, "width": 11.0, "speed": [65.0, 85.0], "colors": CAR_COLORS, "paint": art.hatch},
	"sedan": {"name": "Saloon", "kind": "car", "length": 26.0, "width": 11.5, "speed": [70.0, 90.0], "colors": CAR_COLORS, "paint": art.sedan},
	"estate": {"name": "Estate", "kind": "car", "length": 27.0, "width": 11.5, "speed": [65.0, 85.0], "colors": CAR_COLORS, "paint": art.estate},
	"suv": {"name": "SUV", "kind": "car", "length": 26.0, "width": 12.5, "speed": [65.0, 85.0], "colors": CAR_COLORS, "paint": art.suv},
	"sports": {"name": "Sports car", "kind": "car", "length": 25.0, "width": 11.5, "speed": [90.0, 110.0],
		"colors": [Color(0.85, 0.1, 0.08), Color(0.98, 0.78, 0.1), Color(0.1, 0.1, 0.12), Color(0.2, 0.55, 0.95)], "paint": art.sports},
	"taxi": {"name": "Taxi", "kind": "car", "length": 26.0, "width": 11.5, "speed": [75.0, 90.0], "colors": [Color(0.98, 0.8, 0.12)], "paint": art.taxi},
	"police": {"name": "Police car", "kind": "car", "length": 26.0, "width": 11.5, "speed": [80.0, 95.0], "colors": [Color(0.95, 0.95, 0.94)], "paint": art.police},
	"pickup": {"name": "Pickup", "kind": "car", "length": 29.0, "width": 12.5, "speed": [65.0, 80.0], "colors": CAR_COLORS, "paint": art.pickup},
	"van": {"name": "Van", "kind": "car", "length": 30.0, "width": 13.0, "speed": [60.0, 75.0],
		"colors": [Color(0.95, 0.95, 0.93), Color(0.16, 0.36, 0.7), Color(0.8, 0.16, 0.12), Color(0.35, 0.36, 0.4)], "paint": art.van},
	"icecream": {"name": "Ice cream van", "kind": "car", "length": 30.0, "width": 13.0, "speed": [45.0, 55.0],
		"colors": [Color(1.0, 0.8, 0.86), Color(0.7, 0.9, 1.0)], "paint": art.icecream},

	"box_truck": {"name": "Box lorry", "kind": "truck", "length": 44.0, "width": 15.0, "speed": [50.0, 62.0], "colors": TRUCK_COLORS, "paint": art.box_truck},
	"tanker_truck": {"name": "Tanker lorry", "kind": "truck", "length": 46.0, "width": 15.0, "speed": [48.0, 58.0], "colors": TRUCK_COLORS, "paint": art.tanker_truck},
	"tipper": {"name": "Tipper lorry", "kind": "truck", "length": 40.0, "width": 15.0, "speed": [45.0, 58.0],
		"colors": [Color(0.95, 0.66, 0.12), Color(0.8, 0.16, 0.12), Color(0.2, 0.5, 0.3)], "paint": art.tipper},
	"mixer": {"name": "Cement mixer", "kind": "truck", "length": 40.0, "width": 15.0, "speed": [45.0, 55.0],
		"colors": [Color(0.95, 0.5, 0.1), Color(0.16, 0.36, 0.7), Color(0.8, 0.16, 0.12)], "paint": art.mixer},
	"log_truck": {"name": "Log lorry", "kind": "truck", "length": 46.0, "width": 15.0, "speed": [45.0, 55.0],
		"colors": [Color(0.2, 0.5, 0.3), Color(0.8, 0.16, 0.12), Color(0.35, 0.36, 0.4)], "paint": art.log_truck},
	"garbage": {"name": "Bin lorry", "kind": "truck", "length": 38.0, "width": 15.0, "speed": [40.0, 50.0],
		"colors": [Color(0.3, 0.6, 0.25), Color(0.95, 0.55, 0.1)], "paint": art.garbage},
	"fire_engine": {"name": "Fire engine", "kind": "truck", "length": 44.0, "width": 15.0, "speed": [75.0, 90.0],
		"colors": [Color(0.85, 0.1, 0.08)], "paint": art.fire_engine},
	"semi": {"name": "Articulated lorry", "kind": "truck", "length": 22.0, "width": 15.0, "speed": [50.0, 60.0], "colors": TRUCK_COLORS, "paint": art.tractor,
		"trailer": {"length": 52.0, "width": 15.0, "hitch": 6.0, "pin": 22.0, "paint": art.semi_trailer}},

	"city_bus": {"name": "Bus", "kind": "bus", "length": 56.0, "width": 16.0, "speed": [50.0, 60.0],
		"colors": [Color(0.16, 0.36, 0.7), Color(0.8, 0.16, 0.12), Color(0.2, 0.55, 0.3), Color(0.95, 0.66, 0.12)], "paint": art.city_bus},
	"school_bus": {"name": "School bus", "kind": "bus", "length": 50.0, "width": 15.5, "speed": [45.0, 55.0],
		"colors": [Color(0.98, 0.75, 0.08)], "paint": art.school_bus},
	"double_decker": {"name": "Double-decker", "kind": "bus", "length": 48.0, "width": 16.0, "speed": [45.0, 55.0],
		"colors": [Color(0.82, 0.1, 0.1), Color(0.16, 0.36, 0.7)], "paint": art.double_decker},
	"coach_bus": {"name": "Coach", "kind": "bus", "length": 58.0, "width": 16.0, "speed": [60.0, 72.0],
		"colors": [Color(0.16, 0.36, 0.7), Color(0.8, 0.16, 0.12), Color(0.45, 0.2, 0.5)], "paint": art.coach_bus},
	"minibus": {"name": "Minibus", "kind": "bus", "length": 34.0, "width": 13.5, "speed": [55.0, 70.0],
		"colors": [Color(0.95, 0.95, 0.93), Color(0.2, 0.55, 0.3)], "paint": art.minibus},
	"bendy_bus": {"name": "Bendy bus", "kind": "bus", "length": 36.0, "width": 16.0, "speed": [48.0, 56.0],
		"colors": [Color(0.2, 0.55, 0.3), Color(0.16, 0.36, 0.7), Color(0.8, 0.16, 0.12)], "paint": art.bendy_front,
		"trailer": {"length": 32.0, "width": 16.0, "hitch": 19.5, "pin": 17.5, "joint": true, "paint": art.bendy_rear}},
}

## What the palette's car / lorry / bus buttons show.
const KIND_ICON := {"car": "sedan", "truck": "box_truck", "bus": "city_bus"}

func types() -> Array:
	return CATALOG.keys()

func has_type(type: String) -> bool:
	return CATALOG.has(type)

func entry(type: String) -> Dictionary:
	return CATALOG.get(type, CATALOG["sedan"])

func types_of(kind: String) -> Array:
	return CATALOG.keys().filter(func(t): return CATALOG[t]["kind"] == kind)

## A random vehicle of `kind` ("car", "truck", "bus"): {type, color, seed}.
func make(kind: String) -> Dictionary:
	var pool := types_of(kind)
	var type: String = pool[randi() % pool.size()]
	return make_type(type)

func make_type(type: String) -> Dictionary:
	var colors: Array = entry(type)["colors"]
	return {"type": type, "color": colors[randi() % colors.size()], "seed": randi() % 100000}

func paint(ci, v: Dictionary, trailer: bool = false) -> void:
	var e := entry(v["type"])
	if trailer:
		e = e["trailer"]
	(e["paint"] as Callable).call(ci, float(e["length"]), float(e["width"]), v["color"], int(v["seed"]))

# --- Baked frames ----------------------------------------------------------------
# Like PersonArt.frame: each look is painted into a flat triangle list once;
# VehiclesView transforms those into one mesh for all the traffic each frame.

const CACHE_LIMIT := 400

var _frames := {}

## [points, colours] of vehicle `v` (or its trailer) in its own frame.
func frame(v: Dictionary, trailer: bool = false) -> Array:
	var key := "%s|%s|%d|%s" % [v["type"], (v["color"] as Color).to_html(), int(v["seed"]), trailer]
	if not _frames.has(key):
		if _frames.size() >= CACHE_LIMIT:
			_frames.clear()
		var b := TriBatch.new()
		paint(b, v, trailer)
		_frames[key] = [b.points, b.colors]
	return _frames[key]

## The soft footprint shadow under a body `length` x `width`.
func shadow_frame(length: float, width: float) -> Array:
	var key := "shadow|%s|%s" % [length, width]
	if not _frames.has(key):
		var b := TriBatch.new()
		art.rr(b, 0.0, 0.0, length + 1.0, width + 0.5, width * 0.3, Color(0, 0, 0, 0.3))
		_frames[key] = [b.points, b.colors]
	return _frames[key]
