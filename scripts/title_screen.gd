extends Control
## Title screen: key art, logo, and the main menu (start / settings / quit).
## Without key art (grey-box style) it falls back to the procedural scene.

signal start_pressed

const Draw = preload("res://scripts/ui/draw_util.gd")
const ArtStyle = preload("res://scripts/art_style.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
const VERSION := "v0.3.0 · UI/UX"
const SCREEN := Vector2(1280, 720)  # this Control is not inside a container, so its own size stays zero
const LAMP_UV := Vector2(0.926, 0.09)  # where the lighthouse lamp sits in the key art
const MENU_X := 96.0

var _time := 0.0
var _keyart: Texture2D
var _logo: Texture2D
var _wash: GradientTexture2D
var _intro := 0.0  # 0 -> 1 over the entrance animation
var _settings: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_logo = UiKit.tex("logo")
	var g := Gradient.new()
	g.set_color(0, Color(Draw.INK, 0.72))
	g.set_color(1, Color(Draw.INK, 0.0))
	g.add_point(0.55, Color(Draw.INK, 0.45))
	_wash = GradientTexture2D.new()
	_wash.gradient = g
	_wash.fill = GradientTexture2D.FILL_RADIAL
	_wash.fill_from = Vector2(0.5, 0.5)
	_wash.fill_to = Vector2(1.0, 0.5)
	_wash.width = 256
	_wash.height = 256

	var tagline := UiKit.heading("雾里有东西在靠近。点亮灯塔，守住港口。", 20)
	tagline.position = Vector2(MENU_X, 226)
	add_child(tagline)

	var entries := [["开始作战", Vector2(270, 62), 24, "play", func(): start_pressed.emit()],
		["设置", Vector2(270, 52), 20, "gear", _open_settings],
		["退出游戏", Vector2(270, 52), 20, "", func(): get_tree().quit()]]
	var y := 282.0
	for i in entries.size():
		var e: Array = entries[i]
		var b := UiKit.button(e[0], e[1], e[2], e[3])
		b.position = Vector2(MENU_X, y)
		b.pressed.connect(e[4])
		add_child(b)
		_slide_in(b, 0.25 + i * 0.08)
		y += e[1].y + 12.0
	_slide_in(tagline, 0.15)

	var version := UiKit.heading(VERSION, 14)
	version.position = Vector2(1140, 692)
	add_child(version)

	create_tween().tween_property(self, "_intro", 1.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _slide_in(c: Control, delay: float) -> void:
	var to := c.position
	c.position = to - Vector2(40, 0)
	c.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "position", to, 0.45).set_delay(delay)
	tw.tween_property(c, "modulate:a", 1.0, 0.35).set_delay(delay)


func _open_settings() -> void:
	if _settings != null:
		return
	_settings = SettingsPanel.new()
	_settings.closed.connect(func():
		_settings.queue_free()
		_settings = null)
	add_child(_settings)


func _process(delta: float) -> void:
	_time += delta
	_keyart = ArtStyle.tex("ui", "keyart", "jpg")  # follows the style setting
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _settings == null and event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		start_pressed.emit()


func _draw() -> void:
	if _keyart != null:
		_draw_keyart()
	else:
		_draw_greybox()
	if _logo != null:
		var s := _logo.get_size() / 2.0
		draw_texture_rect(_logo, Rect2(Vector2(MENU_X - 64, 14 - 16.0 * (1.0 - _intro)), s), false, Color(1, 1, 1, _intro))


func _draw_keyart() -> void:
	draw_texture_rect(_keyart, Rect2(Vector2.ZERO, SCREEN), false)
	# Soft radial ink wash behind the logo and menu (a gradient texture, so no polygon seams).
	draw_texture_rect(_wash, Rect2(Vector2(-320, -260), Vector2(980, 920)), false)
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
	var tip := base + Vector2(0, -250)
	for i in 5:
		draw_circle(tip, 90.0 - i * 16.0, Color(0.95, 0.79, 0.3, 0.05 + 0.03 * pulse), true, -1.0, true)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-60, 0), base + Vector2(60, 0), base + Vector2(30, -230), base + Vector2(-30, -230)]), Color("2b3646"))
	draw_rect(Rect2(tip + Vector2(-26, -10), Vector2(52, 30)), Color("f2d16b"))
	draw_rect(Rect2(Vector2(0, 560), Vector2(SCREEN.x, 160)), Color("0a0e15"))
