extends RefCounted
class_name NavIcons


static func draw(canvas: CanvasItem, center: Vector2, tab: int, color: Color, scale: float = 1.0) -> void:
	var s := scale
	match tab:
		0:
			_draw_sword(canvas, center, s, color)
		1:
			_draw_bag(canvas, center, s, color)
		2:
			_draw_hammer(canvas, center, s, color)
		3:
			_draw_coin(canvas, center, s, color)


static func _draw_sword(canvas: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.0, s * 0.14)
	canvas.draw_line(c + Vector2(0, -s * 0.42), c + Vector2(0, s * 0.32), col, w)
	canvas.draw_line(c + Vector2(-s * 0.22, s * 0.08), c + Vector2(s * 0.22, s * 0.08), col, w)
	canvas.draw_line(c + Vector2(0, s * 0.32), c + Vector2(0, s * 0.48), col, w * 0.85)


static func _draw_bag(canvas: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.0, s * 0.14)
	canvas.draw_line(c + Vector2(-s * 0.18, -s * 0.28), c + Vector2(s * 0.18, -s * 0.28), col, w)
	canvas.draw_arc(c + Vector2(0, -s * 0.12), s * 0.2, PI, TAU, 10, col, w)
	canvas.draw_rect(Rect2(c.x - s * 0.22, c.y - s * 0.12, s * 0.44, s * 0.38), col, false, w)


static func _draw_hammer(canvas: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.0, s * 0.14)
	canvas.draw_line(c + Vector2(-s * 0.05, -s * 0.42), c + Vector2(s * 0.08, s * 0.38), col, w)
	canvas.draw_rect(Rect2(c.x - s * 0.32, c.y - s * 0.42, s * 0.42, s * 0.16), col, false, w)


static func _draw_coin(canvas: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.0, s * 0.14)
	canvas.draw_arc(c + Vector2(0, s * 0.02), s * 0.28, 0, TAU, 18, col, w)
	canvas.draw_line(c + Vector2(-s * 0.12, -s * 0.08), c + Vector2(s * 0.12, s * 0.12), col, w * 0.8)
