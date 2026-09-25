extends Node

## The one place a kind of building or scenery is registered (autoload
## `BuildingCatalog`) -- the same role WagonCatalog and VehicleCatalog
## play. Placing, drawing, clearing the ground and the Build palette only
## read this table; a new kind is one entry here plus one painter in
## BuildingArt.
##
## `size` is the footprint (frontage x depth) in px. `layer` sets what's
## drawn over what: 0 lies flat on the ground (fields, ponds, meadows),
## 1 is buildings, 2 is trees, which stand over everything. `faces_road`
## things turn to face the nearest road and sit back from its kerb.
## `smoke` things puff from their chimney in Play.

var art := BuildingArt.new()

var CATALOG := {
	"house": {"name": "House", "size": Vector2(38, 34), "layer": 1, "faces_road": true, "colors": BuildingArt.ROOFS, "paint": art.house},
	"flats": {"name": "Flats", "size": Vector2(60, 48), "layer": 1, "faces_road": true,
		"colors": [Color(0.72, 0.3, 0.22), Color(0.25, 0.45, 0.65), Color(0.35, 0.55, 0.35), Color(0.85, 0.6, 0.2)], "paint": art.flats},
	"shop": {"name": "Shop", "size": Vector2(40, 34), "layer": 1, "faces_road": true,
		"colors": [Color(0.8, 0.2, 0.2), Color(0.2, 0.5, 0.35), Color(0.2, 0.4, 0.7), Color(0.9, 0.55, 0.15), Color(0.55, 0.3, 0.6)], "paint": art.shop},
	"market": {"name": "Supermarket", "size": Vector2(110, 96), "layer": 1, "faces_road": true,
		"colors": [Color(0.85, 0.2, 0.15), Color(0.15, 0.45, 0.75), Color(0.2, 0.6, 0.3), Color(0.95, 0.6, 0.1)], "paint": art.market},
	"factory": {"name": "Factory", "size": Vector2(110, 76), "layer": 1, "faces_road": true, "smoke": true,
		"colors": [Color(0.5, 0.55, 0.6), Color(0.55, 0.42, 0.35), Color(0.42, 0.5, 0.45)], "paint": art.factory},
	"warehouse": {"name": "Warehouse", "size": Vector2(100, 64), "layer": 1, "faces_road": true,
		"colors": [Color(0.4, 0.52, 0.62), Color(0.62, 0.62, 0.6), Color(0.35, 0.5, 0.38), Color(0.65, 0.5, 0.3)], "paint": art.warehouse},
	"farm": {"name": "Farm", "size": Vector2(140, 96), "layer": 0, "faces_road": false,
		"colors": [Color(0.66, 0.16, 0.12), Color(0.55, 0.22, 0.15)], "paint": art.farm},
	"tree": {"name": "Tree", "size": Vector2(34, 34), "layer": 2, "faces_road": false, "colors": [Color.WHITE], "paint": art.one_tree},
	"forest": {"name": "Woods", "size": Vector2(130, 116), "layer": 2, "faces_road": false, "colors": [Color.WHITE], "paint": art.forest},
	"pond": {"name": "Pond", "size": Vector2(96, 68), "layer": 0, "faces_road": false, "colors": [Color.WHITE], "paint": art.pond},
	"flowers": {"name": "Flowers", "size": Vector2(64, 46), "layer": 0, "faces_road": false, "colors": [Color.WHITE], "paint": art.flowers},
}

func has_kind(kind: String) -> bool:
	return CATALOG.has(kind)

func entry(kind: String) -> Dictionary:
	return CATALOG.get(kind, CATALOG["house"])

func kinds() -> Array:
	return CATALOG.keys()

## Paints `kind` into `ci` through the frame `xf`, shadows falling along
## the world's `sun` offset.
func paint(ci, kind: String, xf: Transform2D, col: Color, seed: int, sun: Vector2 = Vector2(3.5, 4.5)) -> void:
	var e := entry(kind)
	var sz: Vector2 = e["size"]
	art.begin(ci, xf, sun)
	(e["paint"] as Callable).call(ci, xf, sz.x, sz.y, col, seed)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
