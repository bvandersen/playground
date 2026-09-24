extends Node

## Plays a short procedural sine-wave tone at a given frequency, on
## demand, via a small round-robin pool of AudioStreamGenerator players
## -- so several items hitting walls close together each get an
## independent voice instead of cutting each other off. No pre-rendered
## audio assets: every tone is synthesized sample-by-sample, so any
## future item can play any frequency without a sample library.

const POOL_SIZE := 8
const MIX_RATE := 44100.0
const BUFFER_LENGTH := 0.5 # seconds of headroom in each generator's buffer
const TONE_DURATION := 0.16 # seconds; short enough that fast melodies stay crisp
const AMPLITUDE := 0.5

var _players: Array = []
var _next_player: int = 0

func _ready() -> void:
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		var generator := AudioStreamGenerator.new()
		generator.mix_rate = MIX_RATE
		generator.buffer_length = BUFFER_LENGTH
		player.stream = generator
		add_child(player)
		_players.append(player)

## Synthesizes one linearly-decaying sine burst at `frequency` Hz and
## pushes it into the next player in the pool, all at once -- short
## enough (well under BUFFER_LENGTH) that the whole tone fits in the
## generator's buffer in a single call, no streaming-per-frame needed.
func play_tone(frequency: float) -> void:
	if frequency <= 0.0:
		return
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()

	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var frames_to_fill: int = min(int(MIX_RATE * TONE_DURATION), playback.get_frames_available())
	var increment := TAU * frequency / MIX_RATE
	var phase := 0.0
	for i in range(frames_to_fill):
		var envelope: float = 1.0 - float(i) / float(frames_to_fill)
		var sample: float = sin(phase) * AMPLITUDE * envelope
		playback.push_frame(Vector2(sample, sample))
		phase += increment
