extends Control
class_name UIRoot

## Every panel here *floats over* the canvas and can be hidden -- no
## panel ever docks in a way that shrinks the design/play area, so a
## drag started anywhere on the canvas always works (see PLAN.md,
## "Design-mode UI, built for a small phone screen first"). The root
## Control itself ignores mouse input (MOUSE_FILTER_IGNORE) so a tap that
## isn't on a visible panel falls straight through to Main's own
## _unhandled_input, which is what drives selection/dragging.

const TOP_STRIP_HEIGHT := 56.0
const ITEM_SHEET_HEIGHT := 250.0
const ROOM_SHEET_HEIGHT := 340.0

const PALETTE := [
	Color(0.95, 0.65, 0.25), Color(0.35, 0.82, 0.78), Color(0.85, 0.22, 0.31),
	Color(0.56, 0.48, 0.85), Color(0.44, 0.75, 0.36), Color(0.88, 0.56, 0.82),
]

var main: Node

var mode_button: Button
var add_button: Button
var room_button: Button

var item_sheet: PanelContainer
var speed_slider: HSlider
var angle_slider: HSlider
var note_slider: HSlider

var room_sheet: PanelContainer
var width_slider: HSlider
var height_slider: HSlider
var width_wave_check: CheckBox
var height_wave_check: CheckBox
var width_amp_slider: HSlider
var width_period_slider: HSlider
var height_amp_slider: HSlider
var height_period_slider: HSlider

var current_item: Item = null
var _updating_from_item := false

func setup(main_ref: Node) -> void:
	main = main_ref
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_strip()
	_build_item_sheet()
	_build_room_sheet()
	on_selection_changed(null)
	on_mode_changed(main.MODE_DESIGN)

func _dock_top(control: Control, height: float) -> void:
	control.anchor_left = 0.0
	control.anchor_right = 1.0
	control.anchor_top = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = 0.0
	control.offset_right = 0.0
	control.offset_top = 0.0
	control.offset_bottom = height
	control.mouse_filter = Control.MOUSE_FILTER_STOP

func _dock_bottom(control: Control, height: float) -> void:
	control.anchor_left = 0.0
	control.anchor_right = 1.0
	control.anchor_top = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = 0.0
	control.offset_right = 0.0
	control.offset_top = -height
	control.offset_bottom = 0.0
	control.mouse_filter = Control.MOUSE_FILTER_STOP

