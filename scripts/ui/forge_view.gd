extends Control

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const UiFont = preload("res://scripts/ui/ui_font.gd")
const InventorySlotDrawScript = preload("res://scripts/ui/inventory_slot_draw.gd")
const InventoryPanelChromeScript = preload("res://scripts/ui/inventory_panel_chrome.gd")
const InventorySlotMetricsScript = preload("res://scripts/ui/inventory_slot_metrics.gd")
const InventoryIconDrawScript = preload("res://scripts/ui/inventory_icon_draw.gd")
const ItemRarityFrameScript = preload("res://scripts/ui/item_rarity_frame.gd")
const EquipmentSlotIconsScript = preload("res://scripts/ui/equipment_slot_icons.gd")
const HeroScript = preload("res://scripts/game/hero.gd")
const ItemDataScript = preload("res://scripts/game/item_data.gd")

var _altar_panel: Control
var _upgrade_button: Button
var _anvil_texture: Texture2D = null

# Clickable slots (hitbox buttons)
var _equip_slot_btn: Button
var _scroll_slot_btn: Button

# Popup overlay & containers
var _popup_overlay: Button
var _equip_popup: PanelContainer
var _equip_popup_list: ItemList
var _scroll_popup: PanelContainer
var _scroll_popup_list: ItemList

# Data arrays
var _equip_items_data: Array[Dictionary] = []
var _scroll_items_data: Array[Dictionary] = []

# Selected items
var _selected_item_source := "" # "inventory" or "equipment"
var _selected_item_key: Variant = null # index or slot name
var _selected_scroll_id := "" # "scrolls/upgrade-standard" or "scrolls/upgrade-blessed"

# Forge State
var _forge_state := "idle" # "idle", "flashing", "success", "failure"
var _anim_timer := 0.0
var _last_strike_count := 0

# Visual animation variables
var _sparks: Array[Dictionary] = []
var _shake_intensity := 0.0
var _shake_offset := Vector2.ZERO
var _pulse_phase := 0.0


func _ready() -> void:
	# Clear pre-existing scene controls (if any)
	for child in get_children():
		child.queue_free()

	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_on_resized)
	if GameState != null:
		GameState.state_changed.connect(_on_state_changed)

	# 1. Initialize main Altar Panel drawing canvas
	_altar_panel = Control.new()
	_altar_panel.draw.connect(_draw_altar)
	add_child(_altar_panel)

	# 2. Interactive slot buttons (hitboxes)
	_equip_slot_btn = Button.new()
	_equip_slot_btn.flat = true
	_equip_slot_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_equip_slot_btn.pressed.connect(_on_equip_slot_pressed)
	_altar_panel.add_child(_equip_slot_btn)

	_scroll_slot_btn = Button.new()
	_scroll_slot_btn.flat = true
	_scroll_slot_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_scroll_slot_btn.pressed.connect(_on_scroll_slot_pressed)
	_altar_panel.add_child(_scroll_slot_btn)

	# 3. Upgrade Button
	_upgrade_button = Button.new()
	_upgrade_button.text = "UPGRADE"
	_upgrade_button.pressed.connect(_start_upgrade)
	_upgrade_button.add_theme_font_override("font", UiFont.get_font())
	_upgrade_button.add_theme_font_size_override("font_size", UIScaleScript.font_ui())
	_upgrade_button.disabled = true
	_altar_panel.add_child(_upgrade_button)

	# 4. Popup dismiss overlay (giant invisible full-screen button)
	_popup_overlay = Button.new()
	var overlay_style := StyleBoxFlat.new()
	overlay_style.bg_color = Color(0.0, 0.0, 0.0, 0.22)
	_popup_overlay.add_theme_stylebox_override("normal", overlay_style)
	_popup_overlay.add_theme_stylebox_override("hover", overlay_style)
	_popup_overlay.add_theme_stylebox_override("pressed", overlay_style)
	_popup_overlay.visible = false
	_popup_overlay.pressed.connect(_close_popups)
	add_child(_popup_overlay)

	# 5. Equipment Popup Container
	_equip_popup = PanelContainer.new()
	_equip_popup.visible = false
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color(0.06, 0.05, 0.08, 0.98)
	popup_style.border_width_left = 1
	popup_style.border_width_top = 1
	popup_style.border_width_right = 1
	popup_style.border_width_bottom = 1
	popup_style.border_color = Color(0.85, 0.72, 0.45, 1) # Gold
	popup_style.corner_radius_top_left = 6
	popup_style.corner_radius_top_right = 6
	popup_style.corner_radius_bottom_right = 6
	popup_style.corner_radius_bottom_left = 6
	_equip_popup.add_theme_stylebox_override("panel", popup_style)
	add_child(_equip_popup)

	_equip_popup_list = ItemList.new()
	_equip_popup_list.allow_reselect = true
	_equip_popup_list.item_selected.connect(_on_equip_popup_selected)
	_equip_popup_list.add_theme_font_override("font", UiFont.get_font())
	_equip_popup_list.add_theme_font_size_override("font_size", UIScaleScript.font_ui())
	
	var empty_style := StyleBoxEmpty.new()
	_equip_popup_list.add_theme_stylebox_override("panel", empty_style)
	_equip_popup_list.add_theme_stylebox_override("focus", empty_style)
	_equip_popup.add_child(_equip_popup_list)

	# 6. Scroll Popup Container
	_scroll_popup = PanelContainer.new()
	_scroll_popup.visible = false
	_scroll_popup.add_theme_stylebox_override("panel", popup_style)
	add_child(_scroll_popup)

	_scroll_popup_list = ItemList.new()
	_scroll_popup_list.allow_reselect = true
	_scroll_popup_list.item_selected.connect(_on_scroll_popup_selected)
	_scroll_popup_list.add_theme_font_override("font", UiFont.get_font())
	_scroll_popup_list.add_theme_font_size_override("font_size", UIScaleScript.font_ui())
	_scroll_popup_list.add_theme_stylebox_override("panel", empty_style)
	_scroll_popup_list.add_theme_stylebox_override("focus", empty_style)
	_scroll_popup.add_child(_scroll_popup_list)

	draw.connect(func(): if is_instance_valid(_altar_panel): _altar_panel.queue_redraw())

	# Load anvil texture dynamically with fallback for unimported headless files
	var path := "res://assets/ui/anvil.png"
	if ResourceLoader.exists(path):
		_anvil_texture = load(path) as Texture2D
	if _anvil_texture == null:
		var fs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(fs_path):
			var image := Image.new()
			var err := image.load(fs_path)
			if err == OK and image.get_width() > 0:
				_anvil_texture = ImageTexture.create_from_image(image)
			elif err != OK:
				push_warning("Anvil texture load failed (%s): %s" % [err, path])

	_refresh_lists()
	_on_resized()


