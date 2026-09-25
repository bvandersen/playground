extends Node2D

## Screen router: Threshold -> (fade) -> Rite -> (fade) -> Seal, with the
## Enigma Scroll as an overlay. Owns what no screen or engine should:
## deciding when a day seals, fades, and Android Back.

const Threshold := preload("res://scripts/screens/threshold.gd")
const Seal := preload("res://scripts/screens/seal.gd")
const Scroll := preload("res://scripts/screens/scroll.gd")

const FADE_TO_RITE_S := 1.5
const FADE_IN_RITE_S := 1.5
const FADE_HOME_S := 2.0
const HOME_FADE := Color("#07070a")

var screen: Node = null # threshold or seal
var rite: Ritual = null
var rite_day := "" # the ritual day a rite was drawn for; "" for a scroll rite
var scroll: Node = null
var busy := false
var shown_day := ""

var overlay := CanvasLayer.new()
var fader_layer := CanvasLayer.new()
var fader := ColorRect.new()

func _ready() -> void:
	overlay.layer = 5
	add_child(overlay)
	fader_layer.layer = 10
	add_child(fader_layer)
	fader.color = HOME_FADE
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	fader_layer.add_child(fader)

	# The day rolls over at 04:00 even with the app left open.
	var tick := Timer.new()
	tick.wait_time = 30.0
	tick.autostart = true
	tick.timeout.connect(_check_rollover)
	add_child(tick)

	show_home()
	var test_rite := Registry.get_recipe(requested_rite())
	if test_rite.is_empty():
		fade(0.0, FADE_HOME_S)
	else:
		start_rite(test_rite, "") # like a dev code: never seals

## Test links: `?rite=<recipe id>` on the Web build, `-- --rite <id>` on
## desktop. Opens that recipe straight away, any tier, without sealing.
static func requested_rite() -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--rite")
	if i >= 0 and i + 1 < args.size():
		return args[i + 1]
	if OS.has_feature("web"):
		var id = JavaScriptBridge.eval("new URLSearchParams(location.search).get('rite') || ''")
		return str(id) if id != null else ""
	return ""

func show_home() -> void:
	if screen:
		screen.queue_free()
	shown_day = Daily.today()
	Daily.todays_recipe() # fix today's draw now
	if Daily.is_sealed(shown_day):
		screen = Seal.new()
	else:
		screen = Threshold.new()
		screen.begin_requested.connect(_on_begin)
	screen.scroll_requested.connect(open_scroll)
	add_child(screen)

func _check_rollover() -> void:
	if not busy and rite == null and scroll == null and Daily.today() != shown_day:
		fader.color = Color(HOME_FADE, fader.color.a)
		await fade(1.0, 1.0)
		show_home()
		fade(0.0, FADE_HOME_S)

func fade(alpha: float, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(fader, "color:a", alpha, seconds)
	await tw.finished

func _on_begin() -> void:
	var day := Daily.today()
	start_rite(Daily.todays_recipe(), day)

func start_rite(recipe: Dictionary, day: String) -> void:
	if busy or recipe.is_empty():
		return
	busy = true
	rite_day = day
	# Into (and later out of) the rite through its own colour -- white,
	# paper, black -- the first hint of what it is.
	fader.color = Color(Style.for_recipe(recipe).fade, fader.color.a)
	await fade(1.0, FADE_TO_RITE_S)
	if screen:
		screen.queue_free()
		screen = null
	var seed := Daily.seed_for(day if day != "" else Daily.today())
	rite = Registry.instantiate(recipe, seed)
	rite.finished.connect(_on_rite_finished)
	add_child(rite)
	await fade(0.0, FADE_IN_RITE_S)
	busy = false
	rite.begin()

func _on_rite_finished(outcome: String) -> void:
	busy = true
	if rite_day != "" and (outcome == "done" or rite.payoff_reached()):
		Daily.seal(rite_day)
	await fade(1.0, FADE_HOME_S if outcome == "done" else 0.8)
	rite.queue_free()
	rite = null
	show_home()
	busy = false
	fade(0.0, FADE_HOME_S)

func open_scroll() -> void:
	if scroll or busy:
		return
	screen.propagate_call("set_process_unhandled_input", [false])
	scroll = Scroll.new()
	scroll.closed.connect(close_scroll)
	scroll.code_accepted.connect(_on_code)
	overlay.add_child(scroll)

func close_scroll() -> void:
	if scroll == null:
		return
	scroll.queue_free()
	scroll = null
	if screen:
		screen.propagate_call("set_process_unhandled_input", [true])

func _on_code(recipe_id: String) -> void:
	close_scroll()
	start_rite(Registry.get_recipe(recipe_id), "") # dev code: never seals

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and event.keycode == KEY_ESCAPE:
		back()

func back() -> void:
	if busy:
		return
	if scroll:
		close_scroll()
	elif rite:
		rite.leave()
	else:
		get_tree().quit()
