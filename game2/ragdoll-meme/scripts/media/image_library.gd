extends Node

## Photos for faces, limbs and backgrounds (autoload `ImageLibrary`).
## Every image gets a stable id -- "u" + hash of its URL, or "f" + hash of
## an uploaded file's pixels -- and is cached as a downsized PNG under
## user://images/ (IndexedDB on the Web), with a manifest of where each
## one came from, so a saved scene can always get its pictures back.
##
## Three ways in: load_url() (any image URL, pasted), pick_file() (the
## device's photo picker), and search() (free-licensed photos from
## Openverse, falling back to Wikimedia Commons).

signal image_ready(id: String)
signal image_failed(id: String, message: String)
signal search_done(query: String, results: Array)
signal search_failed(query: String, message: String)

const CACHE_DIR := "user://images"
const MANIFEST := "user://images/manifest.json"
const MAX_SIDE := 640
const THUMB_SIDE := 200
const PROXY := "https://wsrv.nl/?url=%s&w=%d&h=%d&fit=inside&output=png"

var _tex := {}
var _sources := {}
var _loading := {}
var _callbacks := {}
var _next_cb := 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	if FileAccess.file_exists(MANIFEST):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if parsed is Dictionary:
			_sources = parsed

static func id_for_url(url: String) -> String:
	return "u" + url.strip_edges().md5_text().substr(0, 16)

func is_loading(id: String) -> bool:
	return _loading.has(id)

func source_of(id: String) -> String:
	return str(_sources.get(id, ""))

## The texture for `id`, from memory or the on-disk cache; null if it
## isn't available (yet).
func texture(id: String) -> Texture2D:
	if id == "":
		return null
	if _tex.has(id):
		return _tex[id]
	var path := "%s/%s.png" % [CACHE_DIR, id]
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			_tex[id] = ImageTexture.create_from_image(img)
			return _tex[id]
	return null

## Make sure every id is loaded -- from cache, or re-fetched from where it
## came from.
func ensure(ids: Array) -> void:
	for id in ids:
		if texture(id) == null and _sources.has(id) and not _loading.has(id):
			_fetch(id, str(_sources[id]), MAX_SIDE, true, "")

## Start loading `url`; returns its id straight away. `fallback` is tried if
## `url` can't be loaded at all (e.g. a search result's full image vs its
## thumbnail). Listen for image_ready / image_failed with that id.
func load_url(url: String, persist: bool = true, max_side: int = MAX_SIDE, fallback: String = "") -> String:
	url = url.strip_edges()
	var id := id_for_url(url)
	if texture(id) != null:
		image_ready.emit.call_deferred(id)
		return id
	if not _loading.has(id):
		_fetch(id, url, max_side, persist, fallback)
	return id

func _fetch(id: String, url: String, max_side: int, persist: bool, fallback: String) -> void:
	_loading[id] = true
	if persist:
		_sources[id] = url
	if WebBridge.ensure():
		_js_call("RagdollLoadImage", [url, max_side], func(data_url: String):
			if data_url == "" and fallback != "":
				_loading.erase(id)
				_fetch(id, fallback, max_side, persist, "")
				return
			_finish(id, _decode_data_url(data_url), persist, "Couldn't load that image (the site may block it).")
		)
		return
	_http_image(url, func(img: Image):
		if img == null:
			var proxied := PROXY % [url.uri_encode(), max_side, max_side]
			_http_image(proxied, func(img2: Image):
				if img2 == null and fallback != "":
					_loading.erase(id)
					_fetch(id, fallback, max_side, persist, "")
					return
				_finish(id, _downsize(img2, max_side), persist, "Couldn't load that image.")
			)
			return
		_finish(id, _downsize(img, max_side), persist, "")
	)

## Open the device photo picker (Web). Emits image_ready with the new id.
func pick_file() -> void:
	if not WebBridge.ensure():
		image_failed.emit("", "Picking a photo from the device works in the browser build.")
		return
	_js_call("RagdollPickImage", [MAX_SIDE], func(data_url: String):
		if data_url == "":
			return
		var img := _decode_data_url(data_url)
		if img == null:
			image_failed.emit("", "That file isn't an image I can read.")
			return
		var id := "f" + Marshalls.raw_to_base64(img.get_data().slice(0, 4096)).md5_text().substr(0, 16)
		_loading[id] = true
		_finish(id, img, true, "")
	)

func _finish(id: String, img: Image, persist: bool, error_message: String) -> void:
	_loading.erase(id)
	if img == null or img.is_empty():
		image_failed.emit(id, error_message if error_message != "" else "Couldn't load that image.")
		return
	_tex[id] = ImageTexture.create_from_image(img)
	if persist:
		img.save_png("%s/%s.png" % [CACHE_DIR, id])
		var f := FileAccess.open(MANIFEST, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(_sources))
	image_ready.emit(id)

