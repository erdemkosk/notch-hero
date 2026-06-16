extends Control

signal tab_pressed(tab: int)
signal menu_pressed

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const UiFont = preload("res://scripts/ui/ui_font.gd")
const NavIconsScript = preload("res://scripts/ui/nav_icons.gd")

enum Tab { COMBAT, INVENTORY, FORGE, MARKET, TALENTS }

const MENU_BTN_WIDTH := 46.0

const TAB_LABELS := {
	Tab.COMBAT: "Fight",
	Tab.INVENTORY: "Bag",
	Tab.FORGE: "Forge",
	Tab.MARKET: "Market",
	Tab.TALENTS: "Perks",
}

const GOLD := Color(0.92, 0.74, 0.38)
const TEXT_IDLE := Color(0.82, 0.76, 0.66)
const TEXT_ACTIVE := Color(0.98, 0.94, 0.84)
const ICON_SCALE := 17.0

var _active := Tab.COMBAT
var _hover := -1
var _menu_hover := false
var _alert_pulse := 0.0


func _ready() -> void:
	UiFont.setup()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(GameState):
		GameState.state_changed.connect(_on_state_changed)
	resized.connect(queue_redraw)
	set_process(true)


func set_active_tab(tab: int) -> void:
	_active = tab as Tab
	queue_redraw()


func _on_state_changed() -> void:
	queue_redraw()


func _inventory_has_alert() -> bool:
	if not is_instance_valid(GameState):
		return false
	return GameState.inventory_unseen > 0 and _active != Tab.INVENTORY


