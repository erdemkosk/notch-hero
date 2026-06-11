extends RefCounted
class_name InventorySlotMetrics

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")

const BAG_ROWS := 3
const MIN_COLS := 5
const MAX_COLS := 14

const EQUIP_COLS := 3
const EQUIP_ROWS := 4

const BAG_WIDTH_SHARE := 0.54


static func stat_column_width() -> float:
	return UIScaleScript.px(44.0)


static func potion_column_width(slot_side: float) -> float:
	return slot_side + UIScaleScript.px(6.0)


static func potion_column_gap() -> float:
	return UIScaleScript.px(4.0)


static func equip_core_width(slot_side: float) -> float:
	var pad_edge := UIScaleScript.px(4.0)
	var col_w := stat_column_width()
	var col_gap := UIScaleScript.px(4.0)
	var gap := UIScaleScript.px(2.0)
	var grid_w := slot_side * float(EQUIP_COLS) + gap * float(EQUIP_COLS - 1)
	return pad_edge + col_w + col_gap + grid_w + col_gap + col_w + pad_edge


static func equip_panel_width(slot_side: float) -> float:
	return equip_core_width(slot_side) + potion_column_gap() + potion_column_width(slot_side)


static func slot_side_for_inner(inner: Vector2, tab_w: float = 0.0) -> float:
	if inner.x < 20.0 or inner.y < 20.0:
		return UIScaleScript.px(36.0)

	var area := inner
	if tab_w > 0.0:
		area = Vector2(maxf(20.0, inner.x - tab_w), inner.y)

	var gap := UIScaleScript.px(2.0)
	var slot_by_height: float = floor((area.y - gap * float(BAG_ROWS - 1)) / float(BAG_ROWS))
	slot_by_height = maxf(slot_by_height, UIScaleScript.px(12.0))

	var cols: int = int(floor((area.x + gap) / (slot_by_height + gap)))
	cols = clampi(cols, MIN_COLS, MAX_COLS)

	var slot_by_width: float = floor((area.x - gap * float(cols - 1)) / float(cols))
	return maxf(floor(minf(slot_by_height, slot_by_width)), UIScaleScript.px(12.0))


static func equip_grid_side(panel_h: float, panel_w: float, cols: int = EQUIP_COLS, rows: int = EQUIP_ROWS) -> float:
	var gap := UIScaleScript.px(2.0)
	var pad_edge := UIScaleScript.px(4.0)
	var col_w := stat_column_width()
	var col_gap := UIScaleScript.px(4.0)
	var pad_top := UIScaleScript.px(20.0)
	var pad_bottom := UIScaleScript.px(6.0)
	var grid_avail_h: float = panel_h - pad_top - pad_bottom
	var est_by_h: float = (grid_avail_h - gap * float(rows - 1)) / float(rows)
	var est_side := maxf(est_by_h, UIScaleScript.px(22.0))
	var core_w := panel_w - potion_column_gap() - potion_column_width(est_side)

	var grid_avail_w: float = core_w - pad_edge * 2.0 - col_w * 2.0 - col_gap * 2.0
	if grid_avail_w < 12.0 or grid_avail_h < 12.0:
		return UIScaleScript.px(22.0)

	var max_w: float = (grid_avail_w - gap * float(cols - 1)) / float(cols)
	var max_h: float = (grid_avail_h - gap * float(rows - 1)) / float(rows)
	return floor(minf(max_w, max_h))


static func shared_slot_side(bag_panel_size: Vector2, tab_w: float, equip_panel_size: Vector2) -> float:
	var bag_side: float = slot_side_for_inner(bag_panel_size, tab_w)
	var equip_side: float = equip_grid_side(equip_panel_size.y, equip_panel_size.x)
	return maxf(minf(bag_side, equip_side), UIScaleScript.px(22.0))


static func content_host_height() -> float:
	return UIScaleScript.PANEL_HEIGHT - UIScaleScript.NAV_HEIGHT


static func _bag_grid_inner_height(host_h: float) -> float:
	var edge := UIScaleScript.px(2.0)
	var overhead := edge * 2.0 \
		+ UIScaleScript.px(18.0) \
		+ UIScaleScript.px(22.0) \
		+ UIScaleScript.px(18.0) \
		+ UIScaleScript.px(14.0) \
		+ UIScaleScript.px(4.0) * 2.0
	return maxf(host_h - overhead, UIScaleScript.px(40.0))


static func slot_side_for_host_height(host_h: float) -> float:
	var inner_h := _bag_grid_inner_height(host_h)
	var gap := UIScaleScript.px(2.0)
	var slot_by_height: float = floor((inner_h - gap * float(BAG_ROWS - 1)) / float(BAG_ROWS))
	return maxf(slot_by_height, UIScaleScript.px(12.0))


static func _bag_margins() -> float:
	return UIScaleScript.px(2.0) * 2.0 + UIScaleScript.px(4.0) * 2.0


static func bag_panel_width(slot_side: float, cols: int = MIN_COLS) -> float:
	var edge := UIScaleScript.px(2.0)
	var pad := UIScaleScript.px(4.0)
	var gap := UIScaleScript.px(2.0)
	var use_cols := clampi(cols, MIN_COLS, MAX_COLS)
	var grid_w := slot_side * float(use_cols) + gap * float(use_cols - 1)
	return edge * 2.0 + pad * 2.0 + grid_w


static func _resolve_slot_side(host_h: float) -> float:
	var side: float = slot_side_for_host_height(host_h)
	var equip_w: float = equip_panel_width(side)
	side = minf(side, equip_grid_side(host_h, equip_w))
	return maxf(side, UIScaleScript.px(22.0))


static func _design_bag_cols(side: float) -> int:
	var equip_w: float = equip_panel_width(side)
	var total_est: float = equip_w / (1.0 - BAG_WIDTH_SHARE)
	var bag_target_w: float = total_est * BAG_WIDTH_SHARE
	var gap := UIScaleScript.px(2.0)
	var inner_target: float = bag_target_w - _bag_margins()
	return clampi(int(floor((inner_target + gap) / (side + gap))), MIN_COLS, MAX_COLS)


static func design_layout() -> Dictionary:
	return layout_for_panel(content_host_height(), design_panel_width())


static func design_panel_width() -> float:
	var host_h := content_host_height()
	var side := _resolve_slot_side(host_h)
	var equip_w := equip_panel_width(side)
	var cols := _design_bag_cols(side)
	var bag_w := bag_panel_width(side, cols)
	return roundf(bag_w + equip_w)


static func layout_for_panel(host_h: float, panel_w: float) -> Dictionary:
	var side := _resolve_slot_side(host_h)
	var equip_w := equip_panel_width(side)
	var bag_w := maxf(panel_w - equip_w, bag_panel_width(side, MIN_COLS))
	return {
		"slot_side": side,
		"bag_w": bag_w,
		"equip_w": equip_w,
		"total_w": bag_w + equip_w,
	}


static func resolve_layout(host_h: float = -1.0) -> Dictionary:
	if host_h < 0.0:
		host_h = content_host_height()
	return layout_for_panel(host_h, design_panel_width())
