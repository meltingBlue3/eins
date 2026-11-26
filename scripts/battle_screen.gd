extends Node2D
## Battle screen: draws the board, routes input into BattleSim, turns sim events into effects,
## and hosts the HUD. All game rules live in BattleSim.

signal retry_requested
signal title_requested

const GameData = preload("res://scripts/game_data.gd")
const BattleSim = preload("res://scripts/sim/battle_sim.gd")
const AutoPlayer = preload("res://scripts/sim/auto_player.gd")
const UnitCard = preload("res://scripts/ui/unit_card.gd")
const Draw = preload("res://scripts/ui/draw_util.gd")
const ArtStyle = preload("res://scripts/art_style.gd")

const TILE := 80.0
const HIGH_LIP := 14.0  # visible front wall of a high-ground tile
const TILE_TINT := Color(0.72, 0.75, 0.84)
const UNIT_FEET := 26.0  # sprite feet sit this far below the cell centre
const SIM_DT := 1.0 / 60.0
const SCREEN := Vector2(1280, 720)
const BOARD_TOP := 66.0
const TEXT_HINT := "把卡片拖到发光的格子上。\n地面：近战，挡住敌人\n高台：远程，输出治疗\n点击场上单位可撤退，返还一半费用。"

var sim
var origin := Vector2.ZERO
var speed := 1
var paused := false
var placing := ""
var drag_from_card := false
var selected = null
var hover_cell := Vector2i(-1, -1)
var hover_override := false
var autoplayer = null

var _acc := 0.0
var _time := 0.0
var _fx: Array = []
var _flash := 0.0
var _shake := 0.0
var _shake_off := Vector2.ZERO
var _end_shown := false
var _style_seen := -1
var _flip := {}  # instance id -> facing left; kept so sprites don't flip on vertical moves

var _cards := {}
var _style_btn: Button
var _life_label: Label
var _enemy_label: Label
var _speed_btn: Button
var _pause_btn: Button
var _hint_label: Label
var _retreat_btn: Button
var _pause_overlay: Control
var _cost_view: Control


func _ready() -> void:
	sim = BattleSim.new(GameData.STAGES[0])
	var board := Vector2(sim.cols, sim.rows) * TILE
	origin = Vector2((SCREEN.x - board.x) / 2.0, BOARD_TOP)
	_build_hud()


func enable_autoplay(plan: Array) -> void:
	autoplayer = AutoPlayer.new(plan)


# --- Loop ------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if not paused and sim.status == "playing":
		_acc = minf(_acc + delta * speed, 0.25)
		while _acc >= SIM_DT:
			_acc -= SIM_DT
			if autoplayer != null:
				autoplayer.update(sim)
			sim.step(SIM_DT)
	if ArtStyle.current != _style_seen:
		_apply_style()
	_consume_events()
	_update_fx(delta)
	if not hover_override:
		hover_cell = _px_to_cell(get_global_mouse_position())
	if selected != null and not selected.alive:
		selected = null
	_refresh_hud()
	if sim.status != "playing" and not _end_shown:
		_show_result()
	queue_redraw()


# --- Input -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# A drag that started on a card ends here, wherever the mouse is released.
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and drag_from_card:
		drag_from_card = false
		if placing != "" and sim.deploy_block_reason(placing, hover_cell) == "":
			_try_deploy(hover_cell)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
		ArtStyle.cycle()
		return
	if sim.status != "playing":
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_board_click(_px_to_cell(get_global_mouse_position()))
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_toggle_pause()
			KEY_F:
				_toggle_speed()
			KEY_ESCAPE:
				_cancel()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				var idx: int = event.keycode - KEY_1
				if idx < GameData.UNIT_ORDER.size():
					_on_card_pressed(GameData.UNIT_ORDER[idx])
					drag_from_card = false


func _on_board_click(cell: Vector2i) -> void:
	if placing != "":
		_try_deploy(cell)
		return
	var u = sim.unit_at(cell)
	selected = u if u != selected else null


func _on_card_pressed(unit_id: String) -> void:
	if sim.status != "playing":
		return
	var reason: String = sim.card_block_reason(unit_id)
	if reason != "":
		_toast(reason, get_global_mouse_position())
		return
	placing = "" if placing == unit_id else unit_id
	drag_from_card = placing != ""
	selected = null


