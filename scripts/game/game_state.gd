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
const StageDataScript = preload("res://scripts/game/stage_data.gd")

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
var last_offline_progress: Dictionary = {}
var market_prices := {
	"fire_crystal": 12.0,
	"ice_shard": 10.0,
	"arcane_dust": 15.0,
}
var market_offers: Array = []
var market_next_refresh_time: float = 0.0
const MARKET_REFRESH_INTERVAL := 7200.0 # 2 hours
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
	generate_market_offers()
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

	var offers: Variant = data.get("market_offers", null)
	if typeof(offers) == TYPE_ARRAY:
		market_offers = offers.duplicate(true)
	else:
		market_offers = []
	market_next_refresh_time = float(data.get("market_next_refresh_time", 0.0))

	melee_engaged = false
	combat.clear_wave()
	stage_runner.restore_from_save(
		hero,
		int(data.get("stage_index", 0)),
		int(data.get("wave_index", 0))
	)
	
	# Calculate offline progress if save_time exists
	var last_save_time := float(data.get("save_time", 0.0))
	if last_save_time > 0.0:
		var current_time := Time.get_unix_time_from_system()
		var elapsed_seconds := current_time - last_save_time
		if elapsed_seconds >= 60.0: # Trigger only if gone for more than 60 seconds
			_calculate_offline_progress(elapsed_seconds)

	session_active = true
	session_paused = false
	_check_market_refresh()
	refresh_combat_pacing()
	state_changed.emit()
	return true


func _calculate_offline_progress(elapsed_seconds: float) -> void:
	last_offline_progress.clear()
	# Cap offline progress to 12 hours (43200 seconds)
	var time_to_simulate := minf(elapsed_seconds, 43200.0)
	
	# Determine average stats of the current stage
	var stage := stage_runner.current_stage()
	if stage.is_empty():
		return

	var total_hp := 0.0
	var total_gold := 0.0
	var total_xp := 0.0
	var enemy_count := 0

	var waves: Array = stage.get("waves", [])
	for wave in waves:
		for enemy_type in wave.get("enemies", []):
			var def := StageDataScript.get_enemy_def(enemy_type)
			var is_boss := bool(def.get("boss", false))

			# Calculate base rewards
			var base_gold := int(round(float(def.get("gold", 5)) * (1.4 if is_boss else 1.0)))
			var base_xp := int(round(float(def.get("xp", 8)) * (1.5 if is_boss else 1.0)))

			# Calculate base hp
			var hp_base := float(def.get("hp", 28.0))
			if is_boss:
				# Use boss scaling logic
				var hp_base_cfg := float(GameBalanceScript.stage_cfg().get("boss_hp_base", 32.0))
				var per_layer := float(GameBalanceScript.stage_cfg().get("boss_scale_per_layer", 0.28))
				var weight := float(def.get("boss_weight", 1.0))
				var layer := stage_runner.progression_layer()
				var tier := 1.0 + float(layer) * per_layer
				hp_base = hp_base_cfg * tier * weight

			var difficulty_mul := stage_runner.enemy_difficulty_for(enemy_type)
			var stage_cfg := GameBalanceScript.stage_cfg()
			var hp_level_mul := float(stage_cfg.get("enemy_boss_level_hp_mul" if is_boss else "enemy_level_hp_mul", 0.12 if is_boss else 0.08))
			var level_mul := 1.0 + float(hero.level - 1) * hp_level_mul
			var role := str(def.get("role", "melee"))
			var role_hp_mods: Dictionary = stage_cfg.get("enemy_role_hp_mod", {"melee": 1.0, "ranged": 0.85, "charger": 1.28})
			var role_hp := float(role_hp_mods.get(role, 1.0))

			var enemy_hp := hp_base * level_mul * difficulty_mul * role_hp * GameBalanceScript.enemy_hp_mul()

			total_hp += enemy_hp
			total_gold += base_gold
			total_xp += base_xp
			enemy_count += 1

	if enemy_count == 0:
		return

	var avg_hp := total_hp / enemy_count
	var avg_gold := total_gold / enemy_count
	var avg_xp := total_xp / enemy_count

	# Calculate player DPS
	var attacks_per_second := 1.0 / (TICK_SEC / clampf(hero.attack_speed_multiplier(), 0.55, 2.5))
	var player_dps := hero.attack_power() * attacks_per_second
	
	# Average time to kill (add 3.5 seconds transition/spawn delay per kill to model movement/wave spawn)
	var avg_kill_time := maxf(1.5, avg_hp / maxf(1.0, player_dps)) + 3.5
	
	# Offline Efficiency (Base efficiency set to 5%)
	var efficiency := clampf(0.05 + hero.get_talent_offline_modifier(), 0.01, 1.0)
	
	# Compute total kills offline
	var total_kills_gained := int(floor((time_to_simulate / avg_kill_time) * efficiency))
	if total_kills_gained <= 0:
		return

	# Calculate Gold and XP gained
	var gold_earned := int(round(total_kills_gained * avg_gold * (1.0 + hero.get_talent_gold_modifier())))
	var xp_earned := int(round(total_kills_gained * avg_xp * (1.0 + hero.get_talent_xp_modifier())))

	# Apply rewards
	hero.gold += gold_earned
	var leveled := hero.add_xp(xp_earned)
	total_kills += total_kills_gained

	# Roll item loot
	var items_added: Array[Dictionary] = []
	var item_drop_chance := GameBalanceScript.drop_chance(false) * efficiency
	var items_dropped_count := int(round(total_kills_gained * item_drop_chance))
	
	var standard_scrolls := 0
	var blessed_scrolls := 0
	var gear_items := 0
	
	var rolls := mini(items_dropped_count, 100)
	for r in range(rolls):
		var scroll_rng := randf()
		var std_chance := 0.04
		var bls_chance := 0.008
		if scroll_rng < bls_chance:
			blessed_scrolls += 1
		elif scroll_rng < bls_chance + std_chance:
			standard_scrolls += 1
		else:
			gear_items += 1
			
	if items_dropped_count > rolls:
		var multiplier := float(items_dropped_count) / float(rolls)
		standard_scrolls = int(round(standard_scrolls * multiplier))
		blessed_scrolls = int(round(blessed_scrolls * multiplier))
		gear_items = int(round(gear_items * multiplier))

	# Add scrolls to inventory
	if standard_scrolls > 0:
		var stack := ItemDataScript.make_consumable_stack("scrolls/upgrade-standard", standard_scrolls)
		var res := hero.add_stackable_to_inventory(stack)
		var added := int(res.get("added", 0))
		if added > 0:
			var added_stack := stack.duplicate(true)
			added_stack["count"] = added
			items_added.append(added_stack)
			inventory_unseen += 1
			
	if blessed_scrolls > 0:
		var stack := ItemDataScript.make_consumable_stack("scrolls/upgrade-blessed", blessed_scrolls)
		var res := hero.add_stackable_to_inventory(stack)
		var added := int(res.get("added", 0))
		if added > 0:
			var added_stack := stack.duplicate(true)
			added_stack["count"] = added
			items_added.append(added_stack)
			inventory_unseen += 1

	# Add gear items to inventory
	var gear_added := 0
	for g in range(gear_items):
		if hero.has_inventory_room():
			var gear := ItemDataScript.roll_loot_instance(ItemDataScript.current_ilvl())
			if hero.add_loot(gear):
				items_added.append(gear)
				gear_added += 1
		else:
			break

	# Save details for the UI Report
	last_offline_progress = {
		"elapsed_seconds": elapsed_seconds,
		"gold": gold_earned,
		"xp": xp_earned,
		"items": items_added,
		"leveled": leveled
	}
	_log("Offline Progress: killed %d enemies." % total_kills_gained)
	request_save()


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
	combat.clear_wave()
	combat.cancel_exchange()
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


