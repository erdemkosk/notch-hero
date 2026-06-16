extends Control

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const InventoryDragScript = preload("res://scripts/ui/inventory_drag.gd")
const ItemDataScript = preload("res://scripts/game/item_data.gd")
const ItemTooltipScript = preload("res://scripts/ui/item_tooltip.gd")
const InventorySlotDrawScript = preload("res://scripts/ui/inventory_slot_draw.gd")
const ItemRarityFrameScript = preload("res://scripts/ui/item_rarity_frame.gd")
const InventoryHoverScript = preload("res://scripts/ui/inventory_hover.gd")
const InventoryPanelChromeScript = preload("res://scripts/ui/inventory_panel_chrome.gd")
const InventoryIconDrawScript = preload("res://scripts/ui/inventory_icon_draw.gd")

enum Category { ALL, WEAPON, FOOD, ARMOR, ACCESSORY, POTION, MATERIAL }

const ROWS := 3
const MIN_COLS := 5
const MAX_COLS := 14

const LABEL_COLOR := Color(0.82, 0.72, 0.58)
const TAB_ACTIVE := Color(0.58, 0.4, 0.22)
const TAB_IDLE := Color(0.38, 0.26, 0.16)
const TAB_TEXT := Color(0.94, 0.88, 0.78)
const TAB_TEXT_ACTIVE := Color(1.0, 0.96, 0.86)
const LEATHER_LIGHT := Color(0.68, 0.46, 0.28)
const FILTER_ON := Color(0.52, 0.38, 0.22)
const FILTER_OFF := Color(0.28, 0.18, 0.12)
const MENU_BG := Color(0.1, 0.07, 0.05, 0.97)
const MENU_BORDER := Color(0.58, 0.44, 0.26, 0.95)
const LOCKED_SLOT_BG := Color(0.1, 0.07, 0.05, 0.88)
const LOCKED_SLOT_INSET := Color(0.08, 0.05, 0.04, 0.95)

const TAB_NAMES := {
	Category.ALL: "All",
	Category.WEAPON: "Weapon",
	Category.ARMOR: "Armor",
	Category.ACCESSORY: "Acc",
	Category.POTION: "Potion",
	Category.MATERIAL: "Mats",
	Category.FOOD: "Food",
}

const CONTEXT_ACTIONS := ["Equip", "Sell", "Info"]

var _tab := Category.ALL
var _hover_slot := -1
var _last_click_slot := -1
var _last_click_ms := 0
var _shared_slot_side := -1.0
var _pulse_phase := 0.0
var _filter_rare := false
var _filter_sellable := false
var _search_field: LineEdit
var _context_slot := -1
var _context_pos := Vector2.ZERO


func set_shared_slot_side(side: float) -> void:
	_shared_slot_side = side
	_layout_search_field()
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_search_field = LineEdit.new()
	_search_field.placeholder_text = "Search..."
	_search_field.add_theme_font_size_override("font_size", UIScaleScript.font_ui())
	_search_field.text_changed.connect(_on_search_changed)
	add_child(_search_field)
	resized.connect(_on_resized)
	if is_instance_valid(GameState):
		GameState.state_changed.connect(_on_state_changed)


func _on_resized() -> void:
	_layout_search_field()
	queue_redraw()


func _on_state_changed() -> void:
	queue_redraw()


func _on_search_changed(_text: String) -> void:
	queue_redraw()


func _layout_search_field() -> void:
	if _search_field == null or size.x < 40.0:
		return
	var layout := _compute_layout()
	var bar: Rect2 = layout["filter_bar"]
	_search_field.position = Vector2(bar.position.x, bar.position.y + UIScaleScript.px(1.0))
	_search_field.size = Vector2(bar.size.x * 0.52, bar.size.y - UIScaleScript.px(2.0))


func _process(delta: float) -> void:
	if not is_instance_valid(GameState) or not GameState.has_hero():
		return
	if _needs_pulse_redraw():
		_pulse_phase += delta * 5.0
		queue_redraw()


