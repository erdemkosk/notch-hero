extends Node

signal state_changed
signal combat_event(text: String)
signal stage_info_changed

const Hero = preload("res://scripts/game/hero.gd")
const CombatEngineScript = preload("res://scripts/game/combat_engine.gd")
const MagicSchoolScript = preload("res://scripts/game/magic_school.gd")
const StageRunnerScript = preload("res://scripts/game/stage_runner.gd")
const ItemDataScript = preload("res://scripts/game/item_data.gd")
const GameBalanceScript = preload("res://scripts/game/game_balance.gd")

const TICK_SEC := 0.32

var hero: Hero
var combat: CombatEngineScript
var stage_runner: StageRunnerScript
var market_prices := {
	"fire_crystal": 12.0,
	"ice_shard": 10.0,
	"arcane_dust": 15.0,
}
var recent_log: Array[String] = []
var total_kills: int = 0
var melee_engaged := false
var inventory_unseen: int = 0
var kills_without_loot: int = 0

var _tick_timer: Timer


func _ready() -> void:
	GameBalanceScript.load_config()
	ItemDataScript.load_catalog()
	ItemDataScript.preload_all_textures()
	hero = Hero.new()
	hero.loot_added.connect(_on_loot_added)
	combat = CombatEngineScript.new(hero)
	combat.spell_cast.connect(_on_spell_cast)
	combat.enemy_defeated.connect(_on_enemy_defeated)
	combat.combo_triggered.connect(_on_combo)
	combat.hero_died.connect(_on_hero_died)

	stage_runner = StageRunnerScript.new()
	stage_runner.load()
	stage_runner.stage_entered.connect(_on_stage_entered)

	_tick_timer = Timer.new()
	_tick_timer.wait_time = TICK_SEC
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)
	_tick_timer.start()

	call_deferred("_start_stage_run")


func _start_stage_run() -> void:
	stage_runner.start_run(hero)


func on_wave_cleared() -> void:
	stage_runner.on_wave_cleared(hero)
	state_changed.emit()


func _on_stage_entered(_info: Dictionary) -> void:
	stage_info_changed.emit()
	state_changed.emit()


func _on_hero_died() -> void:
	melee_engaged = false
	# Defer so combat_strip hero_died handler runs first (stop melee / lock UI).
	call_deferred("_restart_stage_after_death")
	state_changed.emit()


func _restart_stage_after_death() -> void:
	stage_runner.on_hero_died(hero)
	_log("You died! Restarting stage from wave 1.")
	state_changed.emit()


func set_school(school: int) -> void:
	hero.school = school as MagicSchoolScript.School
	_log("School: %s" % MagicSchoolScript.NAMES[hero.school])
	state_changed.emit()


func set_melee_engaged(active: bool) -> void:
	if melee_engaged == active:
		return
	melee_engaged = active


func combat_melee_exchange() -> void:
	if not melee_engaged:
		return
	combat.tick_melee()
	state_changed.emit()


func combat_tick() -> void:
	if melee_engaged:
		combat.tick_melee()
	else:
		combat.tick_passive()
	_drift_market()
	state_changed.emit()


func forge_enchant() -> bool:
	var cost: int = 25 + hero.staff_enchant * 18
	if hero.gold < cost:
		_log("Forge: not enough gold (%d)" % cost)
		return false

	hero.gold -= cost
	if hero.staff_enchant >= 5 and randf() < 0.18 + hero.staff_enchant * 0.03:
		hero.staff_enchant = 0
		_log("Forge: staff BURNED! +0")
		state_changed.emit()
		return false

	hero.staff_enchant += 1
	_log("Forge: staff is now +%d" % hero.staff_enchant)
	state_changed.emit()
	return true


func mark_inventory_seen() -> void:
	if inventory_unseen <= 0:
		return
	inventory_unseen = 0
	state_changed.emit()


func _on_loot_added(_item: Dictionary) -> void:
	inventory_unseen += 1
	kills_without_loot = 0
	state_changed.emit()


func should_pity_loot() -> bool:
	return kills_without_loot >= GameBalanceScript.pity_kills()


func record_kill_without_loot() -> void:
	kills_without_loot += 1


func _gain_inventory_item(item: Dictionary) -> void:
	hero.inventory.append(item)
	inventory_unseen += 1