func combat_begin_round() -> String:
	if not melee_engaged:
		return "none"
	var phase := combat.begin_combat_round()
	state_changed.emit()
	return phase


func refresh_combat_pacing() -> void:
	if _tick_timer == null or hero == null:
		return
	_tick_timer.wait_time = TICK_SEC / clampf(hero.attack_speed_multiplier(), 0.55, 2.5)


func combat_tick() -> void:
	if not session_active or session_paused:
		return
	_check_market_refresh()
	if not melee_engaged:
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
	if hero.hp <= 0.0 or _potion_cooldown > 0 or not melee_engaged:
		return

	var hp_ratio := hero.hp / maxf(1.0, hero.max_hp)
	if hp_ratio <= GameBalanceScript.auto_hp_threshold():
		var stack := hero.potion_bar_stack("health")
		if not stack.is_empty():
			_consume_potion_bar("health")
			return

	var mana_ratio := hero.mana / maxf(1.0, hero.max_mana)
	if mana_ratio <= GameBalanceScript.auto_mana_threshold():
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
	if overflow > 0:
		var leftover := ItemDataScript.make_consumable_stack(str(item.get("id", "")), overflow)
		hero.add_stackable_to_inventory(leftover)

	request_save()
	state_changed.emit()
	return true


func move_inventory_stack(from_index: int, to_index: int) -> bool:
	if from_index == to_index:
		return false
	if not hero.merge_inventory_slots(from_index, to_index):
		return false
	request_save()
	state_changed.emit()
	return true


