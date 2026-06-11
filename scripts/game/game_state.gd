extends Node

signal state_changed
signal combat_event(text: String)
signal stage_info_changed
signal potion_bar_used(kind: String, applied: Dictionary)

const Hero = preload("res://scripts/game/hero.gd")
const CombatEngineScript = preload("res://scripts/game/combat_engine.gd")
const MagicSchoolScript = preload("res://scripts/game/magic_school.gd")
const StageRunnerScript = preload("res://scripts/game/stage_runner.gd")
const ItemDataScript = preload("res://scripts/game/item_data.gd")
const GameBalanceScript = preload("res://scripts/game/game_balance.gd")

const SaveServiceScript = preload("res://scripts/game/save_service.gd")

const TICK_SEC := 0.32

const MARKET_ITEM_IDS := {
	"fire_crystal": "materials/fire-crystal",
	"ice_shard": "materials/ice-shard",
	"arcane_dust": "materials/arcane-dust",
	"minor_health": "potions/minor-health",
	"minor_mana": "potions/minor-mana",
	"health_potion": "potions/health",
	"mana_potion": "potions/mana",
}

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
var _potion_cooldown: int = 0

var _tick_timer: Timer


func has_hero() -> bool:
	return hero != null


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
		"minor_health": 8.0,
		"minor_mana": 8.0,
		"health_potion": 18.0,
		"mana_potion": 18.0,
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
	if _potion_cooldown > 0:
		_potion_cooldown -= 1
	_try_auto_potions()
	_drift_market()
	state_changed.emit()


func _try_auto_potions() -> void:
	if hero.hp <= 0.0 or _potion_cooldown > 0:
		return

	var hp_ratio := hero.hp / maxf(1.0, hero.max_hp)
	if hp_ratio < GameBalanceScript.auto_hp_threshold():
		var stack := hero.potion_bar_stack("health")
		if not stack.is_empty():
			_consume_potion_bar("health")
			return

	var mana_ratio := hero.mana / maxf(1.0, hero.max_mana)
	if mana_ratio < GameBalanceScript.auto_mana_threshold():
		var stack := hero.potion_bar_stack("mana")
		if not stack.is_empty():
			_consume_potion_bar("mana")


func _consume_potion_bar(kind: String) -> bool:
	var applied := hero.use_potion_bar(kind)
	if applied.is_empty():
		return false

	_potion_cooldown = GameBalanceScript.potion_use_cooldown_ticks()
	var id := str(applied.get("item_id", ""))
	var item_name := ItemDataScript.display_name({"id": id})
	var heal := float(applied.get("heal_hp", 0.0))
	var mana := float(applied.get("restore_mana", 0.0))
	if heal > 0.0:
		_log("Auto: %s (+%.0f HP)" % [item_name, heal])
	elif mana > 0.0:
		_log("Auto: %s (+%.0f MP)" % [item_name, mana])
	potion_bar_used.emit(kind, applied)
	request_save()
	state_changed.emit()
	return true


func move_inventory_to_potion_bar(inventory_index: int, kind: String) -> bool:
	if inventory_index < 0 or inventory_index >= hero.inventory.size():
		return false
	if not ItemDataScript.POTION_KINDS.has(kind):
		return false

	var item: Dictionary = hero.inventory[inventory_index]
	if ItemDataScript.potion_kind(item) != kind:
		return false

	var result := hero.add_to_potion_bar(item)
	var added := int(result.get("added", 0))
	if added <= 0:
		return false

	var remaining := ItemDataScript.stack_count(item) - added
	if remaining <= 0:
		hero.inventory.remove_at(inventory_index)
	else:
		item["count"] = remaining
		hero.inventory[inventory_index] = item

	var overflow := int(result.get("overflow", 0))
	if overflow > 0 and hero.has_inventory_room():
		hero.inventory.append(ItemDataScript.make_consumable_stack(str(item.get("id", "")), overflow))

	request_save()
	state_changed.emit()
	return true


func move_potion_bar_to_inventory(kind: String) -> bool:
	if not hero.has_inventory_room():
		_log("Bag full.")
		return false

	var stack := hero.clear_potion_bar_slot(kind)
	if stack.is_empty():
		return false

	hero.inventory.append(stack)
	inventory_unseen += 1

	request_save()
	state_changed.emit()
	return true


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
	if ItemDataScript.is_consumable(item) and ItemDataScript.stack_count(item) > 1:
		item["count"] = ItemDataScript.stack_count(item) - 1
		hero.inventory[index] = item
	else:
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

	var item_id := str(MARKET_ITEM_IDS.get(key, ""))
	if item_id.is_empty():
		return false

	hero.gold -= cost
	var item := ItemDataScript.make_consumable_stack(item_id, 1)
	if not hero.add_loot(item):
		hero.gold += cost
		_log("Bag full.")
		return false

	_log("Bought: %s (-%d gold)" % [ItemDataScript.display_name(item), cost])
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
	if rewards.get("potion_dropped", false):
		var potion: Dictionary = rewards.get("potion", {}) as Dictionary
		msg += " | Potion: %s" % ItemDataScript.display_name(potion)
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
