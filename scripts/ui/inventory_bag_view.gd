extends Control

enum Category { WEAPON, FOOD, ARMOR, ACCESSORY, POTION, MATERIAL }

const ROWS := 3
const MIN_COLS := 5
const MAX_COLS := 14

const LEATHER := Color(0.56, 0.36, 0.21)
const LEATHER_DARK := Color(0.34, 0.21, 0.12)
const LEATHER_MID := Color(0.48, 0.31, 0.18)
const LEATHER_LIGHT := Color(0.68, 0.46, 0.28)
const SLOT_BG := Color(0.24, 0.14, 0.08)
const SLOT_INSET := Color(0.18, 0.1, 0.06)
const SLOT_HI := Color(0.32, 0.2, 0.12)
const STITCH := Color(0.78, 0.58, 0.34)
const TAB_PAPER := Color(0.9, 0.82, 0.66)
const TAB_ACTIVE := Color(0.97, 0.9, 0.74)
const TAB_EDGE := Color(0.62, 0.48, 0.32)
const METAL := Color(0.62, 0.62, 0.66)
const METAL_D := Color(0.42, 0.42, 0.46)

const RARITY_COLORS := {
	"common": Color(0.78, 0.78, 0.82),
	"rare": Color(0.35, 0.72, 1.0),
	"epic": Color(0.78, 0.42, 1.0),
	"trade": Color(0.95, 0.82, 0.35),
}

var _tab := Category.WEAPON
var _hover_slot := -1
var _last_click_slot := -1
var _last_click_ms := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	GameState.state_changed.connect(queue_redraw)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover_slot = _slot_at(get_local_mouse_position())
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var slot := _slot_at(event.position)
		if slot < 0:
			var tab := _tab_at(event.position)
			if tab >= 0:
				_tab = tab as Category
				queue_redraw()
			return

		var now := Time.get_ticks_msec()
		if slot == _last_click_slot and now - _last_click_ms < 350:
			_sell_slot(slot)
			_last_click_slot = -1
		else:
			_last_click_slot = slot
			_last_click_ms = now


func _sell_slot(filtered_index: int) -> void:
	var global_index := _global_index_for_filtered(filtered_index)
	if global_index >= 0:
		GameState.sell_item(global_index)


func _draw() -> void:
	if size.x < 40.0 or size.y < 40.0:
		return

	var layout := _compute_layout()
	_draw_bag(layout)
	_draw_slots(layout)
	_draw_items(layout)
	_draw_tabs(layout)


func _compute_layout() -> Dictionary:
	var tab_w: float = 20.0
	var edge: float = 1.0

	# Canta tum kullanilabilir alani kaplasin.
	var bag_rect := Rect2(edge, edge, size.x - tab_w - edge * 2.0, size.y - edge * 2.0)
	var inner := bag_rect.grow(-4.0)
	var base_gap: float = 2.0

	var slot_by_height: float = floor((inner.size.y - base_gap * float(ROWS - 1)) / float(ROWS))
	slot_by_height = maxf(slot_by_height, 12.0)

	var cols: int = int(floor((inner.size.x + base_gap) / (slot_by_height + base_gap)))
	cols = clampi(cols, MIN_COLS, MAX_COLS)

	var slot_by_width: float = floor((inner.size.x - base_gap * float(cols - 1)) / float(cols))
	var slot_side: float = floor(minf(slot_by_height, slot_by_width))
	slot_side = maxf(slot_side, 12.0)

	var grid_w: float = slot_side * float(cols) + base_gap * float(cols - 1)
	var grid_h: float = slot_side * float(ROWS) + base_gap * float(ROWS - 1)

	# Genislik boslugu varsa araligi ac — grid sola yasli, saga kadar uzanir.
	var gap_x: float = base_gap
	if cols > 1 and grid_w < inner.size.x - 1.0:
		gap_x = (inner.size.x - slot_side * float(cols)) / float(cols - 1)
		grid_w = inner.size.x

	var gap_y: float = base_gap
	if grid_h < inner.size.y - 1.0:
		gap_y = (inner.size.y - slot_side * float(ROWS)) / float(ROWS - 1)
		grid_h = inner.size.y

	var grid_origin := Vector2(
		inner.position.x,
		inner.position.y + (inner.size.y - (slot_side * float(ROWS) + gap_y * float(ROWS - 1))) * 0.5
	)

	return {
		"bag": bag_rect,
		"inner": inner,
		"cols": cols,
		"slot_count": cols * ROWS,
		"slot_size": Vector2(slot_side, slot_side),
		"gap_x": gap_x,
		"gap_y": gap_y,
		"grid_origin": grid_origin,
		"tab_w": tab_w,
		"tab_x": size.x - tab_w - 1.0,
	}


