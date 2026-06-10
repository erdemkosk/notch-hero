extends RefCounted
class_name InventoryPanelChrome

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const InventorySlotDrawScript = preload("res://scripts/ui/inventory_slot_draw.gd")

enum Style { BAG, EQUIP }

const STITCH := Color(0.78, 0.58, 0.34)


static func draw(canvas: CanvasItem, rect: Rect2, style: Style) -> void:
	var dark := Color(0.34, 0.21, 0.12)
	var mid := Color(0.48, 0.31, 0.18)
	var light := Color(0.68, 0.46, 0.28)
	if style == Style.EQUIP:
		dark = Color(0.28, 0.2, 0.13)
		mid = Color(0.4, 0.3, 0.2)
		light = Color(0.58, 0.44, 0.3)

	var r := UIScaleScript.px(6.0)
	InventorySlotDrawScript._draw_rounded_fill(canvas, rect, r, dark)
	var inset := rect.grow(-UIScaleScript.px(2.0))
	InventorySlotDrawScript._draw_rounded_fill(canvas, inset, r - 1.0, mid)
	InventorySlotDrawScript._draw_rounded_stroke(canvas, rect, r, light, 1.5)

	var hl_w := rect.size.x - r * 2.0
	var hl := Rect2(rect.position.x + r, rect.position.y + UIScaleScript.px(1.0), hl_w, UIScaleScript.px(3.0))
	canvas.draw_rect(hl, Color(1.0, 0.94, 0.82, 0.14))

	_draw_vignette(canvas, rect, r)

	var step := UIScaleScript.px(5.0)
	var sx := rect.position.x + r + 2.0
	while sx < rect.end.x - r - 2.0:
		canvas.draw_circle(Vector2(sx, rect.position.y + 3.0), 1.0, STITCH)
		canvas.draw_circle(Vector2(sx, rect.end.y - 3.0), 1.0, STITCH)
		sx += step


static func _draw_vignette(canvas: CanvasItem, rect: Rect2, corner_r: float) -> void:
	var strips := 5
	var inner_x := rect.position.x + corner_r
	var inner_w := rect.size.x - corner_r * 2.0
	var strip_h := rect.size.y / float(strips)
	for i in strips:
		var t := absf(float(i) / float(strips - 1) - 0.5) * 2.0
		var alpha := (1.0 - t) * 0.1
		var y := rect.position.y + strip_h * float(i)
		canvas.draw_rect(Rect2(inner_x, y, inner_w, strip_h), Color(0.02, 0.01, 0.01, alpha))
