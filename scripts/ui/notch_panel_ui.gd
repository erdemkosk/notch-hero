extends Control

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const UiFont = preload("res://scripts/ui/ui_font.gd")

enum Tab { COMBAT, INVENTORY, FORGE, MARKET, TALENTS }

enum GamePhase { MENU, NAME_INTRO, PLAYING }

const NAV_HEIGHT := UIScaleScript.NAV_HEIGHT
const MainMenuViewScript = preload("res://scripts/ui/main_menu_view.gd")
const NameIntroViewScript = preload("res://scripts/ui/name_intro_view.gd")
const SaveServiceScript = preload("res://scripts/game/save_service.gd")
const ItemDataScript = preload("res://scripts/game/item_data.gd")

@onready var content_host: Control = $VBox/ContentHost
@onready var combat_strip: Control = $VBox/ContentHost/CombatStrip
@onready var inventory_view: Control = $VBox/ContentHost/InventoryView
@onready var forge_view: Control = $VBox/ContentHost/ForgeView
@onready var market_view: Control = $VBox/ContentHost/MarketView
@onready var nav_bar: Control = $VBox/NavBar
@onready var inventory_bag: Control = $VBox/ContentHost/InventoryView/InventoryBag
@onready var equipment_panel: Control = $VBox/ContentHost/InventoryView/EquipmentPanel
@onready var forge_label: Label = $VBox/ContentHost/ForgeView/ForgeLabel
@onready var forge_button: Button = $VBox/ContentHost/ForgeView/ForgeButton

var _tab := Tab.COMBAT
var _phase := GamePhase.MENU
var _menu_view: Control
var _name_intro: Control
var talents_view: Control
var _offline_popup: PanelContainer = null


func _ready() -> void:
	UiFont.setup()
	nav_bar.tab_pressed.connect(_select_tab)
	if nav_bar.has_signal("menu_pressed"):
		nav_bar.menu_pressed.connect(_return_to_main_menu)
	
	# Replace old ForgeView container with the correct script attached at runtime
	var old_forge := forge_view
	forge_view = Control.new()
	forge_view.name = "ForgeView"
	forge_view.set_script(load("res://scripts/ui/forge_view.gd"))
	forge_view.visible = false
	content_host.add_child(forge_view)
	old_forge.queue_free()

	# Replace old MarketView container with the correct script attached at runtime
	var old_market := market_view
	market_view = Control.new()
	market_view.name = "MarketView"
	market_view.set_script(load("res://scripts/ui/market_view.gd"))
	market_view.visible = false
	content_host.add_child(market_view)
	old_market.queue_free()

	if GameState != null:
		GameState.state_changed.connect(_refresh_tabs)

	_menu_view = MainMenuViewScript.new()
	_menu_view.continue_pressed.connect(_on_continue_pressed)
	_menu_view.new_game_pressed.connect(_on_new_game_pressed)
	_menu_view.quit_pressed.connect(_on_quit_pressed)
	add_child(_menu_view)

	_name_intro = NameIntroViewScript.new()
	_name_intro.visible = false
	_name_intro.confirm_pressed.connect(_on_name_confirmed)
	_name_intro.back_pressed.connect(_on_name_back_pressed)
	add_child(_name_intro)

	talents_view = Control.new()
	talents_view.name = "TalentsView"
	talents_view.set_script(load("res://scripts/ui/talents_view.gd"))
	talents_view.visible = false
	content_host.add_child(talents_view)

	_set_phase(GamePhase.MENU)


func fit_to(panel_size: Vector2) -> void:
	custom_minimum_size = panel_size
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox: VBoxContainer = $VBox
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 0.0
	vbox.offset_top = 0.0
	vbox.offset_right = 0.0
	vbox.offset_bottom = 0.0

	content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if is_instance_valid(_menu_view):
		_menu_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if is_instance_valid(_name_intro):
		_name_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if _name_intro.has_method("on_shown"):
			_name_intro.call_deferred("_layout")

	if is_instance_valid(talents_view):
		talents_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if talents_view.has_method("fit_to"):
			talents_view.fit_to(panel_size)

	if is_instance_valid(forge_view):
		forge_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if forge_view.has_method("fit_to"):
			forge_view.fit_to(panel_size)

	if is_instance_valid(market_view):
		market_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if is_instance_valid(_offline_popup):
		_offline_popup.position = (panel_size - _offline_popup.size) * 0.5


