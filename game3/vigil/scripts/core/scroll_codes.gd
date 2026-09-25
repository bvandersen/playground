extends RefCounted
class_name ScrollCodes

## Enigma Scroll codes. A code is 4 glyph indices (0..11) around the ring.
##
## DEV CODES ONLY. Listed here and nowhere else -- never shown in any UI,
## never hinted at. A dev code opens that recipe without sealing the day.
## Earned codes (Phase 7) will live elsewhere.

const DEV := {
	"0-6-3-9": "free.breath.001",
	"0-6-3-10": "free.breath.002",
	"0-6-3-11": "deep.breath.001",
	"0-6-4-9": "free.glyph.001",
	"0-6-4-10": "free.glyph.002",
	"0-6-4-11": "deep.glyph.001",
}

static func key(glyphs: Array) -> String:
	return "-".join(glyphs.map(func(g): return str(g)))

## Recipe id for an entered sequence, or "".
static func lookup(glyphs: Array) -> String:
	return DEV.get(key(glyphs), "")
