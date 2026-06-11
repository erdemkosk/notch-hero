extends Control

signal continue_pressed
signal new_game_pressed
signal quit_pressed

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const UiFont = preload("res://scripts/ui/ui_font.gd")
const SaveServiceScript = preload("res://scripts/game/save_service.gd")
const InventorySlotDrawScript = preload("res://scripts/ui/inventory_slot_draw.gd")

const TITLE := Color(0.96, 0.9, 0.72)
const BODY := Color(0.78, 0.72, 0.64)
const BTN := Color(0.18, 0.14, 0.11)
const BTN_HI := Color(0.28, 0.2, 0.14)
const BTN_BORDER := Color(0.58, 0.44, 0.26)

var _continue_enabled := false
var _hover := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 200
	_continue_enabled = SaveServiceScript.has_save()
	resized.connect(queue_redraw)


func set_continue_enabled(enabled: bool) -> void:
	_continue_enabled = enabled
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = _button_at(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		match _button_at(event.position):
			0:
				if _continue_enabled:
					continue_pressed.emit()
			1:
				new_game_pressed.emit()
			2:
				quit_pressed.emit()


func _button_at(pos: Vector2) -> int:
	var rects := _button_rects()
	for i in rects.size():
		if rects[i].has_point(pos):
			return i
	return -1


func _button_rects() -> Array[Rect2]:
	var w := minf(size.x * 0.72, UIScaleScript.px(220.0))
	var h := UIScaleScript.px(34.0)
	var gap := UIScaleScript.px(8.0)
	var cx := size.x * 0.5
	var start_y := size.y * 0.48
	var rects: Array[Rect2] = []
	for i in 3:
		rects.append(Rect2(cx - w * 0.5, start_y + i * (h + gap), w, h))
	return rects


func _draw() -> void:
	if size.x < 20.0 or size.y < 20.0:
		return

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.03, 0.05, 0.94), true)

	var font: Font = UiFont.get_font()
	var title_sz := UIScaleScript.font(18)
	var body_sz := UIScaleScript.font(10)
	var title := "Notch Hero"
	var title_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, title_sz).x
	draw_string(
		font,
		Vector2(size.x * 0.5 - title_w * 0.5, size.y * 0.28),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		title_sz,
		TITLE
	)

	var subtitle := "Auto-battle loot runner"
	var sub_w := font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_CENTER, -1, body_sz).x
	draw_string(
		font,
		Vector2(size.x * 0.5 - sub_w * 0.5, size.y * 0.36),
		subtitle,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		body_sz,
		BODY
	)

	var labels: Array[String] = ["Continue", "New Game", "Quit"]
	var rects := _button_rects()
	for i in rects.size():
		var rect := rects[i]
		var enabled := i == 1 or i == 2 or _continue_enabled
		var hovered := _hover == i and enabled
		var bg := BTN_HI if hovered else BTN
		if not enabled:
			bg = bg.darkened(0.35)
		InventorySlotDrawScript._draw_rounded_fill(self, rect, UIScaleScript.px(6.0), bg)
		var border_col := BTN_BORDER if enabled else BTN_BORDER.darkened(0.4)
		InventorySlotDrawScript._draw_rounded_stroke(self, rect, UIScaleScript.px(6.0), border_col, 1.0)
		var label := labels[i]
		var lbl_sz := UIScaleScript.font(12)
		var lbl_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, lbl_sz).x
		var lbl_col := TITLE if enabled else BODY.darkened(0.25)
		draw_string(
			font,
			Vector2(rect.position.x + rect.size.x * 0.5 - lbl_w * 0.5, rect.position.y + rect.size.y * 0.68),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			lbl_sz,
			lbl_col
		)

	if not _continue_enabled:
		var hint := "No save yet"
		var hint_w := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, body_sz).x
		draw_string(
			font,
			Vector2(size.x * 0.5 - hint_w * 0.5, rects[0].end.y - UIScaleScript.px(2.0)),
			hint,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			body_sz,
			BODY.darkened(0.2)
		)