func _on_card_hovered(unit_id: String, inside: bool) -> void:
	if inside:
		var d: Dictionary = GameData.UNITS[unit_id]
		_hint_label.text = "%s · %s\n%s\n\n生命 %d  攻击 %d  防御 %d" % [
			d["name"], d["role"], d["desc"], d["hp"], d["atk"], d["def"]]
	else:
		_hint_label.text = TEXT_HINT


func _try_deploy(cell: Vector2i) -> void:
	var reason: String = sim.deploy_block_reason(placing, cell)
	if reason != "":
		if sim.in_bounds(cell):
			_toast(reason, get_global_mouse_position())
		placing = ""
		return
	sim.deploy(placing, cell)
	placing = ""


func _cancel() -> void:
	placing = ""
	drag_from_card = false
	selected = null


func _toggle_pause() -> void:
	paused = not paused


func _toggle_speed() -> void:
	speed = 2 if speed == 1 else 1


func _on_retreat() -> void:
	if selected != null:
		sim.retreat(selected)
		selected = null


func _apply_style() -> void:
	_style_seen = ArtStyle.current
	_style_btn.text = "画风 %s" % ArtStyle.style_name()
	for id in _cards:
		_cards[id].set_art(ArtStyle.tex("units", id))


# --- Coordinates -----------------------------------------------------------

func _tp(p: Vector2) -> Vector2:
	return origin + (p + Vector2(0.5, 0.5)) * TILE + _shake_off


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(origin + Vector2(cell) * TILE + _shake_off, Vector2(TILE, TILE))


func _px_to_cell(px: Vector2) -> Vector2i:
	var local := (px - origin) / TILE
	return Vector2i(floori(local.x), floori(local.y))


# --- Events -> effects -----------------------------------------------------

func _consume_events() -> void:
	for ev in sim.events:
		match ev["type"]:
			"deploy":
				var u = ev["unit"]
				_fx_ring(_tp(u.pos), Color(u.def["color"]), 10.0, 60.0, 0.4)
			"spawn":
				_fx_ring(_tp(ev["enemy"].pos), Color("d9455f"), 10.0, 40.0, 0.35)
			"attack":
				_fx_attack(ev)
			"hit":
				var e = ev["enemy"]
				_fx_text(_tp(e.pos + e.jitter) + Vector2(randf_range(-18, 18), randf_range(-26, -12)), str(ev["amount"]), Color(1, 1, 1, 0.9), 15)
			"heal":
				var a = _tp(ev["unit"].pos)
				var b = _tp(ev["target"].pos)
				_fx.append({"k": "line", "a": a, "b": b, "t": 0.0, "d": 0.25, "c": Color("8af2a0"), "w": 3.0})
				_fx_text(b + Vector2(0, -26), "+%d" % ev["amount"], Color("8af2a0"), 18)
			"hurt":
				_fx_text(_tp(ev["unit"].pos) + Vector2(randf_range(-10, 10), -30), str(ev["amount"]), Color("ff8a7a"), 16)
			"kill":
				var p := _tp(ev["enemy"].pos + ev["enemy"].jitter)
				var col := Color(ev["enemy"].def["color"]).lightened(0.3)
				_fx_ring(p, col, 8.0, 46.0, 0.35)
				for i in 7:
					var ang := randf() * TAU
					_fx.append({"k": "spark", "p": p, "v": Vector2(cos(ang), sin(ang)) * randf_range(60, 160), "t": 0.0, "d": 0.45, "c": col})
			"unit_down":
				var u = ev["unit"]
				_fx_ring(_tp(u.pos), Color("aaaaaa"), 20.0, 70.0, 0.6)
				_fx_text(_tp(u.pos) + Vector2(0, -40), "%s 倒下" % u.def["name"], Color("ff8a7a"), 20)
				_shake = 0.2
			"retreat":
				_fx_text(_tp(ev["unit"].pos) + Vector2(0, -40), "撤退 +%d 费用" % ev["refund"], Color("ffd36b"), 18)
			"leak":
				_flash = 0.35
				_shake = 0.3
				_fx_text(_tp(Vector2(sim.base_cell)) + Vector2(0, -44), "-%d 灯火" % ev["enemy"].def["life_cost"], Color("ff6b6b"), 24)
	sim.events.clear()


