extends RefCounted

const ItemDataScript = preload("res://scripts/game/item_data.gd")
const GameBalanceScript = preload("res://scripts/game/game_balance.gd")
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
var potion_bar: Dictionary = {
	"health": null,
	"mana": null,
}

var level_hp_bonus: float = 0.0
var level_spell_power_bonus: int = 0
var player_name := ""

var talent_points: int = 0
var unlocked_talents: Dictionary = {}

const TALENT_DEFS := {
	"nexus": {
		"name": "Ascension Nexus",
		"desc": "The starting point of your ascension power.",
		"cost": 0,
		"cost_gold": 0,
		"requires": "",
		"row": 0.0, "col": 0.0
	},
	# Might Branch (Right: col > 0)
	"might_1": {
		"name": "Might I",
		"desc": "+5% Attack Power",
		"cost": 1,
		"cost_gold": 0,
		"requires": "nexus",
		"row": 0.0, "col": 1.5,
		"mod_atk_pct": 5.0
	},
	"might_hp_1": {
		"name": "Iron Skin",
		"desc": "+10% Max HP & +2 Armor",
		"cost": 1,
		"cost_gold": 150,
		"requires": "might_1",
		"row": 1.0, "col": 3.0,
		"mod_hp_pct": 10.0,
		"mod_arm": 2.0
	},
	"might_atk_2": {
		"name": "Brutality",
		"desc": "+15% Attack Power",
		"cost": 1,
		"cost_gold": 150,
		"requires": "might_1",
		"row": -1.0, "col": 3.0,
		"mod_atk_pct": 15.0
	},
	"might_arm_2": {
		"name": "Juggernaut",
		"desc": "+15% Max HP & +5 Armor",
		"cost": 2,
		"cost_gold": 350,
		"requires": "might_hp_1",
		"row": 1.5, "col": 4.5,
		"mod_hp_pct": 15.0,
		"mod_arm": 5.0
	},
	"might_fury": {
		"name": "Bloodfury",
		"desc": "+25% Attack Power",
		"cost": 2,
		"cost_gold": 400,
		"requires": "might_atk_2",
		"row": -1.5, "col": 4.5,
		"mod_atk_pct": 25.0
	},
	"might_keystone": {
		"name": "Blood Magic",
		"desc": "Skills cost HP instead of Mana. Max Mana is 0. +25% Max HP.",
		"cost": 3,
		"cost_gold": 800,
		"requires": ["might_arm_2", "might_fury"],
		"row": 0.0, "col": 6.0,
		"is_keystone": true,
		"keystone_id": "blood_magic"
	},
	# Wealth Branch (Left: col < 0)
	"wealth_1": {
		"name": "Wealth I",
		"desc": "+10% Gold from enemies",
		"cost": 1,
		"cost_gold": 0,
		"requires": "nexus",
		"row": 0.0, "col": -1.5,
		"mod_gold": 0.10
	},
	"wealth_discount": {
		"name": "Merchant Guild",
		"desc": "Market prices reduced by 15%",
		"cost": 1,
		"cost_gold": 200,
		"requires": "wealth_1",
		"row": 1.0, "col": -3.0,
		"mod_shop_discount": 0.15
	},
	"wealth_gold_2": {
		"name": "Hoarder",
		"desc": "+20% Gold from enemies",
		"cost": 1,
		"cost_gold": 150,
		"requires": "wealth_1",
		"row": -1.0, "col": -3.0,
		"mod_gold": 0.20
	},
	"wealth_starting": {
		"name": "Deep Pockets",
		"desc": "+25% Gold & +100 gold now",
		"cost": 2,
		"cost_gold": 300,
		"requires": "wealth_discount",
		"row": 1.5, "col": -4.5,
		"mod_gold": 0.25,
		"mod_grant_gold": 100
	},
	"wealth_collector": {
		"name": "Taxation",
		"desc": "+30% Gold from enemies",
		"cost": 2,
		"cost_gold": 350,
		"requires": "wealth_gold_2",
		"row": -1.5, "col": -4.5,
		"mod_gold": 0.30
	},
	"wealth_offline": {
		"name": "Off-Duty Trade",
		"desc": "+5% Offline Progress Efficiency",
		"cost": 2,
		"cost_gold": 300,
		"requires": "wealth_collector",
		"row": -2.5, "col": -4.0,
		"mod_offline_efficiency": 0.05
	},
	"wealth_keystone": {
		"name": "Golden Touch",
		"desc": "+40% Gold & 25% Market Discount",
		"cost": 3,
		"cost_gold": 750,
		"requires": ["wealth_starting", "wealth_collector"],
		"row": 0.0, "col": -6.0,
		"mod_gold": 0.40,
		"mod_shop_discount": 0.25
	},
	# Wisdom Branch (Top: row < 0)
	"wisdom_1": {
		"name": "Wisdom I",
		"desc": "+10% XP from enemies",
		"cost": 1,
		"cost_gold": 0,
		"requires": "nexus",
		"row": -1.5, "col": 0.0,
		"mod_xp": 0.10
	},
	"wisdom_intel": {
		"name": "Acolyte",
		"desc": "+3 Intel & +5 Spell Power",
		"cost": 1,
		"cost_gold": 150,
		"requires": "wisdom_1",
		"row": -3.0, "col": -1.0,
		"mod_intel": 3,
		"mod_sp": 5
	},
	"wisdom_xp_2": {
		"name": "Scholar",
		"desc": "+20% XP from enemies",
		"cost": 1,
		"cost_gold": 150,
		"requires": "wisdom_1",
		"row": -3.0, "col": 1.0,
		"mod_xp": 0.20
	},
	"wisdom_offline": {
		"name": "Astral Contemplation",
		"desc": "+5% Offline Progress Efficiency",
		"cost": 2,
		"cost_gold": 300,
		"requires": "wisdom_xp_2",
		"row": -4.0, "col": 3.0,
		"mod_offline_efficiency": 0.05
	},
	"wisdom_regen": {
		"name": "Sage",
		"desc": "+30% Mana Regen & +5 Intel",
		"cost": 2,
		"cost_gold": 300,
		"requires": "wisdom_intel",
		"row": -4.5, "col": -1.5,
		"mod_mana_regen_pct": 0.30,
		"mod_intel": 5
	},
	"wisdom_power": {
		"name": "Archmage",
		"desc": "+15 Spell Power & +10% XP",
		"cost": 2,
		"cost_gold": 350,
		"requires": "wisdom_xp_2",
		"row": -4.5, "col": 1.5,
		"mod_sp": 15,
		"mod_xp": 0.10
	},
	"wisdom_keystone": {
		"name": "Chaos Inoculation",
		"desc": "Max HP is 1. Damage (AP & SP) is boosted by +50%. Mana Regen is doubled.",
		"cost": 3,
		"cost_gold": 800,
		"requires": ["wisdom_regen", "wisdom_power"],
		"row": -6.0, "col": 0.0,
		"is_keystone": true,
		"keystone_id": "chaos_inoculation"
	},
	# Vitality Branch (Bottom: row > 0)
	"vitality_1": {
		"name": "Recovery I",
		"desc": "+1.0 Life Regen per tick",
		"cost": 1,
		"cost_gold": 0,
		"requires": "nexus",
		"row": 1.5, "col": 0.0,
		"mod_life_regen": 1.0
	},
	"vitality_hp": {
		"name": "Healthy Life",
		"desc": "+15% Max HP",
		"cost": 1,
		"cost_gold": 150,
		"requires": "vitality_1",
		"row": 3.0, "col": -1.0,
		"mod_hp_pct": 0.15
	},
	"vitality_regen_2": {
		"name": "Recovery II",
		"desc": "+2.5 Life Regen per tick",
		"cost": 1,
		"cost_gold": 150,
		"requires": "vitality_1",
		"row": 3.0, "col": 1.0,
		"mod_life_regen": 2.5
	},
	"vitality_potency": {
		"name": "Rejuvenation",
		"desc": "+25% Potion Efficacy",
		"cost": 2,
		"cost_gold": 300,
		"requires": "vitality_hp",
		"row": 4.5, "col": -1.5,
		"mod_potion_potency": 0.25
	},
	"vitality_tank": {
		"name": "Stalwart",
		"desc": "+20% Max HP & +4 Armor",
		"cost": 2,
		"cost_gold": 350,
		"requires": "vitality_regen_2",
		"row": 4.5, "col": 1.5,
		"mod_hp_pct": 0.20,
		"mod_arm": 4.0
	},
	"vitality_keystone": {
		"name": "Mind Over Matter",
		"desc": "30% of damage is taken from Mana before Health. +5.0 Life Regen.",
		"cost": 3,
		"cost_gold": 850,
		"requires": ["vitality_potency", "vitality_tank"],
		"row": 6.0, "col": 0.0,
		"is_keystone": true,
		"keystone_id": "mind_over_matter",
		"mod_life_regen": 5.0
	}
}


