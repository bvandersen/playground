extends Node

## Sound effects (autoload `Sfx`). The clips in res://sounds/ were made
## with ElevenLabs' text-to-sound model (the prompts are in docs/game1.md)
## and trimmed to short mono WAVs; nothing is synthesised at runtime.
##
## `play` is for the UI (no position); `play_at` is for things happening
## on the layout, through AudioStreamPlayer2D so a train off to the left
## is heard on the left and one off-screen fades out. Train sounds fire
## many times a second (every chuff, every rail joint under every bogie),
## so each sound has a minimum gap between starts and a cap on how many
## copies may ring at once; past that they're simply dropped.

## key: {db = base volume, gap = min s between starts, max = voices at once}
const SOUNDS := {
	"tap": {"db": -10.0, "gap": 0.03, "max": 2},
	"switch": {"db": -4.0, "gap": 0.08, "max": 2},
	"track": {"db": -2.0, "gap": 0.08, "max": 2},
	"erase": {"db": -6.0, "gap": 0.08, "max": 2},
	"couple": {"db": -4.0, "gap": 0.08, "max": 2},
	"whistle": {"db": -8.0, "gap": 0.25, "max": 2},
	"horn": {"db": -9.0, "gap": 0.25, "max": 2},
	"brake": {"db": -14.0, "gap": 0.4, "max": 2},
	"chuff": {"db": -13.0, "gap": 0.035, "max": 5},
	"clack": {"db": -15.0, "gap": 0.04, "max": 4},
}
const VOICES_2D := 20
const VOICES_UI := 4
## How far away (in screen px, at the current zoom) a sound on the layout
## can still be heard; a bit more than half the screen so what's in view
## is always audible.
const HEAR_SCREEN_PX := 900.0

var enabled := true

var _streams := {}
var _players_2d: Array = []
var _players_ui: Array = []
var _last_start := {} # key -> Time in s
var _playing := {} # player -> key

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in SOUNDS:
		_streams[key] = load("res://sounds/%s.wav" % key)
	for i in range(VOICES_2D):
		var p := AudioStreamPlayer2D.new()
		p.attenuation = 1.6
		add_child(p)
		_players_2d.append(p)
	for i in range(VOICES_UI):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players_ui.append(p)

## A UI sound, the same in both ears.
func play(key: String, db: float = 0.0, pitch: float = 1.0) -> void:
	var p = _claim(key, _players_ui)
	if p == null:
		return
	_start(p, key, db, pitch)

## A sound at world position `pos`.
func play_at(key: String, pos: Vector2, db: float = 0.0, pitch: float = 1.0) -> void:
	var p = _claim(key, _players_2d)
	if p == null:
		return
	var zoom := 1.0
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		zoom = cam.zoom.x
	p.global_position = pos
	p.max_distance = HEAR_SCREEN_PX / maxf(zoom, 0.05)
	_start(p, key, db, pitch)

## A free player for `key`, or null if it's too soon or too many are
## already ringing. If every voice is busy, takes over the one that was
## taken over longest ago.
func _claim(key: String, pool: Array):
	if not enabled or not _streams.has(key):
		return null
	var cfg: Dictionary = SOUNDS[key]
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_start.get(key, -1.0)) < float(cfg["gap"]):
		return null
	var same := 0
	var free = null
	for p in pool:
		if p.playing:
			if _playing.get(p, "") == key:
				same += 1
		elif free == null:
			free = p
	if same >= int(cfg["max"]):
		return null
	if free == null:
		free = pool[0]
		pool.erase(free)
		pool.append(free)
	_last_start[key] = now
	return free

func _start(p, key: String, db: float, pitch: float) -> void:
	p.stream = _streams[key]
	p.volume_db = float(SOUNDS[key]["db"]) + db
	p.pitch_scale = pitch
	_playing[p] = key
	p.play()

func stop_all() -> void:
	for p in _players_2d + _players_ui:
		p.stop()