func move_potion_bar_to_inventory(kind: String, prefer_index: int = -1) -> bool:
	var stack := hero.clear_potion_bar_slot(kind)
	if stack.is_empty():
		return false

	var result := hero.add_stackable_to_inventory(stack, prefer_index)
	if int(result.get("added", 0)) <= 0:
		hero.potion_bar[kind] = stack
		_log("Bag full.")
		return false

	var remaining: Dictionary = result.get("remaining", {}) as Dictionary
	if not remaining.is_empty():
		hero.potion_bar[kind] = remaining
		_log("Bag full — potion bar kept the rest.")

	inventory_unseen += 1
	request_save()
	state_changed.emit()
	return true


func attempt_forge_upgrade(item_source: String, item_key: Variant, scroll_id: String) -> Dictionary:
	var item: Variant = null
	if item_source == "inventory":
		var idx := int(item_key)
		if idx >= 0 and idx < hero.inventory.size():
			item = hero.inventory[idx]
	elif item_source == "equipment":
		var slot := str(item_key)
		item = hero.equipment.get(slot)

	if item == null or typeof(item) != TYPE_DICTIONARY:
		return {"success": false, "reason": "Item not found"}

	# Find scroll
	var scroll_idx := -1
	for i in range(hero.inventory.size()):
		var inv_item := hero.inventory[i]
		if inv_item.get("id", "") == scroll_id and ItemDataScript.stack_count(inv_item) > 0:
			scroll_idx = i
			break

	if scroll_idx == -1:
		return {"success": false, "reason": "Scroll not found"}

	var current_upg := int(item.get("upgrade", 0))
	if current_upg >= 10:
		return {"success": false, "reason": "Item is already +10"}

	var chance := 0.0
	if scroll_id == "scrolls/upgrade-standard":
		var rates := [1.0, 0.95, 0.85, 0.65, 0.50, 0.35, 0.20, 0.10, 0.04, 0.01]
		chance = rates[current_upg]
	elif scroll_id == "scrolls/upgrade-blessed":
		var rates := [1.0, 1.0, 1.0, 0.90, 0.75, 0.60, 0.40, 0.25, 0.12, 0.05]
		chance = rates[current_upg]

	var roll := randf()
	var is_success := roll <= chance

	# Deletion / upgrades
	if is_success:
		item["upgrade"] = current_upg + 1
		_log("Forge Success: %s is now +%d!" % [ItemDataScript.display_name(item), current_upg + 1])
	else:
		# Burn the item!
		if item_source == "inventory":
			var idx := int(item_key)
			hero.inventory.remove_at(idx)
		elif item_source == "equipment":
			var slot := str(item_key)
			hero.equipment[slot] = null
		_log("Forge FAIL: %s burned!" % ItemDataScript.display_name(item))

	# Deduct scroll (find it again since indices might have changed if item was in inventory and removed)
	var final_scroll_idx := -1
	for i in range(hero.inventory.size()):
		var inv_item := hero.inventory[i]
		if inv_item.get("id", "") == scroll_id and ItemDataScript.stack_count(inv_item) > 0:
			final_scroll_idx = i
			break

	if final_scroll_idx != -1:
		var scroll_item := hero.inventory[final_scroll_idx]
		var new_count := ItemDataScript.stack_count(scroll_item) - 1
		if new_count <= 0:
			hero.inventory.remove_at(final_scroll_idx)
		else:
			scroll_item["count"] = new_count
			hero.inventory[final_scroll_idx] = scroll_item

	hero.refresh_combat_stats()
	refresh_combat_pacing()
	request_save()
	state_changed.emit()

	return {"success": true, "upgraded": is_success, "new_level": current_upg + 1 if is_success else 0}


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