func _needs_pulse_redraw() -> bool:
	if not is_instance_valid(GameState) or not GameState.has_hero():
		return false
	if InventoryDragScript.active:
		return true
	for item in GameState.hero.inventory:
		if ItemDataScript.should_rarity_pulse(ItemDataScript.item_rarity(item)):
			return true
	return false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var slot := _slot_at(get_local_mouse_position())
		var layout := _compute_layout()
		if slot >= _usable_slots(layout):
			slot = -1
		_hover_slot = slot
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_left_press(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_on_right_press(event.position)


func _on_right_press(local_pos: Vector2) -> void:
	if _context_hit(local_pos) >= 0:
		_run_context_action(_context_hit(local_pos))
		_context_slot = -1
		queue_redraw()
		return

	var filter_idx := _filter_toggle_at(local_pos)
	if filter_idx >= 0:
		_toggle_filter(filter_idx)
		queue_redraw()
		return

	var tab := _tab_at(local_pos)
	if tab >= 0:
		_set_tab(tab as Category)
		return

	var slot := _slot_at(local_pos)
	if slot >= 0:
		var layout := _compute_layout()
		if slot < _usable_slots(layout):
			_context_slot = slot
			_context_pos = local_pos
			queue_redraw()
			return
	_context_slot = -1
	queue_redraw()


func _on_left_press(local_pos: Vector2) -> void:
	if _context_slot >= 0:
		if _context_menu_rect().has_point(local_pos):
			return
		_context_slot = -1

	var filter_idx := _filter_toggle_at(local_pos)
	if filter_idx >= 0:
		_toggle_filter(filter_idx)
		queue_redraw()
		return

	var tab := _tab_at(local_pos)
	if tab >= 0:
		_set_tab(tab as Category)
		return

	var slot := _slot_at(local_pos)
	if slot < 0:
		return
	var layout := _compute_layout()
	if slot >= _usable_slots(layout):
		return

	if Input.is_key_pressed(KEY_SHIFT):
		_quick_equip_slot(slot)
		return

	var now := Time.get_ticks_msec()
	if slot == _last_click_slot and now - _last_click_ms < 350:
		_sell_slot(slot)
		_last_click_slot = -1
		InventoryDragScript.clear()
		queue_redraw()
		return

	_last_click_slot = slot
	_last_click_ms = now

	if not _slot_has_visible_item(slot):
		return

	InventoryDragScript.start_inventory(
		slot,
		GameState.hero.inventory[slot],
		layout["slot_size"].x
	)
	queue_redraw()


func _set_tab(new_tab: Category) -> void:
	if new_tab == _tab:
		return
	_tab = new_tab
	_hover_slot = -1
	_context_slot = -1
	queue_redraw()


func _toggle_filter(index: int) -> void:
	if index == 0:
		_filter_rare = not _filter_rare
	else:
		_filter_sellable = not _filter_sellable


func _quick_equip_slot(slot_index: int) -> void:
	if not _slot_has_visible_item(slot_index):
		return
	var item: Dictionary = GameState.hero.inventory[slot_index]
	if ItemDataScript.is_potion(item):
		return
	var equip_slot := ItemDataScript.prefer_equip_slot(item, GameState.hero.equipment)
	if equip_slot.is_empty():
		return
	GameState.equip_from_inventory(slot_index, equip_slot)


func _sell_slot(slot_index: int) -> void:
	if not _slot_has_visible_item(slot_index):
		return
	GameState.sell_item(slot_index)


func _run_context_action(action_index: int) -> void:
	if _context_slot < 0:
		return
	match action_index:
		0:
			_quick_equip_slot(_context_slot)
		1:
			_sell_slot(_context_slot)
		2:
			pass


func get_slot_side() -> float:
	if _shared_slot_side > 0.0:
		return _shared_slot_side
	if size.x < 40.0 or size.y < 40.0:
		return UIScaleScript.px(36.0)
	return _compute_layout()["slot_size"].x


func _draw() -> void:
	if not is_instance_valid(GameState) or not GameState.has_hero() or size.x < 40.0 or size.y < 40.0:
		return

	_layout_search_field()
	var layout := _compute_layout()
	InventoryPanelChromeScript.draw(self, layout["bag"], InventoryPanelChromeScript.Style.BAG)
	_draw_header(layout)
	_draw_tab_bar(layout)
	_draw_filter_bar(layout)
	_draw_grid_panel(layout)
	_draw_slots(layout)
	_draw_items(layout)
	_draw_footer(layout)
	_draw_context_menu()
	_draw_hover_tooltip(layout)


func _compute_layout() -> Dictionary:
	var edge := UIScaleScript.px(2.0)
	var bag_rect := Rect2(edge, edge, size.x - edge * 2.0, size.y - edge * 2.0)
	var header_h := UIScaleScript.px(18.0)
	var tab_h := UIScaleScript.px(22.0)
	var filter_h := UIScaleScript.px(18.0)
	var footer_h := UIScaleScript.px(14.0)
	var pad := UIScaleScript.px(4.0)

	var grid_top := bag_rect.position.y + header_h + tab_h + filter_h + pad
	var grid_bottom := bag_rect.end.y - footer_h - pad
	var inner := Rect2(
		bag_rect.position.x + pad,
		grid_top,
		bag_rect.size.x - pad * 2.0,
		grid_bottom - grid_top
	)

	var base_gap := UIScaleScript.px(2.0)
	var slot_side: float
	if _shared_slot_side > 0.0:
		slot_side = _shared_slot_side
	else:
		var slot_by_height: float = floor((inner.size.y - base_gap * float(ROWS - 1)) / float(ROWS))
		slot_by_height = maxf(slot_by_height, UIScaleScript.px(12.0))
		var cols_probe: int = int(floor((inner.size.x + base_gap) / (slot_by_height + base_gap)))
		cols_probe = clampi(cols_probe, MIN_COLS, MAX_COLS)
		var slot_by_width: float = floor((inner.size.x - base_gap * float(cols_probe - 1)) / float(cols_probe))
		slot_side = maxf(floor(minf(slot_by_height, slot_by_width)), UIScaleScript.px(12.0))

	var cols: int = int(floor((inner.size.x + base_gap) / (slot_side + base_gap)))
	cols = clampi(cols, MIN_COLS, MAX_COLS)

	var grid_w: float = slot_side * float(cols) + base_gap * float(cols - 1)
	var gap_x: float = base_gap
	if cols > 1 and grid_w < inner.size.x - 1.0:
		gap_x = (inner.size.x - slot_side * float(cols)) / float(cols - 1)

	var gap_y: float = base_gap
	var grid_h: float = slot_side * float(ROWS) + gap_y * float(ROWS - 1)
	if grid_h < inner.size.y - 1.0:
		gap_y = (inner.size.y - slot_side * float(ROWS)) / float(ROWS - 1)

	var grid_origin := Vector2(
		inner.position.x,
		inner.position.y + (inner.size.y - (slot_side * float(ROWS) + gap_y * float(ROWS - 1))) * 0.5
	)

	var tab_bar := Rect2(
		bag_rect.position.x + pad,
		bag_rect.position.y + header_h,
		bag_rect.size.x - pad * 2.0,
		tab_h
	)
	var filter_bar := Rect2(
		tab_bar.position.x,
		tab_bar.end.y,
		tab_bar.size.x,
		filter_h
	)

	return {
		"bag": bag_rect,
		"inner": inner,
		"tab_bar": tab_bar,
		"filter_bar": filter_bar,
		"header_h": header_h,
		"footer_h": footer_h,
		"cols": cols,
		"slot_count": cols * ROWS,
		"slot_size": Vector2(slot_side, slot_side),
		"gap_x": gap_x,
		"gap_y": gap_y,
		"grid_origin": grid_origin,
	}


func _draw_header(layout: Dictionary) -> void:
	var bag: Rect2 = layout["bag"]
	var font := ThemeDB.fallback_font
	var title_y: float = bag.position.y + float(layout["header_h"]) - UIScaleScript.px(2.0)
	draw_string(
		font,
		Vector2(bag.position.x + UIScaleScript.px(8.0), title_y),
		"Inventory",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		UIScaleScript.font_emphasis(),
		Color(0.96, 0.9, 0.72)
	)

	var usable := _usable_slots(layout)
	var count_text := "%d/%d" % [GameState.hero.inventory.size(), usable]
	var count_w := font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIScaleScript.font_ui()).x
	draw_string(
		font,
		Vector2(bag.end.x - UIScaleScript.px(8.0) - count_w, title_y),
		count_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		UIScaleScript.font_ui(),
		LABEL_COLOR
	)


