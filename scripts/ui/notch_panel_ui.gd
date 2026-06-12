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
@onready var market_list: ItemList = $VBox/ContentHost/MarketView/MarketList

var _tab := Tab.COMBAT
var _phase := GamePhase.MENU
var _menu_view: Control
var _name_intro: Control
var talents_view: Control


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
	
	market_list.item_activated.connect(_on_market_buy)
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
	if tab == Tab.INVENTORY:
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

	var hero := GameState.hero

	market_list.clear()
	for key in GameState.market_prices.keys():
		var discount := 0.0
		if hero != null and hero.has_method("get_talent_shop_discount_modifier"):
			discount = hero.get_talent_shop_discount_modifier()
		var price: int = int(round(GameState.market_prices[key] * (1.0 - discount)))
		var label := str(key)
		var item_id: String = str(GameState.MARKET_ITEM_IDS.get(key, ""))
		if not item_id.is_empty():
			label = str(ItemDataScript.get_def(item_id).get("name", key))
		market_list.add_item("%s  %d gold" % [label, price])

	market_list.add_theme_font_size_override("font_size", UIScaleScript.font_ui())


func _on_market_buy(index: int) -> void:
	var keys := GameState.market_prices.keys()
	if index >= 0 and index < keys.size():
		GameState.buy_crystal(keys[index])