func generate_market_offers() -> void:
	market_offers.clear()
	
	# Slot 0: Potion
	var pot_id := "potions/minor-health" if randf() < 0.5 else "potions/minor-mana"
	if randf() < 0.35:
		pot_id = "potions/health" if randf() < 0.5 else "potions/mana"
	var pot_count := randi_range(2, 5)
	var pot_item := ItemDataScript.make_consumable_stack(pot_id, pot_count)
	var pot_price := randi_range(25, 45) * pot_count
	market_offers.append({"item": pot_item, "price": pot_price, "bought": false})

	# Slot 1: Potion
	var pot_id2 := "potions/minor-mana" if pot_id == "potions/minor-health" else "potions/minor-health"
	var pot_count2 := randi_range(2, 5)
	var pot_item2 := ItemDataScript.make_consumable_stack(pot_id2, pot_count2)
	var pot_price2 := randi_range(25, 45) * pot_count2
	market_offers.append({"item": pot_item2, "price": pot_price2, "bought": false})

	# Slot 2: Material
	var mats: Array[String] = ["materials/fire-crystal", "materials/ice-shard", "materials/arcane-dust"]
	var mat_id := mats[randi() % mats.size()]
	var mat_count := randi_range(1, 3)
	var mat_item := ItemDataScript.make_consumable_stack(mat_id, mat_count)
	var mat_price := randi_range(45, 75) * mat_count
	market_offers.append({"item": mat_item, "price": mat_price, "bought": false})

	# Slot 3: Standard Scroll
	var scr_count := randi_range(1, 3)
	var scr_item := ItemDataScript.make_consumable_stack("scrolls/upgrade-standard", scr_count)
	var scr_price := randi_range(130, 190) * scr_count
	market_offers.append({"item": scr_item, "price": scr_price, "bought": false})

	# Slot 4: Blessed Scroll
	var slot4_item: Dictionary
	var slot4_price: int
	if randf() < 0.6:
		var b_count := randi_range(1, 2)
		slot4_item = ItemDataScript.make_consumable_stack("scrolls/upgrade-blessed", b_count)
		slot4_price = randi_range(380, 580) * b_count
	else:
		var b_count := randi_range(2, 4)
		slot4_item = ItemDataScript.make_consumable_stack("scrolls/upgrade-standard", b_count)
		slot4_price = randi_range(120, 175) * b_count
	market_offers.append({"item": slot4_item, "price": slot4_price, "bought": false})

	# Slot 5: Gear (High gold cost)
	var ilvl := ItemDataScript.current_ilvl()
	var gear := ItemDataScript.roll_loot_instance(ilvl)
	var rarity := ItemDataScript.item_rarity(gear)
	var gear_price := randi_range(120, 220)
	if rarity == "rare":
		gear_price = randi_range(450, 750)
	elif rarity == "unique":
		gear_price = randi_range(1200, 2300)
	market_offers.append({"item": gear, "price": gear_price, "bought": false})

	market_next_refresh_time = Time.get_unix_time_from_system() + MARKET_REFRESH_INTERVAL
	request_save()
	state_changed.emit()


func buy_market_offer(index: int) -> bool:
	if index < 0 or index >= market_offers.size():
		return false
	var offer: Dictionary = market_offers[index]
	if offer.get("bought", false):
		_log("Market: already bought")
		return false
	
	var price: int = offer.get("price", 0)
	var discount := 0.0
	if hero != null and hero.has_method("get_talent_shop_discount_modifier"):
		discount = hero.get_talent_shop_discount_modifier()
	var cost := int(round(price * (1.0 - discount)))
	
	if hero.gold < cost:
		_log("Market: not enough gold")
		return false
	
	var item: Dictionary = offer.get("item", {})
	if item.is_empty():
		return false
	
	# Try to add to inventory
	var added := false
	if ItemDataScript.is_stackable(item):
		var res := hero.add_stackable_to_inventory(item)
		if int(res.get("added", 0)) > 0:
			added = true
	else:
		if hero.has_inventory_room():
			if hero.add_loot(item):
				added = true
	
	if not added:
		_log("Bag full.")
		return false
	
	hero.gold -= cost
	offer["bought"] = true
	_log("Bought: %s (-%d gold)" % [ItemDataScript.display_name(item), cost])
	request_save()
	state_changed.emit()
	return true


func _check_market_refresh() -> void:
	if market_next_refresh_time == 0.0:
		generate_market_offers()
		return
	if Time.get_unix_time_from_system() >= market_next_refresh_time:
		generate_market_offers()


func buy_crystal(key: String) -> bool:
	if not market_prices.has(key):
		return false
	var price: float = market_prices[key]
	var discount := 0.0
	if hero != null and hero.has_method("get_talent_shop_discount_modifier"):
		discount = hero.get_talent_shop_discount_modifier()
	var cost := int(round(price * (1.0 - discount)))
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
	_log(msg)
	request_save()


func grant_kill_loot(rewards: Dictionary) -> Dictionary:
	var result := {
		"item_dropped": false,
		"potion_dropped": false,
		"bag_full": false,
	}

	var item: Dictionary = rewards.get("item", {}) as Dictionary
	if not item.is_empty():
		if hero.add_loot(item):
			result["item_dropped"] = true
		else:
			result["bag_full"] = true

	var potion: Dictionary = rewards.get("potion", {}) as Dictionary
	if not potion.is_empty():
		if hero.add_loot(potion):
			result["potion_dropped"] = true
		elif not result["bag_full"]:
			result["bag_full"] = true

	if result["item_dropped"]:
		_log("Loot: %s" % ItemDataScript.display_name(item))
	if result["potion_dropped"]:
		_log("Potion: %s" % ItemDataScript.display_name(potion))
	elif result["bag_full"]:
		_log("Bag full!")

	if result["item_dropped"] or result["potion_dropped"] or result["bag_full"]:
		request_save()

	return result


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