func _add_labeled_slider(parent: Node, label_text: String, min_v: float, max_v: float) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(78, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = 1.0
	slider.custom_minimum_size = Vector2(190, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	return slider

func _build_top_strip() -> void:
	var strip := PanelContainer.new()
	_dock_top(strip, TOP_STRIP_HEIGHT)
	add_child(strip)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	strip.add_child(row)

	mode_button = Button.new()
	mode_button.pressed.connect(_on_mode_pressed)
	row.add_child(mode_button)

	add_button = Button.new()
	add_button.text = "Add Item"
	add_button.pressed.connect(_on_add_pressed)
	row.add_child(add_button)

	room_button = Button.new()
	room_button.text = "Room"
	room_button.pressed.connect(_on_room_pressed)
	row.add_child(room_button)

func _on_mode_pressed() -> void:
	main.toggle_mode()

func _on_add_pressed() -> void:
	main.add_item_at(Vector2.ZERO)

func _on_room_pressed() -> void:
	room_sheet.visible = not room_sheet.visible
	item_sheet.visible = false

func _build_item_sheet() -> void:
	item_sheet = PanelContainer.new()
	_dock_bottom(item_sheet, ITEM_SHEET_HEIGHT)
	add_child(item_sheet)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	item_sheet.add_child(col)

	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 8)
	col.add_child(color_row)
	for c in PALETTE:
		var swatch := ColorRect.new()
		swatch.color = c
		swatch.custom_minimum_size = Vector2(30, 30)
		swatch.mouse_filter = Control.MOUSE_FILTER_STOP
		swatch.gui_input.connect(_on_color_swatch_input.bind(c))
		color_row.add_child(swatch)

	speed_slider = _add_labeled_slider(col, "Speed", 20.0, 500.0)
	speed_slider.value_changed.connect(_on_speed_changed)

	angle_slider = _add_labeled_slider(col, "Direction", 0.0, 359.0)
	angle_slider.value_changed.connect(_on_angle_changed)

	note_slider = _add_labeled_slider(col, "Pitch (Hz)", 160.0, 1200.0)
	note_slider.value_changed.connect(_on_note_changed)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	col.add_child(button_row)
	var duplicate_button := Button.new()
	duplicate_button.text = "Duplicate"
	duplicate_button.pressed.connect(_on_duplicate_pressed)
	button_row.add_child(duplicate_button)
	var delete_button := Button.new()
	delete_button.text = "Delete"
	delete_button.pressed.connect(_on_delete_pressed)
	button_row.add_child(delete_button)

func _on_color_swatch_input(event: InputEvent, c: Color) -> void:
	if event is InputEventMouseButton and event.pressed and current_item != null:
		current_item.data.color = c
		current_item.queue_redraw()

func _on_speed_changed(v: float) -> void:
	if _updating_from_item or current_item == null:
		return
	var dir := current_item.data.velocity.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	current_item.data.velocity = dir * v

func _on_angle_changed(v: float) -> void:
	if _updating_from_item or current_item == null:
		return
	var speed := current_item.data.velocity.length()
	if speed == 0.0:
		speed = 200.0
	var rad := deg_to_rad(v)
	current_item.data.velocity = Vector2(cos(rad), sin(rad)) * speed

func _on_note_changed(v: float) -> void:
	if _updating_from_item or current_item == null:
		return
	current_item.data.note = v

func _on_duplicate_pressed() -> void:
	if current_item != null:
		main.duplicate_item(current_item)

func _on_delete_pressed() -> void:
	if current_item != null:
		main.remove_item(current_item)

func _build_room_sheet() -> void:
	room_sheet = PanelContainer.new()
	_dock_bottom(room_sheet, ROOM_SHEET_HEIGHT)
	room_sheet.visible = false
	add_child(room_sheet)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	room_sheet.add_child(col)

	width_slider = _add_labeled_slider(col, "Width", 120.0, 900.0)
	width_slider.value_changed.connect(_on_room_size_changed)
	height_slider = _add_labeled_slider(col, "Height", 120.0, 1400.0)
	height_slider.value_changed.connect(_on_room_size_changed)

	width_wave_check = CheckBox.new()
	width_wave_check.text = "Animate width with a sine wave"
	col.add_child(width_wave_check)
	width_amp_slider = _add_labeled_slider(col, "W Amount", 0.0, 300.0)
	width_period_slider = _add_labeled_slider(col, "W Period (s)", 1.0, 20.0)
	width_wave_check.toggled.connect(func(_v): _on_room_wave_changed())
	width_amp_slider.value_changed.connect(func(_v): _on_room_wave_changed())
	width_period_slider.value_changed.connect(func(_v): _on_room_wave_changed())

	height_wave_check = CheckBox.new()
	height_wave_check.text = "Animate height with a sine wave"
	col.add_child(height_wave_check)
	height_amp_slider = _add_labeled_slider(col, "H Amount", 0.0, 300.0)
	height_period_slider = _add_labeled_slider(col, "H Period (s)", 1.0, 20.0)
	height_wave_check.toggled.connect(func(_v): _on_room_wave_changed())
	height_amp_slider.value_changed.connect(func(_v): _on_room_wave_changed())
	height_period_slider.value_changed.connect(func(_v): _on_room_wave_changed())

	# set_value_no_signal, not `.value =`: assigning `.value` fires
	# value_changed immediately, and _on_room_size_changed reads *both*
	# sliders' current value every time it runs -- assigning width first
	# would fire it while height_slider still held its just-constructed
	# default, clobbering main.room.base_height with that stale value
	# before this line ever gets to read it back out.
	width_slider.set_value_no_signal(main.room.base_width)
	height_slider.set_value_no_signal(main.room.base_height)
	width_period_slider.set_value_no_signal(6.0)
	height_period_slider.set_value_no_signal(6.0)

func _on_room_size_changed(_v: float) -> void:
	main.room.set_base_size(width_slider.value, height_slider.value)

## Rebuilds the room's behavior list from scratch from the two checkbox/
## slider groups above -- simplest correct way to keep "0, 1, or 2
## RoomBehaviors attached" in sync with two independent toggles, and
## cheap enough (at most two objects) to just do on every change.
func _on_room_wave_changed() -> void:
	main.room.behaviors.clear()
	if width_wave_check.button_pressed:
		var w := SineSizeRoomBehavior.new()
		w.axis = "width"
		w.amplitude = width_amp_slider.value
		w.period = width_period_slider.value
		main.room.behaviors.append(w)
	if height_wave_check.button_pressed:
		var h := SineSizeRoomBehavior.new()
		h.axis = "height"
		h.amplitude = height_amp_slider.value
		h.period = height_period_slider.value
		main.room.behaviors.append(h)

func on_selection_changed(item: Item) -> void:
	current_item = item
	item_sheet.visible = item != null
	if item != null:
		room_sheet.visible = false
		_updating_from_item = true
		speed_slider.value = item.data.velocity.length()
		angle_slider.value = rad_to_deg(item.data.velocity.angle())
		note_slider.value = item.data.note
		_updating_from_item = false

func on_mode_changed(mode: String) -> void:
	var is_design: bool = mode == main.MODE_DESIGN
	mode_button.text = "▶ Play" if is_design else "■ Design"
	add_button.visible = is_design
	room_button.visible = is_design
	if not is_design:
		item_sheet.visible = false
		room_sheet.visible = false

## Called the instant a drag starts on any item -- a property sheet must
## never linger over a card the player is actively repositioning.
func dismiss_sheets_for_drag() -> void:
	item_sheet.visible = false
	room_sheet.visible = false