func can_unlock_talent(id: String) -> bool:
	var def: Dictionary = TALENT_DEFS.get(id, {})
	if def.is_empty():
		return false
	if unlocked_talents.get(id, false) == true:
		return false
	if talent_points < int(def.get("cost", 1)):
		return false
	var cost_gold := int(def.get("cost_gold", 0))
	if gold < cost_gold:
		return false
	var reqs: Variant = def.get("requires", "")
	if reqs is String:
		if not reqs.is_empty() and unlocked_talents.get(reqs, false) != true:
			return false
	elif reqs is Array:
		var any_ok := false
		for r in reqs:
			if unlocked_talents.get(r, false) == true:
				any_ok = true
				break
		if not any_ok:
			return false
	return true


func unlock_talent(id: String) -> bool:
	if not can_unlock_talent(id):
		return false
	var def: Dictionary = TALENT_DEFS[id]
	talent_points -= int(def.get("cost", 1))
	if def.has("cost_gold"):
		gold -= int(def.get("cost_gold", 0))
	unlocked_talents[id] = true
	if def.has("mod_grant_gold"):
		gold += int(def.get("mod_grant_gold", 0))
	refresh_combat_stats()
	return true


func recalculate_talent_points() -> void:
	var spent := 0
	for key in unlocked_talents.keys():
		if unlocked_talents[key] == true:
			var def: Dictionary = TALENT_DEFS.get(key, {})
			spent += int(def.get("cost", 0))
	var expected := level - 1
	talent_points = expected - spent