func _draw_bag(layout: Dictionary) -> void:
	var bag: Rect2 = layout["bag"]
	var r: float = 7.0

	# Deri govde — yuvarlatilmis, katmanli
	_draw_rounded_fill(bag, r, LEATHER_DARK)
	var inset := bag.grow(-2.0)
	_draw_rounded_fill(inset, r - 1.0, LEATHER_MID)
	_draw_rounded_stroke(bag, r, LEATHER_LIGHT, 1.5)

	# Ust deri parlamasi
	var flap := Rect2(bag.position.x + 8, bag.position.y + 3, bag.size.x - 16, 10)
	_draw_rounded_fill(flap, 4.0, LEATHER.lightened(0.08))

	# Dikis — yuvarlak koseleri takip eden noktalar
	_draw_stitch_line(bag, r)

	# Tokalar + kayislar
	_draw_strap_buckle(bag.position + Vector2(8, 5))
	_draw_strap_buckle(bag.position + Vector2(bag.size.x - 24, 5))
	_draw_bottom_strap(bag.position + Vector2(22, bag.size.y - 3))
	_draw_bottom_strap(bag.position + Vector2(bag.size.x - 30, bag.size.y - 3))


func _draw_stitch_line(bag: Rect2, radius: float) -> void:
	var step := 5.0
	var x := bag.position.x + radius + 2.0
	while x < bag.end.x - radius - 2.0:
		draw_circle(Vector2(x, bag.position.y + 3), 1.0, STITCH)
		draw_circle(Vector2(x, bag.end.y - 3), 1.0, STITCH)
		x += step


func _draw_strap_buckle(pos: Vector2) -> void:
	draw_rect(Rect2(pos.x, pos.y, 4, 10), LEATHER_DARK.darkened(0.05))
	_draw_rounded_fill(Rect2(pos.x + 3, pos.y + 1, 12, 8), 2.0, METAL)
	draw_rect(Rect2(pos.x + 5, pos.y + 3, 8, 4), METAL_D)


func _draw_bottom_strap(pos: Vector2) -> void:
	_draw_rounded_fill(Rect2(pos.x, pos.y, 8, 7), 3.0, LEATHER_DARK)


func _draw_slots(layout: Dictionary) -> void:
	var slot_size: Vector2 = layout["slot_size"]
	var gap_x: float = layout["gap_x"]
	var gap_y: float = layout["gap_y"]
	var origin: Vector2 = layout["grid_origin"]
	var cols: int = layout["cols"]
	var slot_count: int = layout["slot_count"]

	for i in slot_count:
		var rect := _slot_rect(origin, slot_size, gap_x, gap_y, cols, i)
		var hovered: bool = i == _hover_slot
		_draw_slot_square(rect, hovered, slot_size.x)


func _draw_slot_square(rect: Rect2, hovered: bool, slot_side: float) -> void:
	var r: float = clampf(slot_side * 0.12, 3.0, 5.0)
	var bg := SLOT_BG.lightened(0.06 if hovered else 0.0)
	_draw_rounded_fill(rect, r, bg)
	# Ice cukur efekti
	var inner := rect.grow(-2.0)
	_draw_rounded_fill(inner, r - 1.0, SLOT_INSET if not hovered else SLOT_HI)
	_draw_rounded_stroke(rect, r, SLOT_HI if hovered else SLOT_INSET.darkened(0.2), 1.0)


