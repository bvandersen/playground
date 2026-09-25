extends Control
class_name UIRoot

## All the chrome, built for a phone held upright: a thin top strip (what
## to edit + REC), a tool row along the bottom (what a finger does on the
## stage), and bottom sheets that float up over the stage only while
## they're open. The stage itself is never covered by anything permanent,
## and nothing outside it ends up in a recording.
##
## Sheets for moves and forces are generated from MoveCatalog /
## ForceCatalog params -- no per-move or per-force UI code lives here.

const SHEET_FRACTION := 0.42
const ACCENT := Color("#ff2d6f")

const GRADIENTS := [
	[Color("#ffcf5c"), Color("#ff6f91")], [Color("#43e97b"), Color("#38f9d7")],
	[Color("#667eea"), Color("#764ba2")], [Color("#f093fb"), Color("#f5576c")],
	[Color("#4facfe"), Color("#00f2fe")], [Color("#fa709a"), Color("#fee140")],
	[Color("#30cfd0"), Color("#330867")], [Color("#0f0c29"), Color("#302b63")],
]
const BG_COLORS := [
	Color("#00b140"), Color("#ffffff"), Color("#111118"), Color("#ffd32a"),
	Color("#1e90ff"), Color("#ff4757"), Color("#a55eea"), Color("#ffb8d9"),
]
const FLOOR_COLORS := [
	Color("#3b2f4a"), Color("#1d1d24"), Color("#6b4f2a"), Color("#2e7d32"),
	Color("#ffffff"), Color("#00000000"),
]
const EMOJI_GRID := [
	"😎", "🤪", "😱", "🥴", "😂", "🤡", "😈", "🥸", "🤖", "👽", "💀", "🐸",
	"🐶", "🐱", "🐵", "🐷", "🦄", "🐔", "🐙", "🦖", "🐍", "🦆", "🐟", "🦐",
	"🍌", "🌭", "🥒", "🍕", "🍩", "🍉", "🥓", "🍆", "🌽", "🥖", "🧀", "🍔",
	"🔥", "⭐", "💖", "🌈", "✨", "💩", "🎉", "💎", "⚡", "❄️", "🌵", "🌸",
	"✋", "🖐️", "👍", "🤘", "🥊", "🧤", "👊", "✌️", "👟", "🦶", "👠", "🥾",
	"🧦", "🦴", "🎸", "🪩", "🧃", "🎈", "🗿", "🍑", "🥑", "🧠", "👀", "👄",
]

var main: Node

var top_strip: PanelContainer
var tool_row: PanelContainer
var rec_button: Button
var pause_button: Button
var tool_buttons := {}
var sheet_buttons := {}
var hint_label: Label
var countdown_label: Label
var _hint_time := 0.0

var sheets := {}
var _open := ""

# Look sheet state
var look_part := "head"
var look_all := false
var look_doll_label: Label
var look_editor: VBoxContainer
var look_all_check: CheckBox
var part_buttons := {}

var moves_doll_label: Label
var moves_box: VBoxContainer
var world_box: VBoxContainer
var scene_box: VBoxContainer

# Pickers
var emoji_edit: LineEdit
var _emoji_target: Callable
var _image_target: Callable
var image_query: LineEdit
var image_url: LineEdit
var image_status: Label
var image_grid: GridContainer
var _search_query := ""
var _pending_image := ""
var _return_sheet := ""

