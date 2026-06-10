extends RefCounted
class_name CombatOverlayDraw

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const UiFont = preload("res://scripts/ui/ui_font.gd")
const InventorySlotDrawScript = preload("res://scripts/ui/inventory_slot_draw.gd")

const GOLD := Color(0.92, 0.74, 0.38)
const GOLD_BRIGHT := Color(1.0, 0.88, 0.52)
const GOLD_DIM := Color(0.55, 0.4, 0.22)
const PANEL_DARK := Color(0.07, 0.05, 0.1, 0.96)
const PANEL_MID := Color(0.12, 0.09, 0.14, 0.92)
const TEXT_SOFT := Color(0.72, 0.68, 0.62)
const XP_FILL := Color(0.42, 0.72, 0.95)
const XP_FILL_HI := Color(0.62, 0.88, 1.0)
const BOSS_WARN := Color(0.95, 0.42, 0.32)
const BOSS_GOLD := Color(1.0, 0.78, 0.28)


static func draw_top_strip(canvas: CanvasItem, viewport: Vector2, level: int, gold: int, xp: int, xp_to_next: int) -> void:
	var margin := UIScaleScript.px(6.0)
	var h := UIScaleScript.px(24.0)
	var bounds := Rect2(margin, margin, viewport.x - margin * 2.0, h)
	if bounds.size.x < 80.0:
		return

	var r := UIScaleScript.px(5.0)
	InventorySlotDrawScript._draw_rounded_fill(canvas, bounds, r, PANEL_DARK)
	InventorySlotDrawScript._draw_rounded_fill(canvas, bounds.grow(-UIScaleScript.px(2.0)), r - 1.0, PANEL_MID)
	InventorySlotDrawScript._draw_rounded_stroke(canvas, bounds, r, GOLD_DIM, UIScaleScript.px(1.0))

	canvas.draw_rect(
		Rect2(bounds.position.x + r, bounds.position.y + UIScaleScript.px(1.0), bounds.size.x - r * 2.0, UIScaleScript.px(2.0)),
		Color(1.0, 0.92, 0.78, 0.09),
		true
	)

	var font: Font = UiFont.get_font()
	var pad := UIScaleScript.px(8.0)
	var lv_fs := UIScaleScript.font(8)
	var gold_fs := UIScaleScript.font(8)
	var xp_label_fs := UIScaleScript.font(6)

	var lv_w := UIScaleScript.px(34.0)
	var lv_rect := Rect2(bounds.position.x + pad, bounds.position.y + UIScaleScript.px(4.0), lv_w, bounds.size.y - UIScaleScript.px(8.0))
	_draw_lv_badge(canvas, lv_rect, level, font, lv_fs)

	var gold_text := str(gold)
	var gold_w := font.get_string_size(gold_text, HORIZONTAL_ALIGNMENT_LEFT, -1, gold_fs).x + UIScaleScript.px(18.0)
	var gold_rect := Rect2(bounds.end.x - pad - gold_w, bounds.position.y + UIScaleScript.px(4.0), gold_w, bounds.size.y - UIScaleScript.px(8.0))
	_draw_gold_chip(canvas, gold_rect, gold_text, font, gold_fs)

	var xp_left := lv_rect.end.x + UIScaleScript.px(6.0)
	var xp_right := gold_rect.position.x - UIScaleScript.px(6.0)
	var xp_w := maxf(UIScaleScript.px(40.0), xp_right - xp_left)
	var xp_bar_h := UIScaleScript.px(5.0)
	var xp_y := bounds.position.y + (bounds.size.y - xp_bar_h) * 0.5 + UIScaleScript.px(2.0)
	var ratio := clampf(float(xp) / maxf(float(xp_to_next), 1.0), 0.0, 1.0)

	canvas.draw_string(
		font,
		Vector2(xp_left, bounds.position.y + UIScaleScript.px(7.0)),
		"XP",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		xp_label_fs,
		TEXT_SOFT
	)
	var bar_x := xp_left
	var bar_rect := Rect2(bar_x, xp_y, xp_w, xp_bar_h)
	var bar_r := xp_bar_h * 0.5
	InventorySlotDrawScript._draw_rounded_fill(canvas, bar_rect, bar_r, Color(0.08, 0.06, 0.12, 0.95))
	if ratio > 0.01:
		var fill_rect := Rect2(bar_x, xp_y, xp_w * ratio, xp_bar_h)
		InventorySlotDrawScript._draw_rounded_fill(canvas, fill_rect, bar_r, XP_FILL)
		canvas.draw_rect(
			Rect2(bar_x + bar_r, xp_y + UIScaleScript.px(0.5), maxf(0.0, xp_w * ratio - bar_r * 2.0), UIScaleScript.px(1.0)),
			Color(XP_FILL_HI.r, XP_FILL_HI.g, XP_FILL_HI.b, 0.35),
			true
		)
	InventorySlotDrawScript._draw_rounded_stroke(canvas, bar_rect, bar_r, GOLD_DIM.darkened(0.15), UIScaleScript.px(0.75))


