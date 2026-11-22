extends SceneTree
## Headless rule and balance checks.
## Run: godot --headless --path . -s res://tests/test_battle.gd

const GameData = preload("res://scripts/game_data.gd")
const BattleSim = preload("res://scripts/sim/battle_sim.gd")
const AutoPlayer = preload("res://scripts/sim/auto_player.gd")

const DT := 1.0 / 60.0

var _failures := 0


func _init() -> void:
	_test_path()
	_test_deploy_rules()
	_test_retreat()
	_test_idle_loses()
	_test_plan_wins()
	_test_single_blade_struggles()
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func _new_sim():
	return BattleSim.new(GameData.STAGES[0])


func _run(sim, plan: Array, limit := 400.0) -> void:
	var player = AutoPlayer.new(plan)
	while sim.status == "playing" and sim.time < limit:
		player.update(sim)
		sim.step(DT)


func _test_path() -> void:
	print("path")
	var sim = _new_sim()
	_check(sim.path.front() == Vector2(sim.spawn_cell), "path starts at the gate")
	_check(sim.path.back() == Vector2(sim.base_cell), "path ends at the lighthouse")
	_check(sim.path.size() == 28, "stage 1-1 path is the full snake (got %d)" % sim.path.size())
	_check(sim.total_enemies == 34, "stage 1-1 has 34 enemies (got %d)" % sim.total_enemies)


func _test_deploy_rules() -> void:
	print("deploy rules")
	var sim = _new_sim()
	_check(sim.deploy_block_reason("archer", Vector2i(5, 1)) == "需要高台格", "ranged unit rejects ground")
	_check(sim.deploy_block_reason("blade", Vector2i(5, 2)) == "需要地面格", "melee unit rejects high ground")
	_check(sim.deploy_block_reason("caster", Vector2i(4, 2)) == "费用不足", "16-cost unit rejected at 10 cost")
	_check(sim.deploy("blade", Vector2i(5, 1)) != null, "blade deploys on ground")
	_check(is_equal_approx(sim.cost, 0.0), "deploy spends cost")
	sim.cost = 50.0
	_check(sim.deploy_block_reason("blade", Vector2i(6, 1)) == "已在场上", "each unit is on the field once")
	_check(sim.deploy_block_reason("warden", Vector2i(5, 1)) == "格子已被占用", "cells hold one unit")


func _test_retreat() -> void:
	print("retreat")
	var sim = _new_sim()
	var u = sim.deploy("blade", Vector2i(5, 1))
	sim.retreat(u)
	_check(is_equal_approx(sim.cost, 5.0), "retreat refunds half cost (got %.1f)" % sim.cost)
	_check(sim.card_block_reason("blade") == "再部署冷却中", "retreat starts redeploy cooldown")
	for i in 60 * 21:
		sim.step(DT)
	_check(sim.card_block_reason("blade") == "", "cooldown ends after 20s")


func _test_idle_loses() -> void:
	print("balance: idle")
	var sim = _new_sim()
	_run(sim, [])
	print("       idle -> %s at %.0fs" % [sim.status, sim.time])
	_check(sim.status == "lost", "doing nothing loses")


func _test_plan_wins() -> void:
	print("balance: sensible plan")
	var sim = _new_sim()
	_run(sim, AutoPlayer.stage_1_1_plan())
	print("       plan -> %s, life %d/%d, killed %d/%d, %.0fs, %d star(s)" % [
		sim.status, sim.life, sim.max_life, sim.killed, sim.total_enemies, sim.time, sim.stars()])
	_check(sim.status == "won", "sensible plan wins")
	_check(sim.stars() >= 2, "sensible plan earns at least 2 stars")


func _test_single_blade_struggles() -> void:
	print("balance: single blade")
	var sim = _new_sim()
	_run(sim, [{"t": 0.0, "unit": "blade", "cell": Vector2i(5, 1)}])
	print("       blade only -> %s, life %d/%d, killed %d" % [sim.status, sim.life, sim.max_life, sim.killed])
	_check(sim.status == "lost" or sim.stars() < 3, "one unit alone cannot three-star the stage")