func _set_phase(phase: GamePhase) -> void:
	_phase = phase
	var playing := phase == GamePhase.PLAYING

	_update_keyboard_focus(phase == GamePhase.NAME_INTRO)

	$VBox.visible = playing
	if is_instance_valid(_menu_view):
		_menu_view.visible = phase == GamePhase.MENU
		if phase == GamePhase.MENU:
			_menu_view.set_continue_enabled(SaveServiceScript.has_save())
	if is_instance_valid(_name_intro):
		_name_intro.visible = phase == GamePhase.NAME_INTRO
		if phase == GamePhase.NAME_INTRO and _name_intro.has_method("on_shown"):
			_name_intro.call_deferred("on_shown")

	if playing:
		_select_tab(Tab.COMBAT)


func _on_continue_pressed() -> void:
	if GameState.session_paused:
		GameState.resume_session()
		_set_phase(GamePhase.PLAYING)
		return
	if GameState.continue_game():
		_set_phase(GamePhase.PLAYING)
		# Trigger offline progress popup if there was any calculation
		if not GameState.last_offline_progress.is_empty():
			var progress: Dictionary = GameState.last_offline_progress
			show_offline_report(
				float(progress.get("elapsed_seconds", 0.0)),
				int(progress.get("gold", 0)),
				int(progress.get("xp", 0)),
				progress.get("items", [])
			)
			GameState.last_offline_progress = {}


func _on_new_game_pressed() -> void:
	_set_phase(GamePhase.NAME_INTRO)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _update_keyboard_focus(enabled: bool) -> void:
	var win := get_tree().get_first_node_in_group("notch_window")
	if win != null and win.has_method("set_keyboard_input_enabled"):
		win.set_keyboard_input_enabled(enabled)


func _on_name_confirmed(player_name: String) -> void:
	GameState.start_new_game(player_name)
	_set_phase(GamePhase.PLAYING)


func _on_name_back_pressed() -> void:
	_set_phase(GamePhase.MENU)


func _return_to_main_menu() -> void:
	if _phase != GamePhase.PLAYING:
		return
	GameState.pause_session()
	_set_phase(GamePhase.MENU)


func _select_tab(tab: Tab) -> void:
	if _phase != GamePhase.PLAYING:
		return
	_tab = tab
	combat_strip.visible = tab == Tab.COMBAT
	inventory_view.visible = tab == Tab.INVENTORY
	forge_view.visible = tab == Tab.FORGE
	market_view.visible = tab == Tab.MARKET
	if is_instance_valid(talents_view):
		talents_view.visible = tab == Tab.TALENTS
	if nav_bar.has_method("set_active_tab"):
		nav_bar.set_active_tab(tab)
	if tab == Tab.INVENTORY and GameState != null:
		GameState.mark_inventory_seen()
	_refresh_tabs()
	if tab == Tab.INVENTORY and inventory_view != null:
		inventory_view.call_deferred("_layout_children")


func _refresh_tabs() -> void:
	if not is_inside_tree() or _phase != GamePhase.PLAYING:
		return
	if GameState == null or not GameState.has_hero():
		return

	if inventory_bag.has_method("queue_redraw"):
		inventory_bag.queue_redraw()
	if equipment_panel.has_method("queue_redraw"):
		equipment_panel.queue_redraw()
	if inventory_view.has_method("queue_redraw"):
		inventory_view.queue_redraw()
	if nav_bar.has_method("queue_redraw"):
		nav_bar.queue_redraw()
	if is_instance_valid(talents_view) and talents_view.has_method("queue_redraw"):
		talents_view.queue_redraw()
	if is_instance_valid(forge_view) and forge_view.has_method("queue_redraw"):
		forge_view.queue_redraw()

	if is_instance_valid(market_view) and market_view.has_method("queue_redraw"):
		market_view.queue_redraw()


# Market purchase is handled directly by MarketView


