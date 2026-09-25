extends Node2D

## Wires Room + items + UI together and owns the one thing none of them
## should own themselves: which mode the whole scene is in, plus the
## scene-wide state around it (what Play started from, saving/loading,
## the musical key). Everything else about "what an item is" and "what a
## room does" lives in ItemData/Behavior/RoomBehavior -- this script is
## just plumbing.

const MODE_DESIGN := "design"
const MODE_PLAY := "play"

const STATE_VERSION := 1
const AUTOSAVE_DELAY := 0.8 # seconds of quiet after an edit before auto-saving
const VECTOR_HANDLE_RADIUS := 16.0

var mode: String = MODE_DESIGN
var room: Room
var items_layer: Node2D
var items: Array = []
var selected_item: Item = null
var ui: UIRoot

## Scene-wide musical key the note picker offers notes from.
var key_root: int = 0 # 0 = C .. 11 = B
var scale_name: String = MusicTheory.DEFAULT_SCALE

## Settings (persisted in user://settings.json, not per saved setup).
## reset_on_stop: stopping Play restores the scene to exactly what it was
## when Play was pressed. Off: the scene freezes where it stopped, and the
## next Play continues from there.
var reset_on_stop: bool = true
## Once a setup has been saved (or loaded), keep writing edits back to it.
var autosave_enabled: bool = false
var current_slot: String = ""

var _play_start_state: Dictionary = {}
var _autosave_countdown: float = -1.0

var _drag_item: Item = null
var _vector_item: Item = null
var _camera_offset := Vector2.ZERO
var _commit_tap_frame := -1

func _ready() -> void:
	randomize()
	_load_settings()

	room = Room.new()
	add_child(room)

	items_layer = Node2D.new()
	add_child(items_layer)

	var canvas_layer := CanvasLayer.new()
	add_child(canvas_layer)
	ui = UIRoot.new()
	canvas_layer.add_child(ui)
	ui.setup(self)

	_center_room()
	get_viewport().size_changed.connect(_center_room)

	if autosave_enabled and SceneStore.has_slot(current_slot):
		load_slot(current_slot)
	else:
		add_item_at(Vector2(-70, -110))
		add_item_at(Vector2(80, 60))
		ui.sync_from_model()

func _center_room() -> void:
	_camera_offset = get_viewport_rect().size / 2.0
	room.position = _camera_offset
	items_layer.position = _camera_offset

func _process(delta: float) -> void:
	if _autosave_countdown > 0.0:
		_autosave_countdown = max(_autosave_countdown - delta, 0.001)
		if _autosave_countdown <= 0.001:
			_flush_autosave()

func _physics_process(delta: float) -> void:
	if mode != MODE_PLAY:
		return
	room.tick(delta)
	for item in items:
		for b in item.behaviors:
			b.physics_step(item, delta, room)

func toggle_mode() -> void:
	set_mode(MODE_PLAY if mode == MODE_DESIGN else MODE_DESIGN)

func set_mode(new_mode: String) -> void:
	if new_mode == mode:
		return
	if new_mode == MODE_PLAY:
		# Whatever is on screen right now -- fresh, reset, frozen, or edited
		# since -- is what this run starts from and what a reset returns to.
		_flush_autosave()
		_drag_item = null
		_vector_item = null
		_play_start_state = capture_state(true)
	mode = new_mode
	if mode == MODE_DESIGN:
		if reset_on_stop and not _play_start_state.is_empty():
			apply_state(_play_start_state)
		else:
			# Frozen in place: the stopped positions/velocities are the new
			# design, so they're what gets auto-saved.
			for item in items:
				item.position = item.data.position
			mark_dirty()
	for item in items:
		item.set_show_vector(mode == MODE_DESIGN)
	ui.on_mode_changed(mode)
	if mode == MODE_DESIGN:
		# Brings the selected item's sheet back with its (possibly frozen,
		# mid-flight) values.
		ui.on_selection_changed(selected_item)

