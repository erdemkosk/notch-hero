extends RefCounted
class_name InventoryIconDraw

const ItemDataScript = preload("res://scripts/game/item_data.gd")
const InventorySlotDrawScript = preload("res://scripts/ui/inventory_slot_draw.gd")


static func draw_in_slot(canvas: CanvasItem, slot_rect: Rect2, item: Dictionary) -> bool:
	var inner := InventorySlotDrawScript.inner_content_rect(slot_rect)
	return ItemDataScript.draw_item_icon(canvas, inner, item, ItemDataScript.IconFit.STRETCH, 0.0)
