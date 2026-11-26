extends RefCounted
## Player settings, saved to user://settings.cfg and applied on change.

const ArtStyle = preload("res://scripts/art_style.gd")
const PATH := "user://settings.cfg"

static var fullscreen := false
static var show_damage := true
static var _loaded := false


static func load_once() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	fullscreen = cfg.get_value("display", "fullscreen", false)
	show_damage = cfg.get_value("battle", "show_damage", true)
	ArtStyle.select(cfg.get_value("display", "style", ArtStyle.style_id()))
	apply()


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "style", ArtStyle.style_id())
	cfg.set_value("battle", "show_damage", show_damage)
	cfg.save(PATH)


static func apply() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
