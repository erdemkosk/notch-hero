extends Control

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const UiFont = preload("res://scripts/ui/ui_font.gd")
const InventorySlotDrawScript = preload("res://scripts/ui/inventory_slot_draw.gd")
const InventoryPanelChromeScript = preload("res://scripts/ui/inventory_panel_chrome.gd")
const HeroScript = preload("res://scripts/game/hero.gd")

var _hover_id := ""
var _panel_size := Vector2.ZERO

var _pan_offset := Vector2.ZERO
var _is_dragging := false
var _drag_start_pos := Vector2.ZERO
var _drag_start_offset := Vector2.ZERO
var _did_drag := false

var canvas: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_on_resized)
	if GameState != null:
		GameState.state_changed.connect(_on_state_changed)

	canvas = Control.new()
	canvas.clip_contents = true
	canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas.draw.connect(_draw_canvas)
	add_child(canvas)

	draw.connect(func(): if is_instance_valid(canvas): canvas.queue_redraw())


func _on_resized() -> void:
	var layout := _compute_layout()
	canvas.position = Vector2(layout["bag"].position.x, layout["top_y"])
	canvas.size = Vector2(layout["bag"].size.x, layout["bottom_y"] - layout["top_y"])
	canvas.queue_redraw()
	queue_redraw()


func _on_state_changed() -> void:
	canvas.queue_redraw()
	queue_redraw()


func fit_to(panel_size: Vector2) -> void:
	_panel_size = panel_size
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if GameState == null or not GameState.has_hero():
		return

	var hero: HeroScript = GameState.hero
	var layout := _compute_layout()
	var mouse_pos := get_local_mouse_position()
	var mouse_pos_canvas := canvas.get_local_mouse_position()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_is_dragging = true
				_drag_start_pos = mouse_pos
				_drag_start_offset = _pan_offset
				_did_drag = false
				mouse_default_cursor_shape = Control.CURSOR_DRAG
			else:
				_is_dragging = false
				mouse_default_cursor_shape = Control.CURSOR_ARROW
				
				# If we didn't drag much, treat it as a click
				if not _did_drag:
					for id in hero.TALENT_DEFS.keys():
						var rect := _talent_rect_canvas(layout, id)
						if rect.has_point(mouse_pos_canvas):
							if hero.unlock_talent(id):
								GameState.request_save()
								GameState.state_changed.emit()
							break
				queue_redraw()

	elif event is InputEventMouseMotion:
		if _is_dragging:
			var diff := mouse_pos - _drag_start_pos
			if diff.length() > 4.0:
				_did_drag = true
			_pan_offset = _drag_start_offset + diff
			
			# Clamp offset to prevent scrolling too far from the tree
			var max_pan_x := UIScaleScript.px(500.0)
			var max_pan_y := UIScaleScript.px(450.0)
			_pan_offset.x = clampf(_pan_offset.x, -max_pan_x, max_pan_x)
			_pan_offset.y = clampf(_pan_offset.y, -max_pan_y, max_pan_y)
			queue_redraw()
		else:
			var last_hover := _hover_id
			_hover_id = ""
			var hovered_on_buyable := false
			
			for id in hero.TALENT_DEFS.keys():
				var rect := _talent_rect_canvas(layout, id)
				if rect.has_point(mouse_pos_canvas):
					_hover_id = id
					hovered_on_buyable = hero.can_unlock_talent(id) or hero.unlocked_talents.get(id, false) == true
					break
					
			if hovered_on_buyable:
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			else:
				mouse_default_cursor_shape = Control.CURSOR_ARROW
				
			if _hover_id != last_hover:
				queue_redraw()


func _compute_layout() -> Dictionary:
	var edge := UIScaleScript.px(4.0)
	var bag_rect := Rect2(edge, edge, size.x - edge * 2.0, size.y - edge * 2.0)
	var pad := UIScaleScript.px(8.0)
	var top_y := bag_rect.position.y + UIScaleScript.px(34.0)
	var bottom_y := bag_rect.end.y - UIScaleScript.px(74.0) # Leave 74px at bottom for info panel

	var grid_w := bag_rect.size.x - pad * 2.0
	var col_w := grid_w / 3.0
	var grid_h := bottom_y - top_y
	var row_h := grid_h / 3.0

	var box_side := UIScaleScript.px(32.0)

	return {
		"bag": bag_rect,
		"top_y": top_y,
		"bottom_y": bottom_y,
		"col_w": col_w,
		"row_h": row_h,
		"pad": pad,
		"box_side": box_side,
	}


