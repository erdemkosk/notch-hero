extends RefCounted
class_name InventoryHover

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const InventorySlotDrawScript = preload("res://scripts/ui/inventory_slot_draw.gd")

const HOVER_GLOW := Color(0.75, 0.58, 0.32)


static func draw_slot(canvas: CanvasItem, rect: Rect2) -> void:
	var glow := rect.grow(UIScaleScript.px(1.5))
	var r := InventorySlotDrawScript.corner_radius(rect) + UIScaleScript.px(1.0)
	InventorySlotDrawScript._draw_rounded_stroke(canvas, glow, r, HOVER_GLOW, 1.5)