func _fx_attack(ev: Dictionary) -> void:
	var u = ev["unit"]
	var e = ev["target"]
	var a := _tp(u.pos)
	var b := _tp(e.pos + e.jitter)
	match ev["kind"]:
		"melee":
			var ang := (b - a).angle()
			_fx.append({"k": "slash", "p": b, "ang": ang, "t": 0.0, "d": 0.18, "c": Color.WHITE})
		"ranged":
			if ev["damage"] == "arts":
				_fx.append({"k": "orb", "a": a, "b": b, "t": 0.0, "d": 0.2, "c": Color("c9a0ff")})
			else:
				_fx.append({"k": "line", "a": a, "b": b, "t": 0.0, "d": 0.12, "c": Color("e8ffd0"), "w": 2.0})


func _fx_ring(p: Vector2, c: Color, r0: float, r1: float, d: float) -> void:
	_fx.append({"k": "ring", "p": p, "r0": r0, "r1": r1, "t": 0.0, "d": d, "c": c})


func _fx_text(p: Vector2, text: String, c: Color, size: int) -> void:
	_fx.append({"k": "text", "p": p, "s": text, "t": 0.0, "d": 0.75, "c": c, "z": size})


func _toast(text: String, p: Vector2) -> void:
	_fx_text(p + Vector2(0, -20), text, Color("ffb35c"), 20)


func _update_fx(delta: float) -> void:
	for f in _fx:
		f["t"] += delta
	_fx = _fx.filter(func(f): return f["t"] < f["d"])
	_flash = maxf(_flash - delta, 0.0)
	_shake = maxf(_shake - delta, 0.0)
	_shake_off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 7.0 * (_shake / 0.3) if _shake > 0.0 else Vector2.ZERO


# --- Drawing ---------------------------------------------------------------

func _draw() -> void:
	_draw_board()
	_draw_path_flow()
	_draw_placement()
	_draw_actors()
	_draw_fx()
	_draw_selection()
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.9, 0.1, 0.15, _flash * 0.5))


func _draw_board() -> void:
	var size := Vector2(sim.cols, sim.rows) * TILE
	draw_rect(Rect2(origin - Vector2(8, 8) + _shake_off, size + Vector2(16, 16)), Color("0a0e15"))
	var ground := ArtStyle.tex("tiles", "ground")
	if ground != null:
		_draw_board_art(ground)
		_draw_fog()
	else:
		_draw_board_greybox()
	_draw_gate(_tp(Vector2(sim.spawn_cell)))
	_draw_lighthouse(_tp(Vector2(sim.base_cell)))


func _draw_board_greybox() -> void:
	for r in sim.rows:
		for c in sim.cols:
			var cell := Vector2i(c, r)
			var rect := _cell_rect(cell)
			match sim.tile_at(cell):
				".", "R", "B":
					draw_rect(rect, Color("263140"))
					draw_rect(rect.grow(-2), Color("2e3a4b"))
				"^":
					draw_rect(rect, Color("1a222d"))
					var top := Rect2(rect.position + Vector2(2, 0), Vector2(TILE - 4, TILE - 12))
					draw_rect(top, Color("56677c"))
					draw_rect(Rect2(top.position, Vector2(top.size.x, 3)), Color("71849b"))


func _draw_board_art(ground: Texture2D) -> void:
	var high := ArtStyle.tex("tiles", "high")
	var wall := ArtStyle.tex("tiles", "wall")
	var sea := ArtStyle.tex("tiles", "void")
	for r in sim.rows:
		for c in sim.cols:
			var cell := Vector2i(c, r)
			var rect := _cell_rect(cell)
			match sim.tile_at(cell):
				"#":
					_draw_tile(sea, rect, cell, 1.0)
					draw_rect(rect, Color(0.02, 0.04, 0.08, 0.25))
				"^":
					var top := Rect2(rect.position, Vector2(TILE, TILE - HIGH_LIP))
					_draw_tile(high, top, cell, top.size.y / TILE)
					var lip := Rect2(top.position + Vector2(0, top.size.y), Vector2(TILE, HIGH_LIP))
					var q := wall.get_size() / 2.0
					draw_texture_rect_region(wall, lip, Rect2(Vector2((cell.x % 2) * q.x, q.y * 0.4), Vector2(q.x, q.y * HIGH_LIP / TILE)), TILE_TINT)
					draw_rect(lip, Color(0, 0, 0, 0.3))
					draw_rect(Rect2(top.position, Vector2(TILE, 2)), Color(1, 1, 1, 0.16))
				_:
					_draw_tile(ground, rect, cell, 1.0)
					if sim.tile_at(cell + Vector2i(0, -1)) == "^":
						draw_rect(Rect2(rect.position, Vector2(TILE, 10)), Color(0, 0, 0, 0.28))
					draw_rect(rect, Color(0, 0, 0, 0.25), false, 1.0)