func _draw_tab_bar(layout: Dictionary) -> void:
	var bar: Rect2 = layout["tab_bar"]
	var cats := Category.values()
	var gap := UIScaleScript.px(2.0)
	var pill_w := (bar.size.x - gap * float(cats.size() - 1)) / float(cats.size())
	var x := bar.position.x

	for cat in cats:
		var rect := Rect2(x, bar.position.y + 1.0, pill_w, bar.size.y - 2.0)
		var active: bool = cat == _tab
		var hovered: bool = rect.has_point(get_local_mouse_position())
		var fill := TAB_ACTIVE if active else TAB_IDLE
		if hovered and not active:
			fill = fill.lightened(0.08)

		InventorySlotDrawScript._draw_rounded_fill(self, rect, UIScaleScript.px(4.0), fill)
		if active:
			InventorySlotDrawScript._draw_rounded_stroke(self, rect, UIScaleScript.px(4.0), LEATHER_LIGHT, 1.5)

		var label: String = TAB_NAMES.get(cat, "?")
		var font := ThemeDB.fallback_font
		var sz := UIScaleScript.font_ui()
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var tc := TAB_TEXT_ACTIVE if active else TAB_TEXT
		draw_string(
			font,
			Vector2(rect.position.x + (rect.size.x - tw) * 0.5, rect.position.y + rect.size.y - UIScaleScript.px(4.0)),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			sz,
			tc
		)

		var cat_count := _items_for_category(cat as Category).size()
		if cat_count > 0:
			var badge := "%d" % cat_count
			var badge_sz := UIScaleScript.font_caption()
			draw_string(
				font,
				Vector2(rect.end.x - UIScaleScript.px(6.0), rect.position.y + UIScaleScript.px(9.0)),
				badge,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				badge_sz,
				TAB_TEXT_ACTIVE if active else TAB_TEXT.darkened(0.2)
			)
		x += pill_w + gap


