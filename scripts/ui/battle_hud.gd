extends CanvasLayer
## Battle HUD: top bar, deploy cards, cost, contextual tips, selected-unit panel,
## stage intro banner, pause menu and result sheet.
## A view over BattleScreen state; player actions go back through signals.

signal card_pressed(unit_id: String)
signal speed_pressed
signal pause_pressed
signal retreat_pressed
signal retry_pressed
signal title_pressed

const GameData = preload("res://scripts/game_data.gd")
const BattleSim = preload("res://scripts/sim/battle_sim.gd")
const UnitCard = preload("res://scripts/ui/unit_card.gd")
const Draw = preload("res://scripts/ui/draw_util.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const ArtStyle = preload("res://scripts/art_style.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")

const TIPS := {
	"start": ["第一步", "把「剑士」拖到发光的地面格子上，挡住雾兽的路。"],
	"high": ["高台", "弓手、术士、医师放在木栈道上，越过栈道输出和治疗。"],
	"brute": ["雾甲来了", "护甲很厚，物理攻击打不动。用术士的法术对付它。"],
	"retreat": ["撤退", "点击场上的角色可以撤退，返还一半费用。"],
	"down": ["有人倒下了", "20 秒后可以再部署。医师能给前排回血。"],
}
const UNIT_PANEL := Vector2(244, 104)

var screen  # BattleScreen
var _root: Control
var _cards := {}
var _top: Control
var _speed_btn: Button
var _pause_btn: Button
var _tip_view: Control
var _tip_key := "start"
var _hover_id := ""
var _deploys := 0
var _unit_view: Control
var _retreat_btn: Button
var _cost_view: Control
var _menu: Control
var _settings: Control


func setup(s) -> void:
	screen = s
	_root = Control.new()
	_root.size = Vector2(1280, 720)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_top()
	_build_bottom()
	_build_unit_panel()
	_show_intro()


# --- Build -----------------------------------------------------------------

func _build_top() -> void:
	_top = Control.new()
	_top.size = Vector2(1280, 54)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.draw.connect(_draw_top)
	_root.add_child(_top)
	var stage := UiKit.heading("%s  %s" % [screen.sim.stage["id"], screen.sim.stage["name"]], 22)
	stage.position = Vector2(24, 10)
	_root.add_child(stage)
	_speed_btn = UiKit.button("", Vector2(104, 40), 18, "fast")
	_speed_btn.position = Vector2(1032, 6)
	_speed_btn.tooltip_text = "倍速（F）"
	_speed_btn.pressed.connect(func(): speed_pressed.emit())
	_root.add_child(_speed_btn)
	_pause_btn = UiKit.button("", Vector2(56, 40), 18, "pause")
	_pause_btn.position = Vector2(1144, 6)
	_pause_btn.tooltip_text = "暂停（空格）"
	_pause_btn.pressed.connect(func(): pause_pressed.emit())
	_root.add_child(_pause_btn)
	var gear := UiKit.button("", Vector2(56, 40), 18, "gear")
	gear.position = Vector2(1208, 6)
	gear.tooltip_text = "设置"
	gear.pressed.connect(open_settings)
	_root.add_child(gear)


func _build_bottom() -> void:
	_tip_view = Control.new()
	_tip_view.position = Vector2(10, 568)
	_tip_view.size = Vector2(186, 138)
	_tip_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_view.draw.connect(_draw_tip)
	_root.add_child(_tip_view)
	var x := 204.0
	for i in GameData.UNIT_ORDER.size():
		var id: String = GameData.UNIT_ORDER[i]
		var card := UnitCard.new()
		card.setup(id, GameData.UNITS[id], i + 1)
		card.position = Vector2(x, 570)
		card.pressed.connect(func(uid): card_pressed.emit(uid))
		card.hovered.connect(_on_card_hovered)
		_root.add_child(card)
		_cards[id] = card
		x += card.size.x + 10.0
	_cost_view = Control.new()
	_cost_view.position = Vector2(1008, 570)
	_cost_view.size = Vector2(256, 136)
	_cost_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_view.draw.connect(_draw_cost)
	_root.add_child(_cost_view)


func _build_unit_panel() -> void:
	_unit_view = Control.new()
	_unit_view.size = UNIT_PANEL
	_unit_view.visible = false
	_unit_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_unit_view.draw.connect(_draw_unit_panel)
	_root.add_child(_unit_view)
	_retreat_btn = UiKit.button("", Vector2(112, 38), 15, "retreat")
	_retreat_btn.position = Vector2(UNIT_PANEL.x - 112 - 12, UNIT_PANEL.y - 38 - 10)
	_retreat_btn.pressed.connect(func(): retreat_pressed.emit())
	_unit_view.add_child(_retreat_btn)


# --- Per frame ---------------------------------------------------------------

func refresh() -> void:
	var sim = screen.sim
	_speed_btn.text = "%d×" % screen.speed
	_pause_btn.icon = UiKit.icon("play" if screen.paused else "pause")
	for id in _cards:
		var d: Dictionary = GameData.UNITS[id]
		_cards[id].set_state(sim.cost >= float(d["cost"]), sim.cooldown_of(id), sim.is_deployed(id), screen.placing == id)
	_top.queue_redraw()
	_cost_view.queue_redraw()
	_tip_view.queue_redraw()
	var u = screen.selected
	_unit_view.visible = u != null and sim.status == "playing"
	if _unit_view.visible:
		# Above the unit if there is room, else beside it (right, or left near the edge),
		# so the panel never covers the row below.
		var p: Vector2 = screen.unit_screen_pos(u)
		var at := Vector2(p.x - UNIT_PANEL.x / 2.0, p.y - 74.0 - UNIT_PANEL.y)
		if at.y < 60.0:
			var right := p.x + 52.0
			at = Vector2(right if right + UNIT_PANEL.x < 1272.0 else p.x - 52.0 - UNIT_PANEL.x, p.y - UNIT_PANEL.y / 2.0 + 10.0)
		_unit_view.position = Vector2(clampf(at.x, 8.0, 1280.0 - UNIT_PANEL.x - 8.0), maxf(at.y, 60.0))
		_retreat_btn.text = "撤退 +%d" % int(floorf(float(u.def["cost"]) * BattleSim.RETREAT_REFUND))
		_unit_view.queue_redraw()


func apply_style() -> void:
	var paper := ArtStyle.tex("ui", "paper", "jpg")
	for id in _cards:
		_cards[id].set_art(ArtStyle.tex("units", id), paper)


## Advances the contextual tips from battle events.
func on_event(ev: Dictionary) -> void:
	match ev["type"]:
		"deploy":
			_deploys += 1
			if _tip_key == "start":
				_tip_key = "high"
			elif _deploys >= 4 and _tip_key == "high":
				_tip_key = "retreat"
		"spawn":
			if ev["enemy"].type == "brute" and _tip_key != "brute":
				_tip_key = "brute"
		"unit_down":
			_tip_key = "down"


func _on_card_hovered(unit_id: String, inside: bool) -> void:
	_hover_id = unit_id if inside else ""


# --- Drawing -----------------------------------------------------------------

func _draw_top() -> void:
	var sim = screen.sim
	_top.draw_rect(Rect2(0, 0, 1280, 52), Color(Draw.INK, 0.96))
	_top.draw_rect(Rect2(0, 52, 1280, 2), Draw.BRASS_DARK)
	# Lamp life and fog count, as icon + number pills.
	_pill(Vector2(452, 7), "lantern", "%d / %d" % [sim.life, sim.max_life], Draw.LAMP, float(sim.life) / sim.max_life)
	var done: int = sim.killed + sim.leaked
	_pill(Vector2(652, 7), "fog", "%d / %d" % [done, sim.total_enemies], Color("e8c6d4"), float(done) / sim.total_enemies)


func _pill(at: Vector2, icon_name: String, text: String, col: Color, ratio: float) -> void:
	var r := Rect2(at, Vector2(176, 38))
	_top.draw_rect(r, Color(Draw.INK_SOFT, 0.9))
	_top.draw_rect(r, Color(Draw.BRASS_DARK, 0.9), false, 1.5)
	var ic := UiKit.icon(icon_name)
	if ic != null:
		_top.draw_texture_rect(ic, Rect2(at + Vector2(6, 3), Vector2(32, 32)), false)
	Draw.text_c(_top, at + Vector2(104, 17), text, 21, col, 4, Draw.INK)
	_top.draw_rect(Rect2(at + Vector2(44, 32), Vector2(124, 3)), Color(0, 0, 0, 0.5))
	_top.draw_rect(Rect2(at + Vector2(44, 32), Vector2(124 * clampf(ratio, 0.0, 1.0), 3)), Color(col, 0.8))


func _draw_tip() -> void:
	var v := _tip_view
	Draw.paper_panel(v, Rect2(Vector2.ZERO, v.size), ArtStyle.tex("ui", "paper", "jpg"), 17, Color(0.92, 0.9, 0.86))
	var title: String
	var body: String
	if _hover_id != "":
		var d: Dictionary = GameData.UNITS[_hover_id]
		title = "%s · %s" % [d["name"], d["role"]]
		body = "%s\n生命 %d  攻击 %d\n防御 %d  费用 %d" % [d["desc"], d["hp"], d["atk"], d["def"], d["cost"]]
	else:
		title = TIPS[_tip_key][0]
		body = TIPS[_tip_key][1]
	v.draw_rect(Rect2(10, 10, 4, 20), Draw.LAMP if _hover_id == "" else Color(GameData.UNITS[_hover_id]["color"]))
	v.draw_string(Draw.FONT, Vector2(20, 27), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Draw.INK)
	v.draw_multiline_string(Draw.FONT, Vector2(12, 52), body, HORIZONTAL_ALIGNMENT_LEFT, v.size.x - 24, 13, 5, Draw.INK_SOFT)


func _draw_cost() -> void:
	var cv := _cost_view
	var sim = screen.sim
	Draw.paper_panel(cv, Rect2(Vector2.ZERO, cv.size), ArtStyle.tex("ui", "paper", "jpg"), 9, Color(0.78, 0.74, 0.68))
	Draw.text_c(cv, Vector2(cv.size.x / 2.0, 22), "部署费用", 15, Draw.INK_SOFT)
	var flame := UiKit.icon("flame")
	if flame != null:
		cv.draw_texture_rect(flame, Rect2(Vector2(44, 44), Vector2(42, 42)), false)
	Draw.text_c(cv, Vector2(cv.size.x / 2.0 + 18, 66), str(int(sim.cost)), 46, Draw.LAMP, 5, Draw.INK)
	var frac := 1.0 if sim.cost >= BattleSim.COST_MAX else fmod(sim.cost, 1.0)
	Draw.bar(cv, Vector2(24, 108), cv.size.x - 48, 8, frac, Draw.LAMP)


func _draw_unit_panel() -> void:
	var v := _unit_view
	var u = screen.selected
	if u == null:
		return
	var d: Dictionary = u.def
	Draw.paper_panel(v, Rect2(Vector2.ZERO, v.size), ArtStyle.tex("ui", "paper", "jpg"), 5)
	v.draw_rect(Rect2(10, 12, 4, 20), Color(d["color"]))
	v.draw_string(Draw.FONT, Vector2(20, 29), "%s · %s" % [d["name"], d["role"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Draw.INK)
	var ratio: float = u.hp / u.max_hp
	Draw.bar(v, Vector2(14, 40), v.size.x - 28, 7, ratio, Draw.hp_color(ratio))
	v.draw_string(Draw.FONT, Vector2(14, 66), "%d / %d" % [int(u.hp), int(u.max_hp)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Draw.INK_SOFT)
	v.draw_string(Draw.FONT, Vector2(14, 86), "攻 %d  防 %d" % [d["atk"], d["def"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Draw.INK_SOFT)


# --- Intro, menus, result ------------------------------------------------------

func _show_intro() -> void:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size = Vector2(1280, 720)
	_root.add_child(box)
	var band := Panel.new()
	band.add_theme_stylebox_override("panel", UiKit.ribbon())
	band.size = Vector2(560, 76)
	band.position = Vector2(360, 236)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(band)
	var head := UiKit.heading("%s  %s" % [screen.sim.stage["id"], screen.sim.stage["name"]], 32)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.size = Vector2(560, 68)
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	band.add_child(head)
	var goal := UiKit.heading("守住灯塔 · 别让雾兽靠近", 20)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal.size = Vector2(1280, 30)
	goal.position = Vector2(0, 322)
	box.add_child(goal)
	box.modulate.a = 0.0
	var tw := box.create_tween().set_ignore_time_scale(true)
	tw.tween_property(box, "modulate:a", 1.0, 0.35)
	tw.tween_interval(1.9)
	tw.tween_property(box, "modulate:a", 0.0, 0.5)
	tw.tween_callback(box.queue_free)


func is_menu_open() -> bool:
	return _menu != null or _settings != null


func open_pause_menu() -> void:
	if _menu != null:
		return
	_menu = UiKit.modal("暂停", Vector2(360, 330))
	var sheet: Control = _menu.get_node("Sheet")
	var entries := [["继续", "play", func(): pause_pressed.emit()],
		["重新开始", "retreat", func(): retry_pressed.emit()],
		["设置", "gear", open_settings],
		["返回标题", "", func(): title_pressed.emit()]]
	var y := 58.0
	for e in entries:
		var b := UiKit.button(e[0], Vector2(240, 50), 20, e[1])
		b.position = Vector2(60, y)
		b.pressed.connect(e[2])
		sheet.add_child(b)
		y += 60.0
	_root.add_child(_menu)


func open_settings() -> void:
	if _settings != null:
		return
	_settings = SettingsPanel.new()
	_settings.closed.connect(func():
		_settings.queue_free()
		_settings = null)
	_root.add_child(_settings)


func close_menus() -> void:
	if _settings != null:
		_settings.queue_free()
		_settings = null
	if _menu != null:
		_menu.queue_free()
		_menu = null


func show_result(won: bool, stars: int) -> void:
	close_menus()
	_unit_view.visible = false
	var sim = screen.sim
	var sheet_size := Vector2(560, 390)
	var modal := UiKit.modal("作战成功" if won else "作战失败", sheet_size)
	var sheet: Control = modal.get_node("Sheet")
	var star_view := Control.new()
	star_view.size = Vector2(sheet_size.x, 110)
	star_view.position = Vector2(0, 46)
	sheet.add_child(star_view)
	for i in 3:
		var s := _star(i < stars)
		s.position = Vector2(sheet_size.x / 2.0 + (i - 1) * 86.0 - 36.0, 10)
		star_view.add_child(s)
		s.scale = Vector2.ZERO
		var tw := s.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "scale", Vector2.ONE, 0.35).set_delay(0.35 + i * 0.22)
	var summary: String
	if won:
		summary = ["", "勉强守住了灯塔。", "灯塔受了点损伤。", "完美守住了灯塔！"][stars]
	else:
		summary = "灯火熄灭了。试试先挡路，再把术士对准雾甲。"
	var stats := Draw.make_label("%s\n击退 %d / %d   ·   灯火 %d / %d   ·   用时 %d:%02d" % [
		summary, sim.killed, sim.total_enemies, sim.life, sim.max_life, int(sim.time) / 60, int(sim.time) % 60], 18, Draw.INK)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.position = Vector2(0, 176)
	stats.size = Vector2(sheet_size.x, 60)
	sheet.add_child(stats)
	var retry := UiKit.button("再来一次", Vector2(190, 54), 20, "play")
	retry.position = Vector2(70, 280)
	retry.pressed.connect(func(): retry_pressed.emit())
	sheet.add_child(retry)
	var back := UiKit.button("返回标题", Vector2(190, 54), 20)
	back.position = Vector2(300, 280)
	back.pressed.connect(func(): title_pressed.emit())
	sheet.add_child(back)
	_root.add_child(modal)


func _star(lit: bool) -> Control:
	var c := Control.new()
	c.size = Vector2(72, 72)
	c.pivot_offset = c.size / 2.0
	c.draw.connect(func():
		Draw.star(c, Vector2(36, 39), 36.0, Color(Draw.BRASS_DARK, 0.85))
		Draw.star(c, Vector2(36, 36), 33.0, Draw.LAMP if lit else Color("cdbf9f")))
	return c
