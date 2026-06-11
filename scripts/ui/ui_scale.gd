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

# In-game typography (design px; scaled via font()).
const FONT_CAPTION := 8
const FONT_UI := 10
const FONT_HEADING := 11
const FONT_EMPHASIS := 12


static func px(value: float) -> float:
	return value * FACTOR


static func font(value: int) -> int:
	return int(round(value * FACTOR))


static func font_caption() -> int:
	return font(FONT_CAPTION)


static func font_ui() -> int:
	return font(FONT_UI)


static func font_heading() -> int:
	return font(FONT_HEADING)


static func font_emphasis() -> int:
	return font(FONT_EMPHASIS)
