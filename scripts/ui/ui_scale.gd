extends RefCounted
class_name UIScale

const FACTOR := 1.75
const SPRITE_FACTOR := 1.5

const PANEL_HEIGHT := 280.0
# Panel genisligi icerige gore hesaplanir (InventorySlotMetrics.design_panel_width).
const PANEL_WIDTH_SCALE := 1.0
const SPRITE_SCALE := 3.0
const PORTAL_SCALE := 3.0
const NAV_HEIGHT := 77.0
const NAV_FONT := 35


static func px(value: float) -> float:
	return value * FACTOR


static func font(value: int) -> int:
	return int(round(value * FACTOR))
