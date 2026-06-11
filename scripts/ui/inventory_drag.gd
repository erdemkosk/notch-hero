extends RefCounted
class_name InventoryDrag

const ItemDataScript = preload("res://scripts/game/item_data.gd")

enum Source { NONE, INVENTORY, EQUIPMENT, POTION_BAR }

static var active := false
static var source := Source.NONE
static var inventory_index := -1
static var equipment_slot := ""
static var potion_kind := ""
static var item: Dictionary = {}
static var icon_size := 40.0


static func start_inventory(index: int, item_data: Dictionary, size: float) -> void:
	active = true
	source = Source.INVENTORY
	inventory_index = index
	equipment_slot = ""
	potion_kind = ""
	item = item_data.duplicate(true)
	icon_size = size


static func start_equipment(slot: String, item_data: Dictionary, size: float) -> void:
	active = true
	source = Source.EQUIPMENT
	equipment_slot = slot
	inventory_index = -1
	potion_kind = ""
	item = item_data.duplicate(true)
	icon_size = size


static func start_potion_bar(kind: String, item_data: Dictionary, size: float) -> void:
	active = true
	source = Source.POTION_BAR
	potion_kind = kind
	inventory_index = -1
	equipment_slot = ""
	item = item_data.duplicate(true)
	icon_size = size


static func clear() -> void:
	active = false
	source = Source.NONE
	inventory_index = -1
	equipment_slot = ""
	potion_kind = ""
	item = {}
	icon_size = 40.0


static func can_drop_on_equip_slot(equip_slot: String, equipment: Dictionary) -> bool:
	if not active or equip_slot.is_empty():
		return false

	var dragged_slot := ItemDataScript.item_slot(item)
	if dragged_slot.is_empty():
		return false

	if source == Source.EQUIPMENT and equip_slot == equipment_slot:
		return false

	if not ItemDataScript.slot_accepts(dragged_slot, equip_slot):
		return false

	if source == Source.EQUIPMENT:
		var to_item: Variant = equipment.get(equip_slot)
		if to_item != null and typeof(to_item) == TYPE_DICTIONARY:
			var to_type := ItemDataScript.item_slot(to_item)
			return ItemDataScript.slot_accepts(to_type, equipment_slot)
	return true
