extends Node2D

## Wires Room + items + UI together and owns the one thing none of them
## should own themselves: which mode the whole scene is in. Everything
## else about "what an item is" and "what a room does" lives in
## ItemData/Behavior/RoomBehavior -- this script is just plumbing.

const MODE_DESIGN := "design"
const MODE_PLAY := "play"

var mode: String = MODE_DESIGN
var room: Room
var items_layer: Node2D
var items: Array = []
var selected_item: Item = null
var ui: UIRoot

var _drag_item: Item = null
var _camera_offset := Vector2.ZERO

func _ready() -> void:
	randomize()

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

	add_item_at(Vector2(-70, -110))
	add_item_at(Vector2(80, 60))

func _center_room() -> void:
	_camera_offset = get_viewport_rect().size / 2.0
	room.position = _camera_offset
	items_layer.position = _camera_offset

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
	mode = new_mode
	if mode == MODE_DESIGN:
		room.reset_to_base()
		for item in items:
			item.position = item.data.position
	ui.on_mode_changed(mode)

func add_item_at(pos: Vector2, type: String = ItemCatalog.DEFAULT_TYPE) -> Item:
	var data := ItemCatalog.create_item_data(type, pos)
	var item := Item.new()
	items_layer.add_child(item)
	item.setup(data, ItemCatalog.make_behaviors(type))
	items.append(item)
	select_item(item)
	return item

func duplicate_item(source: Item) -> Item:
	var new_item := add_item_at(source.data.position + Vector2(26, 26), source.data.type)
	new_item.data.color = source.data.color
	new_item.data.note = source.data.note
	new_item.data.velocity = source.data.velocity
	new_item.queue_redraw()
	return new_item

func remove_item(item: Item) -> void:
	items.erase(item)
	if selected_item == item:
		select_item(null)
	item.queue_free()

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
		var world_pos := screen_pos - _camera_offset
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
		if _drag_item != null:
			_drag_item = null
			ui.on_selection_changed(selected_item)

func _handle_drag(screen_pos: Vector2) -> void:
	if _drag_item == null:
		return
	var world_pos := screen_pos - _camera_offset
	_drag_item.data.position = world_pos
	_drag_item.position = world_pos
