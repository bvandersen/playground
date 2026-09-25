extends Control
class_name UIRoot

## Same floating-panel approach as game2 (docs/game2.md, "Design-mode UI,
## built for a small phone screen first"): the root ignores input so any
## touch not on a visible panel falls through to Main, one thin strip
## along the top is the only permanent chrome, and everything else is a
## bottom sheet sized to its content that gets out of the way while you
## drag.

const TOP_STRIP_HEIGHT := 52.0
const SAVE_LIST_MAX_HEIGHT := 160.0

const HINTS := {
	"select": "Drag a train along its track. Tap a switch to flip it. Drag the ground to pan, pinch or scroll to zoom.",
	"draw": "Drag to lay track. Start or finish on a track to join it -- joining mid-track makes a switch.",
	"erase": "Tap a piece of track or a train to remove it.",
	"train": "Tap a track to put a train on it.",
	"play": "Tap a train to stop or start it. Tap a switch to flip it.",
}

var main: Node

var top_strip: PanelContainer
var mode_button: IconButton
var tool_buttons := {}
var menu_button: IconButton
var hint_panel: PanelContainer
var hint_label: Label
var undo_button: IconButton

var train_sheet: PanelContainer
var speed_field: NumberField
var running_button: IconButton
var direction_button: IconButton
var consist_grid: GridContainer
var add_car_buttons := {}

var menu_sheet: PanelContainer
var slot_name_edit: LineEdit
var saves_status: Label
var saves_scroll: ScrollContainer
var saves_list: VBoxContainer
var autosave_button: IconButton
var reset_button: IconButton

var current_train: Train = null
var _message_time := 0.0
var _undo_count := 0

func setup(main_ref: Node) -> void:
	main = main_ref
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = _make_theme()
	_build_top_strip()
	_build_hint()
	_build_train_sheet()
	_build_menu_sheet()
	on_selection_changed(null)
	on_mode_changed(main.MODE_DESIGN)
	on_tool_changed(main.tool)
	_install_web_enter_to_blur()

# --- Theme -----------------------------------------------------------------

