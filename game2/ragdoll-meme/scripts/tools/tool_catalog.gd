extends RefCounted
class_name ToolCatalog

## The one place a stage tool gets registered, in tool-row order.

static var _all: Array = []

static func all() -> Array:
	if _all.is_empty():
		_all = [GrabTool.new(), PinTool.new(), BoomTool.new(), BalloonTool.new(), MagnetTool.new(), EraseTool.new()]
	return _all
