extends SceneTree

## End to end, headless and fast-forwarded: boot Main, tap the threshold,
## let today's rite run, expect the seal screen and a sealed day; then boot
## again and expect the seal screen straight away. First, a dev scroll
## code must run its rite without sealing. Run with a throwaway
## save: VIGIL_SAVE=/tmp/x.json godot --headless --path game3/vigil -s tools/flow_test.gd

const SPEED := 40.0

func _initialize() -> void:
	if OS.get_environment("VIGIL_SAVE") == "":
		print("flow: refusing to run without VIGIL_SAVE (it would touch the real save)")
		quit(2)
		return
	await process_frame
	var save = root.get_node("Save")
	var daily = root.get_node("Daily")
	save.data = {}
	save._migrate()
	Engine.time_scale = SPEED

	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await create_timer(3.0).timeout
	var ok: bool = main.screen != null and main.screen.has_signal("begin_requested")

	# A dev scroll code opens its rite without sealing the day.
	main.open_scroll()
	for g in [0, 6, 3, 10]:
		main.scroll._enter(g)
	await create_timer(3.0).timeout
	var dev_id: String = main.rite.recipe["id"] if main.rite else ""
	while main.rite != null or main.busy:
		await create_timer(2.0).timeout
	await create_timer(3.0).timeout
	print("scroll rite: %s, sealed after: %s" % [dev_id, daily.is_sealed()])
	ok = ok and dev_id == "free.breath.002" and not daily.is_sealed()

	_tap(Vector2(240, 600))
	var waited := 0.0
	while not daily.is_sealed() and waited < 400.0:
		await create_timer(2.0).timeout
		waited += 2.0
	await create_timer(6.0).timeout
	ok = ok and daily.is_sealed() and main.rite == null and not main.screen.has_signal("begin_requested")
	print("after rite: sealed=%s screen=%s (%.0fs simulated)" % [daily.is_sealed(), main.screen.get_script().resource_path.get_file(), waited])
	main.free()

	save.load_file()
	var again = load("res://Main.tscn").instantiate()
	root.add_child(again)
	await create_timer(1.0).timeout
	ok = ok and again.screen.get_script().resource_path.ends_with("seal.gd")
	print("relaunch: %s" % again.screen.get_script().resource_path.get_file())
	again.free()
	print("flow: %s" % ("ok" if ok else "FAILED"))
	quit(0 if ok else 1)

func _tap(pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		root.push_input(e)
