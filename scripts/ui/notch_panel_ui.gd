extends Control

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const UiFont = preload("res://scripts/ui/ui_font.gd")

enum Tab { COMBAT, INVENTORY, FORGE, MARKET }

const NAV_HEIGHT := UIScaleScript.NAV_HEIGHT

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


func _ready() -> void:
	UiFont.setup()
	nav_bar.tab_pressed.connect(_select_tab)
	forge_button.pressed.connect(func() -> void: GameState.forge_enchant())
	market_list.item_activated.connect(_on_market_buy)
	GameState.state_changed.connect(_refresh_tabs)
	_select_tab(Tab.COMBAT)


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


func _select_tab(tab: Tab) -> void:
	_tab = tab
	combat_strip.visible = tab == Tab.COMBAT
	inventory_view.visible = tab == Tab.INVENTORY
	forge_view.visible = tab == Tab.FORGE
	market_view.visible = tab == Tab.MARKET
	if nav_bar.has_method("set_active_tab"):
		nav_bar.set_active_tab(tab)
	if tab == Tab.INVENTORY:
		GameState.mark_inventory_seen()
	_refresh_tabs()
	if tab == Tab.INVENTORY and inventory_view != null:
		inventory_view.call_deferred("_layout_children")


func _refresh_tabs() -> void:
	if not is_inside_tree():
		return

	if inventory_bag.has_method("queue_redraw"):
		inventory_bag.queue_redraw()
	if equipment_panel.has_method("queue_redraw"):
		equipment_panel.queue_redraw()
	if inventory_view.has_method("queue_redraw"):
		inventory_view.queue_redraw()
	if nav_bar.has_method("queue_redraw"):
		nav_bar.queue_redraw()

	var hero := GameState.hero
	var cost: int = 25 + hero.staff_enchant * 18
	var risk := 0.0 if hero.staff_enchant < 5 else (18.0 + hero.staff_enchant * 3.0)
	forge_label.text = "Staff +%d | %d gold | risk %.0f%%" % [hero.staff_enchant, cost, risk]

	market_list.clear()
	for key in GameState.market_prices.keys():
		var price: int = int(round(GameState.market_prices[key]))
		market_list.add_item("%s  %d gold" % [key, price])

	forge_label.add_theme_font_size_override("font_size", UIScaleScript.font(14))
	forge_button.add_theme_font_size_override("font_size", UIScaleScript.font(16))
	market_list.add_theme_font_size_override("font_size", UIScaleScript.font(14))


func _on_market_buy(index: int) -> void:
	var keys := GameState.market_prices.keys()
	if index >= 0 and index < keys.size():
		GameState.buy_crystal(keys[index])
