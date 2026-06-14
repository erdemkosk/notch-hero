extends RefCounted
class_name StageMapDraw

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const UiFont = preload("res://scripts/ui/ui_font.gd")
const InventorySlotDrawScript = preload("res://scripts/ui/inventory_slot_draw.gd")

const GOLD := Color(0.92, 0.74, 0.38)
const GOLD_BRIGHT := Color(1.0, 0.88, 0.52)
const GOLD_DIM := Color(0.55, 0.4, 0.22)
const PANEL_DARK := Color(0.07, 0.05, 0.1, 0.96)
const PANEL_MID := Color(0.12, 0.09, 0.14, 0.92)
const TEXT_SOFT := Color(0.72, 0.68, 0.62)
const WAVE_IDLE := Color(0.22, 0.18, 0.26)
const WAVE_DONE := Color(0.62, 0.48, 0.3)


static func draw(canvas: CanvasItem, bounds: Rect2, params: Dictionary) -> void:
	if bounds.size.x < 40.0 or bounds.size.y < 16.0:
		return

	var stage_label: String = str(params.get("stage_label", ""))
	if stage_label.is_empty():
		return

	var wave_index: int = int(params.get("wave_index", 0))
	var wave_count: int = maxi(int(params.get("wave_count", 1)), 1)
	var stage_name: String = str(params.get("stage_name", ""))
	var world: int = int(params.get("world", 1))
	var biome: Dictionary = params.get("biome", {}) as Dictionary
	var accent: Color = biome.get("accent", Color(0.55, 0.72, 0.42)) as Color
	var accent_dark: Color = biome.get("accent_dark", accent.darkened(0.35)) as Color

	var hovered: bool = bool(params.get("hovered", false))
	_draw_panel(canvas, bounds, accent, accent_dark, hovered)
	_draw_content(canvas, bounds, stage_label, stage_name, world, wave_index, wave_count, accent)


static func _draw_panel(canvas: CanvasItem, bounds: Rect2, accent: Color, accent_dark: Color, hovered: bool) -> void:
	var r := UIScaleScript.px(6.0)
	var inset := bounds.grow(-UIScaleScript.px(1.0))
	
	# Blend base panel darks with the biome accent color to give it thematic colors
	var bg_dark := PANEL_DARK.lerp(accent_dark, 0.15)
	var bg_mid := PANEL_MID.lerp(accent_dark, 0.12)
	
	InventorySlotDrawScript._draw_rounded_fill(canvas, inset, r, bg_dark)
	InventorySlotDrawScript._draw_rounded_fill(canvas, inset.grow(-UIScaleScript.px(2.0)), r - 1.0, bg_mid)
	
	var stroke_color := GOLD if hovered else GOLD_DIM
	InventorySlotDrawScript._draw_rounded_stroke(canvas, inset, r, stroke_color, UIScaleScript.px(1.0))

	# Sweeping reflection shimmer shine
	var time_ms := Time.get_ticks_msec()
	var shimmer_speed := 0.15 # pixels per ms
	var width_total := bounds.size.x + UIScaleScript.px(300.0)
	var shimmer_x := fmod(time_ms * shimmer_speed, width_total) - UIScaleScript.px(150.0)
	
	if shimmer_x > inset.position.x and shimmer_x < inset.end.x:
		var sh_w := UIScaleScript.px(14.0)
		var line_pts := PackedVector2Array([
			Vector2(shimmer_x, inset.position.y),
			Vector2(shimmer_x + sh_w, inset.position.y),
			Vector2(shimmer_x - UIScaleScript.px(12.0) + sh_w, inset.end.y),
			Vector2(shimmer_x - UIScaleScript.px(12.0), inset.end.y)
		])
		canvas.draw_polygon(line_pts, [Color(1.0, 0.94, 0.82, 0.06)])

	var hl := Rect2(
		inset.position.x + r,
		inset.position.y + UIScaleScript.px(1.0),
		inset.size.x - r * 2.0,
		UIScaleScript.px(2.5)
	)
	canvas.draw_rect(hl, Color(1.0, 0.92, 0.78, 0.1))

	var stripe_w := UIScaleScript.px(5.0)
	var stripe := Rect2(inset.position.x + UIScaleScript.px(3.0), inset.position.y + UIScaleScript.px(4.0), stripe_w, inset.size.y - UIScaleScript.px(8.0))
	canvas.draw_rect(stripe, accent_dark.darkened(0.15), true)
	canvas.draw_rect(Rect2(stripe.position.x, stripe.position.y, stripe_w * 0.45, stripe.size.y), accent, true)
	canvas.draw_rect(Rect2(stripe.end.x - UIScaleScript.px(1.0), stripe.position.y, UIScaleScript.px(1.0), stripe.size.y), Color(accent.r, accent.g, accent.b, 0.35), true)

	canvas.draw_rect(
		Rect2(inset.position.x + r, inset.position.y, inset.size.x - r * 2.0, UIScaleScript.px(1.5)),
		Color(accent.r, accent.g, accent.b, 0.22),
		true
	)


