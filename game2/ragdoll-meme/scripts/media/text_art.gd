extends Node

## Text drawn by the browser (autoload `TextArt`) -- meme captions in
## Impact with a thick black outline, with emoji. Cached per (text, size,
## wrap width, style). Off the Web, texture() returns null and draw()
## falls back to Godot's default font with an outline.

var _tex := {}

func texture(text: String, px: int, max_width: float, meme: bool) -> Texture2D:
	var key := "%s|%d|%d|%s" % [text, px, int(max_width), meme]
	if _tex.has(key):
		return _tex[key]
	var tex: Texture2D = null
	if WebBridge.ensure():
		var b64 = JavaScriptBridge.eval("window.RagdollText(%s, %d, %d, %s)" % [
			JSON.stringify(text), px, int(max_width), "true" if meme else "false"], true)
		if b64 is String:
			tex = WebBridge.png_texture(b64)
	if _tex.size() > 64:
		_tex.clear()
	_tex[key] = tex
	return tex

## Draw `text` centred on `center_x`, its top at `y` (or its bottom, if
## `from_bottom`).
func draw(ci: CanvasItem, text: String, px: int, max_width: float, meme: bool, center_x: float, y: float, from_bottom: bool = false, alpha: float = 1.0) -> void:
	var tex := texture(text, px, max_width, meme)
	if tex != null:
		var s := tex.get_size()
		ci.draw_texture(tex, Vector2(center_x - s.x * 0.5, y - s.y if from_bottom else y), Color(1, 1, 1, alpha))
		return
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var base := y - px * 0.25 if from_bottom else y + px
	var at := Vector2(center_x - w * 0.5, base)
	if meme:
		ci.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(px / 6, 2), Color(0, 0, 0, alpha))
	ci.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(1, 1, 1, alpha))
