extends Node2D
class_name DrawLayer

## A node whose _draw() is a callback -- lets World keep dolls, props and
## captions in separate draw layers (so ropes go over bodies and captions
## over everything) without a script per layer.

var draw_fn: Callable

func _init(fn: Callable) -> void:
	draw_fn = fn

func _draw() -> void:
	draw_fn.call(self)