func _draw_items(layout: Dictionary) -> void:
	var items := _filtered_items()
	var slot_size: Vector2 = layout["slot_size"]
	var gap_x: float = layout["gap_x"]
	var gap_y: float = layout["gap_y"]
	var origin: Vector2 = layout["grid_origin"]
	var cols: int = layout["cols"]
	var slot_count: int = layout["slot_count"]

	for i in slot_count:
		if i >= items.size():
			break
		var item: Dictionary = items[i]
		var rect := _slot_rect(origin, slot_size, gap_x, gap_y, cols, i)
		_draw_item_icon(rect, item, slot_size.x)
		var rarity: String = item.get("rarity", "common")
		var rc: Color = RARITY_COLORS.get(rarity, RARITY_COLORS["common"])
		draw_circle(rect.position + Vector2(rect.size.x - 4, 5), 1.5, rc)


func _draw_item_icon(rect: Rect2, item: Dictionary, slot_side: float) -> void:
	var name: String = item.get("name", "?")
	var c := _item_color(name)
	var center := rect.get_center()
	var s := slot_side / 32.0
	if name.contains("Asa") or name.contains("asa"):
		draw_rect(Rect2(center.x - 1 * s, center.y - 6 * s, 2 * s, 9 * s), Color(0.88, 0.88, 0.92))
		draw_rect(Rect2(center.x - 3 * s, center.y - 7 * s, 6 * s, 2 * s), METAL)
	elif name.contains("Pelerin"):
		draw_circle(center + Vector2(0, -1 * s), 4.0 * s, c)
	elif name.contains("crystal") or name.contains("shard") or name.contains("dust"):
		draw_circle(center, 3.0 * s, c)
		draw_circle(center + Vector2(-1 * s, -1 * s), 1.0 * s, c.lightened(0.35))
	else:
		draw_circle(center, 3.5 * s, c)


func _draw_tabs(layout: Dictionary) -> void:
	var tab_w: float = layout["tab_w"]
	var tab_x: float = layout["tab_x"]
	var tab_h: float = (size.y - 10.0) / float(Category.size())
	var y: float = 5.0

	for cat in Category.values():
		var active: bool = cat == _tab
		var h: float = tab_h - 2.0
		_draw_parchment_tab(Rect2(tab_x - 3.0, y, tab_w + 3.0, h), active)
		_draw_tab_icon(cat, Vector2(tab_x + tab_w * 0.45, y + h * 0.5))
		y += tab_h


func _draw_parchment_tab(rect: Rect2, active: bool) -> void:
	var fill := TAB_ACTIVE if active else TAB_PAPER
	var pts := PackedVector2Array([
		Vector2(rect.position.x + 4, rect.position.y),
		Vector2(rect.end.x, rect.position.y + 1),
		Vector2(rect.end.x - 1, rect.end.y - 1),
		Vector2(rect.position.x + 6, rect.end.y),
		Vector2(rect.position.x + 2, rect.end.y - 2),
		Vector2(rect.position.x, rect.position.y + 3),
	])
	draw_colored_polygon(pts, fill)
	draw_polyline(pts, TAB_EDGE, 1.0, true)


func _draw_tab_icon(cat: Category, center: Vector2) -> void:
	match cat:
		Category.WEAPON:
			draw_line(center + Vector2(-1, 5), center + Vector2(-1, -5), LEATHER_DARK, 2.0)
			draw_line(center + Vector2(-4, -5), center + Vector2(3, -5), METAL_D, 2.0)
		Category.FOOD:
			draw_circle(center + Vector2(0, 1), 3.5, Color(0.88, 0.28, 0.18))
			draw_rect(Rect2(center.x - 2, center.y - 5, 4, 2), Color(0.22, 0.52, 0.2))
		Category.ARMOR:
			draw_circle(center + Vector2(0, -2), 3.0, METAL)
			draw_rect(Rect2(center.x - 4, center.y, 8, 5), METAL_D)
		Category.ACCESSORY:
			draw_arc(center + Vector2(0, 2), 3.5, PI, TAU, 8, LEATHER_DARK, 1.5)
			draw_circle(center + Vector2(0, -2), 2.0, Color(0.92, 0.78, 0.22))
		Category.POTION:
			_draw_rounded_fill(Rect2(center.x - 2, center.y - 1, 4, 5), 1.0, Color(0.38, 0.68, 0.95))
			draw_rect(Rect2(center.x - 3, center.y - 4, 6, 2), Color(0.82, 0.22, 0.2))
		Category.MATERIAL:
			_draw_rounded_fill(Rect2(center.x - 4, center.y - 2, 8, 5), 1.0, Color(0.78, 0.62, 0.38))


