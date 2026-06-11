extends RefCounted
class_name ItemTooltip

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const ItemDataScript = preload("res://scripts/game/item_data.gd")

const BG := Color(0.07, 0.05, 0.04, 0.97)
const BORDER := Color(0.58, 0.44, 0.26, 0.95)
const TITLE := Color(0.96, 0.92, 0.84)
const BODY := Color(0.82, 0.78, 0.72)
const HINT := Color(0.68, 0.64, 0.58)
const COMPARE_UP := Color(0.45, 0.92, 0.55)
const COMPARE_DOWN := Color(0.92, 0.42, 0.38)
const MAX_TEXT_W := 240.0


static func _wrap_text(font: Font, text: String, font_size: int, max_w: float) -> PackedStringArray:
	if text.is_empty():
		return PackedStringArray()

	var words := text.split(" ", false)
	if words.is_empty():
		return PackedStringArray([text])

	var result: PackedStringArray = []
	var line := ""
	for word in words:
		var candidate := word if line.is_empty() else "%s %s" % [line, word]
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_w:
			line = candidate
			continue
		if not line.is_empty():
			result.append(line)
		if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_w:
			line = word
		else:
			result.append(word)
			line = ""
	if not line.is_empty():
		result.append(line)
	return result


static func _expand_wrapped_lines(
	font: Font,
	lines: PackedStringArray,
	sizes: Array,
	colors: Array,
	max_w: float
) -> Dictionary:
	var out_lines: Array[String] = []
	var out_sizes: Array[int] = []
	var out_colors: Array[Color] = []
	for i in lines.size():
		var sz: int = sizes[i]
		var col: Color = colors[i]
		for wrapped in _wrap_text(font, str(lines[i]), sz, max_w):
			out_lines.append(wrapped)
			out_sizes.append(sz)
			out_colors.append(col)
	return {
		"lines": out_lines,
		"sizes": out_sizes,
		"colors": out_colors,
	}


static func draw_for_slot(
	canvas: CanvasItem,
	slot_rect: Rect2,
	item: Dictionary,
	view_bounds: Rect2,
	footer_hint: String = "",
	equipment: Dictionary = {},
	equip_slot_hint: String = ""
) -> void:
	if item.is_empty():
		return

	var anchor := Vector2(
		slot_rect.position.x + slot_rect.size.x * 0.5,
		slot_rect.position.y
	)
	draw_at(canvas, anchor, item, view_bounds, footer_hint, equipment, equip_slot_hint)


