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

const SaveServiceScript = preload("res://scripts/game/save_service.gd")

const TICK_SEC := 0.32

var hero: Hero
var combat: CombatEngineScript
var stage_runner: StageRunnerScript
var session_active := false
var session_paused := false
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

	_tick_timer.start()


func start_new_game(player_name: String) -> void:
	hero.reset_for_new_game(player_name)
	total_kills = 0
	kills_without_loot = 0
	melee_engaged = false
	_reset_market_prices()
	combat.clear_wave()
	stage_runner.start_run(hero)
	session_active = true
	session_paused = false
	refresh_combat_pacing()
	request_save()
	state_changed.emit()


func pause_session() -> void:
	if not session_active:
		return
	session_paused = true
	melee_engaged = false
	request_save()
	state_changed.emit()


func resume_session() -> void:
	if not session_active:
		return
	session_paused = false
	state_changed.emit()


func continue_game() -> bool:
	var data := SaveServiceScript.load_game()
	if data.is_empty():
		return false

	hero.apply_dict(data.get("hero", {}) as Dictionary)
	var saved_name := str(data.get("player_name", ""))
	if not saved_name.is_empty():
		hero.player_name = saved_name

	total_kills = int(data.get("total_kills", 0))
	kills_without_loot = int(data.get("kills_without_loot", 0))
	var prices: Variant = data.get("market_prices", null)
	if typeof(prices) == TYPE_DICTIONARY:
		market_prices = prices.duplicate()

	melee_engaged = false
	combat.clear_wave()
	stage_runner.restore_from_save(
		hero,
		int(data.get("stage_index", 0)),
		int(data.get("wave_index", 0))
	)
	session_active = true
	session_paused = false
	refresh_combat_pacing()
	state_changed.emit()
	return true


func request_save() -> void:
	if not session_active:
		return
	SaveServiceScript.save_game(SaveServiceScript.build_payload())


func _reset_market_prices() -> void:
	market_prices = {
		"fire_crystal": 12.0,
		"ice_shard": 10.0,
		"arcane_dust": 15.0,
	}


func on_wave_cleared() -> void:
	stage_runner.on_wave_cleared(hero)
	request_save()
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
	request_save()
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


func refresh_combat_pacing() -> void:
	if _tick_timer == null or hero == null:
		return
	_tick_timer.wait_time = TICK_SEC / clampf(hero.attack_speed_multiplier(), 0.55, 2.5)


func combat_tick() -> void:
	if not session_active or session_paused:
		return
	if melee_engaged:
		combat.tick_melee()
	else:
		combat.tick_passive()
	var life_regen := hero.life_regen_per_tick()
	if life_regen > 0.0 and hero.hp > 0.0:
		hero.hp = minf(hero.max_hp, hero.hp + life_regen)
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
		request_save()
		state_changed.emit()
		return false

	hero.staff_enchant += 1
	_log("Forge: staff is now +%d" % hero.staff_enchant)
	request_save()
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
	request_save()
	state_changed.emit()


func should_pity_loot() -> bool:
	return kills_without_loot >= GameBalanceScript.pity_kills()


func record_kill_without_loot() -> void:
	kills_without_loot += 1


func _gain_inventory_item(item: Dictionary) -> bool:
	if not hero.has_inventory_room():
		return false
	hero.inventory.append(item)
	inventory_unseen += 1
	return true


func _projected_bag_capacity(replace_slot: String, replace_item: Variant) -> int:
	var items: Array = []
	for slot in ItemDataScript.EQUIP_SLOTS:
		var equipped: Variant = hero.equipment.get(slot)
		if slot == replace_slot:
			if replace_item != null and typeof(replace_item) == TYPE_DICTIONARY:
				items.append(replace_item)
		elif equipped != null and typeof(equipped) == TYPE_DICTIONARY:
			items.append(equipped)
	return hero.bag_slot_capacity_for_equipped(items)


func sell_item(index: int) -> bool:
	if index < 0 or index >= hero.inventory.size():
		return false
	var item: Dictionary = hero.inventory[index]
	var value := ItemDataScript.sell_value(item)
	hero.gold += value
	hero.inventory.remove_at(index)
	_log("Sold: %s (+%d gold)" % [ItemDataScript.display_name(item), value])
	request_save()
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

	var current: Variant = hero.equipment.get(equip_slot)
	var inv_after := hero.inventory.size() - 1
	if current != null and typeof(current) == TYPE_DICTIONARY:
		inv_after += 1
	var new_cap := _projected_bag_capacity(equip_slot, item)
	if inv_after > new_cap:
		_log("Bag full — need more bag slots.")
		return false

	hero.inventory.remove_at(inventory_index)
	if current != null and typeof(current) == TYPE_DICTIONARY:
		if not _gain_inventory_item(current):
			hero.inventory.insert(inventory_index, item)
			_log("Bag full — can't swap gear.")
			return false

	hero.equipment[equip_slot] = item
	hero.refresh_combat_stats()
	refresh_combat_pacing()
	request_save()
	_log("Equipped: %s" % ItemDataScript.display_name(item))
	state_changed.emit()
	return true


func unequip_slot(equip_slot: String) -> bool:
	if not hero.equipment.has(equip_slot):
		return false

	var current: Variant = hero.equipment.get(equip_slot)
	if current == null or typeof(current) != TYPE_DICTIONARY:
		return false

	var new_cap := _projected_bag_capacity(equip_slot, null)
	if hero.inventory.size() + 1 > new_cap:
		_log("Bag full — free space before unequipping.")
		return false

	if not _gain_inventory_item(current):
		_log("Bag full.")
		return false

	hero.equipment[equip_slot] = null
	hero.refresh_combat_stats()
	refresh_combat_pacing()
	request_save()
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
	refresh_combat_pacing()
	request_save()
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
	if not hero.add_loot({"name": key, "rarity": "trade", "power": 1}):
		hero.gold += cost
		_log("Bag full.")
		return false
	_log("Bought: %s (-%d gold)" % [key, cost])
	request_save()
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
	elif rewards.get("bag_full", false):
		msg += " | Bag full!"
	_log(msg)
	request_save()


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
