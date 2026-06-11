extends RefCounted
class_name CombatPotionBar

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const ItemDataScript = preload("res://scripts/game/item_data.gd")
const InventorySlotDrawScript = preload("res://scripts/ui/inventory_slot_draw.gd")
const InventoryIconDrawScript = preload("res://scripts/ui/inventory_icon_draw.gd")
const InventoryHoverScript = preload("res://scripts/ui/inventory_hover.gd")
const UiFont = preload("res://scripts/ui/ui_font.gd")

const HP_TINT := Color(0.35, 0.88, 0.45)
const MP_TINT := Color(0.35, 0.72, 1.0)
const LABEL_COLOR := Color(0.96, 0.9, 0.72)
const COUNT_COLOR := Color(0.98, 0.94, 0.86)
const EMPTY_COLOR := Color(0.45, 0.38, 0.32, 0.85)
const VALID_PULSE := Color(0.42, 0.92, 0.55)
const INVALID_PULSE := Color(0.92, 0.32, 0.28)
const SLOT_HI := Color(0.32, 0.2, 0.12)


static func combat_slot_side() -> float:
	return UIScaleScript.px(24.0)


static func combat_layout(viewport: Vector2, stage_hud_h: float) -> Dictionary:
	var side := combat_slot_side()
	var gap := UIScaleScript.px(4.0)
	var margin := UIScaleScript.px(8.0)
	var label_h := UIScaleScript.font_caption() + UIScaleScript.px(2.0)
	var block_w := side * 2.0 + gap
	var origin := Vector2(
		viewport.x - margin - block_w,
		viewport.y - stage_hud_h - margin - side - label_h
	)
	return {
		"origin": origin,
		"side": side,
		"gap": gap,
		"vertical": false,
		"show_label": true,
		"label": "Potions",
	}


static func equip_panel_layout(grid: Dictionary) -> Dictionary:
	var potion_x: float = grid.get("potion_col_x", grid["right_col_x"])
	var potion_w: float = grid.get("potion_col_w", grid["side"])
	var origin_y: float = grid["origin_y"]
	var grid_h: float = grid["grid_h"]
	var side: float = grid["side"]
	var gap: float = grid.get("gap", UIScaleScript.px(2.0))
	var label_h := UIScaleScript.font_caption() + UIScaleScript.px(4.0)
	var slots_h := side * 2.0 + gap
	var block_h := label_h + slots_h
	var slot_x := potion_x + (potion_w - side) * 0.5
	var block_y := origin_y + (grid_h - block_h) * 0.5
	return {
		"origin": Vector2(slot_x, block_y + label_h),
		"side": side,
		"gap": gap,
		"vertical": true,
		"show_label": true,
		"label": "Pot",
		"label_y": block_y + caption_baseline(label_h),
		"label_center_x": potion_x + potion_w * 0.5,
	}


static func caption_baseline(label_block_h: float) -> float:
	return label_block_h - UIScaleScript.px(2.0)


static func slot_rect(metrics: Dictionary, kind: String) -> Rect2:
	var origin: Vector2 = metrics["origin"]
	var side: float = metrics["side"]
	var gap: float = metrics["gap"]
	var idx := 0 if kind == "health" else 1
	if metrics.get("vertical", false):
		return Rect2(origin.x, origin.y + float(idx) * (side + gap), side, side)
	return Rect2(origin.x + float(idx) * (side + gap), origin.y, side, side)


static func kind_tint(kind: String) -> Color:
	return HP_TINT if kind == "health" else MP_TINT


static func potion_kind_at(metrics: Dictionary, local_pos: Vector2) -> String:
	for kind in ItemDataScript.POTION_KINDS:
		if slot_rect(metrics, kind).has_point(local_pos):
			return kind
	return ""


