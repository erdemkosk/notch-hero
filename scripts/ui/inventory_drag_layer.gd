extends Control

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const InventoryDragScript = preload("res://scripts/ui/inventory_drag.gd")
const ItemDataScript = preload("res://scripts/game/item_data.gd")
const ItemRarityFrameScript = preload("res://scripts/ui/item_rarity_frame.gd")
const InventorySlotDrawScript = preload("res://scripts/ui/inventory_slot_draw.gd")
const InventoryIconDrawScript = preload("res://scripts/ui/inventory_icon_draw.gd")

const VALID := Color(0.42, 0.92, 0.55)
const INVALID := Color(0.92, 0.32, 0.28)
const NEUTRAL := Color(0.95, 0.82, 0.35)

var _equipment_panel: Control
var _inventory_bag: Control
var _pulse := 0.0


func set_equipment_panel(panel: Control) -> void:
	_equipment_panel = panel


func set_inventory_bag(bag: Control) -> void:
	_inventory_bag = bag


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	set_anchors_preset(Control.PRESET_FULL_RECT)
	GameState.state_changed.connect(queue_redraw)


func _process(delta: float) -> void:
	if InventoryDragScript.active:
		_pulse += delta * 6.5
		queue_redraw()


func _drop_feedback() -> int:
	if not InventoryDragScript.active or not GameState.has_hero():
		return 0

	var global_mouse := get_global_mouse_position()
	if _equipment_panel != null and _equipment_panel.get_global_rect().has_point(global_mouse):
		if _equipment_panel.has_method("potion_kind_at_global"):
			var potion_kind: String = _equipment_panel.potion_kind_at_global(global_mouse)
			if not potion_kind.is_empty():
				if InventoryDragScript.source == InventoryDragScript.Source.INVENTORY:
					if ItemDataScript.potion_kind(InventoryDragScript.item) == potion_kind:
						return 1
					return -1
				if InventoryDragScript.source == InventoryDragScript.Source.POTION_BAR:
					return 0

		var slot := ""
		if _equipment_panel.has_method("slot_at_global"):
			slot = _equipment_panel.slot_at_global(global_mouse)
		if slot.is_empty():
			return 0
		if InventoryDragScript.can_drop_on_equip_slot(slot, GameState.hero.equipment):
			return 1
		return -1

	if InventoryDragScript.source == InventoryDragScript.Source.EQUIPMENT \
			and _inventory_bag != null \
			and _inventory_bag.get_global_rect().has_point(global_mouse):
		if GameState.hero.has_inventory_room():
			return 1
		return -1

	if _inventory_bag != null and _inventory_bag.get_global_rect().has_point(global_mouse):
		if not _inventory_bag.has_method("slot_at_global"):
			return 0
		var bag_slot: int = _inventory_bag.slot_at_global(global_mouse)
		if bag_slot < 0:
			return 0

		if InventoryDragScript.source == InventoryDragScript.Source.INVENTORY:
			if bag_slot == InventoryDragScript.inventory_index:
				return 0
			if bag_slot < GameState.hero.inventory.size():
				var target: Dictionary = GameState.hero.inventory[bag_slot]
				if ItemDataScript.can_stack_merge(target, InventoryDragScript.item):
					return 1
				return -1
			return 0

		if InventoryDragScript.source == InventoryDragScript.Source.POTION_BAR:
			if bag_slot < GameState.hero.inventory.size():
				var target: Dictionary = GameState.hero.inventory[bag_slot]
				if ItemDataScript.can_stack_merge(target, InventoryDragScript.item):
					return 1
				if GameState.hero.has_inventory_room():
					return 1
				return -1
			if GameState.hero.has_inventory_room():
				return 1
			return -1

	return 0


func _draw() -> void:
	if not InventoryDragScript.active:
		return

	var feedback := _drop_feedback()
	var local_mouse := get_global_transform().affine_inverse() * get_global_mouse_position()
	var side := InventoryDragScript.icon_size
	var rect := Rect2(local_mouse - Vector2(side * 0.5, side * 0.5), Vector2(side, side))

	var border := NEUTRAL
	if feedback == 1:
		border = VALID
	elif feedback == -1:
		border = INVALID

	var ghost_alpha := 0.8
	var shadow := rect.grow(UIScaleScript.px(3.0))
	shadow.position += Vector2(UIScaleScript.px(2.0), UIScaleScript.px(2.0))
	draw_rect(shadow, Color(0.02, 0.02, 0.04, ghost_alpha * 0.55))

	var rarity := ItemDataScript.item_rarity(InventoryDragScript.item)
	var rc: Color = ItemDataScript.RARITY_COLORS.get(rarity, ItemDataScript.RARITY_COLORS["common"])
	var rank := ItemDataScript.rarity_rank(rarity)
	var pulse_mul := 1.0 + float(rank) * 0.55
	var glow_expand := UIScaleScript.px(2.0) + (sin(_pulse * pulse_mul) + 1.0) * UIScaleScript.px(1.5 + float(rank) * 1.2)
	var glow_alpha := 0.28 + float(rank) * 0.08 + (sin(_pulse * pulse_mul) + 1.0) * 0.12
	var glow_rect := rect.grow(glow_expand)
	var r := InventorySlotDrawScript.corner_radius(rect) + 2.0
	InventorySlotDrawScript._draw_rounded_stroke(
		self,
		glow_rect,
		r,
		Color(rc.r, rc.g, rc.b, ghost_alpha * glow_alpha),
		2.0 + float(rank) * 0.5
	)

	var frame := rect.grow(UIScaleScript.px(1.0))
	draw_rect(frame, Color(0.1, 0.08, 0.06, ghost_alpha * 0.94))
	InventorySlotDrawScript._draw_rounded_stroke(
		self,
		frame,
		InventorySlotDrawScript.corner_radius(frame),
		Color(border.r, border.g, border.b, ghost_alpha * 0.95),
		2.0
	)

	ItemRarityFrameScript.draw_on_slot(self, rect, rarity, _pulse)

	if InventoryIconDrawScript.draw_in_slot(self, rect, InventoryDragScript.item):
		return

	draw_rect(
		ItemDataScript.icon_inner_rect(rect, 0.0),
		Color(0.35, 0.3, 0.25, ghost_alpha * 0.75)
	)