func _on_resized() -> void:
	if not is_inside_tree() or size.x < 10.0 or size.y < 10.0:
		return

	var pad := UIScaleScript.px(4.0)
	
	_altar_panel.position = Vector2(pad, pad)
	_altar_panel.size = Vector2(size.x - pad * 2.0, size.y - pad * 2.0)

	var cx := _altar_panel.size.x * 0.5
	
	# Compute dynamic slot side matching the actual inventory view shared side
	var host_h := size.y
	if host_h < 1.0:
		host_h = InventorySlotMetricsScript.content_host_height()
	var panel_w := size.x
	if panel_w < 1.0:
		panel_w = InventorySlotMetricsScript.design_panel_width()

	var layout := InventorySlotMetricsScript.layout_for_panel(host_h, panel_w)
	var bag_w: float = layout["bag_w"]
	var equip_w: float = layout["equip_w"]
	var slot_size := InventorySlotMetricsScript.shared_slot_side(
		Vector2(bag_w, host_h),
		0.0,
		Vector2(equip_w, host_h)
	)

	# Position Left (Equipment) and Right (Scroll) inputs in V-shape nodes
	var dist_x := UIScaleScript.px(100.0)
	var equip_x := cx - dist_x
	var scroll_x := cx + dist_x - slot_size
	var input_y := UIScaleScript.px(22.0)

	_equip_slot_btn.position = Vector2(equip_x, input_y)
	_equip_slot_btn.size = Vector2(slot_size, slot_size)

	_scroll_slot_btn.position = Vector2(scroll_x, input_y)
	_scroll_slot_btn.size = Vector2(slot_size, slot_size)

	# Overlay covers full area
	_popup_overlay.position = Vector2.ZERO
	_popup_overlay.size = size

	# Upgrade Button at the bottom center
	var btn_w := UIScaleScript.px(120.0)
	var btn_h := UIScaleScript.px(24.0)
	_upgrade_button.position = Vector2((_altar_panel.size.x - btn_w) * 0.5, _altar_panel.size.y - btn_h - UIScaleScript.px(6.0))
	_upgrade_button.size = Vector2(btn_w, btn_h)

	# Dynamic dropdown popup lists bounds
	var pop_w := UIScaleScript.px(230.0)
	var pop_h := UIScaleScript.px(150.0)

	var eq_pos := Vector2(equip_x - UIScaleScript.px(80.0), input_y + slot_size + UIScaleScript.px(4.0))
	eq_pos.x = clampf(eq_pos.x, 10.0, size.x - pop_w - 10.0)
	eq_pos.y = clampf(eq_pos.y, 10.0, size.y - pop_h - 10.0)
	_equip_popup.position = eq_pos
	_equip_popup.size = Vector2(pop_w, pop_h)

	var sc_pos := Vector2(scroll_x - UIScaleScript.px(80.0), input_y + slot_size + UIScaleScript.px(4.0))
	sc_pos.x = clampf(sc_pos.x, 10.0, size.x - pop_w - 10.0)
	sc_pos.y = clampf(sc_pos.y, 10.0, size.y - pop_h - 10.0)
	_scroll_popup.position = sc_pos
	_scroll_popup.size = Vector2(pop_w, pop_h)

	# Constrain popup icon sizes to fit nicely and not look massive
	var list_icon_size := int(slot_size - UIScaleScript.px(8.0))
	_equip_popup_list.fixed_icon_size = Vector2i(list_icon_size, list_icon_size)
	_scroll_popup_list.fixed_icon_size = Vector2i(list_icon_size, list_icon_size)

	queue_redraw()


