extends Node

## Funny sound effects (autoload `Sfx`). Everything that happens on the
## stage -- a body hitting the floor, a knee bending the wrong way, a
## balloon being tied on, an explosion -- is reported as a named event
## (World.sfx, or a direct play() from the UI), and this is the one place
## that decides what that event sounds like: which clips, how loud, how
## much the pitch wobbles, and how often it may repeat.
##
## The clips (res://sfx/*.mp3) were generated with ElevenLabs' text-to-
## sound model -- see docs/game2.md, "Sound effects", for every prompt.
##
## On the Web the clips are played by the page's own Web Audio graph
## (WebBridge's RagdollSfx), not Godot's audio: the recorder can tap that
## graph and put the sound into the video. Godot's Web audio lives inside
## the engine where the page can't reach it. Elsewhere (the editor, a
## desktop build) a small pool of AudioStreamPlayers plays them instead.

const SETTINGS_PATH := "user://sound.json"
const POOL_SIZE := 12

## Event id -> how it sounds. "files" are picked at random; "db" is the
## loudness at full strength; "pitch" is the random +/- pitch wobble;
## "gap" is the minimum seconds between two plays of the same event (so a
## body bouncing on the floor is a few thuds, not a buzz). "voice" and
## "rude" events can be switched off in the Scene sheet.
const SOUNDS := {
	"thud": {"files": ["thud_1", "thud_2"], "db": -5.0, "pitch": 0.15, "gap": 0.07},
	"slam": {"files": ["slam_1", "slam_2"], "db": -2.0, "pitch": 0.12, "gap": 0.12},
	"bonk": {"files": ["bonk_1", "bonk_2"], "db": -4.0, "pitch": 0.12, "gap": 0.15},
	"crack": {"files": ["crack_1", "crack_2"], "db": -2.0, "pitch": 0.1, "gap": 0.2},
	"stretch": {"files": ["stretch"], "db": -6.0, "pitch": 0.15, "gap": 0.8},
	"ouch": {"files": ["ouch_1", "ouch_2"], "db": -4.0, "pitch": 0.1, "gap": 0.6, "voice": true},
	"scream": {"files": ["scream_1", "scream_2"], "db": -5.0, "pitch": 0.08, "gap": 1.2, "voice": true},
	"trombone": {"files": ["trombone"], "db": -5.0, "pitch": 0.03, "gap": 2.5},
	"fart": {"files": ["fart"], "db": -3.0, "pitch": 0.2, "gap": 1.0, "rude": true},
	"boing": {"files": ["boing_1", "boing_2"], "db": -6.0, "pitch": 0.15, "gap": 0.15},
	"whoosh": {"files": ["whoosh"], "db": -5.0, "pitch": 0.2, "gap": 0.15},
	"squeak": {"files": ["squeak"], "db": -9.0, "pitch": 0.2, "gap": 0.1},
	"pin": {"files": ["pin"], "db": -3.0, "pitch": 0.08, "gap": 0.05},
	"rope": {"files": ["rope"], "db": -4.0, "pitch": 0.1, "gap": 0.05},
	"boom": {"files": ["boom_1", "boom_2"], "db": -2.0, "pitch": 0.1, "gap": 0.08},
	"balloon_tie": {"files": ["balloon_tie"], "db": -5.0, "pitch": 0.15, "gap": 0.05},
	"balloon_pop": {"files": ["balloon_pop"], "db": -3.0, "pitch": 0.15, "gap": 0.03},
	"magnet": {"files": ["magnet"], "db": -6.0, "pitch": 0.05, "gap": 0.1},
	"vanish": {"files": ["vanish"], "db": -5.0, "pitch": 0.1, "gap": 0.05},
	"poof": {"files": ["poof"], "db": -4.0, "pitch": 0.1, "gap": 0.05},
	"scratch": {"files": ["scratch"], "db": -4.0, "pitch": 0.0, "gap": 0.2},
	"whistle": {"files": ["whistle"], "db": -5.0, "pitch": 0.05, "gap": 0.2},
	"beep": {"files": ["beep"], "db": -8.0, "pitch": 0.0, "gap": 0.0},
}