func get_talent_offline_modifier() -> float:
	var total := 0.0
	for key in unlocked_talents.keys():
		if unlocked_talents[key] == true:
			total += float(TALENT_DEFS.get(key, {}).get("mod_offline_efficiency", 0.0))
	return total


func get_talent_gold_modifier() -> float:
	var total := 0.0
	for key in unlocked_talents.keys():
		if unlocked_talents[key] == true:
			total += float(TALENT_DEFS.get(key, {}).get("mod_gold", 0.0))
	return total


func get_talent_xp_modifier() -> float:
	var total := 0.0
	for key in unlocked_talents.keys():
		if unlocked_talents[key] == true:
			total += float(TALENT_DEFS.get(key, {}).get("mod_xp", 0.0))
	return total


func get_talent_attack_modifier() -> float:
	var total := 0.0
	for key in unlocked_talents.keys():
		if unlocked_talents[key] == true:
			total += float(TALENT_DEFS.get(key, {}).get("mod_atk_pct", 0.0)) / 100.0
	return total


func get_talent_hp_modifier() -> float:
	var total := 0.0
	for key in unlocked_talents.keys():
		if unlocked_talents[key] == true:
			total += float(TALENT_DEFS.get(key, {}).get("mod_hp_pct", 0.0)) / 100.0
	return total


func get_talent_armor_modifier() -> float:
	var total := 0.0
	for key in unlocked_talents.keys():
		if unlocked_talents[key] == true:
			total += float(TALENT_DEFS.get(key, {}).get("mod_arm", 0.0))
			total += float(TALENT_DEFS.get(key, {}).get("mod_arm_pct", 0.0))
	return total


func get_talent_life_regen_modifier() -> float:
	var total := 0.0
	for key in unlocked_talents.keys():
		if unlocked_talents[key] == true:
			total += float(TALENT_DEFS.get(key, {}).get("mod_life_regen", 0.0))
	return total


func get_talent_mana_regen_modifier() -> float:
	var total := 0.0
	for key in unlocked_talents.keys():
		if unlocked_talents[key] == true:
			total += float(TALENT_DEFS.get(key, {}).get("mod_mana_regen_pct", 0.0))
	return total


func get_talent_spell_power_modifier() -> int:
	var total := 0
	for key in unlocked_talents.keys():
		if unlocked_talents[key] == true:
			total += int(TALENT_DEFS.get(key, {}).get("mod_sp", 0))
	return total


func get_talent_intelligence_modifier() -> int:
	var total := 0
	for key in unlocked_talents.keys():
		if unlocked_talents[key] == true:
			total += int(TALENT_DEFS.get(key, {}).get("mod_intel", 0))
	return total