func _filter_toggle_rects(filter_bar: Rect2) -> Array:
	var labels := ["Rare", "Sellable"]
	var gap := UIScaleScript.px(3.0)
	var search_w := filter_bar.size.x * 0.52
	var toggles_x := filter_bar.position.x + search_w + UIScaleScript.px(6.0)
	var toggles_w := filter_bar.size.x - search_w - UIScaleScript.px(6.0)
	var pill_w := (toggles_w - gap) / 2.0
	var y := filter_bar.position.y + UIScaleScript.px(2.0)
	var h := filter_bar.size.y - UIScaleScript.px(4.0)
	return [
		Rect2(toggles_x, y, pill_w, h),
		Rect2(toggles_x + pill_w + gap, y, pill_w, h),
	]


func _draw_filter_bar(layout: Dictionary) -> void:
	var bar: Rect2 = layout["filter_bar"]
	var rects := _filter_toggle_rects(bar)
	var labels := ["Rare", "Sellable"]
	var states := [_filter_rare, _filter_sellable]
	var font := ThemeDB.fallback_font
	var sz := UIScaleScript.font_caption()

	for i in rects.size():
		var rect: Rect2 = rects[i]
		var on: bool = states[i]
		var fill := FILTER_ON if on else FILTER_OFF
		InventorySlotDrawScript._draw_rounded_fill(self, rect, UIScaleScript.px(3.0), fill)
		if on:
			InventorySlotDrawScript._draw_rounded_stroke(self, rect, UIScaleScript.px(3.0), LEATHER_LIGHT, 1.0)
		var tw := font.get_string_size(labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		draw_string(
			font,
			Vector2(rect.position.x + (rect.size.x - tw) * 0.5, rect.end.y - UIScaleScript.px(3.0)),
			labels[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			sz,
			TAB_TEXT_ACTIVE if on else TAB_TEXT.darkened(0.15)
		)


func _filter_toggle_at(local_pos: Vector2) -> int:
	var layout := _compute_layout()
	var rects := _filter_toggle_rects(layout["filter_bar"])
	for i in rects.size():
		if rects[i].has_point(local_pos):
			return i
	return -1


func _draw_grid_panel(layout: Dictionary) -> void:
	var inner: Rect2 = layout["inner"]
	var r := UIScaleScript.px(5.0)
	InventorySlotDrawScript._draw_rounded_fill(self, inner, r, Color(0.14, 0.09, 0.06, 0.92))
	InventorySlotDrawScript._draw_rounded_stroke(self, inner, r, Color(0.28, 0.18, 0.1), 1.0)


func _usable_slots(layout: Dictionary) -> int:
	if not is_instance_valid(GameState) or not GameState.has_hero():
		return 0
	var cap := GameState.hero.bag_slot_capacity()
	return mini(cap, int(layout.get("slot_count", 0)))


func _draw_slots(layout: Dictionary) -> void:
	var slot_size: Vector2 = layout["slot_size"]
	var gap_x: float = layout["gap_x"]
	var gap_y: float = layout["gap_y"]
	var origin: Vector2 = layout["grid_origin"]
	var cols: int = layout["cols"]
	var slot_count: int = layout["slot_count"]
	var usable := _usable_slots(layout)

	for i in slot_count:
		var rect := _slot_rect(origin, slot_size, gap_x, gap_y, cols, i)
		if i >= usable:
			_draw_locked_slot(rect)
			continue
		var hovered: bool = i == _hover_slot and _slot_has_visible_item(i)
		if hovered:
			InventoryHoverScript.draw_slot(self, rect)
		InventorySlotDrawScript.draw_square(self, rect, hovered)


func _draw_locked_slot(rect: Rect2) -> void:
	var r := InventorySlotDrawScript.corner_radius(rect)
	InventorySlotDrawScript._draw_rounded_fill(self, rect, r, LOCKED_SLOT_BG)
	var inner := rect.grow(-2.0)
	InventorySlotDrawScript._draw_rounded_fill(self, inner, r - 1.0, LOCKED_SLOT_INSET)
	InventorySlotDrawScript._draw_rounded_stroke(self, rect, r, Color(0.2, 0.14, 0.1, 0.9), 1.0)
	var cx := rect.position.x + rect.size.x * 0.5
	var cy := rect.position.y + rect.size.y * 0.52
	var lock_w := rect.size.x * 0.22
	draw_rect(Rect2(cx - lock_w * 0.5, cy - lock_w * 0.15, lock_w, lock_w * 0.72), Color(0.34, 0.26, 0.2, 0.55), true)
	draw_arc(Vector2(cx, cy - lock_w * 0.55), lock_w * 0.42, PI, TAU, 10, Color(0.34, 0.26, 0.2, 0.55), 1.2)


func _draw_items(layout: Dictionary) -> void:
	var slot_size: Vector2 = layout["slot_size"]
	var gap_x: float = layout["gap_x"]
	var gap_y: float = layout["gap_y"]
	var origin: Vector2 = layout["grid_origin"]
	var cols: int = layout["cols"]
	var usable := _usable_slots(layout)

	for i in usable:
		if i >= GameState.hero.inventory.size():
			break
		var item: Dictionary = GameState.hero.inventory[i]
		if not _item_visible_in_view(item):
			continue
		if InventoryDragScript.active \
				and InventoryDragScript.source == InventoryDragScript.Source.INVENTORY \
				and i == InventoryDragScript.inventory_index:
			continue
		var rect := _slot_rect(origin, slot_size, gap_x, gap_y, cols, i)
		_draw_item_icon(rect, item)
		_draw_rarity_frame(rect, item)


func _draw_rarity_frame(rect: Rect2, item: Dictionary, alpha: float = 1.0) -> void:
	if alpha < 0.99:
		return
	ItemRarityFrameScript.draw_on_slot(
		self,
		rect,
		ItemDataScript.item_rarity(item),
		_pulse_phase
	)


func _draw_item_icon(rect: Rect2, item: Dictionary, alpha: float = 1.0) -> void:
	var inner := InventorySlotDrawScript.inner_content_rect(rect)
	if alpha < 0.99:
		draw_rect(inner, Color(0.2, 0.16, 0.12, alpha * 0.5))
	if InventoryIconDrawScript.draw_in_slot(self, rect, item):
		if alpha >= 0.99:
			ItemRarityFrameScript.draw_icon_shimmer(
				self,
				inner,
				ItemDataScript.item_rarity(item),
				_pulse_phase
			)
		return
	draw_rect(inner, Color(0.28, 0.22, 0.16, 0.85 * alpha))
	draw_rect(inner, Color(0.42, 0.34, 0.26, alpha), false, 1.0)


func _draw_footer(layout: Dictionary) -> void:
	var bag: Rect2 = layout["bag"]
	var font := ThemeDB.fallback_font
	var hint := "Double-click: Sell | Shift: Quick equip | Right-click: Menu"
	draw_string(
		font,
		Vector2(bag.position.x + UIScaleScript.px(8.0), bag.end.y - UIScaleScript.px(4.0)),
		hint,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		UIScaleScript.font_caption(),
		LABEL_COLOR.darkened(0.15)
	)


func _context_menu_rect() -> Rect2:
	var w := UIScaleScript.px(72.0)
	var h := UIScaleScript.px(14.0) * float(CONTEXT_ACTIONS.size()) + UIScaleScript.px(6.0)
	var x := clampf(_context_pos.x, 4.0, size.x - w - 4.0)
	var y := clampf(_context_pos.y, 4.0, size.y - h - 4.0)
	return Rect2(x, y, w, h)


func _draw_context_menu() -> void:
	if _context_slot < 0:
		return

	var box := _context_menu_rect()
	var r := UIScaleScript.px(4.0)
	InventorySlotDrawScript._draw_rounded_fill(self, box, r, MENU_BG)
	InventorySlotDrawScript._draw_rounded_stroke(self, box, r, MENU_BORDER, 1.0)

	var font := ThemeDB.fallback_font
	var sz := UIScaleScript.font_ui()
	var y := box.position.y + UIScaleScript.px(12.0)
	var local_mouse := get_local_mouse_position()

	for i in CONTEXT_ACTIONS.size():
		var row := Rect2(box.position.x, y - float(sz), box.size.x, float(sz) + UIScaleScript.px(4.0))
		if row.has_point(local_mouse):
			draw_rect(row.grow(-1.0), Color(0.22, 0.16, 0.1, 0.9))
		draw_string(
			font,
			Vector2(box.position.x + UIScaleScript.px(8.0), y),
			CONTEXT_ACTIONS[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			sz,
			TAB_TEXT
		)
		y += float(sz) + UIScaleScript.px(2.0)


func _context_hit(local_pos: Vector2) -> int:
	if _context_slot < 0:
		return -1
	var box := _context_menu_rect()
	if not box.has_point(local_pos):
		return -1
	var sz := UIScaleScript.font_ui()
	var y := box.position.y + UIScaleScript.px(12.0)
	for i in CONTEXT_ACTIONS.size():
		var row := Rect2(box.position.x, y - float(sz), box.size.x, float(sz) + UIScaleScript.px(4.0))
		if row.has_point(local_pos):
			return i
		y += float(sz) + UIScaleScript.px(2.0)
	return -1


func _draw_hover_tooltip(layout: Dictionary) -> void:
	if _hover_slot < 0 or _context_slot >= 0:
		return
	if _hover_slot >= _usable_slots(layout):
		return
	if not _slot_has_visible_item(_hover_slot):
		return

	var slot_size: Vector2 = layout["slot_size"]
	var gap_x: float = layout["gap_x"]
	var gap_y: float = layout["gap_y"]
	var origin: Vector2 = layout["grid_origin"]
	var cols: int = layout["cols"]
	var rect := _slot_rect(origin, slot_size, gap_x, gap_y, cols, _hover_slot)

	var item: Dictionary = GameState.hero.inventory[_hover_slot]
	var footer := "Double-click: Sell | Shift: Equip"
	if ItemDataScript.is_potion(item):
		footer = "Drag to HP/MP slot — inactive here"

	ItemTooltipScript.draw_for_slot(
		self,
		rect,
		item,
		Rect2(Vector2.ZERO, size),
		footer,
		GameState.hero.equipment
	)


func _slot_rect(
	origin: Vector2,
	slot_size: Vector2,
	gap_x: float,
	gap_y: float,
	cols: int,
	index: int
) -> Rect2:
	var col := index % cols
	var row := int(index / cols)
	var pos := origin + Vector2(
		float(col) * (slot_size.x + gap_x),
		float(row) * (slot_size.y + gap_y)
	)
	return Rect2(pos, slot_size)


func _slot_at(local_pos: Vector2) -> int:
	var layout := _compute_layout()
	var origin: Vector2 = layout["grid_origin"]
	var slot_size: Vector2 = layout["slot_size"]
	var gap_x: float = layout["gap_x"]
	var gap_y: float = layout["gap_y"]
	var cols: int = layout["cols"]
	var slot_count: int = layout["slot_count"]
	for i in slot_count:
		if _slot_rect(origin, slot_size, gap_x, gap_y, cols, i).has_point(local_pos):
			return i
	return -1


func slot_at_global(global_pos: Vector2) -> int:
	var local_pos := get_global_transform().affine_inverse() * global_pos
	var slot := _slot_at(local_pos)
	if slot < 0:
		return -1
	var layout := _compute_layout()
	if slot >= _usable_slots(layout):
		return -1
	return slot


func _tab_at(local_pos: Vector2) -> int:
	var layout := _compute_layout()
	var bar: Rect2 = layout["tab_bar"]
	if not bar.has_point(local_pos):
		return -1

	var cats := Category.values()
	var gap := UIScaleScript.px(2.0)
	var pill_w := (bar.size.x - gap * float(cats.size() - 1)) / float(cats.size())
	var x := bar.position.x
	for cat in cats:
		var rect := Rect2(x, bar.position.y, pill_w, bar.size.y)
		if rect.has_point(local_pos):
			return cat
		x += pill_w + gap
	return -1


func _search_query() -> String:
	if _search_field == null:
		return ""
	return _search_field.text.strip_edges().to_lower()


func _passes_extra_filters(item: Dictionary) -> bool:
	if _filter_rare:
		var rarity := ItemDataScript.item_rarity(item)
		if rarity != "rare" and rarity != "unique":
			return false
	if _filter_sellable:
		if str(item.get("id", "")).is_empty():
			return false
	return true


func _passes_search(item: Dictionary) -> bool:
	var q := _search_query()
	if q.is_empty():
		return true
	return ItemDataScript.display_name(item).to_lower().contains(q)


func _passes_category_filter(item: Dictionary) -> bool:
	if _tab == Category.ALL:
		return true
	return _item_category(item) == _tab


func _item_visible_in_view(item: Dictionary) -> bool:
	return _passes_category_filter(item) \
		and _passes_search(item) \
		and _passes_extra_filters(item)


func _slot_has_visible_item(slot_index: int) -> bool:
	if not is_instance_valid(GameState) or not GameState.has_hero() or slot_index < 0 or slot_index >= GameState.hero.inventory.size():
		return false
	return _item_visible_in_view(GameState.hero.inventory[slot_index])


func _items_for_category(category: Category) -> Array:
	if not is_instance_valid(GameState) or not GameState.has_hero():
		return []
	var result: Array = []
	for item in GameState.hero.inventory:
		if category != Category.ALL and _item_category(item) != category:
			continue
		if not _passes_search(item):
			continue
		if not _passes_extra_filters(item):
			continue
		result.append(item)
	return result


func _item_category(item: Dictionary) -> Category:
	var slot: String = ItemDataScript.item_slot(item)
	match slot:
		"weapon":
			return Category.WEAPON
		"chest", "legs", "feet", "gloves", "helmet":
			return Category.ARMOR
		"earring", "ring", "amulet":
			return Category.ACCESSORY

	match ItemDataScript.item_category(item):
		"potion":
			return Category.POTION
		"food":
			return Category.FOOD
		"material":
			return Category.MATERIAL
		_:
			return Category.MATERIAL
