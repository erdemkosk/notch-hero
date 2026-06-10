extends Control

signal tab_pressed(tab: int)

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const UiFont = preload("res://scripts/ui/ui_font.gd")
const NavIconsScript = preload("res://scripts/ui/nav_icons.gd")

enum Tab { COMBAT, INVENTORY, FORGE, MARKET }

const TAB_LABELS := {
	Tab.COMBAT: "Fight",
	Tab.INVENTORY: "Bag",
	Tab.FORGE: "Forge",
	Tab.MARKET: "Market",
}

const GOLD := Color(0.92, 0.74, 0.38)
const TEXT_IDLE := Color(0.82, 0.76, 0.66)
const TEXT_ACTIVE := Color(0.98, 0.94, 0.84)
const LABEL_FONT := 12
const BADGE_FONT := 9
const ICON_SCALE := 17.0

var _active := Tab.COMBAT
var _hover := -1


func _ready() -> void:
	UiFont.setup()
	mouse_filter = Control.MOUSE_FILTER_STOP
	GameState.state_changed.connect(_on_state_changed)
	resized.connect(queue_redraw)


func set_active_tab(tab: int) -> void:
	_active = tab as Tab
	queue_redraw()


func _on_state_changed() -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = _tab_at(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var tab := _tab_at(event.position)
		if tab >= 0:
			tab_pressed.emit(tab)


func _tab_at(pos: Vector2) -> int:
	if size.x < 4.0:
		return -1
	var count := Tab.values().size()
	var tab_w := size.x / float(count)
	var idx := int(floor(pos.x / tab_w))
	if idx < 0 or idx >= count:
		return -1
	var rect := Rect2(float(idx) * tab_w, 0.0, tab_w, size.y)
	if rect.has_point(pos):
		return idx
	return -1


func _inventory_badge() -> String:
	if GameState.inventory_unseen > 0:
		return str(mini(GameState.inventory_unseen, 9))
	if GameState.hero.inventory.size() >= 12:
		return "!"
	return ""


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return

	var font: Font = UiFont.get_font()
	var tab_w := size.x / float(Tab.values().size())
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
		NavIconsScript.draw(self, icon_center, tab, icon_col, UIScaleScript.px(ICON_SCALE))

		var label: String = TAB_LABELS.get(tab, "?")
		var label_sz := UIScaleScript.font(LABEL_FONT)
		var tw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_sz).x
		var tx: float = lifted_rect.position.x + (lifted_rect.size.x - tw) * 0.5
		var ty := lifted_rect.position.y + lifted_rect.size.y - UIScaleScript.px(4.0)
		draw_string(font, Vector2(tx, ty), label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_sz, icon_col)

		if tab == Tab.INVENTORY:
			var badge := _inventory_badge()
			if not badge.is_empty():
				var badge_sz := UIScaleScript.px(11.0)
				var bx := lifted_rect.position.x + lifted_rect.size.x - badge_sz - UIScaleScript.px(2.0)
				var by := lifted_rect.position.y + UIScaleScript.px(2.0)
				draw_circle(Vector2(bx + badge_sz * 0.5, by + badge_sz * 0.5), badge_sz * 0.55, Color(0.82, 0.22, 0.18))
				var bsz := UIScaleScript.font(BADGE_FONT)
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