func _on_state_changed() -> void:
	if _forge_state == "idle":
		_refresh_lists()
		_restore_selection()
		_update_forge_button_state()
	queue_redraw()


func fit_to(panel_size: Vector2) -> void:
	_on_resized()
	queue_redraw()


func _on_equip_slot_pressed() -> void:
	if _forge_state != "idle":
		return
	_close_popups()
	_refresh_lists()
	_popup_overlay.visible = true
	_equip_popup.visible = true


func _on_scroll_slot_pressed() -> void:
	if _forge_state != "idle":
		return
	_close_popups()
	_refresh_lists()
	_popup_overlay.visible = true
	_scroll_popup.visible = true


func _close_popups() -> void:
	_popup_overlay.visible = false
	_equip_popup.visible = false
	_scroll_popup.visible = false


func _on_equip_popup_selected(index: int) -> void:
	if index >= 0 and index < _equip_items_data.size():
		var data := _equip_items_data[index]
		_selected_item_source = data["source"]
		_selected_item_key = data["key"]
	_close_popups()
	_on_state_changed()


func _on_scroll_popup_selected(index: int) -> void:
	if index >= 0 and index < _scroll_items_data.size():
		var data := _scroll_items_data[index]
		_selected_scroll_id = data["id"]
	_close_popups()
	_on_state_changed()


func _refresh_lists() -> void:
	if GameState == null or not GameState.has_hero():
		return
	var hero: HeroScript = GameState.hero

	# 1. Populating Equipment List
	_equip_popup_list.clear()
	_equip_items_data.clear()

	# Equipped items
	for slot in ItemDataScript.EQUIP_SLOTS:
		var item: Variant = hero.equipment.get(slot)
		if item != null and typeof(item) == TYPE_DICTIONARY:
			var idx := _equip_popup_list.add_item("[E] %s" % ItemDataScript.display_name(item), ItemDataScript.get_texture(item["id"]))
			_equip_items_data.append({
				"source": "equipment",
				"key": slot,
				"item": item
			})
			var rarity := ItemDataScript.item_rarity(item)
			var col: Color = ItemDataScript.RARITY_COLORS.get(rarity, Color.WHITE)
			_equip_popup_list.set_item_custom_fg_color(idx, col)

	# Inventory items
	for i in range(hero.inventory.size()):
		var item: Variant = hero.inventory[i]
		if item != null and typeof(item) == TYPE_DICTIONARY:
			if ItemDataScript.is_gear_loot_id(item["id"]):
				var idx := _equip_popup_list.add_item(ItemDataScript.display_name(item), ItemDataScript.get_texture(item["id"]))
				_equip_items_data.append({
					"source": "inventory",
					"key": i,
					"item": item
				})
				var rarity := ItemDataScript.item_rarity(item)
				var col: Color = ItemDataScript.RARITY_COLORS.get(rarity, Color.WHITE)
				_equip_popup_list.set_item_custom_fg_color(idx, col)

	if _equip_items_data.is_empty():
		var idx := _equip_popup_list.add_item("No Upgradeable Gear")
		_equip_popup_list.set_item_disabled(idx, true)

	# 2. Populating Scroll List
	_scroll_popup_list.clear()
	_scroll_items_data.clear()

	for i in range(hero.inventory.size()):
		var item: Variant = hero.inventory[i]
		if item != null and typeof(item) == TYPE_DICTIONARY:
			var id: String = item.get("id", "")
			if id == "scrolls/upgrade-standard" or id == "scrolls/upgrade-blessed":
				var count := ItemDataScript.stack_count(item)
				var idx := _scroll_popup_list.add_item("%s (x%d)" % [ItemDataScript.get_def(id).get("name", id), count], ItemDataScript.get_texture(id))
				_scroll_items_data.append({
					"id": id,
					"item": item
				})
				if id == "scrolls/upgrade-blessed":
					_scroll_popup_list.set_item_custom_fg_color(idx, Color(0.75, 0.45, 0.95))
				else:
					_scroll_popup_list.set_item_custom_fg_color(idx, Color(0.85, 0.85, 0.85))

	if _scroll_items_data.is_empty():
		var idx := _scroll_popup_list.add_item("No Upgrade Scrolls")
		_scroll_popup_list.set_item_disabled(idx, true)


func _restore_selection() -> void:
	var item: Variant = _get_selected_item()
	if item == null:
		_selected_item_source = ""
		_selected_item_key = null

	var found_scroll := false
	if not _selected_scroll_id.is_empty():
		if GameState != null and GameState.has_hero():
			for inv_item in GameState.hero.inventory:
				if inv_item != null and typeof(inv_item) == TYPE_DICTIONARY:
					if inv_item.get("id") == _selected_scroll_id:
						found_scroll = true
						break
	if not found_scroll:
		_selected_scroll_id = ""


func _update_forge_button_state() -> void:
	var can_upgrade := not _selected_item_source.is_empty() and not _selected_scroll_id.is_empty() and _forge_state == "idle"
	_upgrade_button.disabled = not can_upgrade


