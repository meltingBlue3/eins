extends Node
## Screen flow: title -> battle -> retry or title.
## `-- --autoshot=<dir>` plays the sample plan and saves screenshots, for visual QA.

const TitleScreen = preload("res://scripts/title_screen.gd")
const BattleScreen = preload("res://scripts/battle_screen.gd")
const AutoPlayer = preload("res://scripts/sim/auto_player.gd")
const ArtStyle = preload("res://scripts/art_style.gd")

var _current: Node


func _ready() -> void:
	var shot_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autoshot="):
			shot_dir = arg.trim_prefix("--autoshot=")
		elif arg.begins_with("--style="):
			ArtStyle.select(arg.trim_prefix("--style="))
	if shot_dir != "":
		_autoshot(shot_dir)
	else:
		show_title()


func show_title() -> void:
	var title := TitleScreen.new()
	title.start_pressed.connect(start_battle)
	_swap(title)


func start_battle() -> void:
	var battle := BattleScreen.new()
	battle.retry_requested.connect(start_battle)
	battle.title_requested.connect(show_title)
	_swap(battle)


func _swap(node: Node) -> void:
	if _current != null:
		_current.queue_free()
	_current = node
	add_child(node)


func _autoshot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	show_title()
	await get_tree().create_timer(0.6).timeout
	await _shot(dir, "01_title")
	start_battle()
	var battle = _current
	battle.enable_autoplay(AutoPlayer.stage_1_1_plan())
	battle.speed = 2
	Engine.time_scale = 2.0
	await _wait_sim(battle, 2.0)
	await _shot(dir, "02_start")
	# Show the placement preview the way a player sees it mid-drag; paused so autoplay waits.
	await _wait_sim(battle, 30.0)
	await _freeze(true)
	var saved_cost: float = battle.sim.cost
	battle.sim.cost = 20.0
	battle.placing = "warden"
	battle.hover_override = true
	battle.hover_cell = Vector2i(3, 3)
	await _shot_all_styles(dir, "03_placing")
	battle.placing = ""
	battle.hover_override = false
	battle.sim.cost = saved_cost
	await _freeze(false)
	await _wait_sim(battle, 58.0)
	await _shot(dir, "04_brute")
	battle.selected = battle.sim.units[0] if not battle.sim.units.is_empty() else null
	await _wait_sim(battle, 88.0)
	await _freeze(true)
	await _shot_all_styles(dir, "05_midgame")
	await _freeze(false)
	battle.selected = null
	while battle.sim.status == "playing":
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	await _shot(dir, "06_result")
	get_tree().quit()


func _wait_sim(battle, t: float) -> void:
	while battle.sim.time < t and battle.sim.status == "playing":
		await get_tree().process_frame


## Stops game time without the pause banner. Waits two frames so no in-flight frame
## still runs with the old time scale.
func _freeze(on: bool) -> void:
	Engine.time_scale = 0.0 if on else 2.0
	await get_tree().process_frame
	await get_tree().process_frame


## Same frame in every art style, for side-by-side comparison. Restores the active style.
func _shot_all_styles(dir: String, name: String) -> void:
	var keep := ArtStyle.current
	for i in ArtStyle.STYLES.size():
		ArtStyle.current = i
		await get_tree().process_frame
		await _shot(dir, "%s_%s" % [name, ArtStyle.style_id()])
	ArtStyle.current = keep
	await get_tree().process_frame


func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(name + ".png"))
	print("shot ", name)
