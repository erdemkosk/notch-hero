extends Control

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const InventoryDragScript = preload("res://scripts/ui/inventory_drag.gd")
const ItemDataScript = preload("res://scripts/game/item_data.gd")
const ItemTooltipScript = preload("res://scripts/ui/item_tooltip.gd")
const InventorySlotDrawScript = preload("res://scripts/ui/inventory_slot_draw.gd")
const ItemRarityFrameScript = preload("res://scripts/ui/item_rarity_frame.gd")
const EquipmentSlotIconsScript = preload("res://scripts/ui/equipment_slot_icons.gd")
const InventoryHoverScript = preload("res://scripts/ui/inventory_hover.gd")
const InventoryPanelChromeScript = preload("res://scripts/ui/inventory_panel_chrome.gd")
const InventoryIconDrawScript = preload("res://scripts/ui/inventory_icon_draw.gd")

const LABEL_COLOR := Color(0.82, 0.72, 0.58)
const SLOT_HI := Color(0.32, 0.2, 0.12)
const VALID_PULSE := Color(0.42, 0.92, 0.55)
const INVALID_PULSE := Color(0.92, 0.32, 0.28)

const HERO_SHEET := "res://assets/characters/hero_sheet.png"
const HERO_FRAME := Vector2i(32, 32)

const SLOT_GRID := {
	"helmet": Vector2i(0, 0),
	"amulet": Vector2i(2, 0),
	"weapon": Vector2i(0, 1),
	"chest": Vector2i(1, 1),
	"gloves": Vector2i(2, 1),
	"ring_1": Vector2i(0, 2),
	"legs": Vector2i(1, 2),
	"ring_2": Vector2i(2, 2),
	"earring_1": Vector2i(0, 3),
	"feet": Vector2i(1, 3),
	"earring_2": Vector2i(2, 3),
}

const STAT_DEFS := {
	"attack": {"label": "ATK", "color": Color(0.92, 0.55, 0.38)},
	"armor": {"label": "ARM", "color": Color(0.55, 0.72, 0.95)},
	"max_hp": {"label": "HP", "color": Color(0.48, 0.88, 0.52)},
	"spell_power": {"label": "SP", "color": Color(0.72, 0.58, 0.95)},
}

const LEFT_STAT_KEYS := ["attack", "armor"]
const RIGHT_STAT_KEYS := ["max_hp", "spell_power"]

const BONUS_STAT_DEFS := [
	{"key": "attack_speed_pct", "label": "AS", "suffix": "%"},
	{"key": "move_speed_pct", "label": "MS", "suffix": "%"},
	{"key": "life_regen", "label": "LR", "suffix": ""},
	{"key": "bag_slots", "label": "Bag", "suffix": ""},
]

var _hover_slot := ""
var _hero_sheet: Texture2D
var _bag_ref: Control
var _shared_slot_side := -1.0
var _pulse_phase := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hero_sheet = load(HERO_SHEET)
	resized.connect(queue_redraw)
	GameState.state_changed.connect(queue_redraw)


func _process(delta: float) -> void:
	if _needs_pulse_redraw():
		_pulse_phase += delta * 5.5
		queue_redraw()
	elif InventoryDragScript.active:
		_pulse_phase += delta * 6.5
		queue_redraw()
	else:
		_pulse_phase = 0.0


func _needs_pulse_redraw() -> bool:
	for slot in ItemDataScript.EQUIP_SLOTS:
		var equipped: Variant = GameState.hero.equipment.get(slot)
		if equipped != null and typeof(equipped) == TYPE_DICTIONARY:
			if ItemDataScript.item_rarity(equipped) == "unique":
				return true
	return false


func set_inventory_bag(bag: Control) -> void:
	_bag_ref = bag


func set_shared_slot_side(side: float) -> void:
	_shared_slot_side = side
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover_slot = _slot_at(get_local_mouse_position())
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_press(event.position)


func _on_press(local_pos: Vector2) -> void:
	var slot := _slot_at(local_pos)
	if slot.is_empty():
		return

	var equipped: Variant = GameState.hero.equipment.get(slot)
	if equipped != null and typeof(equipped) == TYPE_DICTIONARY:
		var rect := _slot_rect_for(slot)
		InventoryDragScript.start_equipment(slot, equipped, rect.size.x)