func get_talent_shop_discount_modifier() -> float:
	var total := 0.0
	for key in unlocked_talents.keys():
		if unlocked_talents[key] == true:
			total += float(TALENT_DEFS.get(key, {}).get("mod_shop_discount", 0.0))
	return total


func get_talent_potion_potency_modifier() -> float:
	var total := 0.0
	for key in unlocked_talents.keys():
		if unlocked_talents[key] == true:
			total += float(TALENT_DEFS.get(key, {}).get("mod_potion_potency", 0.0))
	return total


signal loot_added(item: Dictionary)


func _init() -> void:
	unlocked_talents["nexus"] = true
	_reset_equipment()
	_reset_potion_bar()
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
	talent_points += 1
	refresh_combat_stats()
	hp = max_hp
	mana = max_mana


func refresh_combat_stats() -> void:
	var cfg := GameBalanceScript.hero_cfg()
	var eq := equipment_stats()
	var prev_max_hp := max_hp
	var prev_max_mana := max_mana

	max_hp = (
		float(cfg.get("base_max_hp", 5.0))
		+ float(eq.get("max_hp", 0.0))
		+ level_hp_bonus
	) * GameBalanceScript.hero_hp_mul()
	max_hp *= (1.0 + get_talent_hp_modifier())
	max_mana = float(cfg.get("base_max_mana", 40.0)) + float(eq.get("max_mana", 0.0))
	spell_power = int(cfg.get("base_spell_power", 0)) + int(eq.get("spell_power", 0.0)) + level_spell_power_bonus + get_talent_spell_power_modifier()
	mana_regen = float(cfg.get("base_mana_regen", 3.0)) * (1.0 + float(eq.get("mana_regen_pct", 0.0)) / 100.0) * (1.0 + get_talent_mana_regen_modifier())

	if has_keystone("blood_magic"):
		max_hp = float(round(max_hp * 1.25))
		max_mana = 0.0
		mana = 0.0
	elif has_keystone("chaos_inoculation"):
		max_hp = 1.0
		spell_power = int(float(spell_power) * 1.5)
		mana_regen *= 2.0

	intelligence = (level - 1) + get_talent_intelligence_modifier()

	if max_hp > prev_max_hp:
		hp += max_hp - prev_max_hp
	else:
		hp = minf(hp, max_hp)

	if max_mana > prev_max_mana:
		mana += max_mana - prev_max_mana
	else:
		mana = minf(mana, max_mana)


func attack_speed_multiplier() -> float:
	var mult := 1.0 + float(equipment_stats().get("attack_speed_pct", 0.0)) / 100.0
	var w = equipment.get("weapon")
	if w != null and typeof(w) == TYPE_DICTIONARY:
		var fam = ItemDataScript.weapon_family(w)
		if fam == "sticks":
			mult += 0.30
		elif fam == "axes":
			mult -= 0.15
	return mult


func attacks_per_round() -> int:
	var bonus_pct := float(equipment_stats().get("attack_speed_pct", 0.0))
	var threshold_pct := float(GameBalanceScript.combat_cfg().get("double_attack_speed_pct", 75.0))
	return 2 if bonus_pct >= threshold_pct else 1


func move_speed_multiplier() -> float:
	return 1.0 + float(equipment_stats().get("move_speed_pct", 0.0)) / 100.0


func life_regen_per_tick() -> float:
	return float(equipment_stats().get("life_regen", 0.0)) + get_talent_life_regen_modifier()


func regen_mana(delta_scale: float = 1.0) -> void:
	mana = minf(max_mana, mana + mana_regen * delta_scale)


func armor() -> float:
	return float(equipment_stats().get("armor", 0.0)) + get_talent_armor_modifier()


func attack_power() -> float:
	var cfg := GameBalanceScript.hero_cfg()
	var eq := equipment_stats()
	var staff_bonus := float(staff_enchant) * float(cfg.get("staff_enchant_attack", 1.0))
	var level_atk := float(maxi(0, level - 1)) * float(cfg.get("level_attack_gain", 1.0))
	var base := float(cfg.get("base_attack", 1.0)) + float(eq.get("attack", 0.0)) + staff_bonus + level_atk
	var w = equipment.get("weapon")
	if w != null and typeof(w) == TYPE_DICTIONARY:
		var fam = ItemDataScript.weapon_family(w)
		if fam == "axes":
			base *= 1.25
		elif fam == "sticks":
			base *= 0.85
	var final_atk := base * (1.0 + get_talent_attack_modifier())
	if has_keystone("chaos_inoculation"):
		final_atk *= 1.5
	return final_atk


