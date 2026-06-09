extends Control
class_name StatBar

@export var bar_color: Color = Color(0.35, 0.75, 1.0)
@export var bg_color: Color = Color(0.08, 0.08, 0.12, 0.9)

var _ratio := 1.0
var _label := ""


func set_value(current: float, maximum: float, label: String = "") -> void:
	_ratio = 1.0 if maximum <= 0.0 else clampf(current / maximum, 0.0, 1.0)
	_label = label
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, bg_color, true)
	var fill := Rect2(Vector2.ZERO, Vector2(size.x * _ratio, size.y))
	draw_rect(fill, bar_color, true)

	if not _label.is_empty() and size.y >= 10.0:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(4, size.y - 3),
			_label,
			HORIZONTAL_ALIGNMENT_LEFT,
			int(size.x - 8),
			max(8, int(size.y) - 2),
			Color(0.95, 0.95, 1.0)
		)
