extends Node

## Headless physics sanity check -- no window, no browser:
##   godot4 --headless --path game2/ragdoll-meme res://tools/sim_check.tscn
## (a scene rather than a `-s` script, because autoloads -- ImageLibrary,
## EmojiCache... -- only exist when a scene runs).
## Steps a World directly and prints what a person would look at: does a
## doll stand, does it fall over without balance, can a hand be dragged
## (and the body follow), do moves and forces run without blowing up.

var _w: World

func _ready() -> void:
	var w := World.new()
	_w = w
	add_child(w)
	var d := w.add_doll()
	_run(w, 120)
	_report("stand (2s)", d)
	d.moves["stand"]["enabled"] = false
	_run(w, 180)
	_report("balance off (3s)", d)
	d.moves["stand"]["enabled"] = true
	_run(w, 240)
	_report("balance back on (4s)", d)
	w.grabs[0] = {"doll": d, "i": Skeleton.R_HAND, "from": d.pos[Skeleton.R_HAND], "to": Vector2(600, 300)}
	_run(w, 90)
	_report("right hand dragged to (600,300)", d)
	print("  hand at ", d.pos[Skeleton.R_HAND].round())
	w.grabs.clear()
	_run(w, 180)
	for m in MoveCatalog.all():
		for other in MoveCatalog.all():
			d.moves[other.id]["enabled"] = other.id == "stand" or other.id == m.id
		_run(w, 180)
		_report("move " + m.id, d)
	# Drift: a move that isn't Walk should dance on the spot, not travel.
	for combo in [["dance"], ["floss"], ["flail"], ["headbang"], ["wave"], ["dance", "flail"], ["dance", "headbang", "floss"]]:
		for other in MoveCatalog.all():
			d.moves[other.id]["enabled"] = other.id == "stand" or other.id in combo
		w.reset_scene()
		d = w.dolls[0]
		_run(w, 60)
		var x0 := d.pos[Skeleton.PELVIS].x
		var max_off := 0.0
		for k in 20:
			_run(w, 15)
			max_off = maxf(max_off, absf(d.pos[Skeleton.PELVIS].x - x0))
		print("%-34s strayed up to %d px, ended %d px away after 5s, upright=%s" % ["drift " + "+".join(combo), max_off,
			absf(d.pos[Skeleton.PELVIS].x - x0), d.pos[Skeleton.HEAD].y < d.pos[Skeleton.PELVIS].y - 60.0])
	for f in ForceCatalog.all():
		if f.always_on:
			continue
		w.forces[f.id]["enabled"] = true
		_run(w, 120)
		_report("force " + f.id, d)
		w.forces[f.id]["enabled"] = f.id == "walls"
	w.add_balloon(d, Skeleton.HEAD)
	w.add_balloon(d, Skeleton.L_HAND)
	w.add_balloon(d, Skeleton.R_HAND)
	w.add_balloon(d, Skeleton.CHEST)
	_run(w, 240)
	_report("4 balloons", d)
	w.clear_props()
	w.boom(d.pos[Skeleton.PELVIS] + Vector2(0, 40))
	_run(w, 5)
	_report("boom (after 5 ticks)", d)
	d.moves["spin"]["enabled"] = false
	w.forces["body"]["params"]["stretch"] = 1.0
	for k in 6:
		_run(w, 60)
		_report("rubber limbs t=%ds" % (k + 1), d)
	print("  arm length ", snappedf(d.pos[Skeleton.NECK].distance_to(d.pos[Skeleton.L_ELBOW]), 0.1), " (rest 75)")
	var state := w.to_dict()
	w.from_dict(JSON.parse_string(JSON.stringify(state)))
	print("round-trip dolls: ", w.dolls.size(), " same: ", JSON.stringify(w.to_dict()) == JSON.stringify(state))
	_sound_checks(w)
	get_tree().quit()

func _run(w: World, ticks: int) -> void:
	for t in ticks:
		w._physics_process(1.0 / 60.0)

## Sound events: what a few deliberate mishaps sound like (each should make
## its noise), after the per-move counts above showed which ones stay quiet.
func _sound_checks(w: World) -> void:
	print("--- sounds")
	w.reset_design()
	var d := w.add_doll()
	_run(w, 120)
	w.sounds.counts.clear()
	d.moves["stand"]["enabled"] = false
	_run(w, 240)
	print("%-34s %s" % ["fall over (balance off)", w.sounds.counts])
	d.moves["stand"]["enabled"] = true
	w.reset_scene()
	d = w.dolls[0]
	_run(w, 60)
	w.sounds.counts.clear()
	for i in Skeleton.COUNT:
		d.pos[i] += Vector2(0, -700)
		d.prev[i] = d.pos[i]
	_run(w, 120)
	print("%-34s %s" % ["dropped from 700 px", w.sounds.counts])
	w.sounds.counts.clear()
	var knee := d.pos[Skeleton.L_KNEE]
	w.grabs[0] = {"doll": d, "i": Skeleton.L_FOOT, "from": d.pos[Skeleton.L_FOOT], "to": knee + Vector2(-10, -95)}
	w.grabs[1] = {"doll": d, "i": Skeleton.L_KNEE, "from": knee, "to": knee}
	_run(w, 30)
	w.grabs.clear()
	_run(w, 60)
	print("%-34s %s" % ["knee folded back", w.sounds.counts])
	w.sounds.counts.clear()
	for i in Skeleton.COUNT:
		d.set_velocity(i, Vector2(2600, -1800), w.last_h)
	_run(w, 90)
	print("%-34s %s" % ["thrown hard", w.sounds.counts])
	var d2 := w.add_doll(null, false)
	_run(w, 60)
	w.sounds.counts.clear()
	for i in Skeleton.COUNT:
		d.set_velocity(i, (d2.pos[Skeleton.CHEST] - d.pos[Skeleton.CHEST]).normalized() * 1800.0, w.last_h)
	_run(w, 40)
	print("%-34s %s" % ["thrown into another doll", w.sounds.counts])

func _report(label: String, d: Doll) -> void:
	var ok := true
	for i in Skeleton.COUNT:
		if not d.pos[i].is_finite():
			ok = false
	var up := d.pos[Skeleton.HEAD].y < d.pos[Skeleton.PELVIS].y - 60.0
	print("%-34s pelvis %s head %s  upright=%s finite=%s grounded=%s" % [
		label, d.pos[Skeleton.PELVIS].round(), d.pos[Skeleton.HEAD].round(), up, ok, d.grounded])
	if not _w.sounds.counts.is_empty():
		print("  sounds ", _w.sounds.counts)
	_w.sounds.counts.clear()