func _talent_rect_canvas(layout: Dictionary, id: String) -> Rect2:
	if GameState == null or not GameState.has_hero():
		return Rect2()
	var def: Dictionary = GameState.hero.TALENT_DEFS[id]
	var col: float = float(def.get("col", 0.0))
	var row: float = float(def.get("row", 0.0))

	# Canvas center in canvas local space
	var canvas_sz := Vector2(layout["bag"].size.x, layout["bottom_y"] - layout["top_y"])
	var center := canvas_sz * 0.5

	var step := UIScaleScript.px(72.0)
	var cx := center.x + _pan_offset.x + col * step
	var cy := center.y + _pan_offset.y + row * step
	var side: float = layout["box_side"]

	return Rect2(cx - side * 0.5, cy - side * 0.5, side, side)


func _draw() -> void:
	if GameState == null or not GameState.has_hero() or size.x < 10.0 or size.y < 10.0:
		return

	var hero: HeroScript = GameState.hero
	var layout := _compute_layout()
	var font := UiFont.get_font()

	# Draw background frame
	InventoryPanelChromeScript.draw(self, layout["bag"], InventoryPanelChromeScript.Style.BAG)

	# Draw Title
	var title_text := "Ascension Tree"
	var title_sz := UIScaleScript.font_emphasis()
	draw_string(
		font,
		Vector2(layout["bag"].position.x + UIScaleScript.px(10.0), layout["bag"].position.y + UIScaleScript.px(18.0)),
		title_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		title_sz,
		Color(0.96, 0.9, 0.72)
	)

	# Draw Points
	var pts_text := "Points: %d" % hero.talent_points
	var pts_sz := UIScaleScript.font_ui()
	var pts_w := font.get_string_size(pts_text, HORIZONTAL_ALIGNMENT_LEFT, -1, pts_sz).x
	draw_string(
		font,
		Vector2(layout["bag"].end.x - UIScaleScript.px(10.0) - pts_w, layout["bag"].position.y + UIScaleScript.px(18.0)),
		pts_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		pts_sz,
		Color(0.92, 0.74, 0.38) if hero.talent_points > 0 else Color(0.82, 0.76, 0.66)
	)

	# Draw Bottom Info Area
	_draw_info_area(layout, hero, font)


func _draw_canvas() -> void:
	if GameState == null or not GameState.has_hero():
		return
	var hero: HeroScript = GameState.hero
	var layout := _compute_layout()
	var font := UiFont.get_font()

	# 1. Draw runic magic circles and guidelines
	_draw_runic_background(layout)

	# 2. Draw grid connections
	_draw_connections(layout, hero)

	# 3. Draw talent nodes
	for id in hero.TALENT_DEFS.keys():
		_draw_talent_node(layout, hero, id, font)


