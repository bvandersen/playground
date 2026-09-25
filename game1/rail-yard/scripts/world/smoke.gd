extends Node2D
class_name Smoke

## Loco exhaust as hand-rolled particles (no GPUParticles, so it behaves
## the same on every Web/GL target): each puff drifts with the wind and
## a bit of the loco's own velocity, slows down, swells and fades. A puff
## is a small cluster of blobs that spread apart as it grows, so it reads
## as billowing smoke rather than a disc. Steam chuffs are big and pale;
## diesel exhaust is small, dark and thickens with throttle.

const MAX_PUFFS := 200
const WIND := Vector2(10.0, -7.0)
const BLOBS := 3

class Puff:
	var pos: Vector2
	var vel: Vector2
	var age := 0.0
	var life := 1.0
	var r0 := 2.0
	var r1 := 10.0
	var color := Color.WHITE
	var offsets: Array = [] # per blob: [direction * spread, size factor]
	var spin := 0.0

var _puffs: Array = []

func puff(pos: Vector2, vel: Vector2, kind: String, strength: float) -> void:
	if _puffs.size() >= MAX_PUFFS:
		_puffs.pop_front()
	var p := Puff.new()
	p.pos = pos
	var jitter := Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
	if kind == "steam":
		var g := randf_range(0.84, 0.95)
		p.vel = vel + jitter
		p.life = randf_range(1.6, 2.4) * strength + 0.6
		p.r0 = 2.5 * strength + 1.5
		p.r1 = randf_range(10.0, 14.0) * strength + 3.0
		p.color = Color(g, g, g * 1.02, 0.34)
	else:
		var g2 := randf_range(0.16, 0.26)
		p.vel = vel + jitter * 0.6
		p.life = randf_range(0.9, 1.4) * strength + 0.4
		p.r0 = 1.4
		p.r1 = randf_range(5.0, 7.0) * strength + 2.0
		p.color = Color(g2, g2, g2, 0.3)
	for k in range(BLOBS):
		var a := randf() * TAU
		p.offsets.append([Vector2(cos(a), sin(a)) * randf_range(0.3, 0.8), randf_range(0.55, 0.9)])
	p.spin = randf_range(-0.6, 0.6)
	_puffs.append(p)

func clear() -> void:
	_puffs.clear()
	queue_redraw()

func _process(delta: float) -> void:
	if _puffs.is_empty():
		return
	var keep := []
	var damp := exp(-1.6 * delta)
	for p in _puffs:
		p.age += delta
		if p.age >= p.life:
			continue
		p.vel = p.vel * damp + WIND * (1.0 - damp)
		p.pos += p.vel * delta
		keep.append(p)
	_puffs = keep
	queue_redraw()

func _draw() -> void:
	for p in _puffs:
		var t: float = p.age / p.life
		var r: float = lerpf(p.r0, p.r1, 1.0 - pow(1.0 - t, 2.4))
		var a: float = p.color.a * pow(1.0 - t, 1.3) * minf(t * 10.0, 1.0)
		var rot: float = p.spin * t
		draw_circle(p.pos + Vector2(3.0, 4.0) * (0.8 + t * 1.5), r * 0.9, Color(0, 0, 0, a * 0.22))
		draw_circle(p.pos, r * 0.75, Color(p.color.r, p.color.g, p.color.b, a))
		for o in p.offsets:
			var off: Vector2 = (o[0] as Vector2).rotated(rot) * r
			var br: float = r * o[1]
			draw_circle(p.pos + off, br, Color(p.color.r, p.color.g, p.color.b, a * 0.8))
			draw_circle(p.pos + off + Vector2(-br * 0.25, -br * 0.3), br * 0.5,
				Color(minf(p.color.r + 0.1, 1.0), minf(p.color.g + 0.1, 1.0), minf(p.color.b + 0.1, 1.0), a * 0.5))