## Each tile texture spans 2x2 cells; pick the quarter by cell parity so neighbours connect.
## Tiles are tinted down so characters stay the brightest thing on screen.
func _draw_tile(t: Texture2D, dest: Rect2, cell: Vector2i, v_frac: float) -> void:
	var q := t.get_size() / 2.0
	var src := Rect2(Vector2(cell.x % 2, cell.y % 2) * q, Vector2(q.x, q.y * v_frac))
	draw_texture_rect_region(t, dest, src, TILE_TINT)


## Slow fog banks drifting across the harbour; purely decorative.
func _draw_fog() -> void:
	var board := Vector2(sim.cols, sim.rows) * TILE
	for i in 7:
		var speed := 9.0 + 5.0 * (i % 3)
		var span := board.x + 320.0
		var x := origin.x - 160.0 + fmod(i * 233.0 + _time * speed, span)
		var y := origin.y + 40.0 + fmod(i * 157.0, board.y - 80.0)
		var w := 150.0 + 40.0 * (i % 4)
		var fade := clampf(minf(x - origin.x, origin.x + board.x - x) / w, 0.0, 1.0)
		for k in 3:
			Draw.ellipse(self, Vector2(x, y), Vector2(w * (1.0 - k * 0.25), 34.0 * (1.0 - k * 0.25)), Color(0.78, 0.84, 0.95, 0.035 * fade))


func _draw_gate(p: Vector2) -> void:
	var t := ArtStyle.tex("props", "gate")
	if t != null:
		var pulse := 0.5 + 0.5 * sin(_time * 3.0)
		draw_circle(p, 42, Color(0.85, 0.27, 0.37, 0.10 + 0.08 * pulse), true, -1.0, true)
		Draw.sprite(self, t, p + Vector2(0, 38), ArtStyle.screen_size(t))
		return
	draw_circle(p, 30, Color(0.85, 0.27, 0.37, 0.25), true, -1.0, true)
	for i in 3:
		var a := _time * (1.5 + i * 0.6) + i * 2.0
		draw_arc(p, 14.0 + i * 7.0, a, a + 2.2, 16, Color("e0566e"), 3.0, true)
	draw_circle(p, 9, Color("2a0d16"), true, -1.0, true)


func _draw_lighthouse(p: Vector2) -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 2.4)
	var ratio := float(sim.life) / float(sim.max_life)
	var t := ArtStyle.tex("props", "lighthouse")
	if t != null:
		var s := ArtStyle.screen_size(t)
		var feet := p + Vector2(0, 38)
		Draw.sprite(self, t, feet, s, false, Color.WHITE.lerp(Color(0.45, 0.47, 0.55), 1.0 - ratio))
		var lamp := feet - Vector2(0, s.y * 0.78)
		for i in 4:
			draw_circle(lamp, 40.0 - i * 8.0, Color(1.0, 0.8, 0.35, (0.04 + 0.04 * pulse) * ratio), true, -1.0, true)
		return
	for i in 4:
		draw_circle(p + Vector2(0, -8), 44.0 - i * 9.0, Color(0.95, 0.79, 0.3, (0.05 + 0.04 * pulse) * ratio + 0.02), true, -1.0, true)
	draw_rect(Rect2(p + Vector2(-10, -2), Vector2(20, 28)), Color("3a4554"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-12, -2), p + Vector2(12, -2), p + Vector2(8, -22), p + Vector2(-8, -22)]), Color("f2d16b").lerp(Color("555555"), 1.0 - ratio))
	draw_rect(Rect2(p + Vector2(-13, -28), Vector2(26, 7)), Color("4f8fd8"))


func _draw_path_flow() -> void:
	# Faint dots drifting along the route so the enemy direction reads at a glance.
	var spacing := 0.5
	var offset := fmod(_time * 0.8, spacing)
	var dist := offset
	var seg_start := 0.0
	for i in range(1, sim.path.size()):
		var a: Vector2 = sim.path[i - 1]
		var b: Vector2 = sim.path[i]
		var seg_len := a.distance_to(b)
		while dist <= seg_start + seg_len:
			var t := (dist - seg_start) / seg_len
			draw_circle(_tp(a.lerp(b, t)), 2.5, Color(1, 0.45, 0.5, 0.22), true, -1.0, true)
			dist += spacing
		seg_start += seg_len


