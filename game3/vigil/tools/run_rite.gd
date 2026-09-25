extends SceneTree

## Runs one recipe's engine headless and prints its outcome:
##   godot --headless --path game3/vigil -s tools/run_rite.gd -- free.breath.001 \
##         [--fake "tilt=0,0;still=1"] [--seconds 300] [--seed 1]
## Simulated time runs fast (fixed steps, not the wall clock). --fake is
## parsed and handed to Senses once Phase 1 adds it.

const STEP := 1.0 / 30.0

var rite # untyped: a static Ritual reference would compile before the autoloads exist
var outcome := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: -- <recipe id> [--fake spec] [--seconds N] [--seed N]")
		quit(2)
		return
	var id: String = args[0]
	var seconds := 300.0
	var seed := 1
	var fake := ""
	for i in range(1, args.size() - 1):
		match args[i]:
			"--seconds": seconds = float(args[i + 1])
			"--seed": seed = int(args[i + 1])
			"--fake": fake = args[i + 1]
	# Autoloads are added after _initialize; wait one frame for them.
	await process_frame
	var registry = root.get_node("Registry")
	var recipe: Dictionary = registry.get_recipe(id)
	if recipe.is_empty():
		print("outcome: unknown recipe %s" % id)
		quit(2)
		return
	rite = registry.instantiate(recipe, seed)
	rite.finished.connect(func(o): outcome = o)
	root.add_child(rite)
	rite.set_process(false) # stepped by hand below
	rite.begin()
	var t := 0.0
	while t < seconds and outcome == "":
		rite._process(STEP)
		t += STEP
	if outcome == "":
		outcome = "timeout"
	print("recipe: %s  engine: %s  simulated: %.1fs  payoff: %s  fake: %s" % [id, recipe["engine"], t, rite.payoff_reached(), fake])
	print("outcome: %s" % outcome)
	quit(0 if outcome == "done" else 1)
