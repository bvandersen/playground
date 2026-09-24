extends RefCounted
class_name SceneStore

## Named saved setups plus the player's persistent settings, as JSON under
## user:// -- on the Web export that's the browser's IndexedDB, so saves
## survive a page reload on the same device/browser.

const SAVE_DIR := "user://saves"
const SETTINGS_PATH := "user://settings.json"

static func sanitize_name(slot_name: String) -> String:
	return slot_name.strip_edges().validate_filename()

static func _slot_path(slot_name: String) -> String:
	return "%s/%s.json" % [SAVE_DIR, sanitize_name(slot_name)]

static func has_slot(slot_name: String) -> bool:
	return sanitize_name(slot_name) != "" and FileAccess.file_exists(_slot_path(slot_name))

## Saved slot names, most recently saved first.
static func list_slots() -> Array:
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return []
	var entries := []
	for file in dir.get_files():
		if file.get_extension() == "json":
			var path := "%s/%s" % [SAVE_DIR, file]
			entries.append([file.get_basename(), FileAccess.get_modified_time(path)])
	entries.sort_custom(func(a, b): return a[1] > b[1])
	return entries.map(func(e): return e[0])

static func save_slot(slot_name: String, state: Dictionary) -> bool:
	if sanitize_name(slot_name) == "":
		return false
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	return _write_json(_slot_path(slot_name), state)

static func load_slot(slot_name: String) -> Dictionary:
	return _read_json(_slot_path(slot_name))

static func delete_slot(slot_name: String) -> void:
	if has_slot(slot_name):
		DirAccess.remove_absolute(_slot_path(slot_name))

static func load_settings() -> Dictionary:
	return _read_json(SETTINGS_PATH)

static func save_settings(settings: Dictionary) -> void:
	_write_json(SETTINGS_PATH, settings)

static func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("SceneStore: can't write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
