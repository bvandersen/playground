extends Node2D

## Wires the stage (World), the UI and the recorder together. Owns only
## what none of them should: fitting the 9:16 stage between the top strip
## and the tool row, routing fingers to the current tool, auto-saving the
## design, and the record countdown. What a doll is, how it moves and what
## pushes it all live in Doll / Move / Force / StageTool.

const TOP_H := 58.0
const BOTTOM_H := 60.0
const SAVE_PATH := "user://scene.json"
const AUTOSAVE_DELAY := 1.0
const STATE_VERSION := 1

var world: World
var ui: UIRoot
var tool: StageTool

var _touches := {} # index -> true for touches that started on the stage
var _autosave_countdown := -1.0
var _countdown := -1.0
## Frames to wait between clearing the countdown and starting capture, so
## the last "1" is never in the video.
var _start_in_frames := -1

func _ready() -> void:
	randomize()
	world = World.new()
	add_child(world)
	world.changed.connect(mark_dirty)
	world.sfx.connect(Sfx.play_at)
	tool = ToolCatalog.all()[0]

	var layer := CanvasLayer.new()
	add_child(layer)
	ui = UIRoot.new()
	layer.add_child(ui)
	ui.setup(self)

	if not _load_scene():
		world.add_doll()
	ui.refresh_all()
	_layout()
	get_viewport().size_changed.connect(_layout)
	ImageLibrary.image_ready.connect(func(_id): mark_dirty())

func stage_rect() -> Rect2:
	return Rect2(world.base_position, World.STAGE_SIZE * world.scale.x)

## Where an open sheet's top edge is (-1 = no sheet): the stage shrinks to
## fit above it, so whatever you're editing stays in view while you edit.
var _sheet_top := -1.0

func set_sheet_top(y: float) -> void:
	_sheet_top = y
	_layout()

func _layout() -> void:
	var vp := get_viewport_rect().size
	var bottom := vp.y - BOTTOM_H
	if _sheet_top > 0.0:
		bottom = clampf(_sheet_top - 4.0, TOP_H + 120.0, bottom)
	var avail := Vector2(vp.x, bottom - TOP_H)
	var s := minf(avail.x / World.STAGE_SIZE.x, avail.y / World.STAGE_SIZE.y)
	world.scale = Vector2(s, s)
	world.base_position = Vector2((vp.x - World.STAGE_SIZE.x * s) * 0.5, TOP_H + (avail.y - World.STAGE_SIZE.y * s) * 0.5)
	world.position = world.base_position
	Recorder.update_crop(stage_rect())

func _to_stage(p: Vector2) -> Vector2:
	return (p - world.base_position) / world.scale.x

func set_tool(t: StageTool) -> void:
	for idx in _touches.keys():
		tool.release(world, idx, Vector2.ZERO)
	_touches.clear()
	tool = t

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if ui.is_over_panel(event.position) or not stage_rect().has_point(event.position):
				return
			ui.on_stage_touched()
			_touches[event.index] = true
			tool.press(world, event.index, _to_stage(event.position))
			world.show_hint = false
			ui.refresh_selection()
		elif _touches.has(event.index):
			_touches.erase(event.index)
			tool.release(world, event.index, _to_stage(event.position))
	elif event is InputEventScreenDrag and _touches.has(event.index):
		tool.drag(world, event.index, _to_stage(event.position))
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				toggle_pause()
			KEY_R:
				toggle_recording()

func toggle_pause() -> void:
	world.paused = not world.paused
	Sfx.play("scratch" if world.paused else "whistle")
	ui.refresh_toolbar()

# --- Recording ----------------------------------------------------------------

func toggle_recording() -> void:
	if Recorder.recording:
		Recorder.stop()
		world.recording = false
		ui.refresh_toolbar()
		return
	if _countdown > 0.0 or _start_in_frames > 0:
		_countdown = -1.0
		_start_in_frames = -1
		ui.show_countdown("")
		world.recording = false
		ui.refresh_toolbar()
		return
	if not Recorder.supported():
		ui.flash("Recording works in the browser version (Chrome, Edge, Safari, Firefox).")
		return
	ui.close_sheets()
	world.recording = true
	world.show_hint = false
	world.paused = false
	_countdown = 3.0
	Sfx.play("beep")
	ui.refresh_toolbar()

func _process(delta: float) -> void:
	if _countdown > 0.0:
		var shown := ceili(_countdown)
		_countdown -= delta
		if _countdown <= 0.0:
			ui.show_countdown("")
			_start_in_frames = 2
		else:
			if ceili(_countdown) != shown:
				Sfx.play("beep") # 3.. 2.. 1..
			ui.show_countdown(str(ceili(_countdown)))
	elif _start_in_frames > 0:
		_start_in_frames -= 1
		if _start_in_frames == 0:
			_start_in_frames = -1
			if not Recorder.start(stage_rect()):
				world.recording = false
				ui.flash("Couldn't start recording in this browser.")
			ui.refresh_toolbar()
	if world.recording and not Recorder.recording and _countdown <= 0.0 and _start_in_frames < 0:
		# Stopped by the time limit.
		world.recording = false
		ui.refresh_toolbar()
	if Recorder.recording:
		ui.update_rec_time(Recorder.elapsed)
	if _autosave_countdown > 0.0:
		_autosave_countdown -= delta
		if _autosave_countdown <= 0.0:
			save_scene()

# --- Saving -------------------------------------------------------------------

## Every design edit (look, moves, forces, scene) comes through here; it's
## written back to user://scene.json after a moment of quiet, so a reload
## brings the same dolls back. Positions and props aren't saved -- a
## reload stands everyone back up.
func mark_dirty() -> void:
	_autosave_countdown = AUTOSAVE_DELAY

func save_scene() -> void:
	_autosave_countdown = -1.0
	var state := world.to_dict()
	state["version"] = STATE_VERSION
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(state))

func _load_scene() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (parsed is Dictionary) or (parsed.get("dolls", []) as Array).is_empty():
		return false
	world.from_dict(parsed)
	world.show_hint = false
	ImageLibrary.ensure(world.image_ids())
	return not world.dolls.is_empty()

func new_scene() -> void:
	DirAccess.remove_absolute(SAVE_PATH)
	world.reset_design()
	world.add_doll()
	world.show_hint = true
	ui.refresh_all()
	mark_dirty()

## "Surprise me": every doll gets a random look and a random mix of moves,
## and one random force goes on. The fastest way to something weird.
func chaos() -> void:
	var r := RandomNumberGenerator.new()
	r.randomize()
	for doll in world.dolls:
		doll.style.randomize_style()
		doll.head_radius = r.randf_range(30.0, 95.0)
		doll.muscle = r.randf_range(0.2, 0.8)
		for m in MoveCatalog.all():
			doll.moves[m.id]["enabled"] = m.id == "stand" or r.randf() < 0.22
		doll.rebuild_keep_place()
	var optional := ForceCatalog.all().filter(func(f): return not f.always_on and f.id != "walls")
	for f in optional:
		world.forces[f.id]["enabled"] = false
	if r.randf() < 0.7:
		var f: Force = optional[r.randi() % optional.size()]
		world.forces[f.id]["enabled"] = true
	var gradients := UIRoot.GRADIENTS
	var g: Array = gradients[r.randi() % gradients.size()]
	world.background["kind"] = "gradient"
	world.background["color"] = g[0]
	world.background["color2"] = g[1]
	Sfx.play("poof", 1.0, 0.0, 0.8)
	ui.refresh_all()
	mark_dirty()
