extends Control
## Title screen. Working title only; the story milestone decides the real name.

signal start_pressed

const Draw = preload("res://scripts/ui/draw_util.gd")
const VERSION := "v0.1.0 · 灰盒原型"

var _time := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var title := Draw.make_label("雾港守灯人", 72, Color("f4ead2"))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color("0a0e15"))
	title.position = Vector2(110, 200)
	add_child(title)

	var subtitle := Draw.make_label("雾里有东西在靠近。点亮灯塔，守住港口。", 22, Color("aebbd0"))
	subtitle.position = Vector2(116, 310)
	add_child(subtitle)

	var start := Button.new()
	start.text = "开始作战"
	start.position = Vector2(116, 390)
	start.size = Vector2(240, 64)
	Draw.style_button(start, Color("2f6f4f"), 26)
	start.pressed.connect(func(): start_pressed.emit())
	add_child(start)

	var controls := Draw.make_label("鼠标：点击或拖动卡片部署 · 点击单位撤退\n键盘：1–5 选卡 · 空格 暂停 · F 倍速 · Esc 取消", 16, Color("7f8da3"))
	controls.position = Vector2(116, 600)
	add_child(controls)

	var version := Draw.make_label(VERSION, 14, Color("5d6b80"))
	version.position = Vector2(1100, 690)
	add_child(version)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		start_pressed.emit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0d121b"))
	# Drifting fog banks.
	for i in 9:
		var x := fmod(i * 173.0 + _time * (12.0 + i * 3.0), 1600.0) - 160.0
		var y := 420.0 + sin(i * 1.7) * 160.0
		draw_circle(Vector2(x, y), 120.0 + i * 12.0, Color(0.42, 0.36, 0.56, 0.05), true, -1.0, true)
	# Lighthouse with a sweeping beam.
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
	draw_rect(Rect2(Vector2(0, 560), Vector2(size.x, 160)), Color("0a0e15"))