func _draw_runic_background(layout: Dictionary) -> void:
	var canvas_sz := canvas.size
	var center := canvas_sz * 0.5
	var nexus_center := center + _pan_offset

	# Spacing for the grid of runic constellations
	var grid_w := UIScaleScript.px(420.0)
	var grid_h := UIScaleScript.px(360.0)

	var color_circle := Color(0.24, 0.2, 0.16, 0.32)
	var color_lines := Color(0.18, 0.15, 0.12, 0.24)

	# Draw in a 5x5 grid covering the entire possible scroll range (-2 to 2)
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var circle_center := nexus_center + Vector2(dx * grid_w, dy * grid_h)
			
			# Viewport frustum culling: skip drawing if the circle is completely off-screen
			var max_r := UIScaleScript.px(220.0)
			if circle_center.x + max_r < 0.0 or circle_center.x - max_r > canvas_sz.x:
				continue
			if circle_center.y + max_r < 0.0 or circle_center.y - max_r > canvas_sz.y:
				continue

			var is_center := dx == 0 and dy == 0
			if is_center:
				# Nexus Center Circle (Full elaborate drawing)
				var r1 := UIScaleScript.px(72.0)
				var r2 := UIScaleScript.px(144.0)
				var r3 := UIScaleScript.px(216.0)

				canvas.draw_circle(nexus_center, r1, Color.TRANSPARENT)
				canvas.draw_arc(nexus_center, r1, 0.0, TAU, 64, color_circle, UIScaleScript.px(1.0))
				canvas.draw_arc(nexus_center, r2, 0.0, TAU, 80, color_circle, UIScaleScript.px(1.2))
				canvas.draw_arc(nexus_center, r3, 0.0, TAU, 96, color_circle, UIScaleScript.px(0.8))

				var line_len := UIScaleScript.px(260.0)
				var angles := [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
				for deg in angles:
					var rad := deg_to_rad(deg)
					var end_pos := nexus_center + Vector2(cos(rad), sin(rad)) * line_len
					canvas.draw_line(nexus_center, end_pos, color_lines, UIScaleScript.px(1.0))

				for i in range(angles.size()):
					var deg: float = angles[i]
					var rad := deg_to_rad(deg)
					var rune_pos := nexus_center + Vector2(cos(rad), sin(rad)) * r2

					# Might=Red (Right), Wealth=Gold (Left), Wisdom=Blue (Top), Vitality=Green (Bottom)
					var rune_color := Color(0.32, 0.28, 0.25, 0.38)
					if deg == 0.0 or deg == 45.0 or deg == 315.0:
						rune_color = Color(0.58, 0.18, 0.18, 0.44) # Red tint (Might)
					elif deg == 180.0 or deg == 135.0 or deg == 225.0:
						rune_color = Color(0.52, 0.42, 0.15, 0.44) # Gold/Orange tint (Wealth)
					elif deg == 270.0:
						rune_color = Color(0.18, 0.28, 0.48, 0.44) # Blue tint (Wisdom)
					elif deg == 90.0:
						rune_color = Color(0.18, 0.42, 0.22, 0.44) # Green tint (Vitality)

					_draw_rune_symbol(rune_pos, UIScaleScript.px(12.0), rune_color, i)
			else:
				# Secondary/Orbital Runic Circles (Simpler, faint style)
				var r_sub := UIScaleScript.px(80.0)
				var sub_circle_color := Color(color_circle.r, color_circle.g, color_circle.b, color_circle.a * 0.45)
				canvas.draw_arc(circle_center, r_sub, 0.0, TAU, 48, sub_circle_color, UIScaleScript.px(0.8))
				canvas.draw_arc(circle_center, r_sub * 0.4, 0.0, TAU, 32, sub_circle_color, UIScaleScript.px(0.5))
				
				# Place 4 runes at cardinal directions in the sub-circles
				var sub_angles := [0.0, 90.0, 180.0, 270.0]
				for i in range(sub_angles.size()):
					var deg: float = sub_angles[i]
					var rad := deg_to_rad(deg)
					var rune_pos := circle_center + Vector2(cos(rad), sin(rad)) * r_sub
					var seed_val := int(abs(dx) * 3 + abs(dy) * 7 + i)
					_draw_rune_symbol(rune_pos, UIScaleScript.px(8.0), sub_circle_color, seed_val)


func _draw_rune_symbol(pos: Vector2, rune_size: float, color: Color, type: int) -> void:
	var half := rune_size * 0.5
	var line_w := UIScaleScript.px(1.5)
	match type % 8:
		0:
			# Ingwaz (Diamond shape)
			var pts := PackedVector2Array([
				pos + Vector2(0.0, -half),
				pos + Vector2(half, 0.0),
				pos + Vector2(0.0, half),
				pos + Vector2(-half, 0.0),
				pos + Vector2(0.0, -half)
			])
			canvas.draw_polyline(pts, color, line_w)
		1:
			# Gebo (Cross)
			canvas.draw_line(pos + Vector2(-half, -half), pos + Vector2(half, half), color, line_w)
			canvas.draw_line(pos + Vector2(half, -half), pos + Vector2(-half, half), color, line_w)
		2:
			# Algiz (Tree branch)
			canvas.draw_line(pos + Vector2(0.0, half), pos + Vector2(0.0, -half), color, line_w)
			canvas.draw_line(pos + Vector2(-half, -half), pos + Vector2(0.0, 0.0), color, line_w)
			canvas.draw_line(pos + Vector2(half, -half), pos + Vector2(0.0, 0.0), color, line_w)
		3:
			# Kenaz (Wedge)
			canvas.draw_line(pos + Vector2(half, -half), pos + Vector2(-half, 0.0), color, line_w)
			canvas.draw_line(pos + Vector2(-half, 0.0), pos + Vector2(half, half), color, line_w)
		4:
			# Teiwaz (Up Arrow)
			canvas.draw_line(pos + Vector2(0.0, half), pos + Vector2(0.0, -half), color, line_w)
			canvas.draw_line(pos + Vector2(-half, -half + half * 0.5), pos + Vector2(0.0, -half), color, line_w)
			canvas.draw_line(pos + Vector2(half, -half + half * 0.5), pos + Vector2(0.0, -half), color, line_w)
		5:
			# Laguz (Hook)
			canvas.draw_line(pos + Vector2(0.0, half), pos + Vector2(0.0, -half), color, line_w)
			canvas.draw_line(pos + Vector2(0.0, -half), pos + Vector2(half, -half + half * 0.5), color, line_w)
		6:
			# Dagaz (Hourglass)
			var pts := PackedVector2Array([
				pos + Vector2(-half, -half),
				pos + Vector2(half, -half),
				pos + Vector2(-half, half),
				pos + Vector2(half, half),
				pos + Vector2(-half, -half)
			])
			canvas.draw_polyline(pts, color, line_w)
		7:
			# Sowilo (Lightning)
			var pts := PackedVector2Array([
				pos + Vector2(half, -half),
				pos + Vector2(-half, -half + half * 0.5),
				pos + Vector2(half, half - half * 0.5),
				pos + Vector2(-half, half)
			])
			canvas.draw_polyline(pts, color, line_w)


func _draw_connections(layout: Dictionary, hero: HeroScript) -> void:
	for id in hero.TALENT_DEFS.keys():
		var def: Dictionary = hero.TALENT_DEFS[id]
		var reqs: Variant = def.get("requires", "")
		
		var req_list: Array = []
		if reqs is String:
			if not reqs.is_empty():
				req_list.append(reqs)
		elif reqs is Array:
			req_list = reqs

		for req in req_list:
			var r_child := _talent_rect_canvas(layout, id)
			var r_parent := _talent_rect_canvas(layout, req)
			var p_start := r_parent.get_center()
			var p_end := r_child.get_center()

			var is_unlocked: bool = hero.unlocked_talents.get(id, false) == true
			var parent_unlocked: bool = hero.unlocked_talents.get(req, false) == true

			var line_color := Color(0.18, 0.14, 0.12)
			var line_width := UIScaleScript.px(2.0)

			if is_unlocked:
				line_color = Color(0.95, 0.78, 0.35)
				line_width = UIScaleScript.px(3.0)
			elif parent_unlocked:
				line_color = Color(0.65, 0.65, 0.7)
				line_width = UIScaleScript.px(2.0)

			canvas.draw_line(p_start, p_end, line_color, line_width)


func _draw_talent_node(layout: Dictionary, hero: HeroScript, id: String, font: Font) -> void:
	var def: Dictionary = hero.TALENT_DEFS[id]
	var rect := _talent_rect_canvas(layout, id)
	var r := InventorySlotDrawScript.corner_radius(rect)

	var is_unlocked: bool = hero.unlocked_talents.get(id, false) == true
	var is_buyable: bool = hero.can_unlock_talent(id)
	var is_hovered := id == _hover_id

	var bg_color := Color(0.12, 0.12, 0.14)
	var border_color := Color(0.35, 0.3, 0.26)
	var text_color := Color(0.55, 0.48, 0.44)
	var border_w := 1.0

	if id == "nexus":
		if is_unlocked:
			bg_color = Color(0.25, 0.25, 0.38)
			border_color = Color(0.95, 0.78, 0.35)
			text_color = Color(1.0, 0.96, 0.82)
			border_w = 2.0
	elif is_unlocked:
		# Custom color depending on the branch
		if id.begins_with("might"):
			bg_color = Color(0.48, 0.18, 0.18)
		elif id.begins_with("wealth"):
			bg_color = Color(0.48, 0.38, 0.15)
		elif id.begins_with("wisdom"):
			bg_color = Color(0.18, 0.28, 0.48)
		else: # vitality
			bg_color = Color(0.18, 0.42, 0.22)
			
		border_color = Color(0.95, 0.78, 0.35)
		text_color = Color(1.0, 0.96, 0.82)
		border_w = 1.5
	elif is_buyable:
		bg_color = Color(0.24, 0.22, 0.20)
		border_color = Color(0.85, 0.85, 0.9)
		text_color = Color(0.94, 0.88, 0.78)
	
	if is_hovered:
		bg_color = bg_color.lightened(0.08)
		if not is_unlocked and is_buyable:
			border_color = Color(1.0, 0.95, 0.45)

	# Draw background
	InventorySlotDrawScript._draw_rounded_fill(canvas, rect, r, bg_color)
	InventorySlotDrawScript._draw_rounded_stroke(canvas, rect, r, border_color, border_w)

	# Parse initial and tier text
	var initial := ""
	var tier := ""
	if id == "nexus":
		initial = "N"
		tier = "X"
	else:
		var parts := id.split("_")
		initial = parts[0][0].to_upper()
		if parts.size() > 1:
			var last := parts[parts.size() - 1]
			if last.is_valid_int():
				tier = last
			else:
				tier = last[0].to_upper()
		else:
			tier = ""

	var node_text := "%s%s" % [initial, tier]
	var font_sz := UIScaleScript.font_ui()
	var tw := font.get_string_size(node_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz).x

	canvas.draw_string(
		font,
		Vector2(rect.position.x + (rect.size.x - tw) * 0.5, rect.position.y + rect.size.y * 0.65),
		node_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_sz,
		text_color
	)


func _draw_info_area(layout: Dictionary, hero: HeroScript, font: Font) -> void:
	var info_rect := Rect2(
		layout["bag"].position.x + UIScaleScript.px(6.0),
		layout["bottom_y"] + UIScaleScript.px(4.0),
		layout["bag"].size.x - UIScaleScript.px(12.0),
		UIScaleScript.px(64.0)
	)
	var r := UIScaleScript.px(4.0)

	InventorySlotDrawScript._draw_rounded_fill(self, info_rect, r, Color(0.1, 0.07, 0.05, 0.95))
	InventorySlotDrawScript._draw_rounded_stroke(self, info_rect, r, Color(0.38, 0.28, 0.18), 1.0)

	var caption_sz := UIScaleScript.font_caption()
	var detail_sz := UIScaleScript.font_ui()

	if _hover_id.is_empty():
		var tip := "Click and Drag to pan/explore the tree.\nHover over a Perk to inspect. Click to unlock using Points & Gold."
		var lines := tip.split("\n")
		var y := info_rect.position.y + UIScaleScript.px(24.0)
		for line in lines:
			var tw := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, detail_sz).x
			draw_string(
				font,
				Vector2(info_rect.position.x + (info_rect.size.x - tw) * 0.5, y),
				line,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				detail_sz,
				Color(0.55, 0.48, 0.42)
			)
			y += font.get_height(detail_sz) - UIScaleScript.px(2.0)
		return

	var def: Dictionary = hero.TALENT_DEFS[_hover_id]
	var title: String = def["name"]
	var desc: String = def["desc"]
	var cost: int = def.get("cost", 0)
	var cost_gold: int = def.get("cost_gold", 0)

	var is_unlocked: bool = hero.unlocked_talents.get(_hover_id, false) == true
	var is_buyable: bool = hero.can_unlock_talent(_hover_id)

	# Draw Talent Name
	draw_string(
		font,
		Vector2(info_rect.position.x + UIScaleScript.px(8.0), info_rect.position.y + UIScaleScript.px(18.0)),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		detail_sz,
		Color(0.96, 0.9, 0.72)
	)

	# Compute status details
	var status_text := "LOCKED"
	var status_color := Color(0.78, 0.22, 0.18)
	
	if is_unlocked:
		status_text = "UNLOCKED"
		status_color = Color(0.28, 0.72, 0.35)
	elif is_buyable:
		if cost_gold > 0:
			status_text = "BUYABLE (Cost: %d Pts & %d Gold)" % [cost, cost_gold]
		else:
			status_text = "BUYABLE (Cost: %d Pts)" % cost
		status_color = Color(0.92, 0.74, 0.38)
	else:
		var has_points := hero.talent_points >= cost
		var has_gold := hero.gold >= cost_gold
		
		var reqs_ok := true
		var req_msg := ""
		
		var reqs: Variant = def.get("requires", "")
		if reqs is String:
			if not reqs.is_empty() and hero.unlocked_talents.get(reqs, false) != true:
				reqs_ok = false
				req_msg = "Requires: " + hero.TALENT_DEFS[reqs]["name"]
		elif reqs is Array:
			var any_ok := false
			for req_id in reqs:
				if hero.unlocked_talents.get(req_id, false) == true:
					any_ok = true
					break
			if not any_ok:
				reqs_ok = false
				var names: Array[String] = []
				for req_id in reqs:
					names.append(hero.TALENT_DEFS[req_id]["name"])
				req_msg = "Requires: " + ", ".join(names)
				
		if not reqs_ok:
			status_text = req_msg
		elif not has_points and not has_gold:
			status_text = "Need %d Pts & %d Gold" % [cost, cost_gold]
		elif not has_points:
			status_text = "Need %d Perk Points" % cost
		elif not has_gold:
			status_text = "Need %d Gold" % cost_gold

	var stat_w := font.get_string_size(status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_sz).x
	draw_string(
		font,
		Vector2(info_rect.end.x - UIScaleScript.px(8.0) - stat_w, info_rect.position.y + UIScaleScript.px(18.0)),
		status_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		caption_sz,
		status_color
	)

	# Draw Description
	draw_string(
		font,
		Vector2(info_rect.position.x + UIScaleScript.px(8.0), info_rect.position.y + UIScaleScript.px(38.0)),
		desc,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		caption_sz,
		Color(0.94, 0.88, 0.78)
	)
