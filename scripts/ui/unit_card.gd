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


func set_art(t: Texture2D) -> void:
	art = t
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

	draw_rect(rect, Color("1b2433"))
	draw_rect(Rect2(rect.position, Vector2(size.x, 6)), col)

	var center := rect.position + Vector2(size.x / 2.0, 62)
	if art != null:
		draw_circle(center + Vector2(0, 6), 34, col.darkened(0.55), true, -1.0, true)
		draw_circle(center + Vector2(0, 6), 31, col.darkened(0.2), true, -1.0, true)
		var s := art.get_size() / 2.0
		Draw.sprite(self, art, rect.position + Vector2(size.x / 2.0, 99), s * (80.0 / s.y))
	else:
		draw_circle(center, 33, col.darkened(0.5), true, -1.0, true)
		draw_circle(center, 30, col, true, -1.0, true)
		draw_circle(center + Vector2(-9, -10), 10, Color(1, 1, 1, 0.2), true, -1.0, true)
		Draw.text_c(self, center, def["glyph"], 30, Color.WHITE, 4, col.darkened(0.6))

	draw_rect(Rect2(rect.position + Vector2(6, 12), Vector2(40, 26)), Color("0b1018"))
	Draw.text_c(self, rect.position + Vector2(26, 25), str(def["cost"]), 20, Color("ffd36b") if cost_ok else Color("ff6b6b"))
	Draw.text_c(self, rect.position + Vector2(size.x - 28, 25), "高台" if def["tile"] == "high" else "地面", 14, Color("9fb0c6"))
	Draw.text_c(self, rect.position + Vector2(size.x / 2.0, 112), "%s · %s" % [def["name"], def["role"]], 17, Color.WHITE)
	Draw.text_c(self, rect.position + Vector2(size.x - 12, size.y - 12), str(hotkey), 12, Color(1, 1, 1, 0.35))

	if on_field:
		draw_rect(rect, Color(0, 0, 0, 0.55))
		Draw.text_c(self, rect.position + Vector2(size.x / 2.0, 62), "在场", 24, Color("9fe0b0"), 4)
	elif cooldown > 0.0:
		draw_rect(rect, Color(0, 0, 0, 0.6))
		Draw.text_c(self, rect.position + Vector2(size.x / 2.0, 62), "%d" % ceili(cooldown), 34, Color("f2f2f2"), 4)
	elif not cost_ok:
		draw_rect(rect, Color(0, 0, 0, 0.4))

	var border := Color.WHITE if active else col.darkened(0.25)
	draw_rect(rect, border, false, 3.0 if active else 1.5)
