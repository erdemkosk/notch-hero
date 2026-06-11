extends RefCounted

const MagicSchoolScript = preload("res://scripts/game/magic_school.gd")
const ItemDataScript = preload("res://scripts/game/item_data.gd")
const GameBalanceScript = preload("res://scripts/game/game_balance.gd")

var school: MagicSchoolScript.School = MagicSchoolScript.School.PYROMANCY
var level: int = 1
var xp: int = 0
var xp_to_next: int = 40
var gold: int = 0

var hp: float = 10.0
var max_hp: float = 10.0
var mana: float = 40.0
var max_mana: float = 40.0

var intelligence: int = 0
var spell_power: int = 0
var mana_regen: float = 3.0

var staff_enchant: int = 0
var inventory: Array[Dictionary] = []
var equipment: Dictionary = {}

var level_hp_bonus: float = 0.0
var level_spell_power_bonus: int = 0
var player_name := ""

signal loot_added(item: Dictionary)


func _init() -> void:
	_reset_equipment()
	refresh_combat_stats()
	hp = max_hp
	mana = max_mana


func _reset_equipment() -> void:
	equipment.clear()
	for slot in ItemDataScript.EQUIP_SLOTS:
		equipment[slot] = null


func xp_progress() -> float:
	if xp_to_next <= 0:
		return 1.0
	return clampf(float(xp) / float(xp_to_next), 0.0, 1.0)


func add_xp(amount: int) -> bool:
	xp += amount
	var leveled := false
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		leveled = true
		_on_level_up()
	return leveled


func _on_level_up() -> void:
	var cfg := GameBalanceScript.hero_cfg()
	xp_to_next = 35 + level * 18
	level_hp_bonus += float(cfg.get("level_hp_gain", 2.0))
	level_spell_power_bonus += int(cfg.get("level_spell_power_gain", 1))
	intelligence += 1
	refresh_combat_stats()
	hp = max_hp
	mana = max_mana


func refresh_combat_stats() -> void:
	var cfg := GameBalanceScript.hero_cfg()
	var eq := equipment_stats()
	var prev_max_hp := max_hp
	var prev_max_mana := max_mana

	max_hp = float(cfg.get("base_max_hp", 5.0)) + float(eq.get("max_hp", 0.0)) + level_hp_bonus
	max_mana = float(cfg.get("base_max_mana", 40.0)) + float(eq.get("max_mana", 0.0))
	spell_power = int(cfg.get("base_spell_power", 0)) + int(eq.get("spell_power", 0.0)) + level_spell_power_bonus
	mana_regen = float(cfg.get("base_mana_regen", 3.0)) * (1.0 + float(eq.get("mana_regen_pct", 0.0)) / 100.0)

	if max_hp > prev_max_hp:
		hp += max_hp - prev_max_hp
	else:
		hp = minf(hp, max_hp)

	if max_mana > prev_max_mana:
		mana += max_mana - prev_max_mana
	else:
		mana = minf(mana, max_mana)


func attack_speed_multiplier() -> float:
	return 1.0 + float(equipment_stats().get("attack_speed_pct", 0.0)) / 100.0


func move_speed_multiplier() -> float:
	return 1.0 + float(equipment_stats().get("move_speed_pct", 0.0)) / 100.0


func life_regen_per_tick() -> float:
	return float(equipment_stats().get("life_regen", 0.0))


func regen_mana(delta_scale: float = 1.0) -> void:
	mana = minf(max_mana, mana + mana_regen * delta_scale)


func armor() -> float:
	return float(equipment_stats().get("armor", 0.0))


func attack_power() -> float:
	var cfg := GameBalanceScript.hero_cfg()
	var eq := equipment_stats()
	var staff_bonus := float(staff_enchant) * float(cfg.get("staff_enchant_attack", 1.0))
	return float(cfg.get("base_attack", 1.0)) + float(eq.get("attack", 0.0)) + staff_bonus


func take_damage(raw_amount: float) -> float:
	var actual := GameBalanceScript.apply_armor(raw_amount, armor())
	hp = maxf(0.0, hp - actual)
	return actual


func heal_to_full() -> void:
	hp = max_hp


func school_bonus_for(element: String) -> float:
	match school:
		MagicSchoolScript.School.PYROMANCY:
			return 1.25 if element == "fire" else 1.0
		MagicSchoolScript.School.CRYOMANCY:
			return 1.25 if element == "ice" else 1.0
		MagicSchoolScript.School.ARCANE:
			return 1.25 if element == "arcane" else 1.0
	return 1.0


