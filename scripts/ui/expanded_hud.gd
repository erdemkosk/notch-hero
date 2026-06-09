extends Control

@onready var title_label: Label = $Root/Header/TitleLabel
@onready var gold_label: Label = $Root/Header/GoldLabel
@onready var arena: Control = $Root/Arena
@onready var wizard_sprite: ColorRect = $Root/Arena/Wizard
@onready var enemy_sprite: ColorRect = $Root/Arena/Enemy
@onready var spell_label: Label = $Root/Arena/SpellLabel
const StatBarControl = preload("res://scripts/ui/stat_bar.gd")
const MagicSchoolScript = preload("res://scripts/game/magic_school.gd")
const Hero = preload("res://scripts/game/hero.gd")
const Enemy = preload("res://scripts/game/enemy.gd")

@onready var hp_bar: StatBarControl = $Root/Arena/HPBar
@onready var mp_bar: StatBarControl = $Root/Arena/MPBar
@onready var xp_bar: StatBarControl = $Root/Arena/XPBar
@onready var tab_container: TabContainer = $Root/Tabs
@onready var log_label: Label = $Root/Tabs/Savaş/LogLabel
@onready var inventory_list: ItemList = $Root/Tabs/Envanter/InventoryList
@onready var forge_label: Label = $Root/Tabs/Örs/ForgeLabel
@onready var forge_button: Button = $Root/Tabs/Örs/ForgeButton
@onready var market_list: ItemList = $Root/Tabs/Pazar/MarketList
@onready var school_option: OptionButton = $Root/Tabs/Savaş/SchoolRow/SchoolOption


func _ready() -> void:
	_setup_schools()
	forge_button.pressed.connect(_on_forge_pressed)
	market_list.item_activated.connect(_on_market_buy)
	inventory_list.item_activated.connect(_on_inventory_sell)
	GameState.state_changed.connect(refresh)
	resized.connect(_layout_arena)
	refresh()


func _layout_arena() -> void:
	if arena == null:
		return
	var w := arena.size.x
	if w < 40.0:
		return
	var bar_left := 36.0
	var bar_w := maxf(60.0, w - bar_left - 8.0)
	hp_bar.position = Vector2(bar_left, 20)
	hp_bar.size = Vector2(bar_w, 10)
	mp_bar.position = Vector2(bar_left, 32)
	mp_bar.size = Vector2(bar_w, 10)
	xp_bar.position = Vector2(bar_left, 44)
	xp_bar.size = Vector2(bar_w, 10)
	enemy_sprite.position = Vector2(w - 36.0, 16)
	enemy_sprite.size = Vector2(28, 34)
	spell_label.position = Vector2(bar_left, 2)
	spell_label.size = Vector2(bar_w - 40.0, 14)


func _setup_schools() -> void:
	school_option.clear()
	school_option.add_item("Ates (Pyromancy)", MagicSchoolScript.School.PYROMANCY)
	school_option.add_item("Buz (Cryomancy)", MagicSchoolScript.School.CRYOMANCY)
	school_option.add_item("Kadim (Arcane)", MagicSchoolScript.School.ARCANE)
	school_option.select(GameState.hero.school)
	school_option.item_selected.connect(func(idx: int) -> void:
		GameState.set_school(idx)
	)


func refresh() -> void:
	var hero: Hero = GameState.hero
	var enemy: Enemy = GameState.combat.enemy

	title_label.text = "Lv.%d %s" % [hero.level, MagicSchoolScript.NAMES[hero.school]]
	gold_label.text = "%d altin | %d kill" % [hero.gold, GameState.total_kills]

	wizard_sprite.color = MagicSchoolScript.COLORS[hero.school]
	enemy_sprite.color = Color(0.85, 0.2, 0.25) if enemy.status == Enemy.Status.BURNING else Color(0.55, 0.58, 0.65)
	if enemy.status == Enemy.Status.FROZEN:
		enemy_sprite.color = Color(0.55, 0.85, 1.0)

	spell_label.text = GameState.combat.last_spell_name
	if not GameState.combat.combo_flash.is_empty():
		spell_label.text = GameState.combat.combo_flash

	hp_bar.set_value(hero.hp, hero.max_hp, "HP")
	mp_bar.set_value(hero.mana, hero.max_mana, "MP")
	xp_bar.bar_color = Color(0.95, 0.78, 0.25)
	xp_bar.set_value(hero.xp, hero.xp_to_next, "XP")

	log_label.text = "\n".join(GameState.recent_log)

	inventory_list.clear()
	for i in hero.inventory.size():
		var item: Dictionary = hero.inventory[i]
		inventory_list.add_item("%s [%s]" % [item.get("name", "?"), item.get("rarity", "?")])

	var cost: int = 25 + hero.staff_enchant * 18
	var risk := 0.0 if hero.staff_enchant < 5 else (18.0 + hero.staff_enchant * 3.0)
	forge_label.text = (
		"Asa: +%d\nMaliyet: %d altin\nRisk: %.0f%%"
		% [hero.staff_enchant, cost, risk]
	)
	forge_button.text = "Arti Bas (+1)"

	market_list.clear()
	for key in GameState.market_prices.keys():
		var price: int = int(round(GameState.market_prices[key]))
		market_list.add_item("%s  %d altin" % [key, price])

	_layout_arena()


func _on_forge_pressed() -> void:
	GameState.forge_enchant()


func _on_market_buy(index: int) -> void:
	var keys := GameState.market_prices.keys()
	if index >= 0 and index < keys.size():
		GameState.buy_crystal(keys[index])


func _on_inventory_sell(index: int) -> void:
	GameState.sell_item(index)
