extends RefCounted
## The UI kit: nine-slice frames, icons and the title logo (assets/art/watercolor/ui).
## The kit is the game's UI in every art style, including the grey-box debug view.

const Draw = preload("res://scripts/ui/draw_util.gd")
const KitButton = preload("res://scripts/ui/kit_button.gd")
const DIR := "res://assets/art/watercolor/ui/"

static var _cache := {}


static func tex(name: String) -> Texture2D:
	var path := DIR + name + ".png"
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


static func icon(name: String) -> Texture2D:
	return tex("icons/" + name)


static func _frame(name: String, margins: Vector4, content: Vector4) -> StyleBox:
	var t := tex(name)
	if t == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Draw.INK
		flat.border_color = Draw.BRASS
		flat.set_border_width_all(2)
		return flat
	var sb := StyleBoxTexture.new()
	sb.texture = t
	sb.texture_margin_left = margins.x
	sb.texture_margin_top = margins.y
	sb.texture_margin_right = margins.z
	sb.texture_margin_bottom = margins.w
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	return sb


## Brass-framed navy plaque.
static func plaque() -> StyleBox:
	return _frame("button", Vector4(16, 16, 16, 16), Vector4(18, 6, 18, 6))


## Cream paper sheet with brass lens corners.
static func panel() -> StyleBox:
	return _frame("panel", Vector4(46, 46, 46, 46), Vector4(28, 24, 28, 24))


## Smaller paper panel for HUD cards; cached because cards redraw often.
## `dim` tones it down for widgets that should not outshine the battlefield.
static func panel_small(dim := false) -> StyleBox:
	var key := "small_dim" if dim else "small"
	if not _cache.has(key):
		var sb := _frame("panel_small", Vector4(26, 26, 26, 26), Vector4(14, 12, 14, 12))
		if dim and sb is StyleBoxTexture:
			(sb as StyleBoxTexture).modulate_color = Color(0.8, 0.77, 0.72)
		_cache[key] = sb
	return _cache[key]


## Navy ribbon with swallowtail ends, for headings.
static func ribbon() -> StyleBox:
	return _frame("ribbon", Vector4(84, 0, 84, 0), Vector4(90, 0, 90, 0))


## Applies the plaque look to a button: hover brightens, press darkens.
static func style_button(btn: Button, font_size := 20) -> void:
	var tints := {"normal": Color.WHITE, "hover": Color(1.25, 1.2, 1.1), "pressed": Color(0.8, 0.8, 0.85),
		"disabled": Color(0.5, 0.5, 0.55), "focus": Color.WHITE}
	for state in tints:
		var sb: StyleBox = plaque()
		if sb is StyleBoxTexture:
			(sb as StyleBoxTexture).modulate_color = tints[state]
		if state == "focus":
			sb = StyleBoxEmpty.new()
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color("f4ead2"))
	btn.add_theme_color_override("font_hover_color", Draw.LAMP)
	btn.add_theme_color_override("font_pressed_color", Draw.LAMP)
	btn.add_theme_color_override("font_disabled_color", Color("8a8678"))
	btn.add_theme_constant_override("icon_max_width", 26)
	btn.add_theme_constant_override("h_separation", 8)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## A plaque button that grows on hover. `icon_name` is one of the kit icons, or "".
## Primary buttons (the one main action per screen) get lamp-gold text and a larger font.
static func button(label: String, button_size: Vector2, font_size := 20, icon_name := "", primary := false) -> Button:
	var b: Button = KitButton.new()
	b.text = label
	b.size = button_size
	b.custom_minimum_size = button_size
	style_button(b, font_size + (2 if primary else 0))
	if primary:
		b.add_theme_color_override("font_color", Draw.LAMP)
		b.add_theme_color_override("font_hover_color", Color("fff1c4"))
	if icon_name != "":
		b.icon = icon(icon_name)
	return b


## Full-screen modal: dimmed backdrop, paper sheet named "Sheet" with a ribbon heading.
## Add content to root.get_node("Sheet"); free the root to close. Pops in with a small scale.
static func modal(title: String, sheet_size: Vector2) -> Control:
	var root := Control.new()
	root.size = Vector2(1280, 720)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.6)
	dim.size = root.size
	root.add_child(dim)
	var sheet := Panel.new()
	sheet.name = "Sheet"
	sheet.add_theme_stylebox_override("panel", panel())
	sheet.size = sheet_size
	sheet.position = (root.size - sheet_size) / 2.0
	sheet.pivot_offset = sheet_size / 2.0
	root.add_child(sheet)
	var band := Panel.new()
	band.add_theme_stylebox_override("panel", ribbon())
	band.size = Vector2(minf(sheet_size.x + 40.0, 440.0), 76)
	band.position = Vector2((sheet_size.x - band.size.x) / 2.0, -38)
	sheet.add_child(band)
	var head := heading(title, 28)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.size = band.size - Vector2(0, 8)
	band.add_child(head)
	sheet.scale = Vector2(0.9, 0.9)
	sheet.modulate.a = 0.0
	# Ignores time scale so menus still animate while the battle is frozen.
	var tw := sheet.create_tween().set_parallel(true).set_ignore_time_scale(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sheet, "scale", Vector2.ONE, 0.25)
	tw.tween_property(sheet, "modulate:a", 1.0, 0.18)
	return root


## Text with the heading treatment: cream fill, ink outline.
static func heading(text: String, size: int) -> Label:
	var l := Draw.make_label(text, size, Color("f7efdc"))
	l.add_theme_constant_override("outline_size", maxi(4, size / 6))
	l.add_theme_color_override("font_outline_color", Color(Draw.INK, 0.92))
	return l
