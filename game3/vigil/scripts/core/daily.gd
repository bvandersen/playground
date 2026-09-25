extends Node

## Autoload Daily: the ritual day, its seed, the draw and the seal
## (docs/game3.md, "The daily draw"). The draw itself is a pure static
## function so tools/draw_sim.gd can run it over simulated days.

const ROLLOVER_HOUR := 4 # the ritual day starts at 04:00 local time
const OPENING_DAYS := 7
const ENGINE_COOLDOWN_DAYS := 3

## Local ritual day for a unix time, "YYYY-MM-DD".
static func ritual_day(unix: float) -> String:
	var bias_s: int = Time.get_time_zone_from_system().get("bias", 0) * 60
	var local := int(unix) + bias_s - ROLLOVER_HOUR * 3600
	return Time.get_date_string_from_unix_time(local)

static func day_number(day: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(day) / 86400)

static func day_seed(day: String, salt: String) -> int:
	return (day + ":" + salt).hash()

## Picks the recipe id for `day`.
## pool: drawable recipes; history: {day: {"rite": id, ...}} of earlier
## days (later days are ignored); opening: curated ids for the first days.
static func draw(day: String, salt: String, history: Dictionary, pool: Array, opening: Array) -> String:
	if pool.is_empty():
		return ""
	var by_id := {}
	for r in pool:
		by_id[r["id"]] = r
	var past := history.keys().filter(func(d): return d < day)
	past.sort()

	# The first week is curated, not random.
	if past.size() < OPENING_DAYS and past.size() < opening.size():
		var id: String = opening[past.size()]
		if by_id.has(id):
			return id

	# Seen = drawn since the pool was last exhausted.
	var seen := {}
	for d in past:
		var id = history[d].get("rite", "")
		if by_id.has(id):
			seen[id] = true
			if seen.size() >= by_id.size():
				seen.clear()
	var recent_engines := {}
	var today := day_number(day)
	for d in past:
		if today - day_number(d) <= ENGINE_COOLDOWN_DAYS:
			var r = by_id.get(history[d].get("rite", ""))
			if r != null:
				recent_engines[r["engine"]] = true

	# Nor the ground or typeface of the last rite: the look must not repeat.
	var last_style: Dictionary = {}
	if not past.is_empty() and by_id.has(history[past[-1]].get("rite", "")):
		last_style = by_id[history[past[-1]]["rite"]].get("style", {})
	var new_look := func(r) -> bool:
		var st: Dictionary = r.get("style", {})
		return last_style.is_empty() or (st.get("ground", "void") != last_style.get("ground", "void")
			and st.get("font", "") != last_style.get("font", ""))

	# Loosened in order while nothing is left (too few engines yet for the
	# cooldown, ...); at each level a new look is preferred.
	var levels := [
		func(r): return not seen.has(r["id"]) and not recent_engines.has(r["engine"]),
		func(r): return not seen.has(r["id"]),
		func(_r): return true,
	]
	var candidates := []
	for keep in levels:
		candidates = pool.filter(func(r): return keep.call(r) and new_look.call(r))
		if candidates.is_empty():
			candidates = pool.filter(keep)
		if not candidates.is_empty():
			break
	candidates.sort_custom(func(a, b): return a["id"] < b["id"])

	var rng := RandomNumberGenerator.new()
	rng.seed = day_seed(day, salt)
	var weights := PackedFloat32Array()
	for r in candidates:
		weights.append(float(r.get("weight", 1)))
	return candidates[rng.rand_weighted(weights)]["id"]

# --- this install -----------------------------------------------------

func today() -> String:
	return ritual_day(Time.get_unix_time_from_system())

func seed_for(day: String) -> int:
	return day_seed(day, Save.data["install_salt"])

## Today's recipe; drawn once and remembered, so reopening the app (or a
## later library change) never changes it.
func todays_recipe() -> Dictionary:
	var day := today()
	var history: Dictionary = Save.data["history"]
	var entry: Dictionary = history.get(day, {})
	var r := Registry.get_recipe(entry.get("rite", ""))
	if r.is_empty():
		var id := draw(day, Save.data["install_salt"], history, Registry.drawable(), Registry.opening)
		r = Registry.get_recipe(id)
		history[day] = {"rite": id, "sealed": false}
		Save.write()
	return r

func is_sealed(day: String = "") -> bool:
	if day == "":
		day = today()
	return Save.data["history"].get(day, {}).get("sealed", false)

func seal(day: String = "") -> void:
	if day == "":
		day = today()
	var entry: Dictionary = Save.data["history"].get(day, {})
	entry["sealed"] = true
	Save.data["history"][day] = entry
	Save.write()