static func _draw_content(
	canvas: CanvasItem,
	bounds: Rect2,
	stage_label: String,
	stage_name: String,
	world: int,
	wave_index: int,
	wave_count: int,
	accent: Color
) -> void:
	var font: Font = UiFont.get_font()
	var pad_l := UIScaleScript.px(14.0)
	var pad_r := UIScaleScript.px(10.0)
	var content_top := bounds.position.y + UIScaleScript.px(5.0)
	var wave_bar_h := UIScaleScript.px(5.0)
	var wave_gap := UIScaleScript.px(5.0)
	var text_row_h := bounds.size.y - UIScaleScript.px(10.0) - wave_bar_h - wave_gap
	var text_cy := content_top + text_row_h * 0.55

	_draw_world_pill(canvas, font, Vector2(bounds.position.x + pad_l, text_cy), world, accent)

	var code_x := bounds.position.x + pad_l + UIScaleScript.px(52.0)
	_draw_stage_code(canvas, font, Vector2(code_x, text_cy), stage_label)

	var name_x := code_x + UIScaleScript.px(38.0)
	var name_sz := UIScaleScript.font_heading()
	if not stage_name.is_empty():
		canvas.draw_string(
			font,
			Vector2(name_x + 1.0, text_cy + 1.0),
			stage_name,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			name_sz,
			Color(0.0, 0.0, 0.0, 0.45)
		)
		canvas.draw_string(
			font,
			Vector2(name_x, text_cy),
			stage_name,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			name_sz,
			Color(0.97, 0.94, 0.88)
		)

	var wave_sz := UIScaleScript.font_caption()
	var wave_text := "Wave %d / %d" % [wave_index + 1, wave_count]
	var wave_w := font.get_string_size(wave_text, HORIZONTAL_ALIGNMENT_LEFT, -1, wave_sz).x
	var right := bounds.position.x + bounds.size.x - pad_r

	canvas.draw_string(
		font,
		Vector2(right - wave_w, text_cy - UIScaleScript.px(1.0)),
		wave_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		wave_sz,
		Color(0.68, 0.78, 0.9)
	)

	var bar_x := bounds.position.x + pad_l
	var bar_w := bounds.size.x - pad_l - pad_r
	var bar_y := bounds.position.y + bounds.size.y - wave_bar_h - UIScaleScript.px(5.0)
	_draw_wave_segments(canvas, Rect2(bar_x, bar_y, bar_w, wave_bar_h), wave_index, wave_count, accent)