static func draw(
	canvas: CanvasItem,
	metrics: Dictionary,
	hero,
	use_flash: Dictionary = {},
	gain_flash: Dictionary = {},
	pulse_phase: float = 0.0,
	hover_kind: String = "",
	drag_valid_kind: String = "",
	drag_invalid_kind: String = "",
	dragging_from_kind: String = "",
	drag_item_kind: String = ""
) -> void:
	if hero == null:
		return

	var origin: Vector2 = metrics["origin"]
	var side: float = metrics["side"]
	var font: Font = UiFont.get_font()
	var caption := UIScaleScript.font_caption()

	if metrics.get("show_label", false):
		var label_text := str(metrics.get("label", "Potions"))
		if metrics.has("label_center_x"):
			var label_x: float = float(metrics["label_center_x"])
			var label_y: float = float(metrics.get("label_y", origin.y - UIScaleScript.px(2.0)))
			var tw := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, caption).x
			canvas.draw_string(
				font,
				Vector2(label_x - tw * 0.5, label_y),
				label_text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				caption,
				LABEL_COLOR
			)
		else:
			canvas.draw_string(
				font,
				Vector2(origin.x, origin.y - UIScaleScript.px(2.0)),
				label_text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				caption,
				LABEL_COLOR
			)

	var labels := {"health": "HP", "mana": "MP"}
	for kind in ItemDataScript.POTION_KINDS:
		var rect := slot_rect(metrics, kind)
		var use_a := clampf(float(use_flash.get(kind, 0.0)), 0.0, 1.0)
		var gain_a := clampf(float(gain_flash.get(kind, 0.0)), 0.0, 1.0)
		var tint := kind_tint(kind)
		var pulse := 0.5 + 0.5 * sin(pulse_phase * 8.0) if use_a > 0.05 else 0.0
		var hovered: bool = kind == hover_kind
		var bg_override := Color(-1, -1, -1, -1)

		if drag_valid_kind == kind:
			_draw_drop_pulse(canvas, rect, VALID_PULSE, pulse_phase)
		elif drag_invalid_kind == kind:
			_draw_drop_pulse(canvas, rect, INVALID_PULSE, pulse_phase)

		if not drag_item_kind.is_empty() and hovered:
			if kind == drag_item_kind:
				bg_override = SLOT_HI.lightened(0.18)
			else:
				bg_override = Color(0.42, 0.14, 0.1, 0.95)

		if use_a > 0.02:
			var glow := rect.grow(side * 0.22 * use_a * pulse)
			canvas.draw_rect(glow, Color(tint.r, tint.g, tint.b, 0.28 * use_a), true)
			InventorySlotDrawScript._draw_rounded_stroke(
				canvas,
				rect.grow(-UIScaleScript.px(1.0)),
				InventorySlotDrawScript.corner_radius(rect),
				Color(tint.r, tint.g, tint.b, 0.55 + 0.45 * use_a),
				UIScaleScript.px(1.5)
			)
		elif gain_a > 0.02:
			InventorySlotDrawScript._draw_rounded_stroke(
				canvas,
				rect.grow(-UIScaleScript.px(1.0)),
				InventorySlotDrawScript.corner_radius(rect),
				Color(0.95, 0.82, 0.35, 0.45 + 0.55 * gain_a),
				UIScaleScript.px(1.5)
			)

		if hovered:
			InventoryHoverScript.draw_slot(canvas, rect)

		InventorySlotDrawScript.draw_square(canvas, rect, hovered or use_a > 0.3, bg_override)

		var stack: Dictionary = hero.potion_bar_stack(kind)
		if dragging_from_kind == kind:
			stack = {}
		if not stack.is_empty():
			InventoryIconDrawScript.draw_in_slot(canvas, rect, stack)
			var count := ItemDataScript.stack_count(stack)
			if count > 0:
				var count_text := "x%d" % count
				var tw := font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, caption).x
				canvas.draw_string(
					font,
					Vector2(rect.end.x - tw - 1.0, rect.end.y - 1.0),
					count_text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					caption,
					COUNT_COLOR
				)
		else:
			var label: String = labels.get(kind, "?")
			canvas.draw_string(
				font,
				Vector2(rect.position.x + rect.size.x * 0.22, rect.end.y - UIScaleScript.px(3.0)),
				label,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				caption,
				EMPTY_COLOR
			)

		if use_a > 0.08:
			var press_text := "USE"
			var press_fs := UIScaleScript.font(8)
			var ptw := font.get_string_size(press_text, HORIZONTAL_ALIGNMENT_LEFT, -1, press_fs).x
			canvas.draw_string(
				font,
				Vector2(rect.position.x + (rect.size.x - ptw) * 0.5, rect.position.y + rect.size.y * 0.42),
				press_text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				press_fs,
				Color(tint.r, tint.g, tint.b, 0.65 + 0.35 * use_a)
			)


static func _draw_drop_pulse(canvas: CanvasItem, rect: Rect2, color: Color, pulse_phase: float) -> void:
	var wave := (sin(pulse_phase) + 1.0) * 0.5
	var alpha := 0.2 + wave * 0.55
	var expand := UIScaleScript.px(1.0) + wave * UIScaleScript.px(4.0)
	var outer := rect.grow(expand)
	var r := InventorySlotDrawScript.corner_radius(rect) + 2.0
	InventorySlotDrawScript._draw_rounded_fill(
		canvas,
		outer,
		r,
		Color(color.r, color.g, color.b, alpha * 0.4)
	)
	InventorySlotDrawScript._draw_rounded_stroke(
		canvas,
		outer,
		r,
		Color(color.r, color.g, color.b, alpha),
		1.0 + wave * 2.0
	)
