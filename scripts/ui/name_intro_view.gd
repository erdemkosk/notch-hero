extends Control

signal confirm_pressed(player_name: String)
signal back_pressed

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const UiFont = preload("res://scripts/ui/ui_font.gd")
const InventorySlotDrawScript = preload("res://scripts/ui/inventory_slot_draw.gd")

const TITLE := Color(0.96, 0.9, 0.72)
const BODY := Color(0.78, 0.72, 0.64)
const BTN := Color(0.18, 0.14, 0.11)
const BTN_HI := Color(0.28, 0.2, 0.14)
const BTN_BORDER := Color(0.58, 0.44, 0.26)
const FIELD_BG := Color(0.1, 0.08, 0.06, 0.95)
const FIELD_TEXT := Color(0.94, 0.9, 0.82)
const FIELD_PLACEHOLDER := Color(0.52, 0.48, 0.44)

var _name_field: LineEdit
var _confirm_hit: Control
var _back_hit: Control
var _hover_confirm := false
var _hover_back := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 200

	_name_field = LineEdit.new()
	_name_field.placeholder_text = "Hero name"
	_name_field.max_length = 16
	_name_field.mouse_filter = Control.MOUSE_FILTER_STOP
	_name_field.focus_mode = Control.FOCUS_ALL
	_name_field.text_submitted.connect(_on_submit)
	_name_field.add_theme_font_size_override("font_size", UIScaleScript.font_ui())
	_name_field.add_theme_color_override("font_color", FIELD_TEXT)
	_name_field.add_theme_color_override("font_placeholder_color", FIELD_PLACEHOLDER)
	_name_field.add_theme_color_override("caret_color", FIELD_TEXT)
	_name_field.add_theme_stylebox_override("normal", _field_style(FIELD_BG))
	_name_field.add_theme_stylebox_override("focus", _field_style(FIELD_BG.lightened(0.08)))
	add_child(_name_field)

	_confirm_hit = Control.new()
	_confirm_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_hit.mouse_entered.connect(func() -> void:
		_hover_confirm = true
		queue_redraw()
	)
	_confirm_hit.mouse_exited.connect(func() -> void:
		_hover_confirm = false
		queue_redraw()
	)
	_confirm_hit.gui_input.connect(_on_confirm_hit_input)
	add_child(_confirm_hit)

	_back_hit = Control.new()
	_back_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_back_hit.mouse_entered.connect(func() -> void:
		_hover_back = true
		queue_redraw()
	)
	_back_hit.mouse_exited.connect(func() -> void:
		_hover_back = false
		queue_redraw()
	)
	_back_hit.gui_input.connect(_on_back_hit_input)
	add_child(_back_hit)

	resized.connect(_layout)


func on_shown() -> void:
	_layout()
	call_deferred("_focus_name_field")


func _focus_name_field() -> void:
	if not is_instance_valid(_name_field):
		return
	_name_field.grab_focus()
	_name_field.caret_column = _name_field.text.length()


func _field_style(bg: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = BTN_BORDER
	box.set_border_width_all(1)
	box.set_corner_radius_all(int(round(UIScaleScript.px(4.0))))
	box.content_margin_left = UIScaleScript.px(6.0)
	box.content_margin_right = UIScaleScript.px(6.0)
	box.content_margin_top = UIScaleScript.px(4.0)
	box.content_margin_bottom = UIScaleScript.px(4.0)
	return box


func _layout() -> void:
	if not is_instance_valid(_name_field):
		return
	if size.x < 20.0 or size.y < 20.0:
		return

	var w := minf(size.x * 0.72, UIScaleScript.px(220.0))
	var field_h := UIScaleScript.px(30.0)
	_name_field.position = Vector2(size.x * 0.5 - w * 0.5, size.y * 0.46)
	_name_field.size = Vector2(w, field_h)

	if is_instance_valid(_confirm_hit):
		var confirm := _confirm_rect()
		_confirm_hit.position = confirm.position
		_confirm_hit.size = confirm.size

	if is_instance_valid(_back_hit):
		var back := _back_rect()
		_back_hit.position = back.position
		_back_hit.size = back.size

	queue_redraw()


func _on_confirm_hit_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_submit_name()


func _on_back_hit_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		back_pressed.emit()


func _confirm_rect() -> Rect2:
	var w := minf(size.x * 0.72, UIScaleScript.px(220.0))
	var h := UIScaleScript.px(34.0)
	return Rect2(size.x * 0.5 - w * 0.5, size.y * 0.62, w, h)


func _back_rect() -> Rect2:
	var w := minf(size.x * 0.72, UIScaleScript.px(220.0))
	var h := UIScaleScript.px(28.0)
	return Rect2(size.x * 0.5 - w * 0.5, size.y * 0.72, w, h)


func _on_submit(_text: String) -> void:
	_submit_name()


func _submit_name() -> void:
	var name := _name_field.text.strip_edges()
	if name.is_empty():
		name = "Hero"
	confirm_pressed.emit(name)


func _draw() -> void:
	if size.x < 20.0 or size.y < 20.0:
		return

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.03, 0.05, 0.94), true)

	var font: Font = UiFont.get_font()
	var title_sz := UIScaleScript.font_emphasis()
	var body_sz := UIScaleScript.font_ui()

	var title := "New Adventure"
	var title_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, title_sz).x
	draw_string(
		font,
		Vector2(size.x * 0.5 - title_w * 0.5, size.y * 0.24),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		title_sz,
		TITLE
	)

	var lines := [
		"Fight waves, loot gear, equip modifiers.",
		"Death resets the stage — your bag stays.",
		"Pick a name and jump in.",
	]
	var y := size.y * 0.32
	for line in lines:
		var lw := font.get_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, -1, body_sz).x
		draw_string(
			font,
			Vector2(size.x * 0.5 - lw * 0.5, y),
			line,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			body_sz,
			BODY
		)
		y += UIScaleScript.px(14.0)

	var rect := _confirm_rect()
	var bg := BTN_HI if _hover_confirm else BTN
	InventorySlotDrawScript._draw_rounded_fill(self, rect, UIScaleScript.px(6.0), bg)
	InventorySlotDrawScript._draw_rounded_stroke(self, rect, UIScaleScript.px(6.0), BTN_BORDER, 1.0)
	var label := "Start"
	var lbl_sz := UIScaleScript.font_ui()
	var lbl_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, lbl_sz).x
	draw_string(
		font,
		Vector2(rect.position.x + rect.size.x * 0.5 - lbl_w * 0.5, rect.position.y + rect.size.y * 0.68),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		lbl_sz,
		TITLE
	)

	var back_rect := _back_rect()
	var back_label := "Back"
	var back_lbl_sz := UIScaleScript.font_ui()
	var back_lbl_w := font.get_string_size(back_label, HORIZONTAL_ALIGNMENT_CENTER, -1, back_lbl_sz).x
	var back_col := BODY.lightened(0.12) if _hover_back else BODY
	draw_string(
		font,
		Vector2(back_rect.position.x + back_rect.size.x * 0.5 - back_lbl_w * 0.5, back_rect.position.y + back_rect.size.y * 0.72),
		back_label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		back_lbl_sz,
		back_col
	)