func _get_selected_item() -> Variant:
	if GameState == null or not GameState.has_hero():
		return null
	var hero := GameState.hero
	if _selected_item_source == "inventory":
		var idx := int(_selected_item_key)
		if idx >= 0 and idx < hero.inventory.size():
			return hero.inventory[idx]
	elif _selected_item_source == "equipment":
		var slot := str(_selected_item_key)
		return hero.equipment.get(slot)
	return null


func _get_selected_scroll_item() -> Variant:
	if _selected_scroll_id.is_empty():
		return null
	for data in _scroll_items_data:
		if data["id"] == _selected_scroll_id:
			return data["item"]
	return null


func _start_upgrade() -> void:
	if _selected_item_source.is_empty() or _selected_scroll_id.is_empty():
		return
	_forge_state = "flashing"
	_anim_timer = 1.2 # play hammer animation for 1.2 seconds
	_last_strike_count = 0
	_upgrade_button.disabled = true
	_close_popups()
	_altar_panel.queue_redraw()


func _process(delta: float) -> void:
	# Update pulse phase for slot animations
	_pulse_phase += delta * 5.5

	# Update sparks particle simulation
	var active_sparks: Array[Dictionary] = []
	var sparks_changed := not _sparks.is_empty()
	
	for spark in _sparks:
		spark["life"] -= delta
		if spark["life"] > 0.0:
			spark["pos"] += spark["vel"] * delta
			if spark.get("is_ash", false):
				spark["vel"].y -= 15.0 * delta
				spark["pos"].x += sin(spark["life"] * 5.0) * 15.0 * delta
			else:
				spark["vel"].y += 380.0 * delta # Gravity effect
				spark["vel"] *= 0.98 # Drag deceleration
			active_sparks.append(spark)
	_sparks = active_sparks

	# Decay screen shake offsets
	if _shake_intensity > 0.05:
		_shake_offset = Vector2(randf_range(-_shake_intensity, _shake_intensity), randf_range(-_shake_intensity, _shake_intensity))
		_shake_intensity = move_toward(_shake_intensity, 0.0, delta * 24.0)
		sparks_changed = true
	else:
		if not _shake_offset.is_zero_approx():
			_shake_offset = Vector2.ZERO
			sparks_changed = true

	if sparks_changed:
		_altar_panel.queue_redraw()

	if _forge_state == "idle":
		return

	_anim_timer -= delta
	_altar_panel.queue_redraw()

	if _forge_state == "flashing":
		# Trigger hammer hit impacts precisely
		var strike_count := int((1.2 - _anim_timer) * 2.5) # 3 strikes over 1.2s duration
		if strike_count > _last_strike_count:
			_last_strike_count = strike_count
			_trigger_impact()

	if _anim_timer <= 0.0:
		if _forge_state == "flashing":
			_execute_upgrade()
		elif _forge_state == "success" or _forge_state == "failure":
			_forge_state = "idle"
			_selected_scroll_id = "" # Consume selection slot
			_refresh_lists()
			_restore_selection()
			_update_forge_button_state()
			_altar_panel.queue_redraw()


func _trigger_impact() -> void:
	_shake_intensity = UIScaleScript.px(7.0)

	var cx := _altar_panel.size.x * 0.5
	var layout := InventorySlotMetricsScript.resolve_layout()
	var slot_size := float(layout.get("slot_side", UIScaleScript.px(44.0)))
	var output_y := UIScaleScript.px(95.0)
	var impact_pos := Vector2(cx, output_y + slot_size * 0.5)

	# Emit radial bright spark particles from output node
	for i in range(24):
		var angle := randf_range(-PI * 0.85, -PI * 0.15)
		var speed := randf_range(UIScaleScript.px(90.0), UIScaleScript.px(260.0))
		var vel := Vector2(cos(angle), sin(angle)) * speed
		var life := randf_range(0.3, 0.6)
		var r := randf()
		var col := Color(1.0, 0.82, 0.15, 1.0) # Yellow-gold spark
		if r > 0.7:
			col = Color(1.0, 0.45, 0.02, 1.0) # Intense orange
		elif r > 0.9:
			col = Color(0.92, 0.12, 0.02, 1.0) # Fire ember red
			
		_sparks.append({
			"pos": impact_pos,
			"vel": vel,
			"color": col,
			"life": life,
			"max_life": life
		})


func _execute_upgrade() -> void:
	var result := GameState.attempt_forge_upgrade(_selected_item_source, _selected_item_key, _selected_scroll_id)
	if result.get("success", false):
		var upgraded: bool = result.get("upgraded", false)
		if upgraded:
			_forge_state = "success"
		else:
			_forge_state = "failure"
			_selected_item_source = ""
			_selected_item_key = null
			
			# Spawn crumbling ash particles
			var cx := _altar_panel.size.x * 0.5
			var layout := InventorySlotMetricsScript.resolve_layout()
			var slot_size := float(layout.get("slot_side", UIScaleScript.px(44.0)))
			var output_y := UIScaleScript.px(95.0)
			var impact_pos := Vector2(cx, output_y + slot_size * 0.5)
			
			for j in range(45):
				var angle := randf_range(-PI * 0.85, -PI * 0.15)
				var speed := randf_range(25.0, 95.0)
				var vel := Vector2(cos(angle), sin(angle)) * speed
				var life := randf_range(0.9, 1.8)
				_sparks.append({
					"pos": impact_pos + Vector2(randf_range(-slot_size * 0.3, slot_size * 0.3), randf_range(-slot_size * 0.3, slot_size * 0.3)),
					"vel": vel,
					"color": Color(0.36, 0.36, 0.38, randf_range(0.55, 0.95)) if randf() < 0.65 else Color(0.92, 0.42, 0.15, randf_range(0.55, 0.9)),
					"life": life,
					"max_life": life,
					"is_ash": true
				})
		_anim_timer = 1.6 # Show result screen banner for 1.6s
	else:
		_forge_state = "idle"
		_refresh_lists()
		_restore_selection()
		_update_forge_button_state()


