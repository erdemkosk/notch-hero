extends Control
class_name StatBar

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")

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

	if not _label.is_empty() and size.y >= UIScaleScript.px(10.0):
		draw_string(
			ThemeDB.fallback_font,
			Vector2(UIScaleScript.px(4.0), size.y - UIScaleScript.px(3.0)),
			_label,
			HORIZONTAL_ALIGNMENT_LEFT,
			int(size.x - UIScaleScript.px(8.0)),
			max(UIScaleScript.font_caption(), int(size.y) - UIScaleScript.font_caption()),
			Color(0.95, 0.95, 1.0)
		)