## --- Scene state (save/load and the Play-start snapshot) ---------------

## `include_runtime` also captures the room's live animation phase and the
## selection -- needed to put a frozen scene back exactly, not needed in a
## saved setup (which always loads at the room's base size).
func capture_state(include_runtime: bool = false) -> Dictionary:
	var state := {
		"version": STATE_VERSION,
		"room": room.to_dict(),
		"key_root": key_root,
		"scale": scale_name,
		"items": items.map(func(item): return item.data.to_dict()),
	}
	if include_runtime:
		state["runtime"] = {
			"elapsed": room.elapsed,
			"width": room.width,
			"height": room.height,
			"selected": items.find(selected_item),
		}
	return state

func apply_state(state: Dictionary) -> void:
	_drag_item = null
	_vector_item = null
	for item in items:
		item.queue_free()
	items.clear()
	selected_item = null

	room.from_dict(state.get("room", {}))
	key_root = posmod(int(state.get("key_root", key_root)), 12)
	var saved_scale := str(state.get("scale", scale_name))
	scale_name = saved_scale if MusicTheory.SCALES.has(saved_scale) else MusicTheory.DEFAULT_SCALE

	for item_dict in state.get("items", []):
		if item_dict is Dictionary:
			_spawn_item(ItemData.from_dict(item_dict))

	var runtime = state.get("runtime", {})
	var to_select: Item = null
	if runtime is Dictionary and not runtime.is_empty():
		room.elapsed = float(runtime.get("elapsed", 0.0))
		room.width = float(runtime.get("width", room.base_width))
		room.height = float(runtime.get("height", room.base_height))
		room.queue_redraw()
		var sel := int(runtime.get("selected", -1))
		if sel >= 0 and sel < items.size():
			to_select = items[sel]
	for item in items:
		item.set_show_vector(mode == MODE_DESIGN)
	select_item(to_select)
	ui.sync_from_model()

func save_slot(slot_name: String) -> bool:
	var clean := SceneStore.sanitize_name(slot_name)
	if clean == "" or not SceneStore.save_slot(clean, capture_state()):
		return false
	current_slot = clean
	_autosave_countdown = -1.0
	save_settings()
	return true

func load_slot(slot_name: String) -> bool:
	var state := SceneStore.load_slot(slot_name)
	if state.is_empty():
		return false
	if mode == MODE_PLAY:
		set_mode(MODE_DESIGN)
	_play_start_state = {}
	apply_state(state)
	current_slot = SceneStore.sanitize_name(slot_name)
	_autosave_countdown = -1.0
	save_settings()
	return true

func delete_slot(slot_name: String) -> void:
	SceneStore.delete_slot(slot_name)
	if SceneStore.sanitize_name(slot_name) == current_slot:
		current_slot = ""
	save_settings()

## Every design edit calls this; with auto-save on, the current slot is
## rewritten once edits have been quiet for AUTOSAVE_DELAY.
func mark_dirty() -> void:
	if autosave_enabled and current_slot != "":
		_autosave_countdown = AUTOSAVE_DELAY

func _flush_autosave() -> void:
	if _autosave_countdown <= 0.0:
		return
	_autosave_countdown = -1.0
	if autosave_enabled and current_slot != "" and mode == MODE_DESIGN:
		SceneStore.save_slot(current_slot, capture_state())

func _load_settings() -> void:
	var s := SceneStore.load_settings()
	reset_on_stop = bool(s.get("reset_on_stop", reset_on_stop))
	autosave_enabled = bool(s.get("autosave", autosave_enabled))
	current_slot = str(s.get("current_slot", current_slot))

func save_settings() -> void:
	SceneStore.save_settings({
		"reset_on_stop": reset_on_stop,
		"autosave": autosave_enabled,
		"current_slot": current_slot,
	})

## --- Items --------------------------------------------------------------

func _spawn_item(data: ItemData) -> Item:
	var item := Item.new()
	items_layer.add_child(item)
	item.setup(data, ItemCatalog.make_behaviors(data.type))
	items.append(item)
	return item