func _process(delta: float) -> void:
	if not _inventory_has_alert():
		if _alert_pulse != 0.0:
			_alert_pulse = 0.0
			queue_redraw()
		return
	_alert_pulse += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_menu_hover = _menu_rect().has_point(event.position)
		_hover = _tab_at(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _menu_rect().has_point(event.position):
			menu_pressed.emit()
			return
		var tab := _tab_at(event.position)
		if tab >= 0:
			tab_pressed.emit(tab)


func _tab_area_width() -> float:
	return maxf(0.0, size.x - UIScaleScript.px(MENU_BTN_WIDTH))


func _menu_rect() -> Rect2:
	var menu_w := UIScaleScript.px(MENU_BTN_WIDTH)
	return Rect2(size.x - menu_w, 0.0, menu_w, size.y)


func _tab_at(pos: Vector2) -> int:
	var tab_area_w := _tab_area_width()
	if tab_area_w < 4.0:
		return -1
	var count := Tab.values().size()
	var tab_w := tab_area_w / float(count)
	var idx := int(floor(pos.x / tab_w))
	if idx < 0 or idx >= count:
		return -1
	var rect := Rect2(float(idx) * tab_w, 0.0, tab_w, size.y)
	if rect.has_point(pos):
		return idx
	return -1


func _inventory_badge() -> String:
	if not is_instance_valid(GameState) or not GameState.has_hero():
		return ""
	if GameState.inventory_unseen > 0:
		return str(mini(GameState.inventory_unseen, 9))
	if GameState.hero.inventory.size() >= GameState.hero.bag_slot_capacity():
		return "!"
	return ""


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return

	var font: Font = UiFont.get_font()
	var tab_w := _tab_area_width() / float(Tab.values().size())
	var gap := UIScaleScript.px(2.0)
	var tab_h := size.y - gap

	for tab in Tab.values():
		var idx := int(tab)
		var tab_rect := Rect2(float(idx) * tab_w + gap * 0.5, gap * 0.5, tab_w - gap, tab_h - gap)
		var active: bool = idx == int(_active)
		var hovered := idx == _hover

		var lift := UIScaleScript.px(2.0) if active else 0.0
		if hovered and not active:
			lift = UIScaleScript.px(1.0)
		var lifted_rect := Rect2(tab_rect.position + Vector2(0.0, -lift), tab_rect.size)

		var bg := Color(0.5, 0.34, 0.2) if active else Color(0.32, 0.21, 0.13)
		if hovered and not active:
			bg = bg.lightened(0.06)
		_draw_rounded_fill(lifted_rect, UIScaleScript.px(4.0), bg)

		if active:
			var line_h := UIScaleScript.px(3.0)
			draw_rect(
				Rect2(
					lifted_rect.position.x + UIScaleScript.px(4.0),
					lifted_rect.position.y + lifted_rect.size.y - line_h,
					lifted_rect.size.x - UIScaleScript.px(8.0),
					line_h
				),
				GOLD
			)
			_draw_rounded_stroke(lifted_rect, UIScaleScript.px(4.0), GOLD.darkened(0.15), 1.0)

		var icon_center := Vector2(lifted_rect.position.x + lifted_rect.size.x * 0.5, lifted_rect.position.y + lifted_rect.size.y * 0.33)
		var icon_col := TEXT_ACTIVE if active else TEXT_IDLE
		if tab == Tab.INVENTORY and _inventory_has_alert():
			var pulse := 0.5 + 0.5 * sin(_alert_pulse * 5.2)
			var glow_rect := lifted_rect.grow(UIScaleScript.px(2.0 + pulse * 2.0))
			var glow_a := 0.18 + pulse * 0.32
			_draw_rounded_fill(glow_rect, UIScaleScript.px(6.0), Color(0.95, 0.72, 0.28, glow_a))
			_draw_rounded_stroke(
				lifted_rect.grow(UIScaleScript.px(1.0 + pulse * 1.5)),
				UIScaleScript.px(5.0),
				Color(1.0, 0.82, 0.38, 0.35 + pulse * 0.55),
				UIScaleScript.px(1.0) + pulse * 0.6
			)
			icon_col = icon_col.lerp(GOLD, 0.25 + pulse * 0.35)
		NavIconsScript.draw(self, icon_center, tab, icon_col, UIScaleScript.px(ICON_SCALE))

		var label: String = TAB_LABELS.get(tab, "?")
		var label_sz := UIScaleScript.font_ui()
		var tw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_sz).x
		var tx: float = lifted_rect.position.x + (lifted_rect.size.x - tw) * 0.5
		var ty := lifted_rect.position.y + lifted_rect.size.y - UIScaleScript.px(4.0)
		draw_string(font, Vector2(tx, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_sz, icon_col)

		if tab == Tab.INVENTORY:
			var badge := _inventory_badge()
			if not badge.is_empty():
				var pulse := 0.5 + 0.5 * sin(_alert_pulse * 5.2) if _inventory_has_alert() else 0.0
				var badge_sz := UIScaleScript.px(11.0 + pulse * 2.5)
				var bx := lifted_rect.position.x + lifted_rect.size.x - badge_sz - UIScaleScript.px(2.0)
				var by := lifted_rect.position.y + UIScaleScript.px(2.0)
				var badge_center := Vector2(bx + badge_sz * 0.5, by + badge_sz * 0.5)
				if _inventory_has_alert():
					draw_circle(badge_center, badge_sz * 0.72, Color(1.0, 0.55, 0.22, 0.12 + pulse * 0.22))
				draw_circle(badge_center, badge_sz * 0.55, Color(0.82, 0.22, 0.18).lerp(Color(1.0, 0.45, 0.2), pulse * 0.45))
				var bsz := UIScaleScript.font_caption()
				var bw: float = font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bsz).x
				draw_string(
					font,
					Vector2(bx + (badge_sz - bw) * 0.5, by + badge_sz - UIScaleScript.px(2.0)),
					badge,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					bsz,
					Color(1.0, 0.95, 0.9)
				)

	var menu_rect := _menu_rect().grow(-gap * 0.5)
	if menu_rect.size.x > 4.0 and menu_rect.size.y > 4.0:
		var menu_bg := Color(0.28, 0.2, 0.14) if _menu_hover else Color(0.18, 0.14, 0.11)
		_draw_rounded_fill(menu_rect, UIScaleScript.px(4.0), menu_bg)
		_draw_rounded_stroke(menu_rect, UIScaleScript.px(4.0), GOLD.darkened(0.15), 1.0)
		var menu_label := "Menu"
		var menu_fs := UIScaleScript.font_ui()
		var menu_tw := font.get_string_size(menu_label, HORIZONTAL_ALIGNMENT_LEFT, -1, menu_fs).x
		var menu_col := TEXT_ACTIVE if _menu_hover else TEXT_IDLE
		draw_string(
			font,
			Vector2(menu_rect.position.x + (menu_rect.size.x - menu_tw) * 0.5, menu_rect.position.y + menu_rect.size.y * 0.68),
			menu_label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			menu_fs,
			menu_col
		)


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