func slot_at_global(global_pos: Vector2) -> String:
	var local_pos := get_global_transform().affine_inverse() * global_pos
	return _slot_at(local_pos)


func _draw() -> void:
	if size.x < 40.0 or size.y < 40.0:
		return

	var panel_rect := Rect2(2.0, 2.0, size.x - 4.0, size.y - 4.0)
	InventoryPanelChromeScript.draw(self, panel_rect, InventoryPanelChromeScript.Style.EQUIP)
	_draw_header()
	_draw_stat_cards(panel_rect)
	_draw_hero_preview()
	_draw_slots()
	_draw_hover_tooltip()


func _draw_header() -> void:
	draw_string(
		ThemeDB.fallback_font,
		Vector2(UIScaleScript.px(10.0), UIScaleScript.px(16.0)),
		"Equipment",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		UIScaleScript.font_emphasis(),
		Color(0.96, 0.9, 0.72)
	)


func _draw_hero_preview() -> void:
	var grid := _grid_metrics()
	var hero_center := Vector2(
		grid["origin_x"] + grid["side"] * 1.5 + grid["gap"],
		grid["origin_y"] + grid["side"] * 1.5 + grid["gap"]
	)
	var scale := clampf(_slot_side() / 28.0, 1.4, 2.2)
	var frame_side := HERO_FRAME.x * scale

	if _hero_sheet != null:
		var region := Rect2i(0, 0, HERO_FRAME.x, HERO_FRAME.y)
		var dest := Rect2(
			hero_center.x - frame_side * 0.5,
			hero_center.y - frame_side * 0.7,
			frame_side,
			frame_side
		)
		draw_texture_rect_region(_hero_sheet, dest, region)


func _slot_side() -> float:
	if _shared_slot_side > 0.0:
		return _shared_slot_side
	if _bag_ref != null and _bag_ref.has_method("get_slot_side"):
		return _bag_ref.get_slot_side()
	return UIScaleScript.px(36.0)


func _stat_column_width() -> float:
	return UIScaleScript.px(44.0)


func _grid_metrics() -> Dictionary:
	var side := _slot_side()
	var gap := UIScaleScript.px(2.0)
	var cols := 3
	var rows := 4
	var grid_w := side * float(cols) + gap * float(cols - 1)
	var grid_h := side * float(rows) + gap * float(rows - 1)

	var pad_edge := UIScaleScript.px(4.0)
	var pad_top := UIScaleScript.px(20.0)
	var pad_bottom := UIScaleScript.px(6.0)
	var col_w := _stat_column_width()
	var col_gap := UIScaleScript.px(4.0)

	var left_col_x := pad_edge
	var origin_x := left_col_x + col_w + col_gap
	var right_col_x := origin_x + grid_w + col_gap

	var avail_h := size.y - pad_top - pad_bottom
	var origin_y := pad_top + maxf(0.0, (avail_h - grid_h) * 0.5)

	return {
		"side": side,
		"gap": gap,
		"origin_x": origin_x,
		"origin_y": origin_y,
		"grid_w": grid_w,
		"grid_h": grid_h,
		"stat_col_w": col_w,
		"left_col_x": left_col_x,
		"right_col_x": right_col_x,
	}


func _slot_rect_for(equip_slot: String) -> Rect2:
	var grid_pos: Vector2i = SLOT_GRID.get(equip_slot, Vector2i(1, 1))
	var metrics := _grid_metrics()
	var side: float = metrics["side"]
	var gap: float = metrics["gap"]
	var x: float = metrics["origin_x"] + float(grid_pos.x) * (side + gap)
	var y: float = metrics["origin_y"] + float(grid_pos.y) * (side + gap)
	return Rect2(x, y, side, side)


func _draw_hover_tooltip() -> void:
	if _hover_slot.is_empty():
		return

	var equipped: Variant = GameState.hero.equipment.get(_hover_slot)
	if equipped == null or typeof(equipped) != TYPE_DICTIONARY:
		return

	ItemTooltipScript.draw_for_slot(
		self,
		_slot_rect_for(_hover_slot),
		equipped,
		Rect2(Vector2.ZERO, size),
		"",
		GameState.hero.equipment,
		_hover_slot
	)