func take_damage(raw_amount: float) -> float:
	var actual := GameBalanceScript.apply_armor(raw_amount, armor())
	if has_keystone("mind_over_matter"):
		var mana_dmg := actual * 0.3
		var mana_used := minf(mana, mana_dmg)
		mana -= mana_used
		actual -= mana_used
	hp = maxf(0.0, hp - actual)
	return actual


func has_keystone(keystone_id: String) -> bool:
	for key in unlocked_talents.keys():
		if unlocked_talents[key] == true:
			var def = TALENT_DEFS.get(key, {})
			if def.get("is_keystone", false) == true and def.get("keystone_id", "") == keystone_id:
				return true
	return false


func respec_talents() -> void:
	for key in unlocked_talents.keys():
		if unlocked_talents[key] == true:
			var def = TALENT_DEFS.get(key, {})
			talent_points += int(def.get("cost", 1))
	unlocked_talents.clear()
	unlocked_talents["nexus"] = true
	refresh_combat_stats()
	hp = max_hp
	mana = max_mana


func heal_to_full() -> void:
	hp = max_hp



func _reset_potion_bar() -> void:
	potion_bar = {
		"health": null,
		"mana": null,
	}


func potion_bar_stack(kind: String) -> Dictionary:
	var entry: Variant = potion_bar.get(kind)
	if entry != null and typeof(entry) == TYPE_DICTIONARY:
		return (entry as Dictionary).duplicate(true)
	return {}


func add_to_potion_bar(item: Dictionary) -> Dictionary:
	var result := {"added": 0, "overflow": 0}
	if not ItemDataScript.is_potion(item):
		return result

	var kind := ItemDataScript.potion_kind(item)
	if kind.is_empty():
		return result

	var id := str(item.get("id", ""))
	var amount := ItemDataScript.stack_count(item)
	var max_stack := ItemDataScript.max_stack_for(item)
	var current: Variant = potion_bar.get(kind)
	if current == null or typeof(current) != TYPE_DICTIONARY:
		var placed := mini(amount, max_stack)
		potion_bar[kind] = {"id": id, "count": placed}
		result["added"] = placed
		result["overflow"] = amount - placed
		return result

	var stack: Dictionary = current
	if str(stack.get("id", "")) != id:
		result["overflow"] = amount
		return result

	var room := max_stack - ItemDataScript.stack_count(stack)
	var placed := mini(amount, room)
	if placed > 0:
		stack["count"] = ItemDataScript.stack_count(stack) + placed
		potion_bar[kind] = stack
	result["added"] = placed
	result["overflow"] = amount - placed
	return result


func use_potion_bar(kind: String) -> Dictionary:
	var current: Variant = potion_bar.get(kind)
	if current == null or typeof(current) != TYPE_DICTIONARY:
		return {}

	var stack: Dictionary = (current as Dictionary).duplicate(true)
	var applied := ItemDataScript.apply_consumable_effects(self, stack)
	var count := ItemDataScript.stack_count(stack) - 1
	if count <= 0:
		potion_bar[kind] = null
	else:
		stack["count"] = count
		potion_bar[kind] = stack
	applied["kind"] = kind
	applied["item_id"] = str(stack.get("id", ""))
	return applied


func clear_potion_bar_slot(kind: String) -> Dictionary:
	var current: Variant = potion_bar.get(kind)
	potion_bar[kind] = null
	if current != null and typeof(current) == TYPE_DICTIONARY:
		return (current as Dictionary).duplicate(true)
	return {}


func add_loot(item: Dictionary) -> bool:
	var result := add_stackable_to_inventory(item)
	if int(result.get("added", 0)) <= 0:
		return false
	if not (result.get("remaining", {}) as Dictionary).is_empty():
		return false
	loot_added.emit(item)
	return true


