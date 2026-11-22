extends RefCounted
## Deterministic battle rules. The screen drains `events` for effects; tests drive `step()` directly.
## Positions are in tile space: Vector2(col, row) is the center of that cell.

const GameData = preload("res://scripts/game_data.gd")
const SimUnit = preload("res://scripts/sim/sim_unit.gd")
const SimEnemy = preload("res://scripts/sim/sim_enemy.gd")

const COST_START := 10.0
const COST_RATE := 1.0
const COST_MAX := 99.0
const RETREAT_REFUND := 0.5
const BLOCK_REACH := 0.55

var stage: Dictionary
var grid: Array[String] = []
var cols := 0
var rows := 0
var spawn_cell := Vector2i.ZERO
var base_cell := Vector2i.ZERO
var path: Array[Vector2] = []

var time := 0.0
var cost := COST_START
var life := 0
var max_life := 0
var status := "playing"  # playing | won | lost
var units: Array = []
var enemies: Array = []
var cooldowns := {}
var spawn_queue: Array = []
var total_enemies := 0
var killed := 0
var leaked := 0
var events: Array = []
var _next_uid := 1


func _init(stage_def: Dictionary) -> void:
	stage = stage_def
	grid.assign(stage_def["map"])
	rows = grid.size()
	cols = grid[0].length()
	for r in rows:
		for c in cols:
			match grid[r][c]:
				"R":
					spawn_cell = Vector2i(c, r)
				"B":
					base_cell = Vector2i(c, r)
	path = _find_path(spawn_cell, base_cell)
	max_life = int(stage_def["life"])
	life = max_life
	for w in stage_def["waves"]:
		for i in int(w["n"]):
			spawn_queue.append({"t": float(w["t"]) + i * float(w.get("gap", 0.0)), "type": w["type"]})
	spawn_queue.sort_custom(func(a, b): return a["t"] < b["t"])
	total_enemies = spawn_queue.size()


# --- Queries ---------------------------------------------------------------

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows


func tile_at(cell: Vector2i) -> String:
	return grid[cell.y][cell.x] if in_bounds(cell) else "#"


func is_walkable(cell: Vector2i) -> bool:
	return tile_at(cell) in [".", "R", "B"]


func unit_at(cell: Vector2i):
	for u in units:
		if u.alive and u.cell == cell:
			return u
	return null


func is_deployed(unit_id: String) -> bool:
	for u in units:
		if u.alive and u.id == unit_id:
			return true
	return false


func cooldown_of(unit_id: String) -> float:
	return cooldowns.get(unit_id, 0.0)


func cell_fits(unit_id: String, cell: Vector2i) -> bool:
	var tile := tile_at(cell)
	match GameData.UNITS[unit_id]["tile"]:
		"ground":
			return tile == "."
		"high":
			return tile == "^"
	return false


## Why the card cannot be picked right now, or "" if it can.
func card_block_reason(unit_id: String) -> String:
	if status != "playing":
		return "作战已结束"
	if is_deployed(unit_id):
		return "已在场上"
	if cooldown_of(unit_id) > 0.0:
		return "再部署冷却中"
	if cost < float(GameData.UNITS[unit_id]["cost"]):
		return "费用不足"
	return ""


## Why the unit cannot go on this cell, or "" if it can.
func deploy_block_reason(unit_id: String, cell: Vector2i) -> String:
	var card := card_block_reason(unit_id)
	if card != "":
		return card
	if not cell_fits(unit_id, cell):
		return "需要地面格" if GameData.UNITS[unit_id]["tile"] == "ground" else "需要高台格"
	if unit_at(cell) != null:
		return "格子已被占用"
	return ""


func stars() -> int:
	if status != "won":
		return 0
	if life == max_life:
		return 3
	return 2 if life * 2 >= max_life else 1


# --- Commands --------------------------------------------------------------

func deploy(unit_id: String, cell: Vector2i):
	if deploy_block_reason(unit_id, cell) != "":
		return null
	var d: Dictionary = GameData.UNITS[unit_id]
	cost -= float(d["cost"])
	var u = SimUnit.new(_take_uid(), unit_id, d, cell)
	units.append(u)
	events.append({"type": "deploy", "unit": u})
	return u


func retreat(u) -> void:
	if not u.alive or status != "playing":
		return
	var refund := floorf(float(u.def["cost"]) * RETREAT_REFUND)
	cost = minf(cost + refund, COST_MAX)
	_remove_unit(u)
	events.append({"type": "retreat", "unit": u, "refund": refund})


func step(dt: float) -> void:
	if status != "playing":
		return
	time += dt
	cost = minf(cost + COST_RATE * dt, COST_MAX)
	for id in cooldowns.keys():
		cooldowns[id] = maxf(cooldowns[id] - dt, 0.0)
	_spawn_due()
	for e in enemies:
		_tick_enemy(e, dt)
	for u in units:
		_tick_unit(u, dt)
	enemies = enemies.filter(func(e): return e.alive)
	units = units.filter(func(u): return u.alive)
	_check_end()


# --- Rules -----------------------------------------------------------------

