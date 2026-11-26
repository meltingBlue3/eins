extends RefCounted
## Shared immediate-mode drawing helpers for the grey-box look.

const FONT = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")


## Draws text centered on `pos` (both axes).
static func text_c(ci: CanvasItem, pos: Vector2, text: String, size: int, color: Color, outline := 0, outline_color := Color(0, 0, 0, 0.85)) -> void:
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := pos + Vector2(-w / 2.0, size * 0.36)
	if outline > 0:
		ci.draw_string_outline(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(outline_color, outline_color.a * color.a))
	ci.draw_string(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func ellipse(ci: CanvasItem, center: Vector2, radii: Vector2, color: Color) -> void:
	ci.draw_set_transform(center, 0.0, Vector2(1.0, radii.y / radii.x))
	ci.draw_circle(Vector2.ZERO, radii.x, color, true, -1.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Draws a bottom-anchored sprite with its feet at `feet`, optionally mirrored.
static func sprite(ci: CanvasItem, tex: Texture2D, feet: Vector2, size: Vector2, flip := false, modulate := Color.WHITE) -> void:
	ci.draw_set_transform(feet, 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	ci.draw_texture_rect(tex, Rect2(Vector2(-size.x / 2.0, -size.y), size), false, modulate)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func bar(ci: CanvasItem, top_left: Vector2, width: float, height: float, ratio: float, color: Color) -> void:
	ci.draw_rect(Rect2(top_left - Vector2(1, 1), Vector2(width + 2, height + 2)), Color(0, 0, 0, 0.75))
	ci.draw_rect(Rect2(top_left, Vector2(width * clampf(ratio, 0.0, 1.0), height)), color)


static func hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color("6fdc8c")
	if ratio > 0.25:
		return Color("f2c94c")
	return Color("ef5b5b")


static func star(ci: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var r := radius if i % 2 == 0 else radius * 0.45
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, color)


static func style_button(btn: Button, base: Color, font_size := 20) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		match state:
			"normal":
				sb.bg_color = base
			"hover":
				sb.bg_color = base.lightened(0.15)
			"pressed":
				sb.bg_color = base.darkened(0.2)
			"disabled":
				sb.bg_color = base.darkened(0.5)
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(8)
		sb.border_color = base.lightened(0.35)
		sb.set_border_width_all(1)
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func make_label(text: String, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
