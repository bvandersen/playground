extends Node

## Records the stage to a video (autoload `Recorder`). Only the stage's
## rectangle of the canvas is captured -- the top strip, tool row and any
## sheets are outside it -- scaled into a 720x1280 (9:16) frame, which is
## what TikTok / Reels / Shorts want. When it stops, the browser shows the
## clip with Share (the phone's share sheet, straight into an app) and
## Download. Web-only; elsewhere supported() is false.

const OUT_SIZE := Vector2i(720, 1280)
const FPS := 30
const MAX_SECONDS := 60.0

signal started
signal stopped

var recording := false
var elapsed := 0.0

func supported() -> bool:
	if not WebBridge.ensure():
		return false
	return bool(JavaScriptBridge.eval("window.RagdollRec.supported()", true))

## `stage_rect` is in viewport (canvas_items) coordinates.
func start(stage_rect: Rect2) -> bool:
	if recording or not supported():
		return false
	var r := _to_canvas_px(stage_rect)
	var mime = JavaScriptBridge.eval("window.RagdollRec.start(%d, %d, %d, %d, %d, %d, %d)" % [
		r.position.x, r.position.y, r.size.x, r.size.y, OUT_SIZE.x, OUT_SIZE.y, FPS], true)
	if not (mime is String) or mime == "":
		push_warning("Recorder: couldn't start: %s" % JavaScriptBridge.eval("window.RagdollRec.lastError", true))
		return false
	recording = true
	elapsed = 0.0
	started.emit()
	return true

func update_crop(stage_rect: Rect2) -> void:
	if not recording:
		return
	var r := _to_canvas_px(stage_rect)
	JavaScriptBridge.eval("window.RagdollRec.setCrop(%d, %d, %d, %d)" % [r.position.x, r.position.y, r.size.x, r.size.y], true)

func stop() -> void:
	if not recording:
		return
	JavaScriptBridge.eval("window.RagdollRec.stop()", true)
	recording = false
	stopped.emit()

func overlay_open() -> bool:
	return WebBridge.available() and WebBridge.ensure() and bool(JavaScriptBridge.eval("window.RagdollRec.overlayOpen()", true))

func _process(delta: float) -> void:
	if not recording:
		return
	elapsed += delta
	if elapsed >= MAX_SECONDS:
		stop()

## Viewport coordinates -> the canvas element's pixel coordinates (the
## canvas_items stretch mode scales the viewport to the window).
func _to_canvas_px(r: Rect2) -> Rect2i:
	var vp := get_viewport()
	var visible := vp.get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	var k := win / visible
	var ks := minf(k.x, k.y)
	# canvas_items + expand: uniform scale, content anchored top-left.
	return Rect2i(Vector2i((r.position * ks).round()), Vector2i((r.size * ks).round()))
