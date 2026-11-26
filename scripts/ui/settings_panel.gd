extends Control
## Settings sheet, opened from the title menu and the pause menu.
## Changes apply and save immediately. Emits `closed`; the opener frees it.

signal closed

const Draw = preload("res://scripts/ui/draw_util.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Settings = preload("res://scripts/settings.gd")
const ArtStyle = preload("res://scripts/art_style.gd")
const SHEET := Vector2(540, 470)
const HELP := "拖动或点击卡片部署 · 点击场上角色撤退\n1–5 选卡 · 空格 暂停 · F 倍速 · Esc 取消 / 关闭"

var _buttons := {}


func _ready() -> void:
	var modal := UiKit.modal("设置", SHEET)
	add_child(modal)
	size = modal.size
	var sheet: Control = modal.get_node("Sheet")
	var y := 64.0
	for key in ["fullscreen", "style", "damage"]:
		var label := Draw.make_label({"fullscreen": "全屏显示", "style": "画面", "damage": "伤害数字"}[key], 20, Draw.INK)
		label.position = Vector2(56, y + 10)
		sheet.add_child(label)
		var b := UiKit.button("", Vector2(150, 46), 18)
		b.position = Vector2(SHEET.x - 56 - 150, y)
		b.pressed.connect(_toggle.bind(key))
		sheet.add_child(b)
		_buttons[key] = b
		y += 62.0
	var rule := ColorRect.new()
	rule.color = Color(Draw.BRASS_DARK, 0.5)
	rule.position = Vector2(48, y + 4)
	rule.size = Vector2(SHEET.x - 96, 2)
	sheet.add_child(rule)
	var help_head := Draw.make_label("操作说明", 18, Draw.INK)
	help_head.position = Vector2(56, y + 16)
	sheet.add_child(help_head)
	var help := Draw.make_label(HELP, 16, Draw.INK_SOFT)
	help.position = Vector2(56, y + 46)
	sheet.add_child(help)
	var close := UiKit.button("关闭", Vector2(180, 52), 20)
	close.position = Vector2((SHEET.x - 180) / 2.0, SHEET.y - 52 - 46)
	close.pressed.connect(func(): closed.emit())
	sheet.add_child(close)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		closed.emit()


func _toggle(key: String) -> void:
	match key:
		"fullscreen":
			Settings.fullscreen = not Settings.fullscreen
			Settings.apply()
		"style":
			ArtStyle.cycle()
		"damage":
			Settings.show_damage = not Settings.show_damage
	Settings.save()
	_refresh()


func _refresh() -> void:
	_buttons["fullscreen"].text = "开" if Settings.fullscreen else "关"
	_buttons["style"].text = ArtStyle.style_name()
	_buttons["damage"].text = "显示" if Settings.show_damage else "隐藏"