static func _draw_lv_badge(canvas: CanvasItem, rect: Rect2, level: int, font: Font, fs: int) -> void:
	var r := minf(rect.size.y * 0.35, UIScaleScript.px(4.0))
	InventorySlotDrawScript._draw_rounded_fill(canvas, rect, r, Color(0.16, 0.11, 0.2, 0.95))
	InventorySlotDrawScript._draw_rounded_stroke(canvas, rect, r, GOLD_DIM, UIScaleScript.px(0.75))
	var label := "Lv %d" % level
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	canvas.draw_string(
		font,
		Vector2(rect.position.x + (rect.size.x - tw) * 0.5, rect.position.y + rect.size.y * 0.72),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fs,
		GOLD_BRIGHT
	)


static func _draw_gold_chip(canvas: CanvasItem, rect: Rect2, text: String, font: Font, fs: int) -> void:
	var r := minf(rect.size.y * 0.35, UIScaleScript.px(4.0))
	InventorySlotDrawScript._draw_rounded_fill(canvas, rect, r, Color(0.14, 0.1, 0.06, 0.95))
	InventorySlotDrawScript._draw_rounded_stroke(canvas, rect, r, GOLD_DIM, UIScaleScript.px(0.75))
	var coin_r := UIScaleScript.px(4.0)
	var coin_c := Vector2(rect.position.x + UIScaleScript.px(7.0), rect.position.y + rect.size.y * 0.5)
	canvas.draw_circle(coin_c, coin_r, GOLD)
	canvas.draw_circle(coin_c, coin_r * 0.55, GOLD_BRIGHT)
	var tx := rect.position.x + UIScaleScript.px(14.0)
	canvas.draw_string(font, Vector2(tx, rect.position.y + rect.size.y * 0.72), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GOLD_BRIGHT)


static func draw_banner_card(
	canvas: CanvasItem,
	viewport: Vector2,
	alpha: float,
	enter: float,
	title: String,
	subtitle: String,
	biome_label: String,
	biome: Dictionary
) -> void:
	if alpha <= 0.01:
		return

	var a := clampf(alpha, 0.0, 1.0)
	var e := clampf(enter, 0.0, 1.0)
	var eased := _ease_out_back(e)
	var slide := UIScaleScript.px(22.0) * (1.0 - eased) * a
	var scale := lerpf(0.9, 1.0, eased)

	canvas.draw_rect(Rect2(Vector2.ZERO, viewport), Color(0.05, 0.04, 0.08, 0.55 * a), true)

	var accent: Color = biome.get("accent", Color(0.55, 0.72, 0.42)) as Color
	var accent_dark: Color = biome.get("accent_dark", accent.darkened(0.35)) as Color

	var card_w := minf(viewport.x * 0.78, UIScaleScript.px(320.0)) * scale
	var card_h := UIScaleScript.px(88.0) * scale
	var cx := viewport.x * 0.5
	var cy := viewport.y * 0.38 + slide
	var card := Rect2(cx - card_w * 0.5, cy - card_h * 0.5, card_w, card_h)

	_draw_card_frame(canvas, card, accent, accent_dark, a)

	var font: Font = UiFont.get_font()
	var title_fs := int(round(UIScaleScript.font(26) * scale))
	var sub_fs := int(round(UIScaleScript.font(13) * scale))
	var biome_fs := int(round(UIScaleScript.font(10) * scale))
	var title_col := Color(1.0, 0.92, 0.65, a)
	var sub_col := Color(0.92, 0.88, 0.8, a * 0.95)
	var biome_col := Color(accent.r, accent.g, accent.b, a * 0.92)

	var pad_l := UIScaleScript.px(16.0)
	canvas.draw_string(
		font,
		Vector2(card.position.x + pad_l, card.position.y + card.size.y * 0.38),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		int(card.size.x - pad_l * 2.0),
		title_fs,
		title_col
	)
	canvas.draw_string(
		font,
		Vector2(card.position.x + pad_l, card.position.y + card.size.y * 0.58),
		subtitle,
		HORIZONTAL_ALIGNMENT_LEFT,
		int(card.size.x - pad_l * 2.0),
		sub_fs,
		sub_col
	)
	if not biome_label.is_empty():
		canvas.draw_string(
			font,
			Vector2(card.position.x + pad_l, card.position.y + card.size.y * 0.78),
			biome_label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			biome_fs,
			biome_col
		)