func _find_path(from: Vector2i, to: Vector2i) -> Array[Vector2]:
	var prev := {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == to:
			break
		for d in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var nxt: Vector2i = cur + d
			if is_walkable(nxt) and not prev.has(nxt):
				prev[nxt] = cur
				queue.append(nxt)
	assert(prev.has(to), "Stage has no walkable route from gate to lighthouse.")
	var cells: Array[Vector2] = []
	var step_cell := to
	while step_cell != from:
		cells.push_front(Vector2(step_cell))
		step_cell = prev[step_cell]
	cells.push_front(Vector2(from))
	return cells


func _take_uid() -> int:
	_next_uid += 1
	return _next_uid


func _spawn_due() -> void:
	while not spawn_queue.is_empty() and spawn_queue[0]["t"] <= time:
		var entry: Dictionary = spawn_queue.pop_front()
		var type: String = entry["type"]
		var e = SimEnemy.new(_take_uid(), type, GameData.ENEMIES[type], path[0])
		enemies.append(e)
		events.append({"type": "spawn", "enemy": e})


func _tick_enemy(e, dt: float) -> void:
	if not e.alive:
		return
	e.lunge_t = maxf(e.lunge_t - dt, 0.0)
	e.flash_t = maxf(e.flash_t - dt, 0.0)
	if e.blocker != null:
		e.atk_timer -= dt
		if e.atk_timer <= 0.0:
			e.atk_timer += float(e.def["interval"])
			e.face = (e.blocker.pos - e.pos).normalized()
			e.lunge_t = 0.15
			_damage_unit(e.blocker, _physical(e.def["atk"], e.blocker.def["def"]))
		return

	var move: float = float(e.def["speed"]) * dt
	while move > 0.0 and e.path_i < path.size():
		var to: Vector2 = path[e.path_i] - e.pos
		var dist := to.length()
		if dist > 0.0:
			e.face = to / dist
		if dist <= move:
			e.pos = path[e.path_i]
			e.progress += dist
			move -= dist
			e.path_i += 1
		else:
			e.pos += to / dist * move
			e.progress += move
			move = 0.0
	if e.path_i >= path.size():
		_leak(e)
		return

	var blocker = _find_blocker(e)
	if blocker != null:
		e.blocker = blocker
		blocker.blocked.append(e)
		e.atk_timer = float(e.def["interval"]) * 0.5


func _find_blocker(e):
	for u in units:
		if u.can_block_more() and u.pos.distance_to(e.pos) <= BLOCK_REACH:
			return u
	return null


func _tick_unit(u, dt: float) -> void:
	if not u.alive:
		return
	u.lunge_t = maxf(u.lunge_t - dt, 0.0)
	u.flash_t = maxf(u.flash_t - dt, 0.0)
	u.spawn_t = maxf(u.spawn_t - dt, 0.0)
	u.atk_timer = maxf(u.atk_timer - dt, 0.0)
	if u.atk_timer > 0.0:
		return
	if u.def["kind"] == "healer":
		var ally = _pick_heal_target(u)
		if ally == null:
			return
		u.atk_timer = float(u.def["interval"])
		var amount := minf(float(u.def["atk"]), ally.max_hp - ally.hp)
		ally.hp += amount
		events.append({"type": "heal", "unit": u, "target": ally, "amount": int(amount)})
		return

	var target = _pick_enemy_target(u)
	if target == null:
		return
	u.atk_timer = float(u.def["interval"])
	u.face = (target.pos - u.pos).normalized()
	u.lunge_t = 0.15
	var dmg: int
	if u.def["damage"] == "arts":
		dmg = int(float(u.def["atk"]) * (1.0 - float(target.def["res"]) / 100.0))
	else:
		dmg = _physical(u.def["atk"], target.def["def"])
	events.append({"type": "attack", "unit": u, "target": target, "kind": u.def["kind"], "damage": u.def["damage"]})
	_damage_enemy(target, dmg)


func _pick_enemy_target(u):
	# Melee units hit what they hold first; everyone else prefers the enemy closest to the lighthouse.
	for e in u.blocked:
		if e.alive:
			return e
	var best = null
	var reach: float = u.def["range"]
	for e in enemies:
		if e.alive and u.pos.distance_to(e.pos) <= reach:
			if best == null or e.progress > best.progress:
				best = e
	return best


func _pick_heal_target(u):
	var best = null
	var reach: float = u.def["range"]
	for a in units:
		if a.alive and a.hp < a.max_hp and u.pos.distance_to(a.pos) <= reach:
			if best == null or a.hp / a.max_hp < best.hp / best.max_hp:
				best = a
	return best


func _physical(atk, armor) -> int:
	return int(maxf(float(atk) - float(armor), float(atk) * 0.05))


func _damage_enemy(e, amount: int) -> void:
	e.hp -= amount
	e.flash_t = 0.08
	events.append({"type": "hit", "enemy": e, "amount": amount})
	if e.hp <= 0.0 and e.alive:
		e.alive = false
		killed += 1
		if e.blocker != null:
			e.blocker.blocked.erase(e)
			e.blocker = null
		events.append({"type": "kill", "enemy": e})


func _damage_unit(u, amount: int) -> void:
	u.hp -= amount
	u.flash_t = 0.08
	events.append({"type": "hurt", "unit": u, "amount": amount})
	if u.hp <= 0.0 and u.alive:
		_remove_unit(u)
		events.append({"type": "unit_down", "unit": u})


func _remove_unit(u) -> void:
	u.alive = false
	for e in u.blocked:
		e.blocker = null
	u.blocked.clear()
	cooldowns[u.id] = float(u.def["redeploy"])


func _leak(e) -> void:
	e.alive = false
	leaked += 1
	life = maxi(life - int(e.def["life_cost"]), 0)
	events.append({"type": "leak", "enemy": e})


func _check_end() -> void:
	if life <= 0:
		status = "lost"
	elif spawn_queue.is_empty() and enemies.is_empty():
		status = "won"
	else:
		return
	events.append({"type": "end", "status": status})