func setup(main_ref: Node) -> void:
	main = main_ref
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = _make_theme()
	_build_top_strip()
	_build_tool_row()
	_build_look_sheet()
	_build_moves_sheet()
	_build_world_sheet()
	_build_scene_sheet()
	_build_emoji_sheet()
	_build_image_sheet()
	hint_label = Label.new()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hint_label.add_theme_constant_override("outline_size", 6)
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.offset_top = -main.BOTTOM_H - 60
	hint_label.offset_bottom = -main.BOTTOM_H - 6
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint_label)
	countdown_label = Label.new()
	countdown_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_size_override("font_size", 140)
	countdown_label.add_theme_color_override("font_outline_color", Color.BLACK)
	countdown_label.add_theme_constant_override("outline_size", 24)
	countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(countdown_label)
	ImageLibrary.image_ready.connect(_on_image_ready)
	ImageLibrary.image_failed.connect(_on_image_failed)
	ImageLibrary.search_done.connect(_on_search_done)
	ImageLibrary.search_failed.connect(func(q, msg): if q == _search_query: image_status.text = msg)
	refresh_toolbar()

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.09, 0.09, 0.13, 0.94)
	panel.set_corner_radius_all(14)
	panel.set_content_margin_all(10)
	t.set_stylebox("panel", "PanelContainer", panel)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var b := StyleBoxFlat.new()
		b.set_corner_radius_all(10)
		b.content_margin_left = 9
		b.content_margin_right = 9
		b.content_margin_top = 6
		b.content_margin_bottom = 6
		match state:
			"normal", "disabled":
				b.bg_color = Color(0.2, 0.2, 0.27)
			"hover":
				b.bg_color = Color(0.27, 0.27, 0.35)
			"focus":
				b.bg_color = Color(0, 0, 0, 0)
				b.draw_center = false
			_:
				b.bg_color = ACCENT
		t.set_stylebox(state, "Button", b)
	t.set_constant("icon_max_width", "Button", 22)
	t.set_constant("h_separation", "Button", 5)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.32, 0.32, 0.42)
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	var fill := track.duplicate()
	fill.bg_color = ACCENT
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	# The two strips' icon-over-label buttons.
	t.set_type_variation("StripButton", "Button")
	t.set_font_size("font_size", "StripButton", 12)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var b: StyleBoxFlat = t.get_stylebox(state, "Button").duplicate()
		b.content_margin_left = 3
		b.content_margin_right = 3
		b.content_margin_top = 3
		b.content_margin_bottom = 2
		t.set_stylebox(state, "StripButton", b)
	var strip := panel.duplicate()
	strip.set_corner_radius_all(0)
	strip.content_margin_top = 4
	strip.content_margin_bottom = 4
	strip.content_margin_left = 4
	strip.content_margin_right = 4
	t.set_type_variation("Strip", "PanelContainer")
	t.set_stylebox("panel", "Strip", strip)
	return t

# --- Layout helpers -------------------------------------------------------------

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

func _button(parent: Node, text: String, cb: Callable, emoji: String = "") -> Button:
	var b := Button.new()
	b.text = text
	if emoji != "":
		_set_emoji_icon(b, emoji)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _set_emoji_icon(b: Button, emoji: String) -> void:
	var tex := EmojiCache.icon(emoji)
	if tex != null:
		b.icon = tex
		b.expand_icon = false
	elif b.text == "":
		b.text = emoji

func _heading(parent: Node, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color("#ffb3c9"))
	parent.add_child(l)
	return l

func _swatches(parent: Node, colors: Array, cb: Callable, size: float = 30.0) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	parent.add_child(flow)
	for c in colors:
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(size, size)
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(int(size / 2))
		sb.border_color = Color(1, 1, 1, 0.5)
		sb.set_border_width_all(2)
		for state in ["normal", "hover", "pressed", "focus"]:
			sw.add_theme_stylebox_override(state, sb)
		sw.pressed.connect(cb.bind(c))
		flow.add_child(sw)
	return flow

func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()

func _field(parent: Node, text: String, min_v: float, max_v: float, step: float, value: float, cb: Callable) -> NumberField:
	var f := NumberField.new(text, min_v, max_v, step, true, 104.0)
	f.set_value_silently(value)
	f.value_changed.connect(cb)
	parent.add_child(f)
	return f

# --- Top strip & tool row --------------------------------------------------------