func _draw_placement() -> void:
	if placing == "":
		return
	var glow := 0.16 + 0.08 * sin(_time * 6.0)
	for r in sim.rows:
		for c in sim.cols:
			var cell := Vector2i(c, r)
			if sim.cell_fits(placing, cell) and sim.unit_at(cell) == null:
				draw_rect(_cell_rect(cell).grow(-4), Color(0.45, 0.95, 0.65, glow))
	var d: Dictionary = GameData.UNITS[placing]
	if sim.deploy_block_reason(placing, hover_cell) == "":
		var p := _tp(Vector2(hover_cell))
		_draw_range(p, d)
		_draw_unit_body(p, placing, 1.0, 0.6)
		draw_rect(_cell_rect(hover_cell), Color.WHITE, false, 2.0)


func _draw_range(p: Vector2, d: Dictionary) -> void:
	var col := Color(d["color"])
	var r: float = float(d["range"]) * TILE
	draw_circle(p, r, Color(col, 0.12), true, -1.0, true)
	draw_arc(p, r, 0.0, TAU, 64, Color(col, 0.7), 2.0, true)


func _draw_actors() -> void:
	var list: Array = []
	# Units sort in front of enemies on the same row, so a blocker is never hidden
	# behind the big enemy it is holding.
	for u in sim.units:
		list.append([u.pos.y + 0.25, 0, u])
	for e in sim.enemies:
		list.append([e.pos.y + e.jitter.y, 1, e])
	list.sort_custom(func(a, b): return a[0] < b[0])
	for item in list:
		if item[1] == 0:
			_draw_unit(item[2])
		else:
			_draw_enemy(item[2])


## Remembers horizontal facing so a unit moving straight up or down keeps its last side.
func _facing_left(obj, face: Vector2) -> bool:
	var key: int = obj.get_instance_id()
	if absf(face.x) > 0.3:
		_flip[key] = face.x < 0.0
	return _flip.get(key, false)


func _draw_unit(u) -> void:
	var p := _tp(u.pos)
	if u.lunge_t > 0.0:
		p += u.face * 10.0 * (u.lunge_t / 0.15)
	var k: float = u.spawn_t / 0.3
	var top: float
	if ArtStyle.tex("units", u.id) != null:
		var mod := Color(1.7, 1.7, 1.7) if u.flash_t > 0.0 else Color(1, 1, 1, 1.0 - k)
		top = _draw_unit_body(p, u.id, 1.0 + 0.25 * k, 1.0, _facing_left(u, u.face), mod)
	else:
		var pop: float = 1.0 + 0.7 * k
		top = _draw_unit_body(p, u.id, pop, 1.0)
		if u.flash_t > 0.0:
			draw_circle(p, 25.0 * pop, Color(1, 1, 1, 0.55), true, -1.0, true)
	var ratio: float = u.hp / u.max_hp
	Draw.bar(self, p + Vector2(-26, 30), 52, 6, ratio, Draw.hp_color(ratio))
	var cap: int = u.block_capacity()
	for i in cap:
		var pip := Vector2(p.x - (cap - 1) * 5.0 + i * 10.0, top - 8.0)
		if i < u.blocked.size():
			draw_circle(pip, 3.5, Color("ffd36b"), true, -1.0, true)
		else:
			draw_circle(pip, 3.5, Color(1, 1, 1, 0.5), false, 1.5, true)


## Draws a unit standing on `p` and returns the y of the top of its body.
func _draw_unit_body(p: Vector2, id: String, pop: float, alpha: float, flip := false, mod := Color.WHITE) -> float:
	var d: Dictionary = GameData.UNITS[id]
	var t := ArtStyle.tex("units", id)
	if t != null:
		var s := ArtStyle.screen_size(t) * pop
		var feet := p + Vector2(0, UNIT_FEET)
		Draw.ellipse(self, feet, Vector2(24, 7), Color(0, 0, 0, 0.35 * alpha))
		Draw.sprite(self, t, feet, s, flip, Color(mod, mod.a * alpha))
		return feet.y - s.y
	var col := Color(d["color"])
	var r := 25.0 * pop
	Draw.ellipse(self, p + Vector2(0, 22), Vector2(22, 7), Color(0, 0, 0, 0.35 * alpha))
	draw_circle(p, r + 3.0, Color(col.darkened(0.5), alpha), true, -1.0, true)
	draw_circle(p, r, Color(col, alpha), true, -1.0, true)
	draw_circle(p + Vector2(-7, -8) * pop, r * 0.35, Color(1, 1, 1, 0.2 * alpha), true, -1.0, true)
	Draw.text_c(self, p, d["glyph"], int(26 * pop), Color(1, 1, 1, alpha), 4, col.darkened(0.6))
	return p.y - r


