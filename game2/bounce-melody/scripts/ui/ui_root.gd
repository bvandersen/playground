extends Control
class_name UIRoot

## Every panel here *floats over* the canvas and can be hidden -- no
## panel ever docks in a way that shrinks the design/play area, so a
## drag started anywhere on the canvas always works (see docs/game2.md,
## "Design-mode UI, built for a small phone screen first"). The root
## Control itself ignores mouse input (MOUSE_FILTER_IGNORE) so a tap that
## isn't on a visible panel falls straight through to Main's own
## _unhandled_input, which is what drives selection/dragging.
##
## Bottom sheets size themselves to their content (_fit_bottom), and
## every numeric setting is a NumberField: a slider plus a box you can
## type an exact value into.

const TOP_STRIP_HEIGHT := 56.0
const SAVE_LIST_MAX_HEIGHT := 170.0

const PALETTE := [
	Color(0.95, 0.65, 0.25), Color(0.35, 0.82, 0.78), Color(0.85, 0.22, 0.31),
	Color(0.56, 0.48, 0.85), Color(0.44, 0.75, 0.36), Color(0.88, 0.56, 0.82),
]

var main: Node

var top_strip: PanelContainer
var mode_button: Button
var add_button: Button
var room_button: Button
var saves_button: Button

var item_sheet: PanelContainer
var vx_field: NumberField
var vy_field: NumberField
var speed_field: NumberField
var angle_field: NumberField
var root_option: OptionButton
var scale_option: OptionButton
var note_option: OptionButton
var note_label: Label
var hz_field: NumberField
var _scale_midis: Array = []

var room_sheet: PanelContainer
var width_field: NumberField
var height_field: NumberField
var wave_checks := {}
var wave_amp_fields := {}
var wave_period_fields := {}

var saves_sheet: PanelContainer
var slot_name_edit: LineEdit
var saves_status: Label
var saves_scroll: ScrollContainer
var saves_list: VBoxContainer
var autosave_check: CheckBox
var reset_check: CheckBox

var current_item: Item = null

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
	_build_saves_sheet()
	on_selection_changed(null)
	on_mode_changed(main.MODE_DESIGN)
	_install_web_enter_to_blur()

# --- Typing on a phone ---------------------------------------------------
#
# On the Web export, phone typing goes into a hidden HTML <input> that
# Godot's virtual keyboard support focuses -- Godot's own key handling
# only listens on the canvas, so Enter/Done never reaches the SpinBox,
# which only applies typed text on Enter or when it loses focus. So:
# Enter blurs that hidden input, and once it's blurred (Enter, or the
# keyboard dismissed) the SpinBox's focus is released, committing the
# number.

var _vk_input_seen := false

