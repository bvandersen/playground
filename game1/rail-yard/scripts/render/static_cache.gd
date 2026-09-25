extends Node
class_name StaticCache

## Draws the layers that never move on their own -- grass and scenery,
## track, roads, buildings, stations -- into an off-screen texture, and
## shows that texture under everything else instead of drawing all of
## their triangles every frame. They're re-drawn only when the camera
## moves or zooms, the window changes size, or one of them redraws (an
## edit). With the camera still, which is most of the time in Play, a frame
## draws one screen-sized quad plus whatever is moving.
##
## The same picture: the SubViewport shares the game's World2D (so the
## same canvas items), draws only the ones on LAYER, with exactly the
## transform the screen uses, at the screen's own pixel size, and the
## result is put back 1:1 with nearest filtering. Everything it holds is
## under everything it doesn't (see Main._ready's child order).

const LAYER := 1 << 19 # a visibility layer nothing else uses

## Off draws the static layers straight to the screen again, as before
## (for comparing).
var enabled := true:
	set(on):
		enabled = on
		var root_vp := get_viewport()
		if on:
			root_vp.canvas_cull_mask &= ~LAYER
		else:
			root_vp.canvas_cull_mask |= LAYER
		RenderingServer.canvas_item_set_visible(_quad, on)
		_dirty = true

var _roots: Array = []
var _vp: SubViewport
var _quad: RID # the screen-sized picture, in the CanvasLayer under the world
var _dirty := true
var _xf := Transform2D()
var _size := Vector2i.ZERO
var _inv := Transform2D()

## `under` is a CanvasLayer below the world to show the texture in;
## `roots` the static nodes (their children, now and later, go too).
func setup(under: CanvasLayer, roots: Array) -> void:
	_roots = roots
	var root_vp := get_viewport()
	_vp = SubViewport.new()
	_vp.world_2d = root_vp.world_2d
	_vp.canvas_cull_mask = LAYER
	_vp.transparent_bg = false
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	root_vp.canvas_cull_mask &= ~LAYER
	# Drawn through the RenderingServer rather than a node's _draw, so a
	# new size takes effect in the very frame it's noticed (a queued redraw
	# would show one frame late).
	_quad = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_quad, under.get_canvas())
	RenderingServer.canvas_item_set_default_texture_filter(_quad, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	# A canvas item culled by the mask hides its children too, so the
	# parents of the static nodes (which draw nothing themselves) are on
	# both the cache's layer and the screen's.
	for r in _roots:
		_mark(r)
		var p: Node = r.get_parent()
		while p is CanvasItem:
			p.visibility_layer |= LAYER
			p = p.get_parent()
	get_tree().node_added.connect(_on_tree_changed)
	get_tree().node_removed.connect(_on_tree_changed)
	RenderingServer.frame_pre_draw.connect(_pre_draw)

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_pre_draw):
		RenderingServer.frame_pre_draw.disconnect(_pre_draw)
	if _quad.is_valid():
		RenderingServer.free_rid(_quad)
		_quad = RID()

func invalidate() -> void:
	_dirty = true

func _mark(n: Node) -> void:
	if n is CanvasItem:
		n.visibility_layer = LAYER
		if not n.draw.is_connected(invalidate):
			n.draw.connect(invalidate)
		if not n.visibility_changed.is_connected(invalidate):
			n.visibility_changed.connect(invalidate)
	for c in n.get_children():
		_mark(c)

func _on_tree_changed(n: Node) -> void:
	for r in _roots:
		if n == r or r.is_ancestor_of(n):
			if n.is_inside_tree():
				_mark(n)
			_dirty = true
			return

## Just before the frame is drawn -- after the camera, every _process and
## every _draw of this frame -- so a change always shows the same frame.
func _pre_draw() -> void:
	if not enabled:
		return
	var root_vp := get_viewport()
	var size: Vector2i = root_vp.size # the window's real pixels, under any stretch
	# What the screen draws the world with: the window's stretch (and the
	# global canvas transform, which get_final_transform includes) times
	# the camera's.
	var screen := root_vp.get_final_transform()
	var xf := screen * root_vp.canvas_transform
	# The picture sits in a CanvasLayer, which that stretch scales too;
	# undo it so one texel lands on one screen pixel.
	var inv := screen.affine_inverse()
	if size != _size:
		_size = size
		_vp.size = size
		RenderingServer.canvas_item_clear(_quad)
		RenderingServer.canvas_item_add_texture_rect(_quad, Rect2(Vector2.ZERO, Vector2(size)), _vp.get_texture().get_rid())
		_dirty = true
	if inv != _inv:
		_inv = inv
		RenderingServer.canvas_item_set_transform(_quad, inv)
	if xf != _xf:
		_xf = xf
		_vp.canvas_transform = xf
		_dirty = true
	if _dirty:
		_dirty = false
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
