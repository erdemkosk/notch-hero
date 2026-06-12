extends RefCounted
class_name ItemRarityFrame

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const ItemDataScript = preload("res://scripts/game/item_data.gd")
const InventorySlotDrawScript = preload("res://scripts/ui/inventory_slot_draw.gd")


static func draw_on_slot(
	canvas: CanvasItem,
	rect: Rect2,
	rarity: String,
	pulse_phase: float = 0.0
) -> void:
	if rarity.is_empty():
		return

	var cfg := ItemDataScript.rarity_vfx(rarity)
	var base: Color = ItemDataScript.RARITY_COLORS.get(rarity, ItemDataScript.RARITY_COLORS["common"])
	var slot_side := rect.size.x
	var corner_r := clampf(slot_side * 0.12, 3.0, 5.0)
	var rank := int(cfg.get("rank", 0))
	var wave := 0.0
	if rank >= 1:
		var speed := float(cfg.get("pulse_speed", 4.0))
		wave = (sin(pulse_phase * speed) + 1.0) * 0.5

	if rank >= 1:
		var glow_expand := UIScaleScript.px(float(cfg.get("glow_min", 0.5))) \
			+ wave * UIScaleScript.px(float(cfg.get("glow_max", 1.5)))
		var glow_alpha := float(cfg.get("glow_alpha_min", 0.1)) \
			+ wave * float(cfg.get("glow_alpha_max", 0.2))
		var glow_rect := rect.grow(glow_expand)
		InventorySlotDrawScript._draw_rounded_stroke(
			canvas,
			glow_rect,
			corner_r + 1.5,
			Color(base.r, base.g, base.b, glow_alpha),
			float(cfg.get("glow_stroke", 1.5)) + wave * float(cfg.get("glow_stroke_pulse", 0.0))
		)
		if rank >= 2:
			base = base.lightened(float(cfg.get("lighten_min", 0.04)) + wave * float(cfg.get("lighten_max", 0.12)))

	var border_alpha := float(cfg.get("border_alpha", 0.55))
	var border_color := Color(base.r, base.g, base.b, border_alpha)
	var border_w := float(cfg.get("border_width", 1.5))
	if rank >= 2:
		border_w += wave * float(cfg.get("border_pulse", 0.25))

	InventorySlotDrawScript._draw_rounded_stroke(canvas, rect, corner_r, border_color, border_w)

	if rank >= 1:
		var stripe_w := UIScaleScript.px(3.0)
		var stripe := Rect2(rect.position, Vector2(stripe_w, rect.size.y))
		var stripe_a := border_alpha * (0.45 + wave * 0.25)
		canvas.draw_rect(stripe, Color(base.r, base.g, base.b, stripe_a))

		var corner := UIScaleScript.px(5.0)
		var tri := PackedVector2Array([
			Vector2(rect.end.x - corner, rect.position.y),
			Vector2(rect.end.x, rect.position.y),
			Vector2(rect.end.x, rect.position.y + corner),
		])
		canvas.draw_colored_polygon(tri, Color(base.r, base.g, base.b, border_alpha * (0.55 + wave * 0.2)))

	if rank >= 3:
		var spark_wave := (sin(pulse_phase * float(cfg.get("pulse_speed", 5.0)) * 1.7 + 1.2) + 1.0) * 0.5
		var spark_size := UIScaleScript.px(2.0 + spark_wave * 2.0)
		var spark_pos := Vector2(rect.end.x - UIScaleScript.px(6.0), rect.position.y + UIScaleScript.px(5.0))
		canvas.draw_rect(
			Rect2(spark_pos, Vector2(spark_size, spark_size)),
			Color(1.0, 1.0, 1.0, 0.25 + spark_wave * 0.45)
		)


static func draw_icon_shimmer(
	canvas: CanvasItem,
	inner: Rect2,
	rarity: String,
	pulse_phase: float = 0.0
) -> void:
	var cfg := ItemDataScript.rarity_vfx(rarity)
	var rank := int(cfg.get("rank", 0))
	if rank < 2:
		return

	var base: Color = ItemDataScript.RARITY_COLORS.get(rarity, ItemDataScript.RARITY_COLORS["common"])
	var speed := float(cfg.get("pulse_speed", 4.0))
	var wave := (sin(pulse_phase * speed * 1.3) + 1.0) * 0.5
	var alpha := float(cfg.get("shimmer_alpha_min", 0.06)) + wave * float(cfg.get("shimmer_alpha_max", 0.14))
	canvas.draw_rect(inner, Color(base.r, base.g, base.b, alpha), true)

	if rank >= 3:
		var sweep_x := lerpf(inner.position.x, inner.end.x, wave)
		var sweep_w := inner.size.x * 0.22
		canvas.draw_rect(
			Rect2(sweep_x - sweep_w * 0.5, inner.position.y, sweep_w, inner.size.y),
			Color(1.0, 1.0, 1.0, 0.04 + wave * 0.1)
		)
