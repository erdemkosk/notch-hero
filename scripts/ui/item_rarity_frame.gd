extends RefCounted
class_name ItemRarityFrame

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const ItemDataScript = preload("res://scripts/game/item_data.gd")
const InventorySlotDrawScript = preload("res://scripts/ui/inventory_slot_draw.gd")


static func draw_on_slot(
	canvas: CanvasItem,
	rect: Rect2,
	rarity: String,
	pulse_phase: float = 0.0
) -> void:
	if rarity.is_empty():
		return

	var base: Color = ItemDataScript.RARITY_COLORS.get(rarity, ItemDataScript.RARITY_COLORS["common"])
	var slot_side := rect.size.x
	var corner_r := clampf(slot_side * 0.12, 3.0, 5.0)

	if rarity == "unique":
		var wave := (sin(pulse_phase) + 1.0) * 0.5
		var glow_expand := UIScaleScript.px(1.0) + wave * UIScaleScript.px(3.0)
		var glow_alpha := 0.18 + wave * 0.35
		var glow_rect := rect.grow(glow_expand)
		InventorySlotDrawScript._draw_rounded_stroke(
			canvas,
			glow_rect,
			corner_r + 2.0,
			Color(base.r, base.g, base.b, glow_alpha),
			2.0 + wave * 2.0
		)
		base = base.lightened(0.08 + wave * 0.22)
	elif rarity == "rare":
		var glow_rect := rect.grow(UIScaleScript.px(1.5))
		InventorySlotDrawScript._draw_rounded_stroke(
			canvas,
			glow_rect,
			corner_r + 1.0,
			Color(base.r, base.g, base.b, 0.28),
			1.5
		)

	var border_alpha := 0.75
	if rarity == "basic" or rarity == "trade":
		border_alpha = 0.45
	elif rarity == "common":
		border_alpha = 0.62

	var border_color := Color(base.r, base.g, base.b, border_alpha)
	var border_w := 1.5
	if rarity == "unique":
		border_w = 1.5 + (sin(pulse_phase) + 1.0) * 0.5

	InventorySlotDrawScript._draw_rounded_stroke(canvas, rect, corner_r, border_color, border_w)

	var stripe_w := UIScaleScript.px(3.0)
	var stripe := Rect2(rect.position, Vector2(stripe_w, rect.size.y))
	canvas.draw_rect(stripe, Color(base.r, base.g, base.b, border_alpha * 0.55))

	var corner := UIScaleScript.px(5.0)
	var tri := PackedVector2Array([
		Vector2(rect.end.x - corner, rect.position.y),
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x, rect.position.y + corner),
	])
	canvas.draw_colored_polygon(tri, Color(base.r, base.g, base.b, border_alpha * 0.7))