func _is_valid_drop_target(equip_slot: String) -> bool:
	return InventoryDragScript.can_drop_on_equip_slot(equip_slot, GameState.hero.equipment)


func _draw_valid_pulse(rect: Rect2, color: Color) -> void:
	var wave := (sin(_pulse_phase) + 1.0) * 0.5
	var alpha := 0.2 + wave * 0.55
	var expand := UIScaleScript.px(1.0) + wave * UIScaleScript.px(4.0)
	var outer := rect.grow(expand)
	var r := InventorySlotDrawScript.corner_radius(rect) + 2.0
	InventorySlotDrawScript._draw_rounded_fill(
		self,
		outer,
		r,
		Color(color.r, color.g, color.b, alpha * 0.4)
	)
	InventorySlotDrawScript._draw_rounded_stroke(
		self,
		outer,
		r,
		Color(color.r, color.g, color.b, alpha),
		1.0 + wave * 2.0
	)


func _draw_slots() -> void:
	var dragging := InventoryDragScript.active

	for slot in ItemDataScript.EQUIP_SLOTS:
		var rect := _slot_rect_for(slot)
		var hovered: bool = slot == _hover_slot
		var bg_override := Color(-1, -1, -1, -1)
		var valid_target := _is_valid_drop_target(slot)

		if dragging and valid_target:
			_draw_valid_pulse(rect, VALID_PULSE)
		elif dragging and hovered and not valid_target:
			_draw_valid_pulse(rect, INVALID_PULSE)

		if dragging and hovered:
			if valid_target:
				bg_override = SLOT_HI.lightened(0.18)
			else:
				bg_override = Color(0.42, 0.14, 0.1, 0.95)

		if hovered:
			InventoryHoverScript.draw_slot(self, rect)

		InventorySlotDrawScript.draw_square(self, rect, hovered, bg_override)

		if not _slot_has_item(slot):
			EquipmentSlotIconsScript.draw(self, rect, slot, LABEL_COLOR)

		var equipped: Variant = GameState.hero.equipment.get(slot)
		var dragging_slot: bool = InventoryDragScript.active \
			and InventoryDragScript.source == InventoryDragScript.Source.EQUIPMENT \
			and InventoryDragScript.equipment_slot == slot
		if equipped != null and typeof(equipped) == TYPE_DICTIONARY and not dragging_slot:
			_draw_item_icon(rect, equipped)


func _slot_has_item(equip_slot: String) -> bool:
	var equipped: Variant = GameState.hero.equipment.get(equip_slot)
	return equipped != null and typeof(equipped) == TYPE_DICTIONARY


func _draw_stat_cards(_panel_rect: Rect2) -> void:
	var items: Array = []
	for slot in ItemDataScript.EQUIP_SLOTS:
		var equipped: Variant = GameState.hero.equipment.get(slot)
		if equipped != null and typeof(equipped) == TYPE_DICTIONARY:
			items.append(equipped)

	var hero := GameState.hero
	var eq := hero.equipment_stats()
	var stats := {
		"attack": hero.attack_power(),
		"armor": hero.armor(),
		"max_hp": hero.max_hp,
		"spell_power": float(hero.spell_power),
	}
	var metrics := _grid_metrics()
	var col_w: float = metrics["stat_col_w"]
	var grid_h: float = metrics["grid_h"]
	var card_gap := UIScaleScript.px(3.0)
	var card_h := (grid_h - card_gap) * 0.5
	var block_h := card_h * 2.0 + card_gap
	var start_y: float = metrics["origin_y"] + (grid_h - block_h) * 0.5

	_draw_stat_column(metrics["left_col_x"], start_y, col_w, card_h, card_gap, LEFT_STAT_KEYS, stats)
	_draw_stat_column(metrics["right_col_x"], start_y, col_w, card_h, card_gap, RIGHT_STAT_KEYS, stats)
	_draw_bonus_stat_row(metrics, eq, start_y + block_h + UIScaleScript.px(4.0))


