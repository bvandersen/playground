extends Node2D

## After the day's rite: the sigil dimmed, a closing line, and when to
## return. Nothing to press (the scroll's hidden hold still works).

signal scroll_requested

var sigil := HomeSigil.new()

func _ready() -> void:
	var size := get_viewport_rect().size
	var seed := Daily.seed_for(Daily.today())
	sigil.dim = true
	sigil.position = size * Vector2(0.5, 0.44)
	add_child(sigil)
	sigil.held_long.connect(func(): scroll_requested.emit())
	_add_line(Lines.pick("seal", "closing", seed), 19, 0.55, size.y * 0.70, 1.0)
	_add_line(Lines.pick("seal", "return", seed), 14, 0.3, size.y * 0.70 + 44, 4.0)

func _add_line(text: String, font_size: int, alpha: float, y: float, delay: float) -> void:
	var size := get_viewport_rect().size
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color("#d9d1bd"))
	l.modulate.a = 0.0
	l.size = Vector2(size.x - 80, 40)
	l.position = Vector2(40, y)
	add_child(l)
	create_tween().tween_property(l, "modulate:a", alpha, 3.0).set_delay(delay)
