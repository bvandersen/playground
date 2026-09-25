extends Button
class_name IconButton

## A button that shows a picture instead of words: one of IconArt's icons,
## or (when `car` is set) a little wagon painted by WagonArt, with an
## optional "+" / "x" badge. The words live on as the tooltip.

var icon_id := ""
var car := {}
var badge := ""
var icon_fraction := 0.74

func _init(id: String = "", tip: String = "", min_size: Vector2 = Vector2(50, 40)) -> void:
	icon_id = id
	tooltip_text = tip
	custom_minimum_size = min_size

func set_icon(id: String) -> void:
	if id != icon_id:
		icon_id = id
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var box := minf(size.x, size.y) * icon_fraction
	var center := size * 0.5
	var alpha := 0.45 if disabled else 1.0  # fade the picture along with the button
	if self_modulate.a != alpha:
		self_modulate.a = alpha
	if not car.is_empty():
		_draw_car()
	elif icon_id != "":
		IconArt.paint(self, icon_id, center, box)
	if badge != "":
		IconArt.badge(self, badge, Vector2(size.x - box * 0.5 - 2.0, center.y), box)

func _draw_car() -> void:
	var e := WagonCatalog.entry(car["type"])
	var l: float = e["length"]
	var w: float = e["width"]
	var k := minf((size.x - 14.0) / l, (size.y - 8.0) / w)
	draw_set_transform(size * 0.5, 0.0, Vector2(k, k))
	WagonCatalog.paint(car["type"], self, car)
	draw_set_transform(Vector2.ZERO, 0.0)
