extends RefCounted
class_name InventorySlotDraw

const SLOT_BG := Color(0.24, 0.14, 0.08)
const SLOT_INSET := Color(0.18, 0.1, 0.06)
const SLOT_HI := Color(0.32, 0.2, 0.12)
const INNER_GROW := 2.0


static func corner_radius(rect: Rect2) -> float:
	return clampf(rect.size.x * 0.12, 3.0, 5.0)


static func inner_content_rect(rect: Rect2) -> Rect2:
	return rect.grow(-INNER_GROW)


static func draw_square(
	canvas: CanvasItem,
	rect: Rect2,
	hovered: bool,
	bg_override: Color = Color(-1, -1, -1, -1)
) -> void:
	var slot_side := rect.size.x
	var r := clampf(slot_side * 0.12, 3.0, 5.0)
	var bg := SLOT_BG
	if bg_override.a >= 0.0:
		bg = bg_override
	elif hovered:
		bg = bg.lightened(0.06)

	_draw_rounded_fill(canvas, rect, r, bg)
	var inner := rect.grow(-2.0)
	_draw_rounded_fill(canvas, inner, r - 1.0, SLOT_INSET if not hovered else SLOT_HI)
	_draw_rounded_stroke(canvas, rect, r, SLOT_HI if hovered else SLOT_INSET.darkened(0.2), 1.0)


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
