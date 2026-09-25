extends Node

## Autoload Save: the one persistent file, user://vigil.json, versioned.
## Only Daily (and later Entitlement, the Reliquary) read or write it --
## engines never do.

const DEFAULT_PATH := "user://vigil.json"
const VERSION := 1

var data: Dictionary = {}
## VIGIL_SAVE overrides the file (tools/flow_test.gd, so tests never touch
## a real save).
var path: String = OS.get_environment("VIGIL_SAVE") if OS.get_environment("VIGIL_SAVE") != "" else DEFAULT_PATH

func _ready() -> void:
	load_file()

func load_file() -> void:
	data = {}
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			data = parsed
	_migrate()

func write() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Save: cannot write %s" % path)
		return
	f.store_string(JSON.stringify(data, "\t"))

func _migrate() -> void:
	if not data.has("install_salt"):
		# 64-bit random, stored as a string so JSON's doubles can't round it.
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		data["install_salt"] = str((rng.randi() << 32) | rng.randi())
	if not data.has("history"):
		data["history"] = {}
	data["version"] = VERSION
