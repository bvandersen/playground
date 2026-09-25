extends SceneTree

## Simulates the daily draw over N consecutive ritual days for a few
## installs, completing every rite, and checks the rules in docs/game3.md:
## never a recipe the tier doesn't allow, same day + install -> same rite.
##   godot --headless --path game3/vigil -s tools/draw_sim.gd -- 30

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var days := int(args[0]) if not args.is_empty() else 30
	await process_frame
	var registry = root.get_node("Registry")
	var daily = root.get_node("Daily")
	var entitlement = root.get_node("Entitlement")
	var pool: Array = registry.drawable()
	var ok := true
	var withheld: Array = registry.recipes.values().filter(func(r): return not entitlement.allows(r["tier"]))
	print("pool: %d drawable, %d withheld by tier %s" % [pool.size(), withheld.size(), entitlement.tier()])
	if withheld.is_empty():
		print("no deep recipe exists, so the tier filter is untested"); ok = false
	for salt in ["1", "77", "123456789012345"]:
		var history := {}
		var start := int(Time.get_unix_time_from_datetime_string("2026-01-01"))
		var drawn := []
		for n in days:
			var day := Time.get_date_string_from_unix_time(start + n * 86400)
			var id: String = daily.draw(day, salt, history, pool, registry.opening)
			if id != daily.draw(day, salt, history, pool, registry.opening):
				print("not deterministic on %s" % day); ok = false
			var r: Dictionary = registry.get_recipe(id)
			if r.is_empty() or not entitlement.allows(r["tier"]):
				print("drew %s on %s, not allowed for tier %s" % [id, day, entitlement.tier()]); ok = false
			history[day] = {"rite": id, "sealed": true}
			drawn.append(id)
		var counts := {}
		for id in drawn:
			counts[id] = counts.get(id, 0) + 1
		print("salt %s: %s" % [salt, counts])
	print("draw: %s" % ("ok" if ok else "FAILED"))
	quit(0 if ok else 1)