func _draw_enemy(e) -> void:
	var col := Color(e.def["color"])
	var p := _tp(e.pos + e.jitter)
	var r: float = float(e.def["size"]) * TILE
	if e.lunge_t > 0.0:
		p += e.face * 9.0 * (e.lunge_t / 0.15)
	elif e.blocker == null:
		p.y -= absf(sin(_time * 9.0 + e.uid)) * 3.0
	Draw.ellipse(self, _tp(e.pos + e.jitter) + Vector2(0, r * 0.8), Vector2(r * 0.9, r * 0.3), Color(0, 0, 0, 0.35))
	var t := ArtStyle.tex("enemies", e.type)
	if t != null:
		var s := ArtStyle.screen_size(t)
		var feet := p + Vector2(0, r * 0.8)
		var mod := Color(1.8, 1.8, 1.8) if e.flash_t > 0.0 else Color.WHITE
		Draw.sprite(self, t, feet, s, _facing_left(e, e.face), mod)
		if e.hp < e.max_hp:
			var ratio: float = e.hp / e.max_hp
			Draw.bar(self, Vector2(p.x - 22.0, feet.y - s.y - 8.0), 44.0, 4, ratio, Color("ef5b5b"))
		return
	match e.def["shape"]:
		"hound":
			Draw.ellipse(self, p, Vector2(r * 1.25, r * 0.85), col.darkened(0.4))
			Draw.ellipse(self, p, Vector2(r * 1.15, r * 0.75), col)
			draw_circle(p + e.face * r * 0.95, r * 0.62, col.lightened(0.08), true, -1.0, true)
		"brute":
			draw_circle(p, r + 3.0, col.darkened(0.5), true, -1.0, true)
			draw_circle(p, r, col, true, -1.0, true)
			draw_arc(p, r - 2.0, PI * 1.1, PI * 1.9, 16, Color("a7b0c2"), 6.0, true)
			draw_arc(p, r - 2.0, PI * 0.15, PI * 0.85, 16, Color("7d8699"), 5.0, true)
		_:
			draw_circle(p, r + 2.0, col.darkened(0.45), true, -1.0, true)
			draw_circle(p, r, col, true, -1.0, true)
			draw_circle(p + Vector2(-r * 0.3, -r * 0.35), r * 0.4, Color(1, 1, 1, 0.12), true, -1.0, true)
	var eye_base: Vector2 = p + e.face * r * 0.35 + (e.face * r * 0.95 if e.def["shape"] == "hound" else Vector2.ZERO)
	var side := Vector2(-e.face.y, e.face.x) * r * 0.3
	for s in [-1.0, 1.0]:
		var eye: Vector2 = eye_base + side * s
		draw_circle(eye, r * 0.17, Color("f4f0ff"), true, -1.0, true)
		draw_circle(eye + e.face * r * 0.06, r * 0.08, Color("1a1024"), true, -1.0, true)
	if e.flash_t > 0.0:
		draw_circle(p, r + 2.0, Color(1, 1, 1, 0.6), true, -1.0, true)
	if e.hp < e.max_hp:
		var ratio: float = e.hp / e.max_hp
		Draw.bar(self, p + Vector2(-r, -r - 12), r * 2.0, 4, ratio, Color("ef5b5b"))


func _draw_fx() -> void:
	for f in _fx:
		var k: float = f["t"] / f["d"]
		var c: Color = f["c"]
		match f["k"]:
			"ring":
				draw_arc(f["p"], lerpf(f["r0"], f["r1"], k), 0.0, TAU, 32, Color(c, 1.0 - k), 3.0, true)
			"text":
				var pos: Vector2 = f["p"] + Vector2(0, -36.0 * k)
				Draw.text_c(self, pos, f["s"], f["z"], Color(c, 1.0 - k * k), 4)
			"line":
				draw_line(f["a"], f["b"], Color(c, 1.0 - k), f["w"], true)
			"orb":
				var at: Vector2 = f["a"].lerp(f["b"], k)
				draw_circle(at, 9.0, Color(c, 0.3), true, -1.0, true)
				draw_circle(at, 5.0, c, true, -1.0, true)
			"slash":
				var ang: float = f["ang"]
				draw_arc(f["p"], 20.0 + 6.0 * k, ang - 1.3, ang + 1.3, 12, Color(c, 1.0 - k), 4.0, true)
			"spark":
				draw_circle(f["p"] + f["v"] * f["t"], 4.0 * (1.0 - k), c, true, -1.0, true)


