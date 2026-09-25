extends Node2D

## Home: the breathing sigil and one line chosen by the time of day.
## Tap anywhere to begin today's rite.

signal begin_requested
signal scroll_requested

var sigil := HomeSigil.new()
var words := Label.new()

func _ready() -> void:
	var size := get_viewport_rect().size
	sigil.position = size * Vector2(0.5, 0.44)
	add_child(sigil)
	sigil.tapped.connect(_on_tapped)
	sigil.held_long.connect(func(): scroll_requested.emit())

	words.text = Lines.pick("threshold", time_of_day(), Daily.seed_for(Daily.today()))
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_theme_font_size_override("font_size", 19)
	words.add_theme_color_override("font_color", Color("#d9d1bd"))
	words.modulate.a = 0.0
	words.size = Vector2(size.x - 80, 60)
	words.position = Vector2(40, size.y * 0.72)
	add_child(words)
	create_tween().tween_property(words, "modulate:a", 0.6, 3.0).set_delay(1.2)

func _on_tapped() -> void:
	sigil.set_process_unhandled_input(false)
	begin_requested.emit()

static func time_of_day(hour: int = -1) -> String:
	if hour < 0:
		hour = Time.get_datetime_dict_from_system()["hour"]
	if hour >= 4 and hour < 10:
		return "dawn"
	if hour >= 10 and hour < 17:
		return "day"
	if hour >= 17 and hour < 21:
		return "dusk"
	return "night"