func _build_top_strip() -> void:
	top_strip = PanelContainer.new()
	top_strip.theme_type_variation = "Strip"
	top_strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_strip.offset_bottom = main.TOP_H
	add_child(top_strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	top_strip.add_child(row)
	var add := _strip_button(row, "+ Doll", "🧍")
	add.pressed.connect(_add_doll)
	for s in [["look", "Look", "🎨"], ["moves", "Moves", "💃"], ["world", "Forces", "🌪️"], ["scene", "Scene", "🖼️"]]:
		var b := _strip_button(row, s[1], s[2])
		b.toggle_mode = true
		b.pressed.connect(_toggle_sheet.bind(s[0]))
		sheet_buttons[s[0]] = b
	rec_button = _strip_button(row, "REC", "🔴")
	rec_button.pressed.connect(func(): main.toggle_recording())
	rec_button.add_theme_color_override("font_color", Color.WHITE)
	for state in ["normal", "hover", "pressed"]:
		var red: StyleBoxFlat = theme.get_stylebox(state, "StripButton").duplicate()
		red.bg_color = Color("#e0243a") if state != "hover" else Color("#f03a50")
		rec_button.add_theme_stylebox_override(state, red)

func _build_tool_row() -> void:
	tool_row = PanelContainer.new()
	tool_row.theme_type_variation = "Strip"
	tool_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tool_row.offset_top = -main.BOTTOM_H
	add_child(tool_row)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	tool_row.add_child(row)
	var group := ButtonGroup.new()
	for t in ToolCatalog.all():
		var b := _strip_button(row, t.display_name, t.emoji)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = t == main.tool
		b.pressed.connect(func():
			main.set_tool(t)
			flash(t.hint))
		tool_buttons[t.id] = b
	pause_button = _strip_button(row, "Freeze", "🧊")
	pause_button.toggle_mode = true
	pause_button.pressed.connect(func():
		main.toggle_pause()
		if main.world.paused:
			flash("Frozen: drag joints to pose. Tap Freeze again to let go."))

## Icon over label, sharing the row equally -- seven of them fit a phone.
func _strip_button(parent: Node, text: String, emoji: String) -> Button:
	var b := Button.new()
	b.theme_type_variation = "StripButton"
	b.text = text
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.clip_text = true
	b.custom_minimum_size = Vector2(40, 0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tex := EmojiCache.icon(emoji)
	if tex != null:
		b.icon = tex
	parent.add_child(b)
	return b

func refresh_toolbar() -> void:
	if rec_button == null:
		return
	var rec: bool = main.world.recording
	if rec:
		hint_label.text = ""
	rec_button.text = "STOP" if rec else "REC"
	var rec_icon := EmojiCache.icon("⏹️" if rec else "🔴")
	if rec_icon != null:
		rec_button.icon = rec_icon
	pause_button.set_pressed_no_signal(main.world.paused)
	for k in sheet_buttons:
		sheet_buttons[k].disabled = rec
		sheet_buttons[k].set_pressed_no_signal(_open == k)

func update_rec_time(t: float) -> void:
	rec_button.text = "%d:%02d" % [int(t) / 60, int(t) % 60]

func show_countdown(text: String) -> void:
	countdown_label.text = text

func flash(text: String) -> void:
	if main.world.recording:
		return # the hint sits over the stage -- never let it into a video
	hint_label.text = text
	_hint_time = 3.5

func _process(delta: float) -> void:
	if _hint_time > 0.0:
		_hint_time -= delta
		hint_label.modulate.a = clamp(_hint_time, 0.0, 1.0)
		if _hint_time <= 0.0:
			hint_label.text = ""
	_process_web_keyboard()

# --- Sheets ---------------------------------------------------------------------

func _new_sheet(key: String) -> VBoxContainer:
	var sheet := PanelContainer.new()
	sheet.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.offset_bottom = -main.BOTTOM_H - 4
	sheet.visible = false
	add_child(sheet)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 7)
	scroll.add_child(col)
	sheets[key] = sheet
	return col

## Every sheet is the same height (its content scrolls), so the stage above
## it -- shrunk to fit, see Main.set_sheet_top -- doesn't jump around as
## the sheet's content changes.
func _fit_sheet(sheet: PanelContainer) -> void:
	var scroll: ScrollContainer = sheet.get_child(0)
	var h := get_viewport_rect().size.y * SHEET_FRACTION
	scroll.custom_minimum_size = Vector2(0, h)
	sheet.offset_top = sheet.offset_bottom - h - 20.0
	main.set_sheet_top(sheet.get_global_rect().position.y if sheet.visible else -1.0)

func _toggle_sheet(key: String) -> void:
	if _open == key:
		close_sheets()
	else:
		open_sheet(key)

func open_sheet(key: String) -> void:
	for k in sheets:
		sheets[k].visible = k == key
	_open = key
	match key:
		"look":
			refresh_look()
		"moves":
			refresh_moves()
		"world":
			refresh_world()
		"scene":
			refresh_scene()
	_fit_sheet.call_deferred(sheets[key])
	refresh_toolbar()

func close_sheets() -> void:
	for k in sheets:
		sheets[k].visible = false
	_open = ""
	main.set_sheet_top(-1.0)
	refresh_toolbar()

## A press over any visible chrome is the GUI's, never a stage touch.
func is_over_panel(p: Vector2) -> bool:
	for c in [top_strip, tool_row] + sheets.values():
		if c.visible and c.get_global_rect().has_point(p):
			return true
	return false

## A stage touch commits any half-typed box and closes the World/Scene
## sheets (Look and Moves stay: tapping a doll to pick which one you're
## editing is the point there).
func on_stage_touched() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	if _open in ["world", "scene"]:
		close_sheets()

func refresh_all() -> void:
	if _open != "":
		open_sheet(_open)
	refresh_toolbar()

## A tap selected a (maybe different) doll -- keep per-doll sheets on it.
var _last_selected: Doll = null
func refresh_selection() -> void:
	if main.world.selected == _last_selected:
		return
	_last_selected = main.world.selected
	if _open == "look":
		refresh_look()
	elif _open == "moves":
		refresh_moves()

func _changed() -> void:
	main.mark_dirty()

func _doll() -> Doll:
	var w: World = main.world
	if w.selected == null and not w.dolls.is_empty():
		w.selected = w.dolls[0]
	return w.selected

func _doll_header(parent: Node) -> Label:
	var row := _row(parent)
	_button(row, "<", func(): _cycle_doll(-1))
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(label)
	_button(row, ">", func(): _cycle_doll(1))
	_button(row, "Copy", func():
		var d := _doll()
		if d != null and main.world.duplicate_doll(d) == null:
			flash("That's the most dolls a stage can hold.")
		refresh_all(), "👯")
	_button(row, "", func():
		var d := _doll()
		if d != null:
			main.world.remove_doll(d)
			if main.world.dolls.is_empty():
				close_sheets()
			refresh_all(), "🗑️").tooltip_text = "Delete this doll"
	return label

func _doll_title() -> String:
	var w: World = main.world
	var d := _doll()
	if d == null:
		return "No dolls -- tap Doll to add one"
	return "Doll %d of %d" % [w.dolls.find(d) + 1, w.dolls.size()]

func _cycle_doll(dir: int) -> void:
	var w: World = main.world
	if w.dolls.is_empty():
		return
	var i := w.dolls.find(_doll())
	w.selected = w.dolls[posmod(i + dir, w.dolls.size())]
	refresh_all()

func _add_doll() -> void:
	if main.world.add_doll() == null:
		flash("That's the most dolls a stage can hold.")
		return
	flash("New doll! Style it in Look.")
	refresh_all()

# --- Look sheet -------------------------------------------------------------------

func _build_look_sheet() -> void:
	var col := _new_sheet("look")
	look_doll_label = _doll_header(col)
	var presets := HFlowContainer.new()
	presets.add_theme_constant_override("h_separation", 6)
	presets.add_theme_constant_override("v_separation", 6)
	col.add_child(presets)
	for p in DollStyle.PRESETS:
		_button(presets, DollStyle.PRESET_NAMES[p], func():
			var d := _doll()
			if d == null:
				return
			d.style.apply_preset(p)
			_changed()
			refresh_look())
	_button(presets, "Random", func():
		var d := _doll()
		if d == null:
			return
		d.style.randomize_style()
		_changed()
		refresh_look(), "🎲")
	var parts := HFlowContainer.new()
	parts.add_theme_constant_override("h_separation", 4)
	parts.add_theme_constant_override("v_separation", 4)
	col.add_child(parts)
	var group := ButtonGroup.new()
	for g in Skeleton.PART_GROUPS:
		var b := _button(parts, Skeleton.PART_NAMES[g], func():
			look_part = g
			refresh_look())
		b.toggle_mode = true
		b.button_group = group
		part_buttons[g] = b
	look_all_check = CheckBox.new()
	look_all_check.text = "Apply to whole body"
	look_all_check.toggled.connect(func(on): look_all = on)
	col.add_child(look_all_check)
	look_editor = VBoxContainer.new()
	look_editor.add_theme_constant_override("separation", 7)
	col.add_child(look_editor)

## Parts an edit goes to: the chosen one, or (with "whole body") every
## part that can take it -- the head only takes photo/emoji, never a line.
func _targets(key: String = "") -> Array:
	if not look_all:
		return [look_part]
	var out := []
	for g in Skeleton.PART_GROUPS:
		if g == "head" and key in ["line", "width", "color"]:
			continue
		out.append(g)
	return out

func _set_part(key: String, value) -> void:
	var d := _doll()
	if d == null:
		return
	var kind_key := str(value) if key == "kind" else key
	for g in _targets(kind_key):
		var p: Dictionary = d.style.parts[g]
		if key == "kind" and g == "head" and value == "line":
			continue
		if key == "kind" and g != "head" and value == "face":
			continue
		p[key] = value
	_changed()

func refresh_look() -> void:
	look_doll_label.text = _doll_title()
	for g in part_buttons:
		part_buttons[g].set_pressed_no_signal(g == look_part)
	look_all_check.set_pressed_no_signal(look_all)
	_clear(look_editor)
	var d := _doll()
	if d == null:
		return
	var part: Dictionary = d.style.get_part(look_part)
	var kinds := ["face", "emoji", "photo"] if look_part == "head" else ["line", "emoji", "photo"]
	if look_part in ["hands", "feet"]:
		kinds.append("none")
	var kind_row := _row(look_editor, "Made of")
	var names := {"face": "Face", "line": "Lines", "emoji": "Emoji", "photo": "Photo", "none": "None"}
	for k in kinds:
		var b := _button(kind_row, names[k], func():
			_set_part("kind", k)
			refresh_look())
		b.toggle_mode = true
		b.set_pressed_no_signal(part["kind"] == k)

	match part["kind"]:
		"face":
			var faces := HFlowContainer.new()
			faces.add_theme_constant_override("h_separation", 4)
			faces.add_theme_constant_override("v_separation", 4)
			look_editor.add_child(faces)
			for f in FacePainter.FACES:
				var b := _button(faces, FacePainter.NAMES[f], func():
					_set_part("face", f)
					refresh_look())
				b.toggle_mode = true
				b.set_pressed_no_signal(part["face"] == f)
			_heading(look_editor, "Skin")
			_color_row(look_editor, DollStyle.SKIN)
		"line":
			var style_flow := HFlowContainer.new()
			style_flow.add_theme_constant_override("h_separation", 4)
			style_flow.add_theme_constant_override("v_separation", 4)
			look_editor.add_child(style_flow)
			for id in LineStyles.ids():
				var b := _button(style_flow, LineStyles.NAMES[id], func():
					_set_part("line", id)
					refresh_look())
				b.toggle_mode = true
				b.set_pressed_no_signal(part["line"] == id)
			_color_row(look_editor, DollStyle.PALETTE)
			_field(look_editor, "Thickness", 2.0, 90.0, 1.0, part["width"], func(v): _set_part("width", v))
		"emoji":
			var row := _row(look_editor)
			var current := Button.new()
			current.custom_minimum_size = Vector2(52, 44)
			_set_emoji_icon(current, part["emoji"])
			current.pressed.connect(_open_emoji_for_part)
			row.add_child(current)
			_button(row, "Pick any emoji...", _open_emoji_for_part)
			var quick := HFlowContainer.new()
			quick.add_theme_constant_override("h_separation", 4)
			look_editor.add_child(quick)
			var pool: Array = DollStyle.FACE_EMOJI if look_part == "head" else (
				DollStyle.HAND_EMOJI if look_part == "hands" else (
				DollStyle.FOOT_EMOJI if look_part == "feet" else DollStyle.FUN_EMOJI))
			for e in pool.slice(0, 12):
				var b := Button.new()
				b.custom_minimum_size = Vector2(40, 40)
				_set_emoji_icon(b, e)
				b.pressed.connect(func():
					_set_part("emoji", e)
					refresh_look())
				quick.add_child(b)
			if look_part != "head":
				_field(look_editor, "Size", 8.0, 110.0, 1.0, part["width"], func(v): _set_part("width", v))
		"photo":
			var row := _row(look_editor)
			_button(row, "Search web", func(): _open_image_picker(_photo_to_part), "🔎")
			_button(row, "Upload", func():
				_image_target = _photo_to_part
				_return_sheet = "look"
				ImageLibrary.pick_file(), "📷")
			var status := Label.new()
			status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			status.add_theme_color_override("font_color", Color("#aab"))
			if part["image"] == "":
				status.text = "Search the web or paste a link (Search web), or upload -- a face works great."
			elif ImageLibrary.is_loading(part["image"]):
				status.text = "Loading photo..."
			look_editor.add_child(status)
			if look_part in ["head", "hands", "feet"]:
				_field(look_editor, "Zoom", 0.5, 4.0, 0.05, part["zoom"], func(v): _set_part("zoom", v))
				_field(look_editor, "Move x", -0.5, 0.5, 0.01, part["ox"], func(v): _set_part("ox", v))
				_field(look_editor, "Move y", -0.5, 0.5, 0.01, part["oy"], func(v): _set_part("oy", v))
			if look_part != "head":
				_field(look_editor, "Thickness", 6.0, 110.0, 1.0, part["width"], func(v): _set_part("width", v))
	if look_part == "head":
		_heading(look_editor, "Proportions")
		_field(look_editor, "Head size", 20.0, 140.0, 1.0, d.head_radius, func(v):
			d.head_radius = v
			d.rebuild_keep_place()
			_changed())
		_field(look_editor, "Doll size", 0.4, 1.8, 0.05, d.size, func(v):
			d.size = v
			d.rebuild_keep_place()
			_changed())

func _color_row(parent: Node, colors: Array) -> void:
	var flow := _swatches(parent, colors, func(c):
		_set_part("color", c))
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(44, 30)
	var d := _doll()
	picker.color = d.style.get_part(look_part)["color"] if d != null else Color.WHITE
	picker.color_changed.connect(func(c): _set_part("color", c))
	flow.add_child(picker)

func _open_emoji_for_part() -> void:
	_emoji_target = func(e: String):
		_set_part("emoji", e)
	_return_sheet = "look"
	var d := _doll()
	emoji_edit.text = d.style.get_part(look_part)["emoji"] if d != null else ""
	open_sheet("emoji")

func _photo_to_part(id: String) -> void:
	_set_part("image", id)
	_set_part("kind", "photo")

# --- Emoji picker -------------------------------------------------------------------

func _build_emoji_sheet() -> void:
	var col := _new_sheet("emoji")
	var row := _row(col)
	emoji_edit = LineEdit.new()
	emoji_edit.placeholder_text = "Type or paste any emoji"
	emoji_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	emoji_edit.text_submitted.connect(func(_t): _use_emoji(emoji_edit.text))
	row.add_child(emoji_edit)
	_button(row, "Use", func(): _use_emoji(emoji_edit.text))
	_button(row, "Back", func(): open_sheet(_return_sheet if _return_sheet != "" else "look"))
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	col.add_child(grid)
	for e in EMOJI_GRID:
		var b := Button.new()
		b.custom_minimum_size = Vector2(44, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_set_emoji_icon(b, e)
		b.pressed.connect(_use_emoji.bind(e))
		grid.add_child(b)

func _use_emoji(e: String) -> void:
	e = e.strip_edges()
	if e == "":
		return
	if _emoji_target.is_valid():
		_emoji_target.call(e)
	open_sheet(_return_sheet if _return_sheet != "" else "look")

# --- Image picker -------------------------------------------------------------------

func _build_image_sheet() -> void:
	var col := _new_sheet("image")
	var row := _row(col)
	image_query = LineEdit.new()
	image_query.placeholder_text = "Search free photos (e.g. \"cat\", \"pizza\", \"shark\")"
	image_query.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image_query.text_submitted.connect(func(_t): _search())
	row.add_child(image_query)
	_button(row, "Search", _search, "🔎")
	var url_row := _row(col)
	image_url = LineEdit.new()
	image_url.placeholder_text = "...or paste an image link"
	image_url.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image_url.text_submitted.connect(func(_t): _use_url())
	url_row.add_child(image_url)
	_button(url_row, "Use link", _use_url)
	var row2 := _row(col)
	_button(row2, "Upload from device", func(): ImageLibrary.pick_file(), "📷")
	_button(row2, "Back", func(): open_sheet(_return_sheet))
	image_status = Label.new()
	image_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	image_status.add_theme_color_override("font_color", Color("#aab"))
	col.add_child(image_status)
	image_grid = GridContainer.new()
	image_grid.columns = 4
	image_grid.add_theme_constant_override("h_separation", 6)
	image_grid.add_theme_constant_override("v_separation", 6)
	col.add_child(image_grid)

func _open_image_picker(target: Callable) -> void:
	_image_target = target
	_return_sheet = _open if _open != "image" else _return_sheet
	image_status.text = "Photos come from Openverse / Wikimedia Commons (free to use)."
	open_sheet("image")

func _search() -> void:
	_search_query = image_query.text.strip_edges()
	if _search_query == "":
		return
	image_status.text = "Searching..."
	_clear(image_grid)
	ImageLibrary.search(_search_query)

func _on_search_done(query: String, results: Array) -> void:
	if query != _search_query:
		return
	image_status.text = "Tap a picture to use it."
	_clear(image_grid)
	for r in results:
		var b := TextureButton.new()
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
		b.custom_minimum_size = Vector2(96, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = r["title"]
		image_grid.add_child(b)
		var thumb_id := ImageLibrary.load_url(r["thumb"], false, ImageLibrary.THUMB_SIDE)
		b.set_meta("thumb", thumb_id)
		var tex := ImageLibrary.texture(thumb_id)
		if tex != null:
			b.texture_normal = tex
		b.pressed.connect(func():
			image_status.text = "Loading..."
			_pending_image = ImageLibrary.load_url(r["url"], true, ImageLibrary.MAX_SIDE, r["thumb"]))

func _use_url() -> void:
	var url := image_url.text.strip_edges()
	if url == "":
		return
	if not (url.begins_with("http://") or url.begins_with("https://") or url.begins_with("data:image")):
		url = "https://" + url
	image_status.text = "Loading..."
	_pending_image = ImageLibrary.load_url(url)

func _on_image_ready(id: String) -> void:
	for b in image_grid.get_children():
		if b.get_meta("thumb", "") == id:
			b.texture_normal = ImageLibrary.texture(id)
	if id.begins_with("f") or id == _pending_image:
		_pending_image = ""
		if _image_target.is_valid():
			_image_target.call(id)
		if _open == "image":
			open_sheet(_return_sheet if _return_sheet != "" else "look")
		elif _open == "look":
			refresh_look()
		elif _open == "scene":
			refresh_scene()

func _on_image_failed(id: String, message: String) -> void:
	if id == _pending_image or id == "":
		_pending_image = ""
		if _open == "image":
			image_status.text = message
		else:
			flash(message)

# --- Moves sheet --------------------------------------------------------------------

func _build_moves_sheet() -> void:
	var col := _new_sheet("moves")
	moves_doll_label = _doll_header(col)
	moves_box = VBoxContainer.new()
	moves_box.add_theme_constant_override("separation", 6)
	col.add_child(moves_box)

func refresh_moves() -> void:
	moves_doll_label.text = _doll_title()
	_clear(moves_box)
	var d := _doll()
	if d == null:
		return
	_field(moves_box, "Muscles", 0.0, 1.0, 0.05, d.muscle, func(v):
		d.muscle = v
		_changed())
	var tip := Label.new()
	tip.text = "0 = floppy ragdoll, 1 = snappy. Mix moves freely."
	tip.add_theme_color_override("font_color", Color("#aab"))
	tip.add_theme_font_size_override("font_size", 13)
	moves_box.add_child(tip)
	for m in MoveCatalog.all():
		var state: Dictionary = d.moves[m.id]
		_catalog_entry(moves_box, m.display_name, false, state, m.params)
	var row := _row(moves_box)
	_button(row, "Copy moves to all dolls", func():
		for other in main.world.dolls:
			if other != d:
				other.moves = d.moves.duplicate(true)
		flash("Every doll now does the same moves.")
		_changed())

## One catalog entry (a Move or a Force): an on/off switch and, while on,
## a slider per declared param.
func _catalog_entry(parent: Node, title: String, always_on: bool, state: Dictionary, params: Array) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)
	var fields := VBoxContainer.new()
	fields.add_theme_constant_override("separation", 4)
	if always_on:
		_heading(box, title)
	else:
		var check := CheckBox.new()
		check.text = title
		check.button_pressed = state["enabled"]
		box.add_child(check)
		check.toggled.connect(func(on):
			state["enabled"] = on
			fields.visible = on
			_changed())
		fields.visible = state["enabled"]
	box.add_child(fields)
	for p in params:
		var pid: String = p["id"]
		_field(fields, p["name"], p["min"], p["max"], p["step"], state["params"][pid], func(v):
			state["params"][pid] = v
			_changed())

# --- World sheet --------------------------------------------------------------------

func _build_world_sheet() -> void:
	var col := _new_sheet("world")
	world_box = VBoxContainer.new()
	world_box.add_theme_constant_override("separation", 6)
	col.add_child(world_box)

func refresh_world() -> void:
	_clear(world_box)
	var w: World = main.world
	for f in ForceCatalog.all():
		_catalog_entry(world_box, f.display_name, f.always_on, w.forces[f.id], f.params)
	var row := _row(world_box)
	_button(row, "Remove pins & balloons", func():
		w.clear_props()
		flash("All pins, balloons and magnets gone."))
	_button(row, "Stand up", func():
		w.reset_scene()
		refresh_all(), "🧍")

# --- Scene sheet --------------------------------------------------------------------

func _build_scene_sheet() -> void:
	var col := _new_sheet("scene")
	scene_box = VBoxContainer.new()
	scene_box.add_theme_constant_override("separation", 7)
	col.add_child(scene_box)

func refresh_scene() -> void:
	_clear(scene_box)
	var w: World = main.world
	var big := _row(scene_box)
	var chaos := _button(big, "Surprise me!", func():
		main.chaos()
		flash("Chaos applied. Hit REC!"), "🎲")
	chaos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(big, "New scene", func():
		main.new_scene()
		flash("Fresh start."))

	_heading(scene_box, "Caption (meme text)")
	for which in ["top", "bottom"]:
		var edit := LineEdit.new()
		edit.placeholder_text = "Top text -- e.g. \"me on monday\"" if which == "top" else "Bottom text"
		edit.text = w.caption_top if which == "top" else w.caption_bottom
		edit.text_changed.connect(func(t):
			if which == "top":
				w.caption_top = t.to_upper()
			else:
				w.caption_bottom = t.to_upper()
			_changed())
		scene_box.add_child(edit)

	_heading(scene_box, "Background")
	_swatches(scene_box, GRADIENTS.map(func(g): return g[0].lerp(g[1], 0.5)), func(c):
		for g in GRADIENTS:
			if g[0].lerp(g[1], 0.5) == c:
				w.background["kind"] = "gradient"
				w.background["color"] = g[0]
				w.background["color2"] = g[1]
		_changed(), 34.0)
	_swatches(scene_box, BG_COLORS, func(c):
		w.background["kind"] = "color"
		w.background["color"] = c
		_changed(), 34.0)
	var bg_row := _row(scene_box)
	_button(bg_row, "Photo background", func(): _open_image_picker(func(id):
		w.background["kind"] = "photo"
		w.background["image"] = id
		_changed()), "🏞️")
	_button(bg_row, "Upload", func():
		_image_target = func(id):
			w.background["kind"] = "photo"
			w.background["image"] = id
			_changed()
		_return_sheet = "scene"
		ImageLibrary.pick_file(), "📷")
	_heading(scene_box, "Floor")
	_swatches(scene_box, FLOOR_COLORS, func(c):
		w.floor_color = c
		_changed())
	var wm := CheckBox.new()
	wm.text = "\"made with\" watermark"
	wm.button_pressed = w.watermark
	wm.toggled.connect(func(on):
		w.watermark = on
		_changed())
	scene_box.add_child(wm)
	var green := Label.new()
	green.text = "Tip: the green background is a green screen -- key it out in your video editor."
	green.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	green.add_theme_color_override("font_color", Color("#aab"))
	green.add_theme_font_size_override("font_size", 13)
	scene_box.add_child(green)

# --- Typing on a phone ------------------------------------------------------------
#
# Same fix as bounce-melody (docs/game2.md): on the Web export phone typing
# goes into a hidden HTML <input>, so Enter never reaches Godot. Once that
# input blurs, release the focused LineEdit so its value commits.

var _vk_input_seen := false
var _enter_hook := false

func _process_web_keyboard() -> void:
	if not OS.has_feature("web"):
		return
	if not _enter_hook:
		_enter_hook = true
		JavaScriptBridge.eval("""
			document.addEventListener('keydown', function (e) {
				var t = e.target;
				if (e.key === 'Enter' && t && t.tagName === 'INPUT' && t.id !== 'canvas' && t.type !== 'file') {
					t.blur();
				}
			}, true);
		""", true)
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
		var le := owner as LineEdit
		le.text_submitted.emit(le.text)
		owner.release_focus()
