extends Control

enum Tab { COMBAT, INVENTORY, FORGE, MARKET }

const TAB_NAMES := {
	Tab.COMBAT: "Savas",
	Tab.INVENTORY: "Envanter",
	Tab.FORGE: "Ors",
	Tab.MARKET: "Pazar",
}

const NAV_HEIGHT := 36.0
const NAV_FONT := 14

@onready var content_host: Control = $VBox/ContentHost
@onready var combat_strip: Control = $VBox/ContentHost/CombatStrip
@onready var inventory_view: Control = $VBox/ContentHost/InventoryView
@onready var forge_view: Control = $VBox/ContentHost/ForgeView
@onready var market_view: Control = $VBox/ContentHost/MarketView
@onready var nav_bar: HBoxContainer = $VBox/NavBar
@onready var inventory_bag: Control = $VBox/ContentHost/InventoryView/InventoryBag
@onready var forge_label: Label = $VBox/ContentHost/ForgeView/ForgeLabel
@onready var forge_button: Button = $VBox/ContentHost/ForgeView/ForgeButton
@onready var market_list: ItemList = $VBox/ContentHost/MarketView/MarketList

var _tab := Tab.COMBAT
var _nav_buttons: Dictionary = {}


func _ready() -> void:
	_build_nav()
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


func _build_nav() -> void:
	for tab in Tab.values():
		var btn := Button.new()
		btn.text = TAB_NAMES[tab]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, NAV_HEIGHT)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", NAV_FONT)
		btn.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.86))
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.7))
		btn.add_theme_stylebox_override("normal", _nav_style(false))
		btn.add_theme_stylebox_override("hover", _nav_style(false, true))
		btn.add_theme_stylebox_override("pressed", _nav_style(true))
		btn.pressed.connect(func() -> void: _select_tab(tab))
		nav_bar.add_child(btn)
		_nav_buttons[tab] = btn


func _nav_style(active: bool, hover: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.48, 0.32, 0.18) if active else Color(0.34, 0.22, 0.13)
	if hover and not active:
		box.bg_color = Color(0.42, 0.28, 0.16)
	box.border_color = Color(0.68, 0.5, 0.28)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_top = 4
	box.content_margin_bottom = 2
	return box


func _select_tab(tab: Tab) -> void:
	_tab = tab
	combat_strip.visible = tab == Tab.COMBAT
	inventory_view.visible = tab == Tab.INVENTORY
	forge_view.visible = tab == Tab.FORGE
	market_view.visible = tab == Tab.MARKET
	_refresh_nav_styles()
	_refresh_tabs()


func _refresh_nav_styles() -> void:
	for tab in _nav_buttons.keys():
		var btn: Button = _nav_buttons[tab]
		var active: bool = tab == _tab
		btn.add_theme_stylebox_override("normal", _nav_style(active))
		btn.add_theme_stylebox_override("hover", _nav_style(active, true))
		btn.modulate = Color(1.08, 1.04, 0.92) if active else Color(0.88, 0.86, 0.82)


func _refresh_tabs() -> void:
	if not is_inside_tree():
		return

	if inventory_bag.has_method("queue_redraw"):
		inventory_bag.queue_redraw()

	var hero := GameState.hero
	var cost: int = 25 + hero.staff_enchant * 18
	var risk := 0.0 if hero.staff_enchant < 5 else (18.0 + hero.staff_enchant * 3.0)
	forge_label.text = "Asa +%d | %d altin | risk %.0f%%" % [hero.staff_enchant, cost, risk]

	market_list.clear()
	for key in GameState.market_prices.keys():
		var price: int = int(round(GameState.market_prices[key]))
		market_list.add_item("%s  %d altin" % [key, price])


func _on_market_buy(index: int) -> void:
	var keys := GameState.market_prices.keys()
	if index >= 0 and index < keys.size():
		GameState.buy_crystal(keys[index])