static func draw_boss_card(
	canvas: CanvasItem,
	viewport: Vector2,
	alpha: float,
	enter: float,
	boss_name: String,
	shake_x: float
) -> void:
	if alpha <= 0.01:
		return

	var a := clampf(alpha, 0.0, 1.0)
	var e := clampf(enter, 0.0, 1.0)
	var eased := _ease_out_back(e)
	var slide := UIScaleScript.px(26.0) * (1.0 - eased) * a
	var scale := lerpf(0.88, 1.0, eased)

	canvas.draw_rect(Rect2(Vector2.ZERO, viewport), Color(0.03, 0.0, 0.07, 0.62 * a), true)
	canvas.draw_rect(Rect2(Vector2.ZERO, viewport), Color(0.55, 0.12, 0.08, 0.14 * a), true)

	var accent := BOSS_WARN
	var accent_dark := Color(0.42, 0.08, 0.06)

	var card_w := minf(viewport.x * 0.82, UIScaleScript.px(340.0)) * scale
	var card_h := UIScaleScript.px(96.0) * scale
	var cx := viewport.x * 0.5 + shake_x
	var cy := viewport.y * 0.36 + slide
	var card := Rect2(cx - card_w * 0.5, cy - card_h * 0.5, card_w, card_h)

	_draw_card_frame(canvas, card, accent, accent_dark, a)

	var font: Font = UiFont.get_font()
	var tag_fs := int(round(UIScaleScript.font(11) * scale))
	var name_fs := int(round(UIScaleScript.font(22) * scale))
	var sub_fs := int(round(UIScaleScript.font(10) * scale))

	var tag_w := UIScaleScript.px(52.0) * scale
	var tag_h := UIScaleScript.px(16.0) * scale
	var tag_rect := Rect2(card.position.x + UIScaleScript.px(14.0), card.position.y + UIScaleScript.px(10.0), tag_w, tag_h)
	var tag_r := tag_h * 0.35
	InventorySlotDrawScript._draw_rounded_fill(canvas, tag_rect, tag_r, Color(0.35, 0.08, 0.06, 0.95 * a))
	InventorySlotDrawScript._draw_rounded_stroke(canvas, tag_rect, tag_r, Color(BOSS_WARN.r, BOSS_WARN.g, BOSS_WARN.b, 0.7 * a), UIScaleScript.px(0.75))
	canvas.draw_string(
		font,
		Vector2(tag_rect.position.x + UIScaleScript.px(8.0), tag_rect.position.y + tag_h * 0.78),
		"BOSS",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		tag_fs,
		Color(1.0, 0.94, 0.82, a)
	)

	canvas.draw_string(
		font,
		Vector2(card.position.x + UIScaleScript.px(14.0), card.position.y + card.size.y * 0.58),
		boss_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		int(card.size.x - UIScaleScript.px(28.0)),
		name_fs,
		Color(BOSS_GOLD.r, BOSS_GOLD.g, BOSS_GOLD.b, a)
	)
	canvas.draw_string(
		font,
		Vector2(card.position.x + UIScaleScript.px(14.0), card.position.y + card.size.y * 0.8),
		"Final wave",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		sub_fs,
		Color(0.92, 0.88, 0.8, a * 0.9)
	)


static func _draw_card_frame(
	canvas: CanvasItem,
	card: Rect2,
	accent: Color,
	accent_dark: Color,
	alpha: float
) -> void:
	var r := UIScaleScript.px(8.0)
	var inset := card.grow(-UIScaleScript.px(1.0))
	InventorySlotDrawScript._draw_rounded_fill(canvas, inset, r, Color(PANEL_DARK.r, PANEL_DARK.g, PANEL_DARK.b, PANEL_DARK.a * alpha))
	InventorySlotDrawScript._draw_rounded_fill(
		canvas,
		inset.grow(-UIScaleScript.px(2.0)),
		r - 1.0,
		Color(PANEL_MID.r, PANEL_MID.g, PANEL_MID.b, PANEL_MID.a * alpha)
	)
	InventorySlotDrawScript._draw_rounded_stroke(canvas, inset, r, Color(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b, alpha), UIScaleScript.px(1.0))

	var stripe_w := UIScaleScript.px(5.0)
	var stripe := Rect2(
		inset.position.x + UIScaleScript.px(3.0),
		inset.position.y + UIScaleScript.px(6.0),
		stripe_w,
		inset.size.y - UIScaleScript.px(12.0)
	)
	canvas.draw_rect(stripe, Color(accent_dark.r, accent_dark.g, accent_dark.b, alpha), true)
	canvas.draw_rect(
		Rect2(stripe.position.x, stripe.position.y, stripe_w * 0.45, stripe.size.y),
		Color(accent.r, accent.g, accent.b, alpha),
		true
	)

	canvas.draw_rect(
		Rect2(inset.position.x + r, inset.position.y, inset.size.x - r * 2.0, UIScaleScript.px(1.5)),
		Color(accent.r, accent.g, accent.b, 0.28 * alpha),
		true
	)
	canvas.draw_rect(
		Rect2(inset.position.x + r, inset.position.y + UIScaleScript.px(1.0), inset.size.x - r * 2.0, UIScaleScript.px(2.0)),
		Color(1.0, 0.92, 0.78, 0.1 * alpha),
		true
	)


static func _ease_out_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var u := clampf(t, 0.0, 1.0)
	return 1.0 + c3 * pow(u - 1.0, 3.0) + c1 * pow(u - 1.0, 2.0)