var enabled := true
var volume := 0.8 # 0..1
var voices := true # "ow!" and screams
var rude := true # fart jokes

var _streams := {} # file -> AudioStreamMP3
var _last := {} # event -> Time.get_ticks_msec() of its last play
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
## Web: files not yet handed to the page's Web Audio (one per frame, so the
## decode never hitches the first frame).
var _web_queue: Array = []
var _web := false

func _ready() -> void:
	_load_settings()
	var files := {}
	for id in SOUNDS:
		for f in SOUNDS[id]["files"]:
			files[f] = true
	for f in files:
		var s = load("res://sfx/%s.mp3" % f)
		if s is AudioStreamMP3:
			_streams[f] = s
	_web = WebBridge.ensure()
	if _web:
		_web_queue = _streams.keys()
		_apply_volume()
	else:
		for i in POOL_SIZE:
			var p := AudioStreamPlayer.new()
			add_child(p)
			_pool.append(p)

func _process(_delta: float) -> void:
	if _web_queue.is_empty():
		return
	var f: String = _web_queue.pop_back()
	var b64 := Marshalls.raw_to_base64((_streams[f] as AudioStreamMP3).data)
	JavaScriptBridge.eval("window.RagdollSfx.load('%s', '%s')" % [f, b64], true)

## Play event `id`. `strength` 0..1 scales the loudness (a soft landing vs
## a slam); `pan` -1..1 is left..right; `pitch` multiplies the random
## pitch (slow-mo plays everything lower, small dolls squeak higher).
func play(id: String, strength: float = 1.0, pan: float = 0.0, pitch: float = 1.0) -> void:
	if not enabled or volume <= 0.0 or not SOUNDS.has(id):
		return
	var s: Dictionary = SOUNDS[id]
	if (s.get("voice", false) and not voices) or (s.get("rude", false) and not rude):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(id, -100000)) < int(float(s["gap"]) * 1000.0):
		return
	_last[id] = now
	var files: Array = s["files"]
	var f: String = files[randi() % files.size()]
	var db: float = float(s["db"]) + linear_to_db(lerpf(0.35, 1.0, clampf(strength, 0.0, 1.0)))
	var rate: float = clampf(pitch * (1.0 + randf_range(-1.0, 1.0) * float(s["pitch"])), 0.3, 3.0)
	if _web:
		JavaScriptBridge.eval("window.RagdollSfx.play('%s', %f, %f, %f)" % [f, db_to_linear(db), rate, clampf(pan, -1.0, 1.0)], true)
		return
	if not _streams.has(f) or _pool.is_empty():
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _streams[f]
	p.volume_db = db + linear_to_db(volume)
	p.pitch_scale = rate
	p.play()

## `id` at a stage x position (0..720): panned by where it happened.
func play_at(id: String, strength: float, stage_x: float, pitch: float = 1.0) -> void:
	play(id, strength, clampf(stage_x / 360.0 - 1.0, -1.0, 1.0) * 0.6, pitch)

func set_enabled(on: bool) -> void:
	enabled = on
	_apply_volume()
	_save_settings()

func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	_apply_volume()
	_save_settings()

func set_voices(on: bool) -> void:
	voices = on
	_save_settings()

func set_rude(on: bool) -> void:
	rude = on
	_save_settings()

func _apply_volume() -> void:
	if _web:
		JavaScriptBridge.eval("window.RagdollSfx.setVolume(%f)" % (volume if enabled else 0.0), true)

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if d is Dictionary:
		enabled = bool(d.get("enabled", true))
		volume = clampf(float(d.get("volume", 0.8)), 0.0, 1.0)
		voices = bool(d.get("voices", true))
		rude = bool(d.get("rude", true))

func _save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"enabled": enabled, "volume": volume, "voices": voices, "rude": rude}))