func _draw_altar() -> void:
	var size_r := _altar_panel.size
	var font := UiFont.get_font()
	var font_sz := UIScaleScript.font_ui()
	var font_caption := UIScaleScript.font_caption()

	# Apply shake translations to the entire drawing canvas
	_altar_panel.draw_set_transform(_shake_offset, 0.0, Vector2.ONE)

	# 1. Main Background Chrome
	InventoryPanelChromeScript.draw(_altar_panel, Rect2(Vector2.ZERO, size_r), InventoryPanelChromeScript.Style.BAG)

	var cx := size_r.x * 0.5
	
	# Fetch layout metrics
	var host_h := size.y
	if host_h < 1.0:
		host_h = InventorySlotMetricsScript.content_host_height()
	var panel_w := size.x
	if panel_w < 1.0:
		panel_w = InventorySlotMetricsScript.design_panel_width()

	var layout := InventorySlotMetricsScript.layout_for_panel(host_h, panel_w)
	var bag_w: float = layout["bag_w"]
	var equip_w: float = layout["equip_w"]
	var slot_size := InventorySlotMetricsScript.shared_slot_side(
		Vector2(bag_w, host_h),
		0.0,
		Vector2(equip_w, host_h)
	)

	# V-shape coordinate nodes
	var dist_x := UIScaleScript.px(100.0)
	var equip_x := cx - dist_x
	var scroll_x := cx + dist_x - slot_size
	var input_y := UIScaleScript.px(22.0)
	var output_y := UIScaleScript.px(95.0)

	# Center points for the slot nodes
	var p_left_start := Vector2(equip_x + slot_size * 0.5, input_y + slot_size * 0.5)
	var p_right_start := Vector2(scroll_x + slot_size * 0.5, input_y + slot_size * 0.5)
	var p_left_end := Vector2(cx - slot_size * 0.25, output_y)
	var p_right_end := Vector2(cx + slot_size * 0.25, output_y)

	var item: Variant = _get_selected_item()

	# 2. Draw connector lines (similar to talent tree branches)
	var col_left := Color(0.95, 0.78, 0.35) if item != null else Color(0.22, 0.20, 0.18)
	var col_right := Color(0.95, 0.78, 0.35) if not _selected_scroll_id.is_empty() else Color(0.22, 0.20, 0.18)
	
	var w_left := UIScaleScript.px(3.0) if item != null else UIScaleScript.px(1.5)
	var w_right := UIScaleScript.px(3.0) if not _selected_scroll_id.is_empty() else UIScaleScript.px(1.5)

	# Main paths
	_altar_panel.draw_line(p_left_start, p_left_end, col_left, w_left)
	_altar_panel.draw_line(p_right_start, p_right_end, col_right, w_right)

	# Draw arrowhead polygons pointing down-inward
	var dir_left := (p_left_end - p_left_start).normalized()
	var ortho_left := Vector2(-dir_left.y, dir_left.x)
	var ah_size := UIScaleScript.px(6.0)
	var arrow_left_points := PackedVector2Array([
		p_left_end,
		p_left_end - dir_left * ah_size + ortho_left * (ah_size * 0.6),
		p_left_end - dir_left * ah_size - ortho_left * (ah_size * 0.6),
		p_left_end
	])
	_altar_panel.draw_polygon(arrow_left_points, [col_left])

	var dir_right := (p_right_end - p_right_start).normalized()
	var ortho_right := Vector2(-dir_right.y, dir_right.x)
	var arrow_right_points := PackedVector2Array([
		p_right_end,
		p_right_end - dir_right * ah_size + ortho_right * (ah_size * 0.6),
		p_right_end - dir_right * ah_size - ortho_right * (ah_size * 0.6),
		p_right_end
	])
	_altar_panel.draw_polygon(arrow_right_points, [col_right])

	# Pulsing flowing energy along paths during active forge
	if _forge_state == "flashing":
		var t := fmod((1.2 - _anim_timer) * 2.5, 1.0)
		var orb_left := p_left_start.lerp(p_left_end, t)
		_altar_panel.draw_circle(orb_left, UIScaleScript.px(4.0), Color(1.0, 0.9, 0.4, 0.9))
		var orb_right := p_right_start.lerp(p_right_end, t)
		_altar_panel.draw_circle(orb_right, UIScaleScript.px(4.0), Color(1.0, 0.9, 0.4, 0.9))

	# 3. Draw Equipment & Scroll Input Slot Nodes
	var equip_rect := Rect2(equip_x, input_y, slot_size, slot_size)
	var scroll_rect := Rect2(scroll_x, input_y, slot_size, slot_size)
	
	# Draw Equipment Slot using standard inventory slot styling
	var equip_hovered := is_instance_valid(_equip_slot_btn) and _equip_slot_btn.is_hovered()
	InventorySlotDrawScript.draw_square(_altar_panel, equip_rect, equip_hovered)

	if item == null:
		EquipmentSlotIconsScript.draw(_altar_panel, equip_rect, "weapon", Color(0.82, 0.72, 0.58))
	else:
		InventoryIconDrawScript.draw_in_slot(_altar_panel, equip_rect, item)
		ItemRarityFrameScript.draw_on_slot(_altar_panel, equip_rect, ItemDataScript.item_rarity(item), _pulse_phase)

	# Draw Scroll Slot using standard inventory slot styling
	var scroll_hovered := is_instance_valid(_scroll_slot_btn) and _scroll_slot_btn.is_hovered()
	InventorySlotDrawScript.draw_square(_altar_panel, scroll_rect, scroll_hovered)

	var scroll_item: Variant = _get_selected_scroll_item()
	if scroll_item == null:
		var txt := "Scroll"
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_caption).x
		var th := font.get_height(font_caption)
		_altar_panel.draw_string(font, Vector2(scroll_rect.position.x + (slot_size - tw) * 0.5, scroll_rect.position.y + slot_size * 0.5 + th * 0.3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_caption, Color(0.34, 0.32, 0.28))
	else:
		InventoryIconDrawScript.draw_in_slot(_altar_panel, scroll_rect, scroll_item)
		var rarity_name := "rare" if _selected_scroll_id == "scrolls/upgrade-blessed" else "common"
		ItemRarityFrameScript.draw_on_slot(_altar_panel, scroll_rect, rarity_name, _pulse_phase)

	# 4. Draw Result/Output Slot Node using standard inventory slot styling
	var result_rect := Rect2(cx - slot_size * 0.5, output_y, slot_size, slot_size)
	var result_center := result_rect.get_center()

	# Draw Runic Ritual Circle
	var runic_color := Color(0.85, 0.72, 0.45, 0.16)
	if _forge_state == "flashing":
		runic_color = Color(1.0, 0.65, 0.15, 0.55 + sin(_pulse_phase * 2.0) * 0.15)
	
	var r_runic := slot_size * 1.05
	_altar_panel.draw_arc(result_center, r_runic, 0.0, TAU, 48, runic_color, UIScaleScript.px(1.0))
	_altar_panel.draw_arc(result_center, r_runic * 0.82, 0.0, TAU, 40, runic_color, UIScaleScript.px(0.8))
	
	var tick_angle_step := TAU / 12.0
	var rotation_offset := _pulse_phase * (0.45 if _forge_state == "flashing" else 0.08)
	for i in range(12):
		var angle := i * tick_angle_step + rotation_offset
		var dir := Vector2(cos(angle), sin(angle))
		var p_start := result_center + dir * (r_runic * 0.82)
		var p_end := result_center + dir * r_runic
		_altar_panel.draw_line(p_start, p_end, runic_color, UIScaleScript.px(1.0))

	# Draw Vector Anvil Visual
	_draw_anvil(_altar_panel, result_center, slot_size)

	# Draw main result slot frame
	InventorySlotDrawScript.draw_square(_altar_panel, result_rect, false)

	if _forge_state == "success":
		# Render successfully upgraded weapon/item
		var next_item: Dictionary = (item as Dictionary).duplicate(true)
		next_item["upgrade"] = int(item.get("upgrade", 0)) + 1
		InventoryIconDrawScript.draw_in_slot(_altar_panel, result_rect, next_item)
		ItemRarityFrameScript.draw_on_slot(_altar_panel, result_rect, ItemDataScript.item_rarity(next_item), _pulse_phase)
	
	elif _forge_state == "flashing" or (item != null and _forge_state == "idle"):
		# Render preview weapon/item with translucent ghost effect
		var current_upg := int(item.get("upgrade", 0))
		var next_item: Dictionary = (item as Dictionary).duplicate(true)
		next_item["upgrade"] = current_upg + 1
		
		# Draw preview icon in stretched slot
		var inner := InventorySlotDrawScript.inner_content_rect(result_rect)
		ItemDataScript.draw_item_icon(_altar_panel, inner, next_item, ItemDataScript.IconFit.STRETCH, 0.0, Color(1.0, 1.0, 1.0, 0.55))
		ItemRarityFrameScript.draw_on_slot(_altar_panel, result_rect, ItemDataScript.item_rarity(next_item), _pulse_phase)
		
		# Draw green preview label "+X" on the bottom corner of the slot
		var upg_txt := "+%d" % next_item["upgrade"]
		var tw := font.get_string_size(upg_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_caption).x
		var th := font.get_height(font_caption)
		_altar_panel.draw_string(font, Vector2(result_rect.end.x - tw - UIScaleScript.px(2.0), result_rect.end.y - UIScaleScript.px(2.0)), upg_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_caption, Color(0.35, 0.95, 0.45))
	
	elif _forge_state == "failure":
		# Empty / destroyed
		pass
	else:
		# Ghost Sword outline icon in result node
		EquipmentSlotIconsScript.draw(_altar_panel, result_rect, "weapon", Color(0.82, 0.72, 0.58))

	# 5. Draw stats comparisons & risk calculations to the left/right of the flowchart
	if item != null and typeof(item) == TYPE_DICTIONARY:
		var current_upg := int(item.get("upgrade", 0))
		var base_stats := ItemDataScript.compute_instance_stats(item)

		var next_item: Dictionary = (item as Dictionary).duplicate(true)
		next_item["upgrade"] = current_upg + 1
		var next_stats := ItemDataScript.compute_instance_stats(next_item)

		var stat_lines: Array[String] = []
		for key in base_stats.keys():
			if key != "bag_slots" and key != "power":
				var v1 := float(base_stats[key])
				var v2 := float(next_stats[key])
				if absf(v1) > 0.001 or absf(v2) > 0.001:
					var label: String = str(ItemDataScript.STAT_LABELS.get(key, key))
					stat_lines.append("%s: %.1f -> %.1f" % [label, v1, v2])

		# Left side: stats comparison
		var y_stat := UIScaleScript.px(42.0)
		for line in stat_lines:
			_altar_panel.draw_string(font, Vector2(UIScaleScript.px(12.0), y_stat), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, Color(0.94, 0.88, 0.78))
			y_stat += font.get_height(font_sz)

		# Right side: risk estimate
		var chance := 0.0
		if not _selected_scroll_id.is_empty():
			if _selected_scroll_id == "scrolls/upgrade-standard":
				var rates := [1.0, 0.95, 0.85, 0.65, 0.50, 0.35, 0.20, 0.10, 0.04, 0.01]
				chance = rates[current_upg]
			elif _selected_scroll_id == "scrolls/upgrade-blessed":
				var rates := [1.0, 1.0, 1.0, 0.90, 0.75, 0.60, 0.40, 0.25, 0.12, 0.05]
				chance = rates[current_upg]

		var risk_text := ""
		var risk_color := Color(0.7, 0.7, 0.7)
		if _selected_scroll_id.is_empty():
			risk_text = "Select Scroll to estimate risk"
		else:
			if chance == 1.0:
				risk_text = "Risk: Safe (100%)"
				risk_color = Color(0.28, 0.72, 0.35)
			elif chance >= 0.75:
				risk_text = "Risk: Low (%.0f%%)" % (chance * 100.0)
				risk_color = Color(0.55, 0.75, 0.32)
			elif chance >= 0.40:
				risk_text = "Risk: Moderate (%.0f%%)" % (chance * 100.0)
				risk_color = Color(0.92, 0.74, 0.38)
			elif chance >= 0.15:
				risk_text = "Risk: High (%.0f%%)" % (chance * 100.0)
				risk_color = Color(0.92, 0.45, 0.25)
			else:
				risk_text = "Risk: Extreme! (%.0f%%)" % (chance * 100.0)
				risk_color = Color(0.92, 0.22, 0.18)

		var r_tw := font.get_string_size(risk_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz).x
		_altar_panel.draw_string(font, Vector2(size_r.x - r_tw - UIScaleScript.px(12.0), UIScaleScript.px(42.0)), risk_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, risk_color)
	else:
		var instruct := "Select gear & scroll\nto start upgrade altar."
		var lines := instruct.split("\n")
		var y_pos := UIScaleScript.px(42.0)
		for line in lines:
			_altar_panel.draw_string(font, Vector2(UIScaleScript.px(12.0), y_pos), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, Color(0.48, 0.44, 0.40))
			y_pos += font.get_height(font_sz)

	# 6. Draw Spark Particles
	for spark in _sparks:
		_altar_panel.draw_line(spark.pos, spark.pos - spark.vel * 0.04, spark.color, UIScaleScript.px(1.5))

	# 7. Draw Hammer Animation striking the output node
	if _forge_state == "flashing":
		var strike_cycle := fmod((1.2 - _anim_timer) * 2.5, 1.0)
		var pivot := Vector2(cx + UIScaleScript.px(55.0), output_y - UIScaleScript.px(15.0))
		var target := Vector2(cx, output_y + slot_size * 0.5)

		var head_pos := Vector2.ZERO
		var hammer_angle := 0.0

		if strike_cycle < 0.75:
			var t := strike_cycle / 0.75
			head_pos = target.lerp(pivot + Vector2(UIScaleScript.px(-15.0), UIScaleScript.px(-35.0)), t)
			hammer_angle = -PI / 4.0 * t
		else:
			var t := (strike_cycle - 0.75) / 0.25
			head_pos = (pivot + Vector2(UIScaleScript.px(-15.0), UIScaleScript.px(-35.0))).lerp(target, t)
			hammer_angle = -PI / 4.0 * (1.0 - t)

		# Draw wooden handle
		_altar_panel.draw_line(pivot, head_pos, Color(0.55, 0.35, 0.18), UIScaleScript.px(3.5))

		# Draw metal head
		var head_w := UIScaleScript.px(20.0)
		var head_h := UIScaleScript.px(12.0)
		var head_points := PackedVector2Array([
			head_pos + Vector2(-head_w/2, -head_h/2).rotated(hammer_angle),
			head_pos + Vector2(head_w/2, -head_h/2).rotated(hammer_angle),
			head_pos + Vector2(head_w/2, head_h/2).rotated(hammer_angle),
			head_pos + Vector2(-head_w/2, head_h/2).rotated(hammer_angle)
		])
		_altar_panel.draw_polygon(head_points, [Color(0.24, 0.25, 0.28)])
		_altar_panel.draw_polyline(head_points, Color(0.1, 0.1, 0.1), 1.0)

	# 8. Full-screen success/burned banners
	if _forge_state == "success":
		# Solid dark green backing
		_altar_panel.draw_rect(Rect2(Vector2.ZERO, size_r), Color(0.06, 0.22, 0.08, 0.82))
		
		# Draw expanding golden shockwave
		var glow_elapsed := 1.6 - _anim_timer
		var wave_radius := glow_elapsed * UIScaleScript.px(280.0)
		if wave_radius < size_r.x:
			var wave_a := clampf(1.0 - (glow_elapsed / 1.4), 0.0, 1.0)
			_altar_panel.draw_arc(result_center, wave_radius, 0.0, TAU, 72, Color(1.0, 0.92, 0.65, wave_a * 0.85), UIScaleScript.px(4.0))
			_altar_panel.draw_arc(result_center, wave_radius - UIScaleScript.px(6.0), 0.0, TAU, 64, Color(1.0, 0.82, 0.35, wave_a * 0.5), UIScaleScript.px(2.0))
		
		# Draw holy halo glow
		for r_i in range(8):
			var rad := slot_size * (1.1 + float(r_i) * 0.28)
			var val_a := 0.28 * (1.0 - float(r_i) / 8.0)
			_altar_panel.draw_circle(result_center, rad, Color(1.0, 0.88, 0.52, val_a * 0.58))
			
		var text := "UPGRADE SUCCESS!"
		var t_sz := UIScaleScript.font_emphasis()
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, t_sz).x
		_altar_panel.draw_string(font, Vector2(cx - tw * 0.5, size_r.y * 0.45), text, HORIZONTAL_ALIGNMENT_LEFT, -1, t_sz, Color(0.35, 0.95, 0.45))
		
		var bonus := "Stats Boosted!"
		var b_tw := font.get_string_size(bonus, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz).x
		_altar_panel.draw_string(font, Vector2(cx - b_tw * 0.5, size_r.y * 0.65), bonus, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, Color(0.96, 0.9, 0.72))

	elif _forge_state == "failure":
		# Dark charcoal/ash backing
		_altar_panel.draw_rect(Rect2(Vector2.ZERO, size_r), Color(0.18, 0.05, 0.05, 0.88))
		
		# Draw expanding ash shockwave
		var fail_elapsed := 1.6 - _anim_timer
		var wave_radius := fail_elapsed * UIScaleScript.px(220.0)
		if wave_radius < size_r.x:
			var wave_a := clampf(1.0 - (fail_elapsed / 1.4), 0.0, 1.0)
			_altar_panel.draw_arc(result_center, wave_radius, 0.0, TAU, 60, Color(0.42, 0.38, 0.35, wave_a * 0.62), UIScaleScript.px(3.0))
			_altar_panel.draw_arc(result_center, wave_radius + UIScaleScript.px(4.0), 0.0, TAU, 64, Color(0.85, 0.35, 0.12, wave_a * 0.28), UIScaleScript.px(1.5))
			
		var text := "ITEM BURNED!"
		var t_sz := UIScaleScript.font_emphasis()
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, t_sz).x
		_altar_panel.draw_string(font, Vector2(cx - tw * 0.5, size_r.y * 0.45), text, HORIZONTAL_ALIGNMENT_LEFT, -1, t_sz, Color(0.95, 0.22, 0.18))
		
		var loss := "Item destroyed completely"
		var l_tw := font.get_string_size(loss, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz).x
		_altar_panel.draw_string(font, Vector2(cx - l_tw * 0.5, size_r.y * 0.65), loss, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, Color(0.85, 0.75, 0.72))


func _draw_anvil(canvas: Control, result_center: Vector2, slot_size: float) -> void:
	if _anvil_texture == null:
		return

	var cy := result_center.y
	var cx := result_center.x

	# Scale the pixel art anvil relative to the upgrade slot
	var anvil_w := slot_size * 2.3
	var anvil_h := slot_size * 2.3
	
	# Position the anvil so its top plate aligns right under the result slot
	var rect := Rect2(cx - anvil_w * 0.5, cy + slot_size * 0.72 - anvil_h * 0.5, anvil_w, anvil_h)

	var modulate_col := Color.WHITE
	if _forge_state == "flashing":
		# Pulse reddish-orange to simulate heat glowing through the metal
		var pulse := sin(_pulse_phase * 4.0) * 0.18 + 0.82
		modulate_col = Color(1.0, pulse * 0.75, pulse * 0.55)

	canvas.draw_texture_rect(_anvil_texture, rect, false, modulate_col)