func add_item_at(pos: Vector2, type: String = ItemCatalog.DEFAULT_TYPE) -> Item:
	var item := _spawn_item(ItemCatalog.create_item_data(type, pos))
	select_item(item)
	mark_dirty()
	return item

func duplicate_item(source: Item) -> Item:
	var data := ItemData.from_dict(source.data.to_dict())
	data.position += Vector2(26, 26)
	var new_item := _spawn_item(data)
	select_item(new_item)
	mark_dirty()
	return new_item

func remove_item(item: Item) -> void:
	items.erase(item)
	if selected_item == item:
		select_item(null)
	item.queue_free()
	mark_dirty()

func select_item(item: Item) -> void:
	if selected_item != null:
		selected_item.set_selected(false)
	selected_item = item
	if selected_item != null:
		selected_item.set_selected(true)
	ui.on_selection_changed(item)

func _find_item_at(world_pos: Vector2) -> Item:
	for i in range(items.size() - 1, -1, -1):
		var item: Item = items[i]
		if world_pos.distance_to(item.data.position) <= item.data.radius + 8.0:
			return item
	return null

## --- Input --------------------------------------------------------------

## Only reached once no Control has already consumed the event (see
## UIRoot's MOUSE_FILTER_IGNORE root + MOUSE_FILTER_STOP panels) -- this
## is what lets dragging work everywhere on screen except literally on
## top of a docked panel.
func _unhandled_input(event: InputEvent) -> void:
	if mode != MODE_DESIGN:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_handle_press(mb.pressed, mb.position)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_handle_press(st.pressed, st.position)
	elif event is InputEventMouseMotion:
		_handle_drag((event as InputEventMouseMotion).position)
	elif event is InputEventScreenDrag:
		_handle_drag((event as InputEventScreenDrag).position)

func _handle_press(pressed: bool, screen_pos: Vector2) -> void:
	if pressed:
		if ui.is_over_panel(screen_pos):
			return
		# First tap off a number box being typed into just commits it (the
		# SpinBox applies its text on focus loss) and closes the keyboard,
		# without also changing the selection.
		# A touch arrives twice (ScreenTouch + its emulated mouse press, same
		# frame), so remember the frame to swallow the twin as well.
		if Engine.get_process_frames() == _commit_tap_frame:
			return
		var focused := get_viewport().gui_get_focus_owner()
		if focused is LineEdit:
			focused.release_focus()
			_commit_tap_frame = Engine.get_process_frames()
			return
		var world_pos := screen_pos - _camera_offset
		# The selected item's arrow tip is a handle: dragging it sets the
		# velocity vector directly (direction and speed at once).
		if selected_item != null:
			var tip := selected_item.data.position + selected_item.vector_tip()
			if world_pos.distance_to(tip) <= VECTOR_HANDLE_RADIUS:
				_vector_item = selected_item
				ui.dismiss_sheets_for_drag()
				return
		var hit := _find_item_at(world_pos)
		if hit != null:
			_drag_item = hit
			select_item(hit)
			ui.dismiss_sheets_for_drag()
		else:
			select_item(null)
	else:
		# Releasing a drag never changes the selection itself -- bring the
		# property sheet back for whatever's still selected (dismissed the
		# instant the drag started, on the press branch above), same as
		# tapping that item fresh would.
		if _drag_item != null or _vector_item != null:
			_drag_item = null
			_vector_item = null
			ui.on_selection_changed(selected_item)
			mark_dirty()

func _handle_drag(screen_pos: Vector2) -> void:
	var world_pos := screen_pos - _camera_offset
	if _vector_item != null:
		_vector_item.data.velocity = _vector_item.velocity_for_tip(world_pos - _vector_item.data.position)
		_vector_item.queue_redraw()
		return
	if _drag_item == null:
		return
	_drag_item.data.position = world_pos
	_drag_item.position = world_pos