static func _draw_world_pill(canvas: CanvasItem, font: Font, center: Vector2, world: int, accent: Color) -> void:
	var label := "D%d" % world
	var sz := UIScaleScript.font_caption()
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var pw := tw + UIScaleScript.px(10.0)
	var ph := UIScaleScript.px(14.0)
	var rect := Rect2(center.x - pw * 0.5, center.y - ph * 0.5, pw, ph)
	InventorySlotDrawScript._draw_rounded_fill(canvas, rect, UIScaleScript.px(3.0), Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.35, 0.85))
	InventorySlotDrawScript._draw_rounded_stroke(canvas, rect, UIScaleScript.px(3.0), Color(accent.r, accent.g, accent.b, 0.55), 1.0)
	canvas.draw_string(
		font,
		Vector2(rect.position.x + (pw - tw) * 0.5, rect.position.y + ph - UIScaleScript.px(3.0)),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		sz,
		accent.lightened(0.35)
	)


static func _draw_stage_code(canvas: CanvasItem, font: Font, center: Vector2, code: String) -> void:
	var sz := UIScaleScript.font_ui()
	var tw := font.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var pw := tw + UIScaleScript.px(10.0)
	var ph := UIScaleScript.px(15.0)
	var rect := Rect2(center.x - pw * 0.5, center.y - ph * 0.5, pw, ph)
	InventorySlotDrawScript._draw_rounded_fill(canvas, rect, UIScaleScript.px(3.0), Color(0.1, 0.07, 0.12, 0.95))
	InventorySlotDrawScript._draw_rounded_stroke(canvas, rect, UIScaleScript.px(3.0), GOLD, UIScaleScript.px(1.0))
	canvas.draw_rect(
		Rect2(rect.position.x + UIScaleScript.px(2.0), rect.position.y + UIScaleScript.px(1.0), rect.size.x - UIScaleScript.px(4.0), UIScaleScript.px(2.0)),
		Color(GOLD.r, GOLD.g, GOLD.b, 0.15),
		true
	)
	canvas.draw_string(
		font,
		Vector2(rect.position.x + (pw - tw) * 0.5, rect.position.y + ph - UIScaleScript.px(3.0)),
		code,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		sz,
		GOLD_BRIGHT
	)


static func _draw_wave_segments(
	canvas: CanvasItem,
	rect: Rect2,
	wave_index: int,
	wave_count: int,
	accent: Color
) -> void:
	InventorySlotDrawScript._draw_rounded_fill(canvas, rect, UIScaleScript.px(2.0), Color(0.06, 0.05, 0.08, 0.9))
	InventorySlotDrawScript._draw_rounded_stroke(canvas, rect, UIScaleScript.px(2.0), GOLD_DIM, 1.0)

	if wave_count <= 0:
		return

	var inner := rect.grow(-UIScaleScript.px(2.0))
	var gap := UIScaleScript.px(2.0)
	var seg_w := (inner.size.x - gap * float(wave_count - 1)) / float(wave_count)
	var x := inner.position.x

	for i in wave_count:
		var seg := Rect2(x, inner.position.y, seg_w, inner.size.y)
		var done := i < wave_index
		var current := i == wave_index
		var fill := WAVE_IDLE
		if done:
			fill = WAVE_DONE
		elif current:
			fill = Color(accent.r * 0.85, accent.g * 0.85, accent.b * 0.85, 1.0)

		InventorySlotDrawScript._draw_rounded_fill(canvas, seg, UIScaleScript.px(1.5), fill.darkened(0.2 if not done and not current else 0.0))
		if done or current:
			var hi := Rect2(seg.position.x, seg.position.y, seg.size.x, seg.size.y * 0.45)
			canvas.draw_rect(hi, Color(1.0, 0.95, 0.85, 0.12 if done else 0.18))

		if current:
			var pulse := 0.55 + sin(Time.get_ticks_msec() * 0.007) * 0.35
			var pulse_color := Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, pulse)
			InventorySlotDrawScript._draw_rounded_stroke(canvas, seg, UIScaleScript.px(1.5), pulse_color, UIScaleScript.px(1.0))
			var glow_rect := seg.grow(UIScaleScript.px(1.0))
			canvas.draw_rect(glow_rect, Color(accent.r, accent.g, accent.b, pulse * 0.16), false, UIScaleScript.px(1.0))

		x += seg_w + gap