func sell_item(index: int) -> bool:
	if index < 0 or index >= hero.inventory.size():
		return false
	var item: Dictionary = hero.inventory[index]
	var def := ItemDataScript.get_def(str(item.get("id", "")))
	var stats := ItemDataScript.compute_stats(def)
	var value := 8 + int(stats.get("power", item.get("power", 1))) * 6
	hero.gold += value
	hero.inventory.remove_at(index)
	_log("Sold: %s (+%d gold)" % [ItemDataScript.display_name(item), value])
	state_changed.emit()
	return true


func equip_from_inventory(inventory_index: int, equip_slot: String) -> bool:
	if inventory_index < 0 or inventory_index >= hero.inventory.size():
		return false
	if not ItemDataScript.EQUIP_SLOTS.has(equip_slot):
		return false

	var item: Dictionary = hero.inventory[inventory_index]
	var item_slot := ItemDataScript.item_slot(item)
	if not ItemDataScript.slot_accepts(item_slot, equip_slot):
		return false

	hero.inventory.remove_at(inventory_index)
	var current: Variant = hero.equipment.get(equip_slot)
	if current != null and typeof(current) == TYPE_DICTIONARY:
		_gain_inventory_item(current)

	hero.equipment[equip_slot] = item
	hero.refresh_combat_stats()
	_log("Equipped: %s" % ItemDataScript.display_name(item))
	state_changed.emit()
	return true


func unequip_slot(equip_slot: String) -> bool:
	if not hero.equipment.has(equip_slot):
		return false

	var current: Variant = hero.equipment.get(equip_slot)
	if current == null or typeof(current) != TYPE_DICTIONARY:
		return false

	_gain_inventory_item(current)
	hero.equipment[equip_slot] = null
	hero.refresh_combat_stats()
	_log("Unequipped: %s" % ItemDataScript.display_name(current))
	state_changed.emit()
	return true


func swap_equipment(from_slot: String, to_slot: String) -> bool:
	if from_slot == to_slot:
		return false
	if not hero.equipment.has(from_slot) or not hero.equipment.has(to_slot):
		return false

	var from_item: Variant = hero.equipment[from_slot]
	if from_item == null or typeof(from_item) != TYPE_DICTIONARY:
		return false

	var to_item: Variant = hero.equipment[to_slot]
	var from_type := ItemDataScript.item_slot(from_item)

	if to_item != null and typeof(to_item) == TYPE_DICTIONARY:
		if not ItemDataScript.slot_accepts(from_type, to_slot):
			return false
		if not ItemDataScript.slot_accepts(ItemDataScript.item_slot(to_item), from_slot):
			return false
		hero.equipment[from_slot] = to_item
		hero.equipment[to_slot] = from_item
	else:
		if not ItemDataScript.slot_accepts(from_type, to_slot):
			return false
		hero.equipment[to_slot] = from_item
		hero.equipment[from_slot] = null

	hero.refresh_combat_stats()
	state_changed.emit()
	return true


func buy_crystal(key: String) -> bool:
	if not market_prices.has(key):
		return false
	var price: float = market_prices[key]
	var cost := int(round(price))
	if hero.gold < cost:
		_log("Market: not enough gold")
		return false
	hero.gold -= cost
	hero.add_loot({"name": key, "rarity": "trade", "power": 1})
	_log("Bought: %s (-%d gold)" % [key, cost])
	state_changed.emit()
	return true


func _on_tick() -> void:
	combat_tick()


func _on_spell_cast(info: Dictionary) -> void:
	if info.get("combo", false):
		return
	var dmg: float = info.get("damage", 0.0)
	combat_event.emit("%s %.0f" % [info.get("name", "?"), dmg])


func _on_enemy_defeated(rewards: Dictionary) -> void:
	total_kills += 1
	var msg := "+%d XP, +%d gold" % [rewards.get("xp", 0), rewards.get("gold", 0)]
	if rewards.get("leveled", false):
		msg += " | LEVEL UP!"
	if rewards.get("item_dropped", false):
		var item: Dictionary = rewards.get("item", {}) as Dictionary
		msg += " | Loot: %s" % ItemDataScript.display_name(item)
	_log(msg)


func _on_combo(name: String, damage: float) -> void:
	_log("%s %.0f damage!" % [name, damage])
	combat_event.emit(name)


func _drift_market() -> void:
	for key in market_prices.keys():
		market_prices[key] = maxf(5.0, market_prices[key] + randf_range(-1.2, 1.2))


func _log(text: String) -> void:
	recent_log.push_front(text)
	if recent_log.size() > 6:
		recent_log.resize(6)
	combat_event.emit(text)
