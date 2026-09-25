extends SceneTree

## Renders the Android launcher icons and the Google Play listing art from
## the game's own procedural painters, so there's no hand-made art to keep
## in step with the game (docs/game1.md, "Android build").
##
## Needs a real renderer, not --headless -- scripts/game1-android-art.sh
## runs it under Xvfb, once per shot, sizing the window per shot:
##
##   godot4 --path game1/rail-yard --rendering-driver opengl3 \
##       --resolution WxH --script res://tools/store_art.gd -- <shot>
##
## Shots: icon_bg, icon_fg, icon_mono, icon_192 (launcher icons ->
## res://art/android/), store_icon, feature, phone_design, phone_sheet,
## phone_play (Play listing -> game1/store/rail-yard/).

const ICON_DIR := "res://art/android"
const STORE_DIR := "res://../store/rail-yard"
const GRASS := Color(0.33, 0.45, 0.24)
## Icons are drawn this many times too big with anti-aliasing off, then
## scaled down: IconArt's AA fringe is sized for a 24 px button, and
## blown up to launcher size it would blur every edge.
const ICON_SUPERSAMPLE := 4

var shot := ""
var main: Node
var frame := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	shot = args[0] if args.size() > 0 else "icon_192"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ICON_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STORE_DIR))
	if ICONS.has(shot):
		root.transparent_bg = true
		var canvas := Node2D.new()
		root.add_child(canvas)
		canvas.draw.connect(_draw_icon.bind(canvas))
		return
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)

## Icon shots: [file, background?, foreground?, monochrome?]. The adaptive
## layers are 432 px; the launcher masks them to a circle, squircle, ...
## and only the central ~66% is always visible. Monochrome is the layer
## Android 13+ tints for themed icons.
const ICONS := {
	"icon_bg": [ICON_DIR + "/icon_background_432.png", true, false, false],
	"icon_fg": [ICON_DIR + "/icon_foreground_432.png", false, true, false],
	"icon_mono": [ICON_DIR + "/icon_monochrome_432.png", false, true, true],
	"icon_192": [ICON_DIR + "/icon_192.png", true, true, false],
	"store_icon": [STORE_DIR + "/icon_512.png", true, true, false],
}

func _process(_delta: float) -> bool:
	frame += 1
	if ICONS.has(shot):
		if frame == 5:
			var img := root.get_texture().get_image()
			var px := img.get_width() / ICON_SUPERSAMPLE
			img.resize(px, px, Image.INTERPOLATE_LANCZOS)
			_save(img, ICONS[shot][0])
			quit()
		return false
	match shot:
		"phone_design":
			if frame == 40:
				_save(root.get_texture().get_image(), STORE_DIR + "/phone_1_design.png")
				quit()
		"phone_sheet":
			if frame == 5:
				main.select_train(main.trains[1])
			if frame == 40:
				_save(root.get_texture().get_image(), STORE_DIR + "/phone_2_train_sheet.png")
				quit()
		"phone_play":
			if frame == 5:
				main.set_mode(main.MODE_PLAY)
			if frame == 300:
				_save(root.get_texture().get_image(), STORE_DIR + "/phone_3_play.png")
				quit()
		"feature":
			if frame == 5:
				# The demo layout is tall; turn the camera a quarter so it
				# fills the landscape banner, with no UI over it.
				main.ui.visible = false
				main.set_mode(main.MODE_PLAY)
				var r: Rect2 = main.net.bounds().grow(30.0)
				var vp: Vector2 = root.get_visible_rect().size
				var z := minf(vp.x / r.size.y, vp.y / r.size.x)
				main.camera.ignore_rotation = false
				main.camera.rotation = -PI * 0.5
				main.camera.zoom = Vector2(z, z)
				main.camera.position = r.get_center()
			if frame == 240:
				_save(root.get_texture().get_image(), STORE_DIR + "/feature_1024x500.png")
				quit()
	return false

## IconArt's steam engine -- the same one on the +Train button -- on a
## stretch of track, over a grass-green field.
func _draw_icon(canvas: Node2D) -> void:
	var spec: Array = ICONS[shot]
	var s := root.get_visible_rect().size.x
	if spec[1]:
		canvas.draw_rect(Rect2(0, 0, s, s), GRASS)
		canvas.draw_circle(Vector2(s, s) * 0.5, s * 0.36, GRASS.lightened(0.12))
	if spec[2]:
		_paint_engine(canvas, s, spec[3])

func _paint_engine(ci: CanvasItem, s: float, mono: bool) -> void:
	var box := s * 0.58
	var c := Vector2(s * 0.5, s * 0.5)
	var k := box / 24.0
	ci.draw_set_transform(c - Vector2(box, box) * 0.5, 0.0, Vector2(k, k))
	var rail := Color.WHITE if mono else Color(0.2, 0.19, 0.18)
	var sleeper := Color.WHITE if mono else Color(0.45, 0.33, 0.22)
	for x in [-1.0, 3.5, 8.0, 12.5, 17.0, 21.5]:
		ci.draw_rect(Rect2(x, 21.6, 3.0, 2.2), sleeper)
	ci.draw_rect(Rect2(-2.0, 21.2, 28.0, 1.1), rail)
	ci.draw_set_transform(Vector2.ZERO, 0.0)
	IconArt.paint(Sharp.new(ci, Color.WHITE if mono else Color.TRANSPARENT), "train", c, box)

## Stands in for the CanvasItem IconArt paints on: the same calls with
## anti-aliasing off (see ICON_SUPERSAMPLE) and, for the monochrome layer
## Android tints itself, every colour replaced by `solid`.
class Sharp:
	var ci: CanvasItem
	var solid: Color
	func _init(target: CanvasItem, solid_color: Color) -> void:
		ci = target
		solid = solid_color
	func _c(col: Color) -> Color:
		return col if solid.a == 0.0 else Color(solid, col.a)
	func draw_set_transform(pos: Vector2, rot: float = 0.0, scale: Vector2 = Vector2.ONE) -> void:
		ci.draw_set_transform(pos, rot, scale)
	func draw_colored_polygon(pts: PackedVector2Array, col: Color) -> void:
		ci.draw_colored_polygon(pts, _c(col))
	func draw_polyline(pts: PackedVector2Array, col: Color, width: float = -1.0, _aa: bool = false) -> void:
		ci.draw_polyline(pts, _c(col), width, false)
	func draw_arc(center: Vector2, radius: float, a0: float, a1: float, count: int, col: Color, width: float = -1.0, _aa: bool = false) -> void:
		ci.draw_arc(center, radius, a0, a1, count, _c(col), width, false)

func _save(img: Image, path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	img.convert(Image.FORMAT_RGBA8)
	var err := img.save_png(abs_path)
	print("%s %dx%d -> %s" % ["wrote" if err == OK else "FAILED", img.get_width(), img.get_height(), abs_path.simplify_path()])
