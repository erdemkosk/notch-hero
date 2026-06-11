extends Control

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const InventoryDragScript = preload("res://scripts/ui/inventory_drag.gd")
const InventorySlotMetricsScript = preload("res://scripts/ui/inventory_slot_metrics.gd")
const InventoryDragLayerScript = preload("res://scripts/ui/inventory_drag_layer.gd")

@onready var inventory_bag: Control = $InventoryBag
@onready var equipment_panel: Control = $EquipmentPanel

var _drag_mouse_down := false
var _drag_layer: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_layer = Control.new()
	_drag_layer.name = "DragLayer"
	_drag_layer.set_script(InventoryDragLayerScript)
	add_child(_drag_layer)

	resized.connect(_layout_children)
	_layout_children()
	if equipment_panel.has_method("set_inventory_bag"):
		equipment_panel.set_inventory_bag(inventory_bag)
	if _drag_layer.has_method("set_equipment_panel"):
		_drag_layer.set_equipment_panel(equipment_panel)
	if _drag_layer.has_method("set_inventory_bag"):
		_drag_layer.set_inventory_bag(inventory_bag)


func _unhandled_input(event: InputEvent) -> void:
	if not InventoryDragScript.active:
		return
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_finish_drag(event.global_position)
		get_viewport().set_input_as_handled()


func _finish_drag(global_pos: Vector2) -> void:
	var on_equip := equipment_panel.get_global_rect().has_point(global_pos)
	var on_bag := inventory_bag.get_global_rect().has_point(global_pos)
	var equip_slot := ""
	var potion_kind: String = ""
	var bag_slot := -1
	if on_bag and inventory_bag.has_method("slot_at_global"):
		bag_slot = inventory_bag.slot_at_global(global_pos)
	if on_equip:
		if equipment_panel.has_method("potion_kind_at_global"):
			potion_kind = equipment_panel.potion_kind_at_global(global_pos)
		if potion_kind.is_empty():
			equip_slot = equipment_panel.slot_at_global(global_pos)

	match InventoryDragScript.source:
		InventoryDragScript.Source.INVENTORY:
			if bag_slot >= 0 \
					and bag_slot != InventoryDragScript.inventory_index \
					and GameState.move_inventory_stack(InventoryDragScript.inventory_index, bag_slot):
				pass
			elif not potion_kind.is_empty():
				GameState.move_inventory_to_potion_bar(InventoryDragScript.inventory_index, potion_kind)
			elif on_equip and not equip_slot.is_empty():
				GameState.equip_from_inventory(InventoryDragScript.inventory_index, equip_slot)
		InventoryDragScript.Source.EQUIPMENT:
			if on_bag:
				GameState.unequip_slot(InventoryDragScript.equipment_slot)
			elif on_equip and not equip_slot.is_empty():
				if equip_slot != InventoryDragScript.equipment_slot:
					GameState.swap_equipment(InventoryDragScript.equipment_slot, equip_slot)
		InventoryDragScript.Source.POTION_BAR:
			if on_bag:
				GameState.move_potion_bar_to_inventory(InventoryDragScript.potion_kind, bag_slot)
			elif not potion_kind.is_empty() and potion_kind != InventoryDragScript.potion_kind:
				pass

	InventoryDragScript.clear()
	if _drag_layer != null:
		_drag_layer.queue_redraw()
	inventory_bag.queue_redraw()
	equipment_panel.queue_redraw()


func _layout_children() -> void:
	if inventory_bag == null or equipment_panel == null:
		return

	var host_h: float = size.y
	if host_h < 1.0:
		host_h = InventorySlotMetricsScript.content_host_height()

	var panel_w: float = size.x
	if panel_w < 1.0:
		panel_w = InventorySlotMetricsScript.design_panel_width()

	var layout: Dictionary = InventorySlotMetricsScript.layout_for_panel(host_h, panel_w)
	var bag_w: float = layout["bag_w"]
	var equip_w: float = layout["equip_w"]
	var total_w: float = layout["total_w"]
	var shared_side: float = InventorySlotMetricsScript.shared_slot_side(
		Vector2(bag_w, host_h),
		0.0,
		Vector2(equip_w, host_h)
	)

	inventory_bag.set_anchors_preset(Control.PRESET_TOP_LEFT)
	inventory_bag.offset_left = 0.0
	inventory_bag.offset_top = 0.0
	inventory_bag.offset_right = bag_w
	inventory_bag.offset_bottom = host_h

	equipment_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	equipment_panel.offset_left = bag_w
	equipment_panel.offset_top = 0.0
	equipment_panel.offset_right = total_w
	equipment_panel.offset_bottom = host_h

	if _drag_layer != null:
		_drag_layer.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_drag_layer.offset_left = 0.0
		_drag_layer.offset_top = 0.0
		_drag_layer.offset_right = total_w
		_drag_layer.offset_bottom = host_h

	if inventory_bag.has_method("set_shared_slot_side"):
		inventory_bag.set_shared_slot_side(shared_side)
	if equipment_panel.has_method("set_shared_slot_side"):
		equipment_panel.set_shared_slot_side(shared_side)


func _process(_delta: float) -> void:
	if not InventoryDragScript.active:
		_drag_mouse_down = false
		return

	var mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if _drag_mouse_down and not mouse_down:
		_finish_drag(get_global_mouse_position())
	_drag_mouse_down = mouse_down

	if equipment_panel.has_method("queue_redraw"):
		equipment_panel.queue_redraw()