func _draw_selection() -> void:
	if selected == null:
		return
	var p := _tp(selected.pos)
	_draw_range(p, selected.def)
	draw_arc(p, 32, 0.0, TAU, 32, Color.WHITE, 2.0, true)
	var info: String = "%s  %d/%d" % [selected.def["name"], int(selected.hp), int(selected.max_hp)]
	var info_y := -104.0 if selected.cell.y > 0 else 112.0
	Draw.text_c(self, p + Vector2(0, info_y), info, 16, Color.WHITE, 4)


# --- HUD -------------------------------------------------------------------

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)

	var top := ColorRect.new()
	top.color = Color(0.04, 0.055, 0.08, 0.95)
	top.position = Vector2.ZERO
	top.size = Vector2(SCREEN.x, 52)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)

	var stage_label := Draw.make_label("%s  %s" % [sim.stage["id"], sim.stage["name"]], 22, Color("cfd8e6"))
	stage_label.position = Vector2(24, 10)
	root.add_child(stage_label)

	_life_label = Draw.make_label("", 24, Color("ffd36b"))
	_life_label.position = Vector2(470, 8)
	root.add_child(_life_label)

	_enemy_label = Draw.make_label("", 22, Color("e8a0b0"))
	_enemy_label.position = Vector2(660, 10)
	root.add_child(_enemy_label)

	_speed_btn = Button.new()
	_speed_btn.position = Vector2(1066, 7)
	_speed_btn.size = Vector2(90, 38)
	Draw.style_button(_speed_btn, Color("2c3a50"), 18)
	_speed_btn.pressed.connect(_toggle_speed)
	root.add_child(_speed_btn)

	_pause_btn = Button.new()
	_pause_btn.position = Vector2(1166, 7)
	_pause_btn.size = Vector2(96, 38)
	Draw.style_button(_pause_btn, Color("2c3a50"), 18)
	_pause_btn.pressed.connect(_toggle_pause)
	root.add_child(_pause_btn)

	_style_btn = Button.new()
	_style_btn.position = Vector2(856, 7)
	_style_btn.size = Vector2(200, 38)
	_style_btn.tooltip_text = "切换画风（V）"
	Draw.style_button(_style_btn, Color("3b3355"), 16)
	_style_btn.pressed.connect(ArtStyle.cycle)
	root.add_child(_style_btn)

	_hint_label = Draw.make_label(TEXT_HINT, 14, Color("aebbd0"))
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_hint_label.custom_minimum_size = Vector2(176, 0)
	_hint_label.position = Vector2(16, 572)
	_hint_label.size = Vector2(176, 136)
	root.add_child(_hint_label)

	var x := 204.0
	for i in GameData.UNIT_ORDER.size():
		var id: String = GameData.UNIT_ORDER[i]
		var card := UnitCard.new()
		card.setup(id, GameData.UNITS[id], i + 1)
		card.position = Vector2(x, 570)
		card.pressed.connect(_on_card_pressed)
		card.hovered.connect(_on_card_hovered)
		root.add_child(card)
		_cards[id] = card
		x += card.size.x + 10.0

	_cost_view = Control.new()
	_cost_view.position = Vector2(1008, 570)
	_cost_view.size = Vector2(256, 136)
	_cost_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_view.draw.connect(_draw_cost_view)
	root.add_child(_cost_view)

	_retreat_btn = Button.new()
	_retreat_btn.size = Vector2(110, 36)
	Draw.style_button(_retreat_btn, Color("8a3b3b"), 16)
	_retreat_btn.pressed.connect(_on_retreat)
	_retreat_btn.visible = false
	root.add_child(_retreat_btn)

	_pause_overlay = Draw.make_label("已暂停 · 按空格继续", 30, Color.WHITE)
	_pause_overlay.add_theme_constant_override("outline_size", 8)
	_pause_overlay.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_pause_overlay.position = Vector2(500, 286)
	_pause_overlay.visible = false
	root.add_child(_pause_overlay)