# --- Search -----------------------------------------------------------------

## Free-to-use photos matching `query`. Emits search_done(query, results)
## with [{"title", "thumb", "url"}], or search_failed.
func search(query: String) -> void:
	query = query.strip_edges()
	if query == "":
		return
	var url := "https://api.openverse.org/v1/images/?page_size=24&mature=false&q=%s" % query.uri_encode()
	_http_json(url, func(data):
		var results := []
		if data == null:
			_search_wikimedia(query, true)
			return
		if data is Dictionary and data.get("results") is Array:
			for r in data["results"]:
				if r is Dictionary and r.get("url") is String:
					var thumb: String = r.get("thumbnail") if r.get("thumbnail") is String else r["url"]
					results.append({"title": str(r.get("title", "")), "thumb": thumb, "url": r["url"]})
		if results.is_empty():
			_search_wikimedia(query)
		else:
			search_done.emit(query, results)
	)

func _search_wikimedia(query: String, first_failed: bool = false) -> void:
	var url := ("https://commons.wikimedia.org/w/api.php?action=query&format=json&origin=*"
		+ "&generator=search&gsrnamespace=6&gsrlimit=24&prop=imageinfo&iiprop=url&iiurlwidth=%d&gsrsearch=%s") % [
		THUMB_SIDE, ("filetype:bitmap " + query).uri_encode()]
	_http_json(url, func(data):
		var results := []
		if data is Dictionary and data.get("query") is Dictionary and data["query"].get("pages") is Dictionary:
			for page in data["query"]["pages"].values():
				var info = page.get("imageinfo")
				if info is Array and not info.is_empty() and info[0].get("thumburl") is String:
					var thumb: String = info[0]["thumburl"]
					results.append({
						"title": str(page.get("title", "")).trim_prefix("File:"),
						"thumb": thumb,
						"url": thumb.replace("/%dpx-" % THUMB_SIDE, "/%dpx-" % MAX_SIDE),
					})
		if data == null and first_failed:
			search_failed.emit(query, "Photo search can't be reached right now -- paste an image link or upload one instead.")
		elif results.is_empty():
			search_failed.emit(query, "No pictures found for \"%s\"." % query)
		else:
			search_done.emit(query, results)
	)

# --- Plumbing ---------------------------------------------------------------

func _js_call(fn_name: String, args: Array, on_done: Callable) -> void:
	var key := _next_cb
	_next_cb += 1
	var cb := JavaScriptBridge.create_callback(func(js_args: Array):
		_callbacks.erase(key)
		on_done.call(str(js_args[0]) if js_args.size() > 0 else "")
	)
	_callbacks[key] = cb # keep it alive until the browser calls it
	JavaScriptBridge.get_interface("window").callv(fn_name, args + [cb])

func _http_json(url: String, on_done: Callable) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, code, _headers, body: PackedByteArray):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			on_done.call(null)
			return
		on_done.call(JSON.parse_string(body.get_string_from_utf8()))
	)
	if http.request(url) != OK:
		http.queue_free()
		on_done.call(null)

func _http_image(url: String, on_done: Callable) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, code, _headers, body: PackedByteArray):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			on_done.call(null)
			return
		on_done.call(decode_bytes(body))
	)
	if http.request(url) != OK:
		http.queue_free()
		on_done.call(null)

## Decode image bytes by sniffing their format (PNG / JPEG / WebP / BMP /
## SVG); null if it's none of those.
static func decode_bytes(b: PackedByteArray) -> Image:
	if b.size() < 12:
		return null
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if b[0] == 0x89 and b[1] == 0x50:
		err = img.load_png_from_buffer(b)
	elif b[0] == 0xFF and b[1] == 0xD8:
		err = img.load_jpg_from_buffer(b)
	elif b.slice(0, 4).get_string_from_ascii() == "RIFF" and b.slice(8, 12).get_string_from_ascii() == "WEBP":
		err = img.load_webp_from_buffer(b)
	elif b[0] == 0x42 and b[1] == 0x4D:
		err = img.load_bmp_from_buffer(b)
	elif b.slice(0, 256).get_string_from_utf8().contains("<svg"):
		err = img.load_svg_from_buffer(b)
	return img if err == OK else null

static func _decode_data_url(data_url: String) -> Image:
	var comma := data_url.find(",")
	if not data_url.begins_with("data:") or comma < 0:
		return null
	return decode_bytes(Marshalls.base64_to_raw(data_url.substr(comma + 1)))

static func _downsize(img: Image, max_side: int) -> Image:
	if img == null:
		return null
	var s := float(max_side) / maxf(img.get_width(), img.get_height())
	if s < 1.0:
		img.resize(maxi(1, int(img.get_width() * s)), maxi(1, int(img.get_height() * s)), Image.INTERPOLATE_BILINEAR)
	return img