func show_offline_report(elapsed_time: float, gold_gained: int, xp_gained: int, items: Array) -> void:
	if is_instance_valid(_offline_popup):
		_offline_popup.queue_free()

	_offline_popup = PanelContainer.new()
	_offline_popup.name = "OfflineReportPopup"
	_offline_popup.z_index = 100
	_offline_popup.z_as_relative = false

	# Premium flat stylebox with gold border and dark violet/obsidian background
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.08, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.92, 0.74, 0.38) # Gold
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	_offline_popup.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(UIScaleScript.px(16.0)))
	margin.add_theme_constant_override("margin_top", int(UIScaleScript.px(12.0)))
	margin.add_theme_constant_override("margin_right", int(UIScaleScript.px(16.0)))
	margin.add_theme_constant_override("margin_bottom", int(UIScaleScript.px(12.0)))
	_offline_popup.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(UIScaleScript.px(6.0)))
	margin.add_child(vbox)

	# Title
	var title_lbl := Label.new()
	title_lbl.text = "OFFLINE PROGRESS REPORT"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", UiFont.get_font())
	title_lbl.add_theme_font_size_override("font_size", UIScaleScript.font_emphasis())
	title_lbl.add_theme_color_override("font_color", Color(0.92, 0.74, 0.38))
	vbox.add_child(title_lbl)

	# Elapsed Time
	var hours := int(elapsed_time / 3600.0)
	var minutes := int(fmod(elapsed_time, 3600.0) / 60.0)
	var time_text := ""
	if hours > 0:
		time_text = "Time elapsed offline: %d hours %d minutes" % [hours, minutes]
	else:
		time_text = "Time elapsed offline: %d minutes" % minutes

	var time_lbl := Label.new()
	time_lbl.text = time_text
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_lbl.add_theme_font_override("font", UiFont.get_font())
	time_lbl.add_theme_font_size_override("font_size", UIScaleScript.font_ui())
	time_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(time_lbl)

	# Divider line
	var div := Label.new()
	div.text = "────────────────────────"
	div.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	div.add_theme_color_override("font_color", Color(0.24, 0.22, 0.20))
	vbox.add_child(div)

	# Rewards summary
	var rewards_lbl := Label.new()
	rewards_lbl.text = "Gold Earned: +%d Gold\nXP Earned: +%d XP" % [gold_gained, xp_gained]
	rewards_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rewards_lbl.add_theme_font_override("font", UiFont.get_font())
	rewards_lbl.add_theme_font_size_override("font_size", UIScaleScript.font_ui())
	rewards_lbl.add_theme_color_override("font_color", Color(0.94, 0.88, 0.78))
	vbox.add_child(rewards_lbl)

	# Found Items
	if not items.is_empty():
		# Limit showing to max 3 items to avoid popup overflow
		var items_desc := "Loot Obtained:\n"
		var show_count := mini(items.size(), 3)
		for idx in range(show_count):
			var item: Dictionary = items[idx]
			var count := ItemDataScript.stack_count(item)
			var count_txt := " (x%d)" % count if count > 1 else ""
			items_desc += "• " + ItemDataScript.display_name(item) + count_txt + "\n"
		if items.size() > show_count:
			items_desc += "• and %d other items..." % (items.size() - show_count)

		var items_lbl := Label.new()
		items_lbl.text = items_desc.strip_edges()
		items_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		items_lbl.add_theme_font_override("font", UiFont.get_font())
		items_lbl.add_theme_font_size_override("font_size", UIScaleScript.font_caption())
		items_lbl.add_theme_color_override("font_color", Color(0.55, 0.75, 0.35)) # Green tint
		vbox.add_child(items_lbl)

	# Close Button
	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.add_theme_font_override("font", UiFont.get_font())
	close_btn.add_theme_font_size_override("font_size", UIScaleScript.font_ui())
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# Nice standard button style overrides
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.18, 0.15, 0.12)
	btn_normal.border_width_left = 1
	btn_normal.border_width_top = 1
	btn_normal.border_width_right = 1
	btn_normal.border_width_bottom = 1
	btn_normal.border_color = Color(0.85, 0.72, 0.45)
	btn_normal.corner_radius_top_left = 4
	btn_normal.corner_radius_top_right = 4
	btn_normal.corner_radius_bottom_right = 4
	btn_normal.corner_radius_bottom_left = 4
	close_btn.add_theme_stylebox_override("normal", btn_normal)
	
	var btn_hover := btn_normal.duplicate()
	btn_hover.bg_color = Color(0.24, 0.2, 0.16)
	close_btn.add_theme_stylebox_override("hover", btn_hover)

	close_btn.custom_minimum_size = Vector2(UIScaleScript.px(100.0), UIScaleScript.px(24.0))
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func() -> void:
		_offline_popup.queue_free()
	)
	vbox.add_child(close_btn)

	add_child(_offline_popup)

	# Calculate popup size and position
	var pop_w := UIScaleScript.px(300.0)
	var pop_h := UIScaleScript.px(160.0)
	if not items.is_empty():
		pop_h += UIScaleScript.px(45.0)
	
	_offline_popup.size = Vector2(pop_w, pop_h)
	_offline_popup.position = (size - _offline_popup.size) * 0.5