func _box(bg: Color, radius: int = 8, pad: float = 8.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad + 2.0
	sb.content_margin_right = pad + 2.0
	sb.content_margin_top = pad * 0.6
	sb.content_margin_bottom = pad * 0.6
	sb.anti_aliasing = true
	return sb

func _make_theme() -> Theme:
	var th := Theme.new()
	var panel := _box(Color(0.07, 0.09, 0.11, 0.93), 14, 10.0)
	panel.content_margin_top = 10.0
	panel.content_margin_bottom = 12.0
	th.set_stylebox("panel", "PanelContainer", panel)
	for type in ["Button", "OptionButton"]:
		th.set_stylebox("normal", type, _box(Color(0.19, 0.22, 0.27)))
		th.set_stylebox("hover", type, _box(Color(0.24, 0.28, 0.34)))
		th.set_stylebox("pressed", type, _box(Color(0.22, 0.5, 0.33)))
		th.set_stylebox("hover_pressed", type, _box(Color(0.26, 0.56, 0.37)))
		th.set_stylebox("disabled", type, _box(Color(0.14, 0.15, 0.17)))
		th.set_stylebox("focus", type, StyleBoxEmpty.new())
		th.set_color("font_pressed_color", type, Color.WHITE)
		th.set_color("font_hover_pressed_color", type, Color.WHITE)
	th.set_color("font_color", "Label", Color(0.88, 0.9, 0.92))
	return th

# --- Typing on a phone (same fix as game2's ui_root.gd) --------------------

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

func _process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_update_hint()
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

# --- Layout helpers --------------------------------------------------------

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

func _fit_bottom(control: Control) -> void:
	control.offset_top = -control.get_combined_minimum_size().y

func _new_sheet_column(sheet: PanelContainer) -> VBoxContainer:
	_dock_bottom(sheet)
	sheet.visible = false
	add_child(sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	sheet.add_child(col)
	return col

func _row(parent: Node, label_text: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	if label_text != "":
		var label := Label.new()
		label.text = label_text
		label.custom_minimum_size = Vector2(70, 0)
		row.add_child(label)
	return row

## Every button is a picture a child can read (IconArt); the words are
## kept as its tooltip.
func _icon_button(parent: Node, id: String, tip: String, handler: Callable, expand: bool = false) -> IconButton:
	var b := IconButton.new(id, tip)
	b.pressed.connect(handler)
	if expand:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(b)
	return b

func _small_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	return l

## See game2's UIRoot.is_over_panel: on the Web export touches reach
## Main._unhandled_input even when they land on a panel.
func is_over_panel(screen_pos: Vector2) -> bool:
	for panel in [top_strip, train_sheet, menu_sheet, undo_button]:
		if panel.visible and panel.get_global_rect().has_point(screen_pos):
			return true
	return false

func _show_sheet(sheet: Control) -> void:
	for s in [train_sheet, menu_sheet]:
		s.visible = s == sheet
	if sheet != null:
		_fit_bottom(sheet)
	_update_hint()

# --- Top strip -------------------------------------------------------------

func _build_top_strip() -> void:
	top_strip = PanelContainer.new()
	var flat := _box(Color(0.07, 0.09, 0.11, 0.93), 0, 6.0)
	top_strip.add_theme_stylebox_override("panel", flat)
	_dock_top(top_strip, TOP_STRIP_HEIGHT)
	add_child(top_strip)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_strip.add_child(row)

	mode_button = _icon_button(row, "play", "Play", func(): main.toggle_mode())
	mode_button.custom_minimum_size = Vector2(62, 40)

	var group := ButtonGroup.new()
	for spec in [["select", "hand", "Select"], ["draw", "pencil", "Draw"], ["erase", "eraser", "Erase"], ["train", "train", "Add a train"]]:
		var b := IconButton.new(spec[1], spec[2])
		if spec[0] == "train":
			b.badge = "plus"
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(func(): main.set_tool(spec[0]))
		row.add_child(b)
		tool_buttons[spec[0]] = b

	menu_button = _icon_button(row, "menu", "Menu", _toggle_menu)

func _build_hint() -> void:
	hint_panel = PanelContainer.new()
	hint_panel.add_theme_stylebox_override("panel", _box(Color(0.05, 0.07, 0.09, 0.62), 10, 6.0))
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.anchor_left = 0.0
	hint_panel.anchor_right = 1.0
	hint_panel.offset_left = 10.0
	hint_panel.offset_right = -10.0
	hint_panel.offset_top = TOP_STRIP_HEIGHT + 8.0
	hint_panel.offset_bottom = TOP_STRIP_HEIGHT + 8.0
	add_child(hint_panel)
	hint_label = Label.new()
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.add_child(hint_label)

	undo_button = IconButton.new("undo", "Undo", Vector2(56, 44))
	undo_button.pressed.connect(func(): main.undo())
	undo_button.anchor_left = 1.0
	undo_button.anchor_right = 1.0
	undo_button.offset_right = -10.0
	undo_button.offset_left = -66.0
	undo_button.offset_top = TOP_STRIP_HEIGHT + 8.0
	undo_button.offset_bottom = TOP_STRIP_HEIGHT + 8.0
	undo_button.visible = false
	add_child(undo_button)

func _update_hint() -> void:
	if _message_time > 0.0:
		return
	var key: String = "play" if main.mode == main.MODE_PLAY else main.tool
	hint_label.text = HINTS.get(key, "")
	hint_panel.visible = not (train_sheet.visible or menu_sheet.visible)
	_place_hint()

func _place_hint() -> void:
	# Leave room for the Undo button on the right when it's showing.
	hint_panel.offset_right = -74.0 if undo_button.visible else -10.0

func show_message(text: String, seconds: float = 3.0) -> void:
	hint_label.text = text
	hint_panel.visible = true
	_message_time = seconds

func _toggle_menu() -> void:
	if menu_sheet.visible:
		_show_sheet(null)
		return
	_refresh_saves()
	_show_sheet(menu_sheet)

# --- Train sheet -----------------------------------------------------------

func _build_train_sheet() -> void:
	train_sheet = PanelContainer.new()
	var col := _new_sheet_column(train_sheet)

	var swatches := _row(col)
	swatches.add_theme_constant_override("separation", 7)
	for c in WagonCatalog.LIVERIES:
		var sw := ColorRect.new()
		sw.color = c
		sw.custom_minimum_size = Vector2(30, 30)
		sw.mouse_filter = Control.MOUSE_FILTER_STOP
		sw.gui_input.connect(_on_livery_input.bind(c))
		swatches.add_child(sw)

	speed_field = NumberField.new("Speed", 0.0, Train.MAX_SPEED, 1.0)
	speed_field.value_changed.connect(_on_speed_changed)
	col.add_child(speed_field)

	var actions := _row(col)
	direction_button = _icon_button(actions, "arrow_right", "Which way it sets off", _on_reverse_pressed, true)
	_icon_button(actions, "turn", "Turn around", _on_turn_pressed, true)
	running_button = IconButton.new("play", "Runs when you press Play")
	running_button.toggle_mode = true
	running_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	running_button.toggled.connect(_on_running_toggled)
	actions.add_child(running_button)

	col.add_child(_small_label("Tap a wagon to take it off:"))
	consist_grid = GridContainer.new()
	consist_grid.columns = 5
	consist_grid.add_theme_constant_override("h_separation", 5)
	consist_grid.add_theme_constant_override("v_separation", 5)
	col.add_child(consist_grid)

	col.add_child(_small_label("Tap to add a wagon at the back:"))
	var add_grid := GridContainer.new()
	add_grid.columns = 5
	add_grid.add_theme_constant_override("h_separation", 5)
	add_grid.add_theme_constant_override("v_separation", 5)
	col.add_child(add_grid)
	for type in WagonCatalog.types():
		var b := _icon_button(add_grid, "", "Add " + WagonCatalog.display_name(type), _on_add_car.bind(type), true)
		b.custom_minimum_size = Vector2(0, 36)
		b.car = {"type": type, "color": WagonCatalog.entry(type)["colors"][0], "seed": 7}
		b.badge = "plus"
		add_car_buttons[type] = b

	var bottom := _row(col)
	_icon_button(bottom, "eye", "Follow with the camera", _on_follow_pressed, true)
	_icon_button(bottom, "bin", "Delete train", _on_delete_train, true)
	_icon_button(bottom, "check", "Done", func(): main.select_train(null), true)

func _on_livery_input(event: InputEvent, c: Color) -> void:
	if event is InputEventMouseButton and event.pressed and current_train != null:
		main.set_livery(current_train, c)
		_refresh_train_fields()

func _on_speed_changed(v: float) -> void:
	if current_train != null:
		current_train.speed = v
		main.mark_dirty()

func _on_reverse_pressed() -> void:
	if current_train != null:
		current_train.direction = -current_train.direction
		_refresh_train_fields()
		main.trains_view.queue_redraw()
		main.mark_dirty()

func _on_turn_pressed() -> void:
	if current_train != null:
		main.turn_train(current_train)

func _on_running_toggled(on: bool) -> void:
	running_button.set_icon("play" if on else "pause")
	if current_train != null:
		current_train.running = on
		main.trains_view.queue_redraw()
		main.mark_dirty()

func _on_add_car(type: String) -> void:
	if current_train != null:
		main.add_car(current_train, type)

func _on_remove_car(index: int) -> void:
	if current_train != null:
		main.remove_car(current_train, index)

func _on_follow_pressed() -> void:
	if current_train != null:
		main.set_follow(current_train)
		main.select_train(null)

func _on_delete_train() -> void:
	if current_train != null:
		main.remove_train(current_train)

func _refresh_train_fields() -> void:
	var t := current_train
	speed_field.set_value_silently(t.speed)
	running_button.set_pressed_no_signal(t.running)
	running_button.set_icon("play" if t.running else "pause")
	direction_button.set_icon("arrow_right" if t.direction > 0 else "arrow_left")
	for child in consist_grid.get_children():
		consist_grid.remove_child(child)
		child.queue_free()
	for i in range(t.cars.size()):
		var b := _icon_button(consist_grid, "", "Take off the " + WagonCatalog.display_name(t.cars[i]["type"]), _on_remove_car.bind(i), true)
		b.custom_minimum_size = Vector2(0, 36)
		b.car = t.cars[i]
		b.badge = "cross"
	# The add buttons show livery wagons in this train's colours.
	for type in add_car_buttons:
		var e := WagonCatalog.entry(type)
		if e.get("livery", false):
			add_car_buttons[type].car["color"] = t.livery
			add_car_buttons[type].queue_redraw()

# --- Menu sheet (save / load / layout) -------------------------------------

func _build_menu_sheet() -> void:
	menu_sheet = PanelContainer.new()
	var col := _new_sheet_column(menu_sheet)

	var view_row := _row(col)
	_icon_button(view_row, "fit", "See everything", func(): main.fit_view(), true)
	_icon_button(view_row, "wand", "Demo layout", _on_demo_pressed, true)
	_icon_button(view_row, "bin", "Clear all", _on_clear_pressed, true)

	var save_row := _row(col)
	slot_name_edit = LineEdit.new()
	slot_name_edit.placeholder_text = "Layout name"
	slot_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_name_edit.text_submitted.connect(func(_t): _on_save_pressed())
	save_row.add_child(slot_name_edit)
	_icon_button(save_row, "save", "Save", _on_save_pressed)

	saves_status = Label.new()
	col.add_child(saves_status)

	saves_scroll = ScrollContainer.new()
	saves_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(saves_scroll)
	saves_list = VBoxContainer.new()
	saves_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	saves_scroll.add_child(saves_list)

	# On/off switches: green when on.
	var toggles := _row(col)
	autosave_button = IconButton.new("autosave", "")
	autosave_button.toggle_mode = true
	autosave_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	autosave_button.toggled.connect(_on_autosave_toggled)
	toggles.add_child(autosave_button)

	reset_button = IconButton.new("rewind", "Put trains back where they started when you press Stop")
	reset_button.toggle_mode = true
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_button.button_pressed = main.reset_on_stop
	reset_button.toggled.connect(_on_reset_toggled)
	toggles.add_child(reset_button)

func _on_demo_pressed() -> void:
	main.push_undo()
	main.load_demo()
	main.fit_view()
	_show_sheet(null)

func _on_clear_pressed() -> void:
	main.clear_all()
	_show_sheet(null)
	main.set_tool(main.TOOL_DRAW)

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
	_show_sheet(menu_sheet)

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
		_icon_button(row, "load", "Load", _on_load_pressed.bind(slot_name))
		_icon_button(row, "bin", "Delete", _on_delete_slot_pressed.bind(slot_name))
	if slots.is_empty():
		var empty := Label.new()
		empty.text = "No saved layouts yet."
		saves_list.add_child(empty)
	saves_scroll.custom_minimum_size.y = min(max(slots.size(), 1) * 46.0, SAVE_LIST_MAX_HEIGHT)

	var has_slot: bool = main.current_slot != ""
	autosave_button.disabled = not has_slot
	autosave_button.set_pressed_no_signal(main.autosave_enabled)
	autosave_button.tooltip_text = ("Auto-save changes to \"%s\"" % main.current_slot) if has_slot \
		else "Auto-save (save or load a layout first)"
	if menu_sheet.visible:
		_fit_bottom.call_deferred(menu_sheet)

# --- Called by Main --------------------------------------------------------

func on_selection_changed(t: Train) -> void:
	current_train = t
	if t == null:
		if train_sheet.visible:
			_show_sheet(null)
		return
	if main.mode != main.MODE_DESIGN:
		return
	_refresh_train_fields()
	_show_sheet(train_sheet)
	_fit_bottom.call_deferred(train_sheet)

func on_mode_changed(mode: String) -> void:
	var is_design: bool = mode == main.MODE_DESIGN
	mode_button.set_icon("play" if is_design else "stop")
	mode_button.tooltip_text = "Play" if is_design else "Stop"
	for b in tool_buttons.values():
		b.visible = is_design
	menu_button.visible = is_design
	undo_button.visible = is_design and _undo_count > 0
	if not is_design:
		_show_sheet(null)
	_update_hint()

func on_tool_changed(tool: String) -> void:
	if tool_buttons.has(tool):
		# Plain assignment (not set_pressed_no_signal) so the ButtonGroup
		# releases the previous tool; it only emits `toggled`, which nothing
		# listens to, so it can't loop back into Main.set_tool.
		tool_buttons[tool].button_pressed = true
	if tool != main.TOOL_SELECT and train_sheet.visible:
		main.select_train(null)
	_update_hint()

func on_undo_changed(count: int) -> void:
	_undo_count = count
	undo_button.visible = main.mode == main.MODE_DESIGN and count > 0
	_place_hint()

func dismiss_sheets_for_drag() -> void:
	_show_sheet(null)
