extends Node
## Screen flow: title -> battle -> retry or title, with an ink fade between screens.
## `-- --autoshot=<dir>` plays the sample plan and saves screenshots, for visual QA.

const TitleScreen = preload("res://scripts/title_screen.gd")
const BattleScreen = preload("res://scripts/battle_screen.gd")
const AutoPlayer = preload("res://scripts/sim/auto_player.gd")
const ArtStyle = preload("res://scripts/art_style.gd")
const Settings = preload("res://scripts/settings.gd")
const Draw = preload("res://scripts/ui/draw_util.gd")

const FADE_OUT := 0.22
const FADE_IN := 0.35

var _current: Node
var _veil: ColorRect
var _busy := false


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_veil = ColorRect.new()
	_veil.color = Draw.INK
	_veil.size = Vector2(1280, 720)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_veil)

	var shot_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autoshot="):
			shot_dir = arg.trim_prefix("--autoshot=")
		elif arg.begins_with("--style="):
			ArtStyle.select(arg.trim_prefix("--style="))
	if shot_dir != "":
		_autoshot(shot_dir)
	else:
		Settings.load_once()
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


## Fades to ink, swaps the screen, fades back. The first screen only fades in.
func _swap(node: Node) -> void:
	if _busy:
		node.free()
		return
	_busy = true
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	if _current != null:
		var out := create_tween()
		out.tween_property(_veil, "color:a", 1.0, FADE_OUT)
		await out.finished
		_current.queue_free()
	_current = node
	add_child(node)
	var back := create_tween()
	back.tween_property(_veil, "color:a", 0.0, FADE_IN)
	await back.finished
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _autoshot(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	show_title()
	await get_tree().create_timer(1.2).timeout
	await _shot(dir, "01_title")
	start_battle()
	while not (_current is BattleScreen and not _busy):
		await get_tree().process_frame
	var battle = _current
	await get_tree().create_timer(0.9).timeout
	await _shot(dir, "02_intro")
	battle.enable_autoplay(AutoPlayer.stage_1_1_plan())
	battle.speed = 2
	Engine.time_scale = 2.0
	await _wait_sim(battle, 9.0)
	await _shot(dir, "03_start")
	# Show the placement preview the way a player sees it mid-drag; time frozen so autoplay waits.
	await _wait_sim(battle, 30.0)
	await _freeze(true)
	var saved_cost: float = battle.sim.cost
	battle.sim.cost = 20.0
	battle.placing = "warden"
	battle.hover_override = true
	battle.hover_cell = Vector2i(3, 3)
	await _shot_all_styles(dir, "04_placing")
	battle.placing = ""
	battle.hover_override = false
	battle.sim.cost = saved_cost
	await _freeze(false)
	await _wait_sim(battle, 47.0)
	await _shot(dir, "05_brute_tip")
	battle.selected = battle.sim.units[0] if not battle.sim.units.is_empty() else null
	await _wait_sim(battle, 88.0)
	await _freeze(true)
	await _shot_all_styles(dir, "06_midgame")
	battle.selected = null
	battle.open_pause_menu()
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot(dir, "07_pause")
	battle.open_settings()
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot(dir, "08_settings")
	battle.close_menus()
	await _freeze(false)
	while battle.sim.status == "playing":
		await get_tree().process_frame
	await get_tree().create_timer(2.4).timeout
	await _shot(dir, "09_result")
	get_tree().quit()


func _wait_sim(battle, t: float) -> void:
	while battle.sim.time < t and battle.sim.status == "playing":
		await get_tree().process_frame


## Stops game time without the pause menu. Waits two frames so no in-flight frame
## still runs with the old time scale. Tweens keep running (they ignore time scale here).
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