func _install_web_enter_to_blur() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		document.addEventListener('keydown', function (e) {
			var t = e.target;
			if (e.key === 'Enter' && t && t.tagName === 'INPUT' && t.id !== 'canvas') {
				t.blur();
			}
		}, true);
	""", true)

func _process(_delta: float) -> void:
	if not OS.has_feature("web"):
		return
	var owner := get_viewport().gui_get_focus_owner()
	if not (owner is LineEdit):
		_vk_input_seen = false
		return
	var typing_in_vk: bool = JavaScriptBridge.eval(
		"document.activeElement !== null && document.activeElement.tagName === 'INPUT'", true)
	if typing_in_vk:
		_vk_input_seen = true
	elif _vk_input_seen:
		_vk_input_seen = false
		owner.release_focus()

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

func _dock_bottom(control: Control) -> void:
	control.anchor_left = 0.0
	control.anchor_right = 1.0
	control.anchor_top = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	_fit_bottom.call_deferred(control)

## A bottom sheet is exactly as tall as its content -- re-run whenever
## rows are shown/hidden so it never covers more canvas than it needs.
func _fit_bottom(control: Control) -> void:
	control.offset_top = -control.get_combined_minimum_size().y

func _new_sheet_column(sheet: PanelContainer) -> VBoxContainer:
	_dock_bottom(sheet)
	sheet.visible = false
	add_child(sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	sheet.add_child(col)
	return col

func _row(parent: Node, label_text: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	if label_text != "":
		var label := Label.new()
		label.text = label_text
		label.custom_minimum_size = Vector2(78, 0)
		row.add_child(label)
	return row

## True when `screen_pos` lands on a visible panel. Main checks this
## before treating a press as a canvas tap: on the Web export a press on
## a SpinBox's text box isn't always consumed by the GUI (it still
## reaches _unhandled_input), and read as an empty-canvas tap it would
## deselect the item and hide the very sheet being edited.
func is_over_panel(screen_pos: Vector2) -> bool:
	for panel in [top_strip, item_sheet, room_sheet, saves_sheet]:
		if panel.visible and panel.get_global_rect().has_point(screen_pos):
			return true
	return false

func _show_sheet(sheet: Control) -> void:
	for s in [item_sheet, room_sheet, saves_sheet]:
		s.visible = s == sheet
	if sheet != null:
		_fit_bottom(sheet)

## Every design edit goes through here so auto-save sees it.
func _changed() -> void:
	main.mark_dirty()

# --- Top strip -----------------------------------------------------------

func _build_top_strip() -> void:
	var strip := PanelContainer.new()
	_dock_top(strip, TOP_STRIP_HEIGHT)
	add_child(strip)
	top_strip = strip

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	strip.add_child(row)

	mode_button = Button.new()
	mode_button.pressed.connect(func(): main.toggle_mode())
	row.add_child(mode_button)

	add_button = Button.new()
	add_button.text = "Add Item"
	add_button.pressed.connect(func(): main.add_item_at(Vector2.ZERO))
	row.add_child(add_button)

	room_button = Button.new()
	room_button.text = "Room"
	room_button.pressed.connect(_toggle_sheet.bind("room"))
	row.add_child(room_button)

	saves_button = Button.new()
	saves_button.text = "Save / Load"
	saves_button.pressed.connect(_toggle_sheet.bind("saves"))
	row.add_child(saves_button)

func _toggle_sheet(which: String) -> void:
	var sheet: Control = room_sheet if which == "room" else saves_sheet
	if sheet.visible:
		_show_sheet(null)
		return
	if sheet == saves_sheet:
		_refresh_saves()
	_show_sheet(sheet)

# --- Item sheet ----------------------------------------------------------

func _build_item_sheet() -> void:
	item_sheet = PanelContainer.new()
	var col := _new_sheet_column(item_sheet)

	var color_row := _row(col)
	color_row.add_theme_constant_override("separation", 8)
	for c in PALETTE:
		var swatch := ColorRect.new()
		swatch.color = c
		swatch.custom_minimum_size = Vector2(30, 30)
		swatch.mouse_filter = Control.MOUSE_FILTER_STOP
		swatch.gui_input.connect(_on_color_swatch_input.bind(c))
		color_row.add_child(swatch)

	# The velocity as a vector (also draggable on the canvas by its arrow
	# tip), plus the same thing as speed + direction.
	var vec_row := _row(col, "Vector")
	vx_field = NumberField.new("x", -Item.MAX_SPEED, Item.MAX_SPEED, 0.1, false, 0.0)
	vy_field = NumberField.new("y", -Item.MAX_SPEED, Item.MAX_SPEED, 0.1, false, 0.0)
	vx_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vy_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vec_row.add_child(vx_field)
	vec_row.add_child(vy_field)
	vx_field.value_changed.connect(func(_v): _set_velocity(Vector2(vx_field.value, vy_field.value)))
	vy_field.value_changed.connect(func(_v): _set_velocity(Vector2(vx_field.value, vy_field.value)))

	speed_field = NumberField.new("Speed", 0.0, Item.MAX_SPEED, 0.1)
	speed_field.value_changed.connect(_on_speed_changed)
	col.add_child(speed_field)

	angle_field = NumberField.new("Direction°", 0.0, 359.9, 0.1)
	angle_field.value_changed.connect(_on_angle_changed)
	col.add_child(angle_field)

	var key_row := _row(col, "Key")
	root_option = OptionButton.new()
	for n in MusicTheory.NOTE_NAMES:
		root_option.add_item(n)
	root_option.item_selected.connect(_on_key_changed)
	key_row.add_child(root_option)
	scale_option = OptionButton.new()
	for s in MusicTheory.scale_names():
		scale_option.add_item(s)
	scale_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_option.item_selected.connect(_on_key_changed)
	key_row.add_child(scale_option)

	var note_row := _row(col, "Note")
	var down := Button.new()
	down.text = "<"
	down.pressed.connect(_step_note.bind(-1))
	note_row.add_child(down)
	note_option = OptionButton.new()
	note_option.custom_minimum_size = Vector2(80, 0)
	note_option.item_selected.connect(_on_note_selected)
	note_row.add_child(note_option)
	var up := Button.new()
	up.text = ">"
	up.pressed.connect(_step_note.bind(1))
	note_row.add_child(up)
	note_label = Label.new()
	note_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_row.add_child(note_label)

	hz_field = NumberField.new("Pitch (Hz)", 20.0, 2100.0, 0.01)
	hz_field.value_changed.connect(func(v): _set_note(v, false))
	col.add_child(hz_field)

	var button_row := _row(col)
	var duplicate_button := Button.new()
	duplicate_button.text = "Duplicate"
	duplicate_button.pressed.connect(_on_duplicate_pressed)
	button_row.add_child(duplicate_button)
	var delete_button := Button.new()
	delete_button.text = "Delete"
	delete_button.pressed.connect(_on_delete_pressed)
	button_row.add_child(delete_button)

	_rebuild_note_options()

func _on_duplicate_pressed() -> void:
	if current_item != null:
		main.duplicate_item(current_item)

func _on_delete_pressed() -> void:
	if current_item != null:
		main.remove_item(current_item)

func _on_color_swatch_input(event: InputEvent, c: Color) -> void:
	if event is InputEventMouseButton and event.pressed and current_item != null:
		current_item.data.color = c
		current_item.queue_redraw()
		_changed()

func _set_velocity(v: Vector2) -> void:
	if current_item == null:
		return
	current_item.data.velocity = v.limit_length(Item.MAX_SPEED)
	current_item.queue_redraw()
	_refresh_velocity_fields()
	_changed()

func _on_speed_changed(v: float) -> void:
	if current_item == null:
		return
	var dir := current_item.data.velocity.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.from_angle(deg_to_rad(angle_field.value))
	_set_velocity(dir * v)

func _on_angle_changed(v: float) -> void:
	if current_item == null:
		return
	var speed := current_item.data.velocity.length()
	if speed == 0.0:
		speed = 200.0
	_set_velocity(Vector2.from_angle(deg_to_rad(v)) * speed)

func _refresh_velocity_fields() -> void:
	var v := current_item.data.velocity
	vx_field.set_value_silently(v.x)
	vy_field.set_value_silently(v.y)
	speed_field.set_value_silently(v.length())
	if v.length() > 0.001:
		angle_field.set_value_silently(fposmod(rad_to_deg(v.angle()), 360.0))

func _on_key_changed(_index: int) -> void:
	main.key_root = root_option.selected
	main.scale_name = scale_option.get_item_text(scale_option.selected)
	_rebuild_note_options()
	_refresh_note_fields()
	_changed()

func _rebuild_note_options() -> void:
	_scale_midis = MusicTheory.scale_notes(main.key_root, main.scale_name)
	note_option.clear()
	for midi in _scale_midis:
		note_option.add_item(MusicTheory.note_name(midi))

func _on_note_selected(index: int) -> void:
	_set_note(MusicTheory.midi_to_hz(_scale_midis[index]), true)

## Next/previous note of the current scale above/below the item's pitch
## (works from an off-scale pitch too -- it snaps to the nearest one in
## that direction).
func _step_note(direction: int) -> void:
	if current_item == null or _scale_midis.is_empty():
		return
	var midi := MusicTheory.hz_to_midi(current_item.data.note)
	var target := -1
	for m in _scale_midis:
		if direction > 0 and m > midi + 0.01:
			target = m
			break
		if direction < 0 and m < midi - 0.01:
			target = m
	if target >= 0:
		_set_note(MusicTheory.midi_to_hz(target), true)

func _set_note(hz: float, preview: bool) -> void:
	if current_item == null:
		return
	current_item.data.note = hz
	_refresh_note_fields()
	if preview:
		ToneEngine.play_tone(hz)
	_changed()

func _refresh_note_fields() -> void:
	if current_item == null:
		return
	var hz: float = current_item.data.note
	hz_field.set_value_silently(hz)
	var midi_f := MusicTheory.hz_to_midi(hz)
	var nearest := roundi(midi_f)
	var index := _scale_midis.find(nearest) if abs(midi_f - nearest) < 0.005 else -1
	note_option.select(index)
	note_label.text = "" if index >= 0 else "~" + MusicTheory.describe_hz(hz)

# --- Room sheet ----------------------------------------------------------

func _build_room_sheet() -> void:
	room_sheet = PanelContainer.new()
	var col := _new_sheet_column(room_sheet)

	width_field = NumberField.new("Width", 120.0, 900.0)
	width_field.value_changed.connect(_on_room_size_changed)
	col.add_child(width_field)
	height_field = NumberField.new("Height", 120.0, 1400.0)
	height_field.value_changed.connect(_on_room_size_changed)
	col.add_child(height_field)

	for axis in ["width", "height"]:
		var prefix: String = "W" if axis == "width" else "H"
		var check := CheckBox.new()
		check.text = "Animate %s with a sine wave" % axis
		check.toggled.connect(func(_v): _on_room_wave_changed())
		col.add_child(check)
		var amp := NumberField.new(prefix + " Amount", 0.0, 400.0)
		amp.value_changed.connect(func(_v): _on_room_wave_changed())
		col.add_child(amp)
		var period := NumberField.new(prefix + " Period (s)", 0.5, 30.0, 0.1)
		period.value_changed.connect(func(_v): _on_room_wave_changed())
		col.add_child(period)
		wave_checks[axis] = check
		wave_amp_fields[axis] = amp
		wave_period_fields[axis] = period

func _on_room_size_changed(_v: float) -> void:
	main.room.set_base_size(width_field.value, height_field.value)
	_changed()

func _on_room_wave_changed() -> void:
	for axis in ["width", "height"]:
		var w: Dictionary = main.room.waves[axis]
		w["enabled"] = wave_checks[axis].button_pressed
		w["amplitude"] = wave_amp_fields[axis].value
		w["period"] = wave_period_fields[axis].value
	main.room.rebuild_behaviors()
	_update_wave_visibility()
	_changed()

## Amount/period rows only show once their axis is switched on.
func _update_wave_visibility() -> void:
	for axis in ["width", "height"]:
		var on: bool = wave_checks[axis].button_pressed
		wave_amp_fields[axis].visible = on
		wave_period_fields[axis].visible = on
	if room_sheet.visible:
		_fit_bottom(room_sheet)

# --- Save / load sheet ---------------------------------------------------

func _build_saves_sheet() -> void:
	saves_sheet = PanelContainer.new()
	var col := _new_sheet_column(saves_sheet)

	var save_row := _row(col)
	slot_name_edit = LineEdit.new()
	slot_name_edit.placeholder_text = "Setup name"
	slot_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_name_edit.text_submitted.connect(func(_t): _on_save_pressed())
	save_row.add_child(slot_name_edit)
	var save_button := Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(_on_save_pressed)
	save_row.add_child(save_button)

	saves_status = Label.new()
	col.add_child(saves_status)

	saves_scroll = ScrollContainer.new()
	saves_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(saves_scroll)
	saves_list = VBoxContainer.new()
	saves_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	saves_scroll.add_child(saves_list)

	autosave_check = CheckBox.new()
	autosave_check.toggled.connect(_on_autosave_toggled)
	col.add_child(autosave_check)

	reset_check = CheckBox.new()
	reset_check.text = "Reset scene on stop (off = freeze)"
	reset_check.button_pressed = main.reset_on_stop
	reset_check.toggled.connect(_on_reset_toggled)
	col.add_child(reset_check)

func _on_save_pressed() -> void:
	var slot_name := SceneStore.sanitize_name(slot_name_edit.text)
	if slot_name == "":
		saves_status.text = "Type a name first."
	elif main.save_slot(slot_name):
		slot_name_edit.text = slot_name
		saves_status.text = "Saved \"%s\"." % slot_name
	else:
		saves_status.text = "Couldn't save \"%s\"." % slot_name
	_refresh_saves()

func _on_load_pressed(slot_name: String) -> void:
	if main.load_slot(slot_name):
		slot_name_edit.text = slot_name
		saves_status.text = "Loaded \"%s\"." % slot_name
	else:
		saves_status.text = "Couldn't load \"%s\"." % slot_name
	_refresh_saves()
	_show_sheet(saves_sheet)

func _on_delete_slot_pressed(slot_name: String) -> void:
	main.delete_slot(slot_name)
	saves_status.text = "Deleted \"%s\"." % slot_name
	_refresh_saves()

func _on_autosave_toggled(on: bool) -> void:
	main.autosave_enabled = on
	main.save_settings()
	if on:
		main.mark_dirty()

func _on_reset_toggled(on: bool) -> void:
	main.reset_on_stop = on
	main.save_settings()

func _refresh_saves() -> void:
	for child in saves_list.get_children():
		child.queue_free()
	var slots := SceneStore.list_slots()
	for slot_name in slots:
		var row := _row(saves_list)
		var label := Label.new()
		label.text = ("* " if slot_name == main.current_slot else "") + slot_name
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		row.add_child(label)
		var load_button := Button.new()
		load_button.text = "Load"
		load_button.pressed.connect(_on_load_pressed.bind(slot_name))
		row.add_child(load_button)
		var delete_button := Button.new()
		delete_button.text = "X"
		delete_button.pressed.connect(_on_delete_slot_pressed.bind(slot_name))
		row.add_child(delete_button)
	if slots.is_empty():
		var empty := Label.new()
		empty.text = "No saved setups yet."
		saves_list.add_child(empty)
	saves_scroll.custom_minimum_size.y = min(max(slots.size(), 1) * 36.0, SAVE_LIST_MAX_HEIGHT)

	var has_slot: bool = main.current_slot != ""
	autosave_check.disabled = not has_slot
	autosave_check.set_pressed_no_signal(main.autosave_enabled)
	autosave_check.text = ("Auto-save changes to \"%s\"" % main.current_slot) if has_slot \
		else "Auto-save (save or load a setup first)"
	if saves_sheet.visible:
		_fit_bottom.call_deferred(saves_sheet)

# --- Called by Main ------------------------------------------------------

## Pushes the whole model (room, key, selected item) into the controls --
## after a load or a reset-on-stop, when everything may have changed.
func sync_from_model() -> void:
	width_field.set_value_silently(main.room.base_width)
	height_field.set_value_silently(main.room.base_height)
	for axis in ["width", "height"]:
		var w: Dictionary = main.room.waves[axis]
		wave_checks[axis].set_pressed_no_signal(w["enabled"])
		wave_amp_fields[axis].set_value_silently(w["amplitude"])
		wave_period_fields[axis].set_value_silently(w["period"])
	_update_wave_visibility()
	root_option.select(main.key_root)
	scale_option.select(max(MusicTheory.scale_names().find(main.scale_name), 0))
	_rebuild_note_options()
	if current_item != null:
		_refresh_velocity_fields()
		_refresh_note_fields()

func on_selection_changed(item: Item) -> void:
	current_item = item
	if item == null:
		item_sheet.visible = false
		return
	if main.mode != main.MODE_DESIGN:
		return
	_refresh_velocity_fields()
	_refresh_note_fields()
	_show_sheet(item_sheet)

func on_mode_changed(mode: String) -> void:
	var is_design: bool = mode == main.MODE_DESIGN
	mode_button.text = "Play" if is_design else "Stop"
	add_button.visible = is_design
	room_button.visible = is_design
	saves_button.visible = is_design
	if not is_design:
		_show_sheet(null)

## Called the instant a drag starts on any item -- a property sheet must
## never linger over a card the player is actively repositioning.
func dismiss_sheets_for_drag() -> void:
	_show_sheet(null)
