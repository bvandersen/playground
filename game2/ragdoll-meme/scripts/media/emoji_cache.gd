extends Node

## Emoji -> texture (autoload `EmojiCache`). Godot's own fonts have no
## emoji glyphs, so on the Web the browser draws them with the device's
## emoji font (WebBridge.RagdollEmoji) -- instant, offline, and they look
## like the emoji people know from their own phone. Anywhere else (or if
## the browser has no emoji font) the Twemoji PNG is fetched instead.
## texture() returns null until an emoji is ready; callers draw a
## placeholder that frame.

const SIZE := 128
const TWEMOJI := "https://cdn.jsdelivr.net/gh/jdecked/twemoji@15.1.0/assets/72x72/%s.png"

var _tex := {}
var _icons := {}

func texture(e: String) -> Texture2D:
	if e == "":
		return null
	if _tex.has(e):
		return _tex[e]
	_tex[e] = null
	if WebBridge.ensure():
		var b64 = JavaScriptBridge.eval("window.RagdollEmoji(%s, %d)" % [JSON.stringify(e), SIZE], true)
		if b64 is String and b64 != "":
			_tex[e] = WebBridge.png_texture(b64)
			return _tex[e]
	_fetch_twemoji(e)
	return null

## A small copy for button icons (a 128px emoji would make every button
## 128px tall). Null until the emoji itself is ready.
func icon(e: String, size: int = 36) -> Texture2D:
	var key := "%s@%d" % [e, size]
	if _icons.has(key):
		return _icons[key]
	var tex := texture(e)
	if tex == null:
		return null
	var img := tex.get_image()
	img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	_icons[key] = ImageTexture.create_from_image(img)
	return _icons[key]

## Twemoji file names are the code points in hex joined by "-", with the
## U+FE0F variation selector dropped unless the sequence has a ZWJ.
static func twemoji_name(e: String) -> String:
	var cps := []
	var has_zwj := e.find(char(0x200D)) >= 0
	for i in e.length():
		var cp := e.unicode_at(i)
		if cp == 0xFE0F and not has_zwj:
			continue
		cps.append("%x" % cp)
	return "-".join(cps)

func _fetch_twemoji(e: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, code, _headers, body):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			return
		var img := Image.new()
		if img.load_png_from_buffer(body) == OK:
			_tex[e] = ImageTexture.create_from_image(img)
	)
	if http.request(TWEMOJI % twemoji_name(e)) != OK:
		http.queue_free()
