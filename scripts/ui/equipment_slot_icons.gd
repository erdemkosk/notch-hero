extends RefCounted
class_name EquipmentSlotIcons

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")


static func draw(canvas: CanvasItem, rect: Rect2, equip_slot: String, color: Color) -> void:
	var center := rect.position + rect.size * 0.5
	var s := rect.size.x * 0.34
	var c := Color(color.r, color.g, color.b, 0.38)
	var w := maxf(1.0, UIScaleScript.px(1.2))

	match equip_slot:
		"helmet":
			_draw_helmet(canvas, center, s, c, w)
		"weapon":
			_draw_sword(canvas, center, s, c, w)
		"chest":
			_draw_chest(canvas, center, s, c, w)
		"legs":
			_draw_legs(canvas, center, s, c, w)
		"feet":
			_draw_feet(canvas, center, s, c, w)
		"gloves":
			_draw_glove(canvas, center, s, c, w)
		"ring_1", "ring_2":
			_draw_ring(canvas, center, s, c, w)
		"earring_1", "earring_2":
			_draw_earring(canvas, center, s, c, w)
		"amulet":
			_draw_amulet(canvas, center, s, c, w)
		_:
			_draw_ring(canvas, center, s * 0.7, c, w)


static func _draw_helmet(canvas: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	canvas.draw_arc(c + Vector2(0, s * 0.05), s * 0.55, PI, TAU, 16, col, w)
	canvas.draw_line(c + Vector2(-s * 0.55, s * 0.05), c + Vector2(s * 0.55, s * 0.05), col, w)


static func _draw_sword(canvas: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	canvas.draw_line(c + Vector2(0, -s * 0.75), c + Vector2(0, s * 0.55), col, w)
	canvas.draw_line(c + Vector2(-s * 0.35, s * 0.15), c + Vector2(s * 0.35, s * 0.15), col, w)
	canvas.draw_line(c + Vector2(0, s * 0.55), c + Vector2(0, s * 0.75), col, w * 0.8)


static func _draw_chest(canvas: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	var body := Rect2(c.x - s * 0.45, c.y - s * 0.35, s * 0.9, s * 0.75)
	canvas.draw_rect(body, col, false, w)
	canvas.draw_line(Vector2(c.x, body.position.y), Vector2(c.x, body.end.y), col, w * 0.7)


static func _draw_legs(canvas: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	canvas.draw_line(c + Vector2(-s * 0.22, -s * 0.35), c + Vector2(-s * 0.22, s * 0.55), col, w)
	canvas.draw_line(c + Vector2(s * 0.22, -s * 0.35), c + Vector2(s * 0.22, s * 0.55), col, w)
	canvas.draw_line(c + Vector2(-s * 0.35, -s * 0.35), c + Vector2(s * 0.35, -s * 0.35), col, w)


static func _draw_feet(canvas: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	canvas.draw_line(c + Vector2(-s * 0.3, -s * 0.2), c + Vector2(-s * 0.3, s * 0.25), col, w)
	canvas.draw_line(c + Vector2(s * 0.3, -s * 0.2), c + Vector2(s * 0.3, s * 0.25), col, w)
	canvas.draw_line(c + Vector2(-s * 0.45, s * 0.25), c + Vector2(-s * 0.15, s * 0.25), col, w)
	canvas.draw_line(c + Vector2(s * 0.15, s * 0.25), c + Vector2(s * 0.45, s * 0.25), col, w)


static func _draw_glove(canvas: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	canvas.draw_line(c + Vector2(-s * 0.15, -s * 0.45), c + Vector2(-s * 0.15, s * 0.35), col, w)
	canvas.draw_line(c + Vector2(s * 0.05, -s * 0.55), c + Vector2(s * 0.05, s * 0.2), col, w)
	canvas.draw_line(c + Vector2(s * 0.25, -s * 0.5), c + Vector2(s * 0.25, s * 0.15), col, w)
	canvas.draw_line(c + Vector2(-s * 0.15, s * 0.35), c + Vector2(s * 0.25, s * 0.15), col, w)


static func _draw_ring(canvas: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	canvas.draw_arc(c + Vector2(0, s * 0.1), s * 0.35, 0, TAU, 24, col, w)
	canvas.draw_circle(c + Vector2(0, -s * 0.35), s * 0.12, col)


static func _draw_earring(canvas: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	canvas.draw_line(c + Vector2(0, -s * 0.55), c + Vector2(0, -s * 0.15), col, w)
	canvas.draw_circle(c + Vector2(0, s * 0.15), s * 0.22, col)


static func _draw_amulet(canvas: CanvasItem, c: Vector2, s: float, col: Color, w: float) -> void:
	canvas.draw_line(c + Vector2(0, -s * 0.55), c + Vector2(0, -s * 0.2), col, w)
	var gem := PackedVector2Array([
		c + Vector2(0, s * 0.35),
		c + Vector2(-s * 0.28, s * 0.05),
		c + Vector2(0, -s * 0.05),
		c + Vector2(s * 0.28, s * 0.05),
	])
	canvas.draw_polyline(gem, col, w, true)