func add_loot(item: Dictionary) -> bool:
	if not has_inventory_room():
		return false
	inventory.append(item)
	loot_added.emit(item)
	return true


func weapon_damage() -> float:
	return attack_power()


func equipped_items() -> Array:
	var items: Array = []
	for slot in equipment.keys():
		var item: Variant = equipment[slot]
		if item != null and typeof(item) == TYPE_DICTIONARY:
			items.append(item)
	return items


func equipment_stats() -> Dictionary:
	return ItemDataScript.aggregate_stats(equipped_items())


func bag_slot_capacity() -> int:
	var bonus := int(equipment_stats().get("bag_slots", 0.0))
	return GameBalanceScript.base_bag_slots() + bonus


func bag_slot_capacity_for_equipped(items: Array) -> int:
	var bonus := int(ItemDataScript.aggregate_stats(items).get("bag_slots", 0.0))
	return GameBalanceScript.base_bag_slots() + bonus


func has_inventory_room() -> bool:
	return inventory.size() < bag_slot_capacity()


func reset_for_new_game(name: String) -> void:
	player_name = name.strip_edges()
	if player_name.is_empty():
		player_name = "Hero"
	school = MagicSchoolScript.School.PYROMANCY
	level = 1
	xp = 0
	xp_to_next = 40
	gold = 0
	intelligence = 0
	spell_power = 0
	staff_enchant = 0
	level_hp_bonus = 0.0
	level_spell_power_bonus = 0
	inventory.clear()
	_reset_equipment()
	refresh_combat_stats()
	hp = max_hp
	mana = max_mana


func to_dict() -> Dictionary:
	var eq := {}
	for slot in ItemDataScript.EQUIP_SLOTS:
		var item: Variant = equipment.get(slot)
		if item != null and typeof(item) == TYPE_DICTIONARY:
			eq[slot] = (item as Dictionary).duplicate(true)
		else:
			eq[slot] = null

	var inv: Array = []
	for item in inventory:
		if typeof(item) == TYPE_DICTIONARY:
			inv.append((item as Dictionary).duplicate(true))

	return {
		"player_name": player_name,
		"school": int(school),
		"level": level,
		"xp": xp,
		"xp_to_next": xp_to_next,
		"gold": gold,
		"hp": hp,
		"max_hp": max_hp,
		"mana": mana,
		"max_mana": max_mana,
		"intelligence": intelligence,
		"spell_power": spell_power,
		"mana_regen": mana_regen,
		"staff_enchant": staff_enchant,
		"level_hp_bonus": level_hp_bonus,
		"level_spell_power_bonus": level_spell_power_bonus,
		"inventory": inv,
		"equipment": eq,
	}


func apply_dict(data: Dictionary) -> void:
	player_name = str(data.get("player_name", player_name))
	school = int(data.get("school", school)) as MagicSchoolScript.School
	level = int(data.get("level", level))
	xp = int(data.get("xp", xp))
	xp_to_next = int(data.get("xp_to_next", xp_to_next))
	gold = int(data.get("gold", gold))
	intelligence = int(data.get("intelligence", intelligence))
	spell_power = int(data.get("spell_power", spell_power))
	mana_regen = float(data.get("mana_regen", mana_regen))
	staff_enchant = int(data.get("staff_enchant", staff_enchant))
	level_hp_bonus = float(data.get("level_hp_bonus", level_hp_bonus))
	level_spell_power_bonus = int(data.get("level_spell_power_bonus", level_spell_power_bonus))

	inventory.clear()
	for item in data.get("inventory", []):
		if typeof(item) == TYPE_DICTIONARY:
			inventory.append((item as Dictionary).duplicate(true))

	_reset_equipment()
	var eq_data: Dictionary = data.get("equipment", {})
	for slot in ItemDataScript.EQUIP_SLOTS:
		var item: Variant = eq_data.get(slot)
		if item != null and typeof(item) == TYPE_DICTIONARY:
			equipment[slot] = (item as Dictionary).duplicate(true)
		else:
			equipment[slot] = null

	refresh_combat_stats()
	hp = clampf(float(data.get("hp", max_hp)), 0.0, max_hp)
	mana = clampf(float(data.get("mana", max_mana)), 0.0, max_mana)
