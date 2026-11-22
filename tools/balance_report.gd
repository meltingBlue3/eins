extends SceneTree
## Prints a key-event timeline for the stage 1-1 sample plan. Use it when tuning numbers.
## Run: godot --headless --path . -s res://tools/balance_report.gd

const GameData = preload("res://scripts/game_data.gd")
const BattleSim = preload("res://scripts/sim/battle_sim.gd")
const AutoPlayer = preload("res://scripts/sim/auto_player.gd")


func _init() -> void:
	var sim = BattleSim.new(GameData.STAGES[0])
	var player = AutoPlayer.new(AutoPlayer.stage_1_1_plan())
	var dealt := {}
	while sim.status == "playing" and sim.time < 400.0:
		player.update(sim)
		sim.step(1.0 / 60.0)
		for ev in sim.events:
			match ev["type"]:
				"deploy", "unit_down", "retreat":
					print("%6.1fs  %-9s %s" % [sim.time, ev["type"], ev["unit"].def["name"]])
				"leak":
					print("%6.1fs  leak      %s (life %d)" % [sim.time, ev["enemy"].def["name"], sim.life])
				"attack":
					var name: String = ev["unit"].def["name"]
					dealt[name] = dealt.get(name, 0) + 1
				"end":
					print("%6.1fs  end       %s, %d star(s)" % [sim.time, ev["status"], sim.stars()])
		sim.events.clear()
	print("attacks per unit: ", dealt)
	print("killed %d/%d, leaked %d" % [sim.killed, sim.total_enemies, sim.leaked])
	quit()
