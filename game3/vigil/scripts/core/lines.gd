extends Node

## Autoload Lines: shared copy pools from data/lines/<pool>.json, each a
## dictionary of key -> array of lines. All user-facing text lives there,
## never inline in scripts (docs/game3.md, "Tone rules").

const DIR := "res://data/lines"

var _pools: Dictionary = {}

func pool(name: String) -> Dictionary:
	if not _pools.has(name):
		var path := "%s/%s.json" % [DIR, name]
		var parsed = null
		if FileAccess.file_exists(path):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			push_error("Lines: missing or invalid %s" % path)
			parsed = {}
		_pools[name] = parsed
	return _pools[name]

## One line from pool[key], chosen by seed (so the same day shows the same
## line). "" when the key is missing or empty.
func pick(name: String, key: String, seed: int = 0) -> String:
	var options = pool(name).get(key, [])
	if options is String:
		return options
	if options.is_empty():
		return ""
	return str(options[posmod(seed, options.size())])
