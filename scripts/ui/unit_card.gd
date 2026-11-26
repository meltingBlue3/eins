extends Control
## One deploy card. Pure view: BattleScreen pushes state every frame and listens to the signals.

signal pressed(unit_id: String)
signal hovered(unit_id: String, inside: bool)

const Draw = preload("res://scripts/ui/draw_util.gd")
const CARD_SIZE := Vector2(150, 136)

var unit_id := ""
var def: Dictionary = {}
var cost_ok := true
var cooldown := 0.0
var on_field := false
var active := false
var hotkey := 0
var art: Texture2D = null  # full-body sprite at 2x; null draws the grey-box glyph
var paper: Texture2D = null
var _hover := false


func setup(id: String, d: Dictionary, key: int) -> void:
	unit_id = id
	def = d
	hotkey = key
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)


func set_state(p_cost_ok: bool, p_cooldown: float, p_on_field: bool, p_active: bool) -> void:
	if p_cost_ok == cost_ok and is_equal_approx(p_cooldown, cooldown) and p_on_field == on_field and p_active == active:
		return
	cost_ok = p_cost_ok
	cooldown = p_cooldown
	on_field = p_on_field
	active = p_active
	queue_redraw()


func set_art(t: Texture2D, p_paper: Texture2D) -> void:
	art = t
	paper = p_paper
	queue_redraw()


func _on_enter() -> void:
	_hover = true
	hovered.emit(unit_id, true)
	queue_redraw()


func _on_exit() -> void:
	_hover = false
	hovered.emit(unit_id, false)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(unit_id)
		accept_event()


func _draw() -> void:
	var usable := cost_ok and cooldown <= 0.0 and not on_field
	var lift := -8.0 if (active or (_hover and usable)) else 0.0
	var rect := Rect2(Vector2(0, lift), size)
	var col := Color(def["color"])

	Draw.paper_panel(self, rect, paper, hotkey)
	# Watercolour wash of the unit's colour behind the portrait.
	draw_rect(Rect2(rect.position + Vector2(5, 5), Vector2(size.x - 10, 7)), Color(col, 0.85))
	var center := rect.position + Vector2(size.x / 2.0, 64)
	draw_circle(center, 36, Color(col, 0.22), true, -1.0, true)
	draw_circle(center, 26, Color(col, 0.18), true, -1.0, true)
	if art != null:
		var s := art.get_size() / 2.0
		Draw.sprite(self, art, rect.position + Vector2(size.x / 2.0, 101), s * (82.0 / s.y))
	else:
		draw_circle(center, 30, col, true, -1.0, true)
		Draw.text_c(self, center, def["glyph"], 30, Color.WHITE, 4, col.darkened(0.6))

	draw_rect(Rect2(rect.position + Vector2(8, 16), Vector2(38, 26)), Draw.INK)
	Draw.text_c(self, rect.position + Vector2(27, 29), str(def["cost"]), 20, Draw.LAMP if cost_ok else Color("ff7a6b"))
	Draw.text_c(self, rect.position + Vector2(size.x - 28, 29), "高台" if def["tile"] == "high" else "地面", 14, Draw.INK_SOFT)
	Draw.text_c(self, rect.position + Vector2(size.x / 2.0, 116), "%s · %s" % [def["name"], def["role"]], 17, Draw.INK)
	Draw.text_c(self, rect.position + Vector2(size.x - 13, size.y - 13), str(hotkey), 12, Color(Draw.INK, 0.45))

	if on_field:
		draw_rect(rect, Color(Draw.INK, 0.62))
		Draw.text_c(self, rect.position + Vector2(size.x / 2.0, 64), "在场", 24, Color("bfe8c8"), 4)
	elif cooldown > 0.0:
		draw_rect(rect, Color(Draw.INK, 0.66))
		Draw.text_c(self, rect.position + Vector2(size.x / 2.0, 64), "%d" % ceili(cooldown), 34, Color("f4ead2"), 4)
	elif not cost_ok:
		draw_rect(rect, Color(Draw.INK, 0.42))

	if active:
		draw_rect(rect.grow(1.0), Draw.LAMP, false, 3.0)
	elif _hover and usable:
		draw_rect(rect.grow(1.0), Color(Draw.LAMP, 0.6), false, 2.0)
