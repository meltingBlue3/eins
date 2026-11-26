extends Control
## Title screen. Working title only; the story milestone decides the real name.
## Shows the style's key art when there is one, else the procedural grey-box scene.

signal start_pressed

const Draw = preload("res://scripts/ui/draw_util.gd")
const ArtStyle = preload("res://scripts/art_style.gd")
const VERSION := "v0.2.1 · 水彩定稿"
const SCREEN := Vector2(1280, 720)  # this Control is not inside a container, so its own size stays zero
const LAMP_UV := Vector2(0.926, 0.09)  # where the lighthouse lamp sits in the key art

var _time := 0.0
var _keyart: Texture2D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_keyart = ArtStyle.tex("ui", "keyart", "jpg")

	var title := Draw.make_label("雾港守灯人", 76, Color("f7efdc"))
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color(Draw.INK, 0.9))
	title.position = Vector2(84, 64)
	add_child(title)

	var subtitle := Draw.make_label("雾里有东西在靠近。点亮灯塔，守住港口。", 22, Color("f4ead2"))
	subtitle.add_theme_constant_override("outline_size", 6)
	subtitle.add_theme_color_override("font_outline_color", Color(Draw.INK, 0.85))
	subtitle.position = Vector2(90, 172)
	add_child(subtitle)

	var start := Button.new()
	start.text = "开始作战"
	start.position = Vector2(90, 228)
	start.size = Vector2(240, 64)
	Draw.style_button(start, Draw.INK, 26)
	start.pressed.connect(func(): start_pressed.emit())
	add_child(start)

	var controls := Draw.make_label("鼠标：点击或拖动卡片部署 · 点击单位撤退\n键盘：1–5 选卡 · 空格 暂停 · F 倍速 · Esc 取消", 15, Color("e6dcc6"))
	controls.add_theme_constant_override("outline_size", 5)
	controls.add_theme_color_override("font_outline_color", Color(Draw.INK, 0.9))
	controls.position = Vector2(24, 664)
	add_child(controls)

	var version := Draw.make_label(VERSION, 14, Color("e6dcc6"))
	version.add_theme_constant_override("outline_size", 5)
	version.add_theme_color_override("font_outline_color", Color(Draw.INK, 0.9))
	version.position = Vector2(1130, 692)
	add_child(version)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		start_pressed.emit()


func _draw() -> void:
	if _keyart != null:
		_draw_keyart()
	else:
		_draw_greybox()


func _draw_keyart() -> void:
	draw_texture_rect(_keyart, Rect2(Vector2.ZERO, SCREEN), false)
	# Ink wash behind the title block and the controls line so text stays legible.
	var wash := Color(Draw.INK, 0.55)
	var clear := Color(Draw.INK, 0.0)
	# Fades out both to the right and downwards, so it leaves no hard edge.
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(760, 0), Vector2(760, 400), Vector2(0, 400)]),
		PackedColorArray([wash, clear, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(560, 0), Vector2(0, 330)]),
		PackedColorArray([Color(Draw.INK, 0.3), clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, 640), Vector2(SCREEN.x, 640), Vector2(SCREEN.x, SCREEN.y), Vector2(0, SCREEN.y)]),
		PackedColorArray([clear, clear, Color(Draw.INK, 0.7), Color(Draw.INK, 0.7)]))
	# The lamp breathes.
	var lamp := LAMP_UV * SCREEN
	var pulse := 0.5 + 0.5 * sin(_time * 2.0)
	for i in 4:
		draw_circle(lamp, 70.0 - i * 14.0, Color(1.0, 0.82, 0.42, 0.03 + 0.03 * pulse), true, -1.0, true)
	# Low fog drifting over the water.
	for i in 6:
		var x := fmod(i * 241.0 + _time * (14.0 + i * 4.0), SCREEN.x + 500.0) - 250.0
		var y := 520.0 + sin(i * 1.9) * 70.0
		for k in 3:
			Draw.ellipse(self, Vector2(x, y), Vector2(260.0 - k * 60.0, 46.0 - k * 10.0), Color(0.86, 0.84, 0.95, 0.035))


func _draw_greybox() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("0d121b"))
	for i in 9:
		var x := fmod(i * 173.0 + _time * (12.0 + i * 3.0), 1600.0) - 160.0
		var y := 420.0 + sin(i * 1.7) * 160.0
		draw_circle(Vector2(x, y), 120.0 + i * 12.0, Color(0.42, 0.36, 0.56, 0.05), true, -1.0, true)
	var base := Vector2(980, 560)
	var pulse := 0.5 + 0.5 * sin(_time * 2.0)
	var beam_angle := sin(_time * 0.7) * 0.6 + PI
	var tip := base + Vector2(0, -250)
	var beam := PackedVector2Array([tip, tip + Vector2.from_angle(beam_angle - 0.12) * 700.0, tip + Vector2.from_angle(beam_angle + 0.12) * 700.0])
	draw_colored_polygon(beam, Color(0.95, 0.82, 0.42, 0.07))
	for i in 5:
		draw_circle(tip, 90.0 - i * 16.0, Color(0.95, 0.79, 0.3, 0.05 + 0.03 * pulse), true, -1.0, true)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-60, 0), base + Vector2(60, 0), base + Vector2(30, -230), base + Vector2(-30, -230)]), Color("2b3646"))
	for i in 4:
		draw_rect(Rect2(base + Vector2(-50 + i * 4, -40 - i * 52), Vector2(100 - i * 8, 14)), Color("8a3b3b"))
	draw_rect(Rect2(tip + Vector2(-26, -10), Vector2(52, 30)), Color("f2d16b"))
	draw_rect(Rect2(tip + Vector2(-32, -24), Vector2(64, 14)), Color("4f8fd8"))
	draw_rect(Rect2(Vector2(0, 560), Vector2(SCREEN.x, 160)), Color("0a0e15"))
