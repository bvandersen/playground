extends RefCounted
class_name StageTool

## What a finger (or the mouse) does on the stage -- one per tool-row
## button. Each touch index is handled independently, so every tool works
## with several fingers at once (grab both hands and puppeteer).
## Positions are in stage units.

var id := ""
var display_name := ""
var emoji := ""
var hint := ""

func press(_world: World, _index: int, _p: Vector2) -> void:
	pass

func drag(_world: World, _index: int, _p: Vector2) -> void:
	pass

func release(_world: World, _index: int, _p: Vector2) -> void:
	pass