func _draw_cost_view() -> void:
	var cv := _cost_view
	cv.draw_rect(Rect2(Vector2.ZERO, cv.size), Color("1b2433"))
	cv.draw_rect(Rect2(Vector2.ZERO, cv.size), Color("3a4a62"), false, 1.5)
	Draw.text_c(cv, Vector2(cv.size.x / 2.0, 24), "部署费用", 16, Color("9fb0c6"))
	Draw.text_c(cv, Vector2(cv.size.x / 2.0, 68), str(int(sim.cost)), 46, Color("ffd36b"), 4)
	var frac := 1.0 if sim.cost >= BattleSim.COST_MAX else fmod(sim.cost, 1.0)
	Draw.bar(cv, Vector2(24, 106), cv.size.x - 48, 8, frac, Color("ffd36b"))


func _refresh_hud() -> void:
	_life_label.text = "灯火 %d / %d" % [sim.life, sim.max_life]
	_enemy_label.text = "雾兽 %d / %d" % [sim.killed + sim.leaked, sim.total_enemies]
	_speed_btn.text = "%d× 倍速" % speed
	_pause_btn.text = "继续" if paused else "暂停"
	_pause_overlay.visible = paused and sim.status == "playing"
	for id in _cards:
		var d: Dictionary = GameData.UNITS[id]
		_cards[id].set_state(sim.cost >= float(d["cost"]), sim.cooldown_of(id), sim.is_deployed(id), placing == id)
	_cost_view.queue_redraw()
	if selected != null and sim.status == "playing":
		var p := _tp(selected.pos)
		_retreat_btn.text = "撤退 +%d" % int(floorf(float(selected.def["cost"]) * BattleSim.RETREAT_REFUND))
		var y := p.y - 86.0 if selected.cell.y > 0 else p.y + 62.0
		_retreat_btn.position = Vector2(p.x - _retreat_btn.size.x / 2.0, y)
		_retreat_btn.visible = true
	else:
		_retreat_btn.visible = false


func _show_result() -> void:
	_end_shown = true
	placing = ""
	selected = null
	var won: bool = sim.status == "won"
	var stars: int = sim.stars()

	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.size = SCREEN
	layer.add_child(dim)

	var panel := Control.new()
	panel.size = Vector2(560, 360)
	panel.position = (SCREEN - panel.size) / 2.0
	panel.pivot_offset = panel.size / 2.0
	panel.draw.connect(_draw_result_panel.bind(panel, won, stars))
	layer.add_child(panel)

	var summary: String
	if won:
		summary = ["", "勉强守住了灯塔。", "灯塔受了点损伤。", "完美守住了灯塔！"][stars]
	else:
		summary = "灯火熄灭了。试试先挡路，再把术士对准雾甲。"
	var minutes := int(sim.time) / 60
	var seconds := int(sim.time) % 60
	var stats := Draw.make_label("%s\n击退 %d / %d   ·   灯火 %d / %d   ·   用时 %d:%02d" % [
		summary, sim.killed, sim.total_enemies, sim.life, sim.max_life, minutes, seconds], 18, Color("cfd8e6"))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.position = Vector2(0, 190)
	stats.size = Vector2(panel.size.x, 60)
	panel.add_child(stats)

	var retry := Button.new()
	retry.text = "再来一次"
	retry.position = Vector2(80, 280)
	retry.size = Vector2(180, 50)
	Draw.style_button(retry, Color("2f6f4f"), 20)
	retry.pressed.connect(func(): retry_requested.emit())
	panel.add_child(retry)

	var back := Button.new()
	back.text = "返回标题"
	back.position = Vector2(300, 280)
	back.size = Vector2(180, 50)
	Draw.style_button(back, Color("2c3a50"), 20)
	back.pressed.connect(func(): title_requested.emit())
	panel.add_child(back)

	panel.scale = Vector2(0.85, 0.85)
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35)
	tw.tween_property(panel, "modulate:a", 1.0, 0.25)


func _draw_result_panel(panel: Control, won: bool, stars: int) -> void:
	panel.draw_rect(Rect2(Vector2.ZERO, panel.size), Color("141c28"))
	panel.draw_rect(Rect2(Vector2.ZERO, Vector2(panel.size.x, 8)), Color("ffd36b") if won else Color("ef5b5b"))
	panel.draw_rect(Rect2(Vector2.ZERO, panel.size), Color("3a4a62"), false, 2.0)
	Draw.text_c(panel, Vector2(panel.size.x / 2.0, 56), "作战成功" if won else "作战失败", 44, Color.WHITE, 6)
	for i in 3:
		var c := Vector2(panel.size.x / 2.0 + (i - 1) * 74.0, 134)
		Draw.star(panel, c, 30.0, Color("ffd36b") if i < stars else Color("2e3a4b"))