func _draw_stat_column(
	col_x: float,
	start_y: float,
	col_w: float,
	card_h: float,
	card_gap: float,
	keys: Array,
	stats: Dictionary
) -> void:
	var y := start_y
	for key in keys:
		var def: Dictionary = STAT_DEFS.get(key, {})
		_draw_one_stat_card(Rect2(col_x, y, col_w, card_h), key, def, stats)
		y += card_h + card_gap


func _draw_one_stat_card(card: Rect2, key: String, def: Dictionary, stats: Dictionary) -> void:
	var val := float(stats.get(key, 0.0))
	var col: Color = def.get("color", LABEL_COLOR)
	var font := ThemeDB.fallback_font

	InventorySlotDrawScript._draw_rounded_fill(
		self,
		card,
		UIScaleScript.px(4.0),
		Color(0.12, 0.09, 0.07, 0.92)
	)
	InventorySlotDrawScript._draw_rounded_stroke(
		self,
		card,
		UIScaleScript.px(4.0),
		Color(col.r, col.g, col.b, 0.45),
		1.0
	)
	draw_rect(
		Rect2(card.position.x + 1.0, card.position.y + 1.0, card.size.x - 2.0, UIScaleScript.px(4.0)),
		Color(col.r, col.g, col.b, 0.55)
	)

	draw_string(
		font,
		Vector2(card.position.x + UIScaleScript.px(4.0), card.position.y + UIScaleScript.px(13.0)),
		str(def.get("label", key)),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		UIScaleScript.font_caption(),
		col.lightened(0.15)
	)
	var val_text := "+%.0f" % val if val > 0.0 else "0"
	var val_sz := UIScaleScript.font_ui()
	var val_w := font.get_string_size(val_text, HORIZONTAL_ALIGNMENT_LEFT, -1, val_sz).x
	draw_string(
		font,
		Vector2(card.end.x - UIScaleScript.px(4.0) - val_w, card.end.y - UIScaleScript.px(3.0)),
		val_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		val_sz,
		LABEL_COLOR
	)


func _draw_bonus_stat_row(metrics: Dictionary, eq: Dictionary, y: float) -> void:
	var left_x: float = metrics["left_col_x"]
	var right_x: float = metrics["right_col_x"]
	var col_w: float = metrics["stat_col_w"]
	var row_w := (right_x + col_w) - left_x
	var row_h := UIScaleScript.px(16.0)
	var rect := Rect2(left_x, y, row_w, row_h)

	var parts: PackedStringArray = []
	for def in BONUS_STAT_DEFS:
		var key: String = str(def.get("key", ""))
		var val := float(eq.get(key, 0.0))
		if val <= 0.001:
			continue
		var label: String = str(def.get("label", key))
		var suffix: String = str(def.get("suffix", ""))
		if key == "life_regen":
			parts.append("%s +%.1f" % [label, val])
		else:
			parts.append("%s +%.0f%s" % [label, val, suffix])

	if parts.is_empty():
		return

	InventorySlotDrawScript._draw_rounded_fill(
		self,
		rect,
		UIScaleScript.px(3.0),
		Color(0.1, 0.08, 0.06, 0.88)
	)

	var text := "  ".join(parts)
	var font := ThemeDB.fallback_font
	var fs := UIScaleScript.font_caption()
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tx := rect.position.x + maxf(UIScaleScript.px(4.0), (rect.size.x - tw) * 0.5)
	draw_string(
		font,
		Vector2(tx, rect.position.y + row_h * 0.72),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fs,
		Color(0.72, 0.78, 0.86)
	)


func _draw_item_icon(rect: Rect2, item: Dictionary) -> void:
	InventoryIconDrawScript.draw_in_slot(self, rect, item)
	ItemRarityFrameScript.draw_on_slot(
		self,
		rect,
		ItemDataScript.item_rarity(item),
		_pulse_phase
	)


func _slot_at(local_pos: Vector2) -> String:
	for slot in ItemDataScript.EQUIP_SLOTS:
		if _slot_rect_for(slot).has_point(local_pos):
			return slot
	return ""