func add_stackable_to_inventory(item: Dictionary, prefer_index: int = -1) -> Dictionary:
	var result := {"added": 0, "remaining": {}}
	if item.is_empty():
		return result

	var incoming := item.duplicate(true)
	var original := ItemDataScript.stack_count(incoming)
	if original <= 0:
		return result

	if prefer_index >= 0:
		incoming = _merge_stack_into_inventory_index(prefer_index, incoming, result)

	for i in inventory.size():
		if ItemDataScript.stack_count(incoming) <= 0:
			break
		if i == prefer_index:
			continue
		incoming = _merge_stack_into_inventory_index(i, incoming, result)

	while ItemDataScript.stack_count(incoming) > 0:
		if not has_inventory_room():
			break
		var chunk := mini(ItemDataScript.stack_count(incoming), ItemDataScript.max_stack_for(incoming))
		inventory.append(ItemDataScript.make_consumable_stack(str(incoming.get("id", "")), chunk))
		result["added"] = int(result.get("added", 0)) + chunk
		var left := ItemDataScript.stack_count(incoming) - chunk
		if left <= 0:
			incoming = {}
		else:
			incoming["count"] = left

	if ItemDataScript.stack_count(incoming) > 0:
		result["remaining"] = incoming
	else:
		result["remaining"] = {}

	return result


func merge_inventory_slots(from_index: int, to_index: int) -> bool:
	if from_index == to_index:
		return false
	if from_index < 0 or from_index >= inventory.size():
		return false
	if to_index < 0 or to_index >= inventory.size():
		return false

	var src: Dictionary = inventory[from_index]
	var dst: Dictionary = inventory[to_index]
	if not ItemDataScript.can_stack_merge(dst, src):
		return false

	var move := mini(ItemDataScript.stack_room_left(dst), ItemDataScript.stack_count(src))
	if move <= 0:
		return false

	dst["count"] = ItemDataScript.stack_count(dst) + move
	inventory[to_index] = dst

	var left := ItemDataScript.stack_count(src) - move
	if left <= 0:
		inventory.remove_at(from_index)
	else:
		src["count"] = left
		inventory[from_index] = src
	return true


func _merge_stack_into_inventory_index(index: int, incoming: Dictionary, result: Dictionary) -> Dictionary:
	if index < 0 or index >= inventory.size():
		return incoming
	if ItemDataScript.stack_count(incoming) <= 0:
		return incoming

	var target: Dictionary = inventory[index]
	if not ItemDataScript.can_stack_merge(target, incoming):
		return incoming

	var move := mini(ItemDataScript.stack_room_left(target), ItemDataScript.stack_count(incoming))
	if move <= 0:
		return incoming

	target["count"] = ItemDataScript.stack_count(target) + move
	inventory[index] = target
	result["added"] = int(result.get("added", 0)) + move

	var left := ItemDataScript.stack_count(incoming) - move
	if left <= 0:
		return {}
	incoming["count"] = left
	return incoming


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
	level = 1
	xp = 0
	xp_to_next = 40
	gold = 0
	intelligence = 0
	spell_power = 0
	staff_enchant = 0
	level_hp_bonus = 0.0
	level_spell_power_bonus = 0
	talent_points = 0
	unlocked_talents.clear()
	inventory.clear()
	_reset_equipment()
	_reset_potion_bar()
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

	var bar := {}
	for kind in ItemDataScript.POTION_KINDS:
		var entry: Variant = potion_bar.get(kind)
		if entry != null and typeof(entry) == TYPE_DICTIONARY:
			bar[kind] = (entry as Dictionary).duplicate(true)
		else:
			bar[kind] = null

	return {
		"player_name": player_name,
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
		"potion_bar": bar,
		"talent_points": talent_points,
		"unlocked_talents": unlocked_talents.duplicate(),
	}


func apply_dict(data: Dictionary) -> void:
	player_name = str(data.get("player_name", player_name))
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

	_reset_potion_bar()
	var bar_data: Dictionary = data.get("potion_bar", {})
	for kind in ItemDataScript.POTION_KINDS:
		var entry: Variant = bar_data.get(kind)
		if entry != null and typeof(entry) == TYPE_DICTIONARY:
			potion_bar[kind] = (entry as Dictionary).duplicate(true)
		else:
			potion_bar[kind] = null

	_reset_equipment()
	var eq_data: Dictionary = data.get("equipment", {})
	for slot in ItemDataScript.EQUIP_SLOTS:
		var item: Variant = eq_data.get(slot)
		if item != null and typeof(item) == TYPE_DICTIONARY:
			equipment[slot] = (item as Dictionary).duplicate(true)
		else:
			equipment[slot] = null

	talent_points = int(data.get("talent_points", 0))
	unlocked_talents = (data.get("unlocked_talents", {}) as Dictionary).duplicate()
	unlocked_talents["nexus"] = true
	recalculate_talent_points()

	refresh_combat_stats()
	hp = clampf(float(data.get("hp", max_hp)), 0.0, max_hp)
	mana = clampf(float(data.get("mana", max_mana)), 0.0, max_mana)
