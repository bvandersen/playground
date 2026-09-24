extends RefCounted
class_name MusicTheory

## Real note names and real scales, so a player picks "E4 in A minor"
## instead of dragging a raw Hz slider. Everything is 12-tone equal
## temperament tuned to A4 = 440 Hz; an item still stores its pitch as a
## frequency (ItemData.note), this only translates to and from note names.

const NOTE_NAMES := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

## Semitone offsets from the root. Insertion order is the order the UI
## lists them in.
const SCALES := {
	"Major": [0, 2, 4, 5, 7, 9, 11],
	"Natural minor": [0, 2, 3, 5, 7, 8, 10],
	"Harmonic minor": [0, 2, 3, 5, 7, 8, 11],
	"Melodic minor": [0, 2, 3, 5, 7, 9, 11],
	"Major pentatonic": [0, 2, 4, 7, 9],
	"Minor pentatonic": [0, 3, 5, 7, 10],
	"Blues": [0, 3, 5, 6, 7, 10],
	"Dorian": [0, 2, 3, 5, 7, 9, 10],
	"Phrygian": [0, 1, 3, 5, 7, 8, 10],
	"Lydian": [0, 2, 4, 6, 7, 9, 11],
	"Mixolydian": [0, 2, 4, 5, 7, 9, 10],
	"Locrian": [0, 1, 3, 5, 6, 8, 10],
	"Whole tone": [0, 2, 4, 6, 8, 10],
	"Chromatic": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
}

const DEFAULT_SCALE := "Major"

## MIDI range offered by the note picker: C2 (65 Hz) .. C7 (2093 Hz).
const MIN_MIDI := 36
const MAX_MIDI := 96

static func midi_to_hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)

static func hz_to_midi(hz: float) -> float:
	return 69.0 + 12.0 * log(hz / 440.0) / log(2.0)

static func note_name(midi: int) -> String:
	return "%s%d" % [NOTE_NAMES[posmod(midi, 12)], floori(midi / 12.0) - 1]

static func scale_names() -> Array:
	return SCALES.keys()

## Every MIDI note in [MIN_MIDI, MAX_MIDI] that belongs to `scale` rooted
## on `root` (0 = C .. 11 = B), ascending.
static func scale_notes(root: int, scale: String) -> Array:
	var intervals: Array = SCALES.get(scale, SCALES[DEFAULT_SCALE])
	var notes := []
	for midi in range(MIN_MIDI, MAX_MIDI + 1):
		if intervals.has(posmod(midi - root, 12)):
			notes.append(midi)
	return notes

## "A4" for an exact note, "A4 +12c" for a frequency between notes.
static func describe_hz(hz: float) -> String:
	if hz <= 0.0:
		return "-"
	var midi_f := hz_to_midi(hz)
	var nearest := roundi(midi_f)
	var cents := roundi((midi_f - nearest) * 100.0)
	if cents == 0:
		return note_name(nearest)
	return "%s %+dc" % [note_name(nearest), cents]