static func draw_at(
	canvas: CanvasItem,
	anchor: Vector2,
	item: Dictionary,
	view_bounds: Rect2,
	footer_hint: String = "",
	equipment: Dictionary = {},
	equip_slot_hint: String = ""
) -> void:
	var lines := ItemDataScript.tooltip_lines(item, footer_hint)
	if lines.is_empty():
		return

	var comparison := ItemDataScript.comparison_line(item, equipment, equip_slot_hint)
	var compare_delta := ItemDataScript.comparison_delta(item, equipment, equip_slot_hint)

	var font := ThemeDB.fallback_font
	var title_size := UIScaleScript.font_emphasis()
	var body_size := UIScaleScript.font_ui()
	var hint_size := UIScaleScript.font_caption()
	var compare_size := UIScaleScript.font_caption()
	var pad := UIScaleScript.px(6.0)
	var line_gap := UIScaleScript.px(3.0)
	var max_w := UIScaleScript.px(MAX_TEXT_W)
	var bar_h := UIScaleScript.px(5.0)
	var icon_side := UIScaleScript.px(34.0)
	var icon_gap := UIScaleScript.px(5.0)
	var has_icon := not str(item.get("id", "")).is_empty()
	var text_max_w := max_w
	if has_icon:
		text_max_w = maxf(UIScaleScript.px(120.0), max_w - icon_side - icon_gap)

	var rarity := ItemDataScript.item_rarity(item)
	var rarity_color: Color = ItemDataScript.RARITY_COLORS.get(rarity, ItemDataScript.RARITY_COLORS["common"])

	var text_lines: Array = []
	var text_sizes: Array[int] = []
	var text_colors: Array[Color] = []

	for i in lines.size():
		var sz := title_size if i == 0 else (hint_size if i == lines.size() - 1 and not footer_hint.is_empty() else body_size)
		var col := TITLE if i == 0 else BODY
		if i == lines.size() - 1 and not footer_hint.is_empty() and lines[i] == footer_hint:
			col = HINT
		text_lines.append(lines[i])
		text_sizes.append(sz)
		text_colors.append(col)

	if not comparison.is_empty():
		text_lines.append(comparison)
		text_sizes.append(compare_size)
		text_colors.append(COMPARE_UP if compare_delta >= 0.0 else COMPARE_DOWN)

	var wrapped := _expand_wrapped_lines(font, PackedStringArray(text_lines), text_sizes, text_colors, text_max_w)
	text_lines = wrapped["lines"]
	text_sizes = wrapped["sizes"]
	text_colors = wrapped["colors"]

	var text_col_w := 0.0
	for i in text_lines.size():
		var w := font.get_string_size(text_lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, text_sizes[i]).x
		text_col_w = maxf(text_col_w, w)

	var content_w := text_col_w
	if has_icon:
		content_w = icon_side + icon_gap + text_col_w
	var box_w := minf(content_w + pad * 2.0, max_w + pad * 2.0)
	var text_block_h := 0.0
	for i in text_lines.size():
		text_block_h += float(text_sizes[i]) + line_gap
	text_block_h -= line_gap

	var content_h := text_block_h
	if has_icon:
		content_h = maxf(content_h, icon_side)

	var box_h := bar_h + pad + content_h + pad

	var box_x := anchor.x - box_w * 0.5
	var box_y := anchor.y - box_h - UIScaleScript.px(4.0)
	if box_y < view_bounds.position.y + 2.0:
		box_y = slot_bottom_y(anchor) + UIScaleScript.px(4.0)

	box_x = clampf(box_x, view_bounds.position.x + 2.0, view_bounds.end.x - box_w - 2.0)
	box_y = clampf(box_y, view_bounds.position.y + 2.0, view_bounds.end.y - box_h - 2.0)

	var box := Rect2(box_x, box_y, box_w, box_h)
	var r := UIScaleScript.px(4.0)
	_draw_rounded_fill(canvas, box, r, BG)
	_draw_rounded_stroke(canvas, box, r, BORDER, 1.0)

	var bar_rect := Rect2(box.position.x + 1.0, box.position.y + 1.0, box.size.x - 2.0, bar_h)
	canvas.draw_rect(bar_rect, Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.92))

	var content_y := box.position.y + bar_h + pad
	var text_x := box.position.x + pad
	if has_icon:
		var icon_rect := Rect2(box.position.x + pad, content_y, icon_side, icon_side)
		canvas.draw_rect(icon_rect.grow(-1.0), Color(0.12, 0.09, 0.07, 0.95))
		canvas.draw_rect(icon_rect.grow(-1.0), Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.35), false, 1.0)
		ItemDataScript.draw_item_icon(canvas, icon_rect, item)
		text_x = icon_rect.end.x + icon_gap

	var y := content_y + float(title_size)
	var draw_w := int(box.end.x - text_x - pad)
	for i in text_lines.size():
		var sz: int = text_sizes[i]
		var col: Color = text_colors[i]
		canvas.draw_string(
			font,
			Vector2(text_x, y),
			text_lines[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			draw_w,
			sz,
			col
		)
		y += float(sz) + line_gap


static func slot_bottom_y(anchor_top: Vector2) -> float:
	return anchor_top.y + UIScaleScript.px(36.0)


static func _draw_rounded_fill(canvas: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	radius = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var r := radius
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y

	canvas.draw_rect(Rect2(x + r, y, w - 2 * r, h), color)
	canvas.draw_rect(Rect2(x, y + r, w, h - 2 * r), color)
	canvas.draw_circle(Vector2(x + r, y + r), r, color)
	canvas.draw_circle(Vector2(x + w - r, y + r), r, color)
	canvas.draw_circle(Vector2(x + r, y + h - r), r, color)
	canvas.draw_circle(Vector2(x + w - r, y + h - r), r, color)


static func _draw_rounded_stroke(canvas: CanvasItem, rect: Rect2, radius: float, color: Color, width: float) -> void:
	radius = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var r := radius
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y

	canvas.draw_line(Vector2(x + r, y), Vector2(x + w - r, y), color, width)
	canvas.draw_line(Vector2(x + r, y + h), Vector2(x + w - r, y + h), color, width)
	canvas.draw_line(Vector2(x, y + r), Vector2(x, y + h - r), color, width)
	canvas.draw_line(Vector2(x + w, y + r), Vector2(x + w, y + h - r), color, width)
	canvas.draw_arc(Vector2(x + r, y + r), r, PI, PI * 1.5, 12, color, width)
	canvas.draw_arc(Vector2(x + w - r, y + r), r, PI * 1.5, TAU, 12, color, width)
	canvas.draw_arc(Vector2(x + r, y + h - r), r, PI * 0.5, PI, 12, color, width)
	canvas.draw_arc(Vector2(x + w - r, y + h - r), r, 0, PI * 0.5, 12, color, width)
