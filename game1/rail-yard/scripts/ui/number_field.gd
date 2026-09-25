extends HBoxContainer
class_name NumberField

## A label + slider + numeric SpinBox kept in sync: drag the slider for a
## rough value, or type into the box for an exact one. `value_changed`
## only fires for player edits, never for set_value_silently().

signal value_changed(value: float)

var slider: HSlider = null
var spin: SpinBox

var value: float:
	get:
		return spin.value

var _silent := false

func _init(label_text: String, min_v: float, max_v: float, step: float = 1.0, show_slider: bool = true, label_width: float = 78.0) -> void:
	add_theme_constant_override("separation", 6)
	if label_text != "":
		var label := Label.new()
		label.text = label_text
		label.custom_minimum_size = Vector2(label_width, 0)
		add_child(label)
	if show_slider:
		slider = HSlider.new()
		slider.min_value = min_v
		slider.max_value = max_v
		slider.step = step
		slider.custom_minimum_size = Vector2(90, 0)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(_on_slider_changed)
		add_child(slider)
	spin = SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step
	spin.select_all_on_focus = true
	spin.custom_minimum_size = Vector2(96, 0)
	if not show_slider:
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var line_edit := spin.get_line_edit()
	line_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	line_edit.focus_entered.connect(_select_all_for_typing, CONNECT_DEFERRED)
	spin.value_changed.connect(_on_spin_changed)
	add_child(spin)

func set_value_silently(v: float) -> void:
	_silent = true
	if slider != null:
		slider.value = v
	spin.value = v
	_silent = false

## A tap focuses the box on the press, so LineEdit defers
## select_all_on_focus to the release -- which the Web export's virtual
## keyboard swallows, leaving the caret after the old number. Select it
## here instead, and re-open the phone keyboard with that selection so
## the first digit typed replaces the old value rather than appending.
func _select_all_for_typing() -> void:
	var line_edit := spin.get_line_edit()
	if not line_edit.has_focus():
		return
	line_edit.select_all()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(line_edit.text, line_edit.get_global_rect(),
			DisplayServer.KEYBOARD_TYPE_NUMBER_DECIMAL, -1, 0, line_edit.text.length())

func _on_slider_changed(v: float) -> void:
	if _silent:
		return
	_silent = true
	spin.value = v
	_silent = false
	value_changed.emit(spin.value)

func _on_spin_changed(v: float) -> void:
	if _silent:
		return
	_silent = true
	if slider != null:
		slider.value = v
	_silent = false
	value_changed.emit(v)