func _draw_rounded_fill(rect: Rect2, radius: float, color: Color) -> void:
	radius = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var r := radius
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y

	draw_rect(Rect2(x + r, y, w - 2 * r, h), color)
	draw_rect(Rect2(x, y + r, w, h - 2 * r), color)
	draw_circle(Vector2(x + r, y + r), r, color)
	draw_circle(Vector2(x + w - r, y + r), r, color)
	draw_circle(Vector2(x + r, y + h - r), r, color)
	draw_circle(Vector2(x + w - r, y + h - r), r, color)


func _draw_rounded_stroke(rect: Rect2, radius: float, color: Color, width: float) -> void:
	radius = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var r := radius
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y

	draw_line(Vector2(x + r, y), Vector2(x + w - r, y), color, width)
	draw_line(Vector2(x + r, y + h), Vector2(x + w - r, y + h), color, width)
	draw_line(Vector2(x, y + r), Vector2(x, y + h - r), color, width)
	draw_line(Vector2(x + w, y + r), Vector2(x + w, y + h - r), color, width)
	draw_arc(Vector2(x + r, y + r), r, PI, PI * 1.5, 12, color, width)
	draw_arc(Vector2(x + w - r, y + r), r, PI * 1.5, TAU, 12, color, width)
	draw_arc(Vector2(x + r, y + h - r), r, PI * 0.5, PI, 12, color, width)
	draw_arc(Vector2(x + w - r, y + h - r), r, 0, PI * 0.5, 12, color, width)


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


func _tab_at(local_pos: Vector2) -> int:
	var layout := _compute_layout()
	var tab_w: float = layout["tab_w"]
	var tab_x: float = layout["tab_x"]
	var tab_h: float = (size.y - 10.0) / float(Category.size())
	var y: float = 5.0
	for cat in Category.values():
		var rect := Rect2(tab_x - 4.0, y, tab_w + 6.0, tab_h)
		if rect.has_point(local_pos):
			return cat
		y += tab_h
	return -1


func _filtered_items() -> Array:
	var result: Array = []
	for item in GameState.hero.inventory:
		if _item_category(item) == _tab:
			result.append(item)
	return result


func _global_index_for_filtered(filtered_index: int) -> int:
	var items := _filtered_items()
	if filtered_index < 0 or filtered_index >= items.size():
		return -1
	var target: Dictionary = items[filtered_index]
	for i in GameState.hero.inventory.size():
		if GameState.hero.inventory[i] == target:
			return i
	return -1


func _item_category(item: Dictionary) -> Category:
	var name: String = str(item.get("name", "")).to_lower()
	if "asa" in name or "kilic" in name or "sword" in name:
		return Category.WEAPON
	if "pelerin" in name or "cloa" in name or "zirh" in name:
		return Category.ARMOR
	if "tilsim" in name or "amulet" in name:
		return Category.ACCESSORY
	if "crystal" in name or "shard" in name or "dust" in name or "iksir" in name:
		return Category.POTION
	if "toz" in name or "altin" in name or "material" in name:
		return Category.MATERIAL
	if "elma" in name or "yiyecek" in name or "food" in name:
		return Category.FOOD
	return Category.MATERIAL


func _item_color(name: String) -> Color:
	var lower := name.to_lower()
	if "ates" in lower or "fire" in lower:
		return Color(0.92, 0.35, 0.2)
	if "buz" in lower or "ice" in lower:
		return Color(0.45, 0.78, 1.0)
	if "epik" in lower:
		return Color(0.72, 0.38, 0.95)
	if "nadir" in lower or "rare" in lower:
		return Color(0.35, 0.72, 1.0)
	return Color(0.68, 0.62, 0.52)
