extends RefCounted

const Hero = preload("res://scripts/game/hero.gd")
const Enemy = preload("res://scripts/game/enemy.gd")
const EnemySpriteScript = preload("res://scripts/ui/enemy_sprite.gd")
const StageDataScript = preload("res://scripts/game/stage_data.gd")
const GameBalanceScript = preload("res://scripts/game/game_balance.gd")
const ItemDataScript = preload("res://scripts/game/item_data.gd")

signal attack_started(info: Dictionary)
signal enemy_defeated(rewards: Dictionary)
signal enemy_slain(slot: int)
signal enemy_damaged(slot: int, amount: float, source: String)
signal wave_spawned(count: int, types: PackedStringArray)
signal hero_damaged(amount: float)
signal hero_healed(amount: float)
signal hero_died

# Kept for older UI hooks; combat is melee-only for now.
signal spell_cast(info: Dictionary)
signal combo_triggered(name: String, damage: float)
signal combat_event(text: String)

enum MeleePhase { IDLE, HERO_SWING, HERO_RESOLVING, ENEMY_SWING }

var hero: Hero
var enemy: Enemy
var enemies: Array[Enemy] = []
var enemy_types: PackedStringArray = []
var last_attack_name := "Attack"
var last_spell_name := "Attack"
var combo_flash := ""
var _slain_flags: Array[bool] = []
var _hero_dead := false
var _melee_phase := MeleePhase.IDLE
var _hero_swings_left := 0
var _pending_strike: Dictionary = {}
var _pending_enemy_damage := 0.0


func _init(p_hero: Hero) -> void:
	hero = p_hero


func spawn_wave(count: int) -> void:
	spawn_wave_with_types(_random_types(count))


func spawn_wave_with_types(types: PackedStringArray) -> void:
	enemies.clear()
	enemy_types.clear()
	_slain_flags.clear()
	_hero_dead = false
	_finish_exchange()
	if types.is_empty():
		types = _types_from_stage_runner()
	if types.is_empty():
		push_warning("spawn_wave_with_types: no enemies for current wave")
		return

	for i in types.size():
		var foe := Enemy.new()
		var enemy_type: String = types[i]
		if not EnemySpriteScript.TYPE_DEFS.has(enemy_type):
			enemy_type = "gladiator"
		var difficulty := 1.0
		if GameState.stage_runner != null:
			difficulty = GameState.stage_runner.enemy_difficulty_for(enemy_type)
		foe.apply_type_def(enemy_type, hero.level, difficulty)
		if types.size() > 1 and not foe.is_boss:
			var pack_hp_mul := float(GameBalanceScript.stage_cfg().get("multi_enemy_hp_mul", 0.88))
			foe.max_hp *= pack_hp_mul
			foe.hp = foe.max_hp
		enemies.append(foe)
		enemy_types.append(enemy_type)
		_slain_flags.append(false)

	_sync_primary()
	wave_spawned.emit(enemies.size(), enemy_types)


func _types_from_stage_runner() -> PackedStringArray:
	var types := PackedStringArray()
	if GameState.stage_runner == null:
		return types
	for enemy_type in GameState.stage_runner.current_wave_enemies():
		types.append(str(enemy_type))
	return types


func _random_types(count: int) -> PackedStringArray:
	count = clampi(count, 1, 3)
	var types := PackedStringArray()
	for i in count:
		types.append(EnemySpriteScript.ENEMY_POOL[randi() % EnemySpriteScript.ENEMY_POOL.size()])
	return types


func living_count() -> int:
	var n := 0
	for foe in enemies:
		if foe.hp > 0.0:
			n += 1
	return n


func tick_passive() -> void:
	hero.regen_mana(0.45)


func is_melee_idle() -> bool:
	return _melee_phase == MeleePhase.IDLE


func is_hero_swing_pending() -> bool:
	return _melee_phase == MeleePhase.HERO_SWING and not _pending_strike.is_empty()


func is_enemy_swing_pending() -> bool:
	return _melee_phase == MeleePhase.ENEMY_SWING


func begin_combat_round() -> String:
	if _melee_phase != MeleePhase.IDLE:
		return "none"
	if hero.hp <= 0.0 or living_count() <= 0:
		return "idle"

	combo_flash = ""
	_hero_swings_left = hero.attacks_per_round()

	if living_count() <= 0:
		return "idle"
	if _begin_hero_swing():
		return "hero_swing"
	return _queue_enemy_turn()


func commit_hero_strike() -> String:
	if _melee_phase != MeleePhase.HERO_SWING or _pending_strike.is_empty():
		return "none"

	_melee_phase = MeleePhase.HERO_RESOLVING

	var front := _front_enemy()
	var dmg: float = float(_pending_strike.get("damage", 0.0))
	var source: String = str(_pending_strike.get("name", last_attack_name))
	var is_skill: bool = bool(_pending_strike.get("is_skill", false))
	var skill_name: String = str(_pending_strike.get("name", last_attack_name))
	_pending_strike.clear()

	if front != null and front.hp > 0.0 and dmg > 0.0:
		if is_skill:
			match skill_name:
				"Double Strike":
					_damage_enemy_at(front, dmg * 0.8, source)
					if front != null and front.hp > 0.0:
						_damage_enemy_at(front, dmg * 0.8, source)
				"Cleave":
					_damage_enemy_at(front, dmg * 1.5, source)
					if randf() < 0.35:
						var bleed_dmg := float(round(dmg * 0.4))
						_damage_enemy_at(front, bleed_dmg, "Bleed")
						combat_event.emit("Bleeding!")
				"Heavy Strike":
					_damage_enemy_at(front, dmg * 1.4, source)
					front.set_meta("stunned", true)
					combat_event.emit("Stunned!")
				"Impaler":
					_damage_enemy_at(front, dmg * 1.2, source)
					if living_count() > 1:
						var splash_dmg := dmg * 0.6
						for foe in enemies:
							if foe != front and foe.hp > 0.0:
								_damage_enemy_at(foe, splash_dmg, "Splash")
				"Elemental Bolt":
					var spell_dmg := float(round(1.5 * float(hero.spell_power) + 0.5 * dmg))
					_damage_enemy_at(front, spell_dmg, source)
				"Fists of Fury":
					_damage_enemy_at(front, dmg * 1.1, source)
					var heal_amt := float(round(hero.max_hp * 0.05))
					hero.hp = minf(hero.max_hp, hero.hp + heal_amt)
		else:
			_damage_enemy_at(front, dmg, source)
			var weapon = hero.equipment.get("weapon")
			if weapon != null and typeof(weapon) == TYPE_DICTIONARY:
				var family = ItemDataScript.weapon_family(weapon)
				if family == "spears" and living_count() > 1:
					var splash_dmg := dmg * 0.5
					for foe in enemies:
						if foe != front and foe.hp > 0.0:
							_damage_enemy_at(foe, splash_dmg, "Splash")
				elif (family == "maces" or family == "warhammers") and randf() < 0.20:
					front.set_meta("stunned", true)
					combat_event.emit("Stunned!")

		_process_hero_on_hit_magical_effects(front, dmg)

	_cleanup_dead()

	if hero.hp <= 0.0 or living_count() <= 0:
		_melee_phase = MeleePhase.IDLE
		return "idle"

	_hero_swings_left -= 1
	if _hero_swings_left > 0 and _begin_hero_swing():
		return "hero_swing"
	return _queue_enemy_turn()


func commit_enemy_strike() -> bool:
	if _melee_phase != MeleePhase.ENEMY_SWING:
		return false

	var dmg := _pending_enemy_damage
	_pending_enemy_damage = 0.0

	if dmg > 0.0 and hero.hp > 0.0:
		var taken := hero.take_damage(dmg)
		hero_damaged.emit(taken)
		if hero.hp <= 0.0 and not _hero_dead:
			_hero_dead = true
			hero_died.emit()
		else:
			if taken > 0.0:
				_process_hero_on_defend_magical_effects()
				_cleanup_dead()

	_melee_phase = MeleePhase.IDLE
	return true


func cancel_exchange() -> void:
	_reset_melee()


func _begin_hero_swing() -> bool:
	if hero.hp <= 0.0 or living_count() <= 0 or _hero_swings_left <= 0:
		return false

	var attack := _build_hero_attack()
	if attack.is_empty():
		_hero_swings_left = 0
		return false

	last_attack_name = str(attack.get("name", "Attack"))
	last_spell_name = last_attack_name
	_pending_strike = attack.duplicate()
	_melee_phase = MeleePhase.HERO_SWING

	var payload := {
		"name": last_attack_name,
		"damage": attack.get("damage", 0.0),
		"element": "physical",
	}
	attack_started.emit(payload)
	spell_cast.emit(payload)
	return true


func _queue_enemy_turn() -> String:
	if hero.hp <= 0.0 or living_count() <= 0:
		_melee_phase = MeleePhase.IDLE
		return "idle"

	var slot := _front_slot()
	if slot < 0 or slot >= enemies.size():
		_melee_phase = MeleePhase.IDLE
		return "idle"

	var foe: Enemy = enemies[slot]
	if foe.hp <= 0.0:
		_melee_phase = MeleePhase.IDLE
		return "idle"

	if foe.has_meta("stunned") and foe.get_meta("stunned") == true:
		foe.set_meta("stunned", false)
		_melee_phase = MeleePhase.IDLE
		return "idle"

	var enemy_type := "gladiator"
	if slot < enemy_types.size():
		enemy_type = enemy_types[slot]
	var dmg := _enemy_strike_damage(foe, enemy_type)
	if dmg < 0.0:
		dmg = 0.0

	_pending_enemy_damage = dmg
	_melee_phase = MeleePhase.ENEMY_SWING
	return "enemy_turn"


func _build_hero_attack() -> Dictionary:
	var base_dmg := hero.weapon_damage()
	if base_dmg <= 0.0:
		base_dmg = 1.0

	var weapon = hero.equipment.get("weapon")
	var family := ""
	if weapon != null and typeof(weapon) == TYPE_DICTIONARY:
		family = ItemDataScript.weapon_family(weapon)

	var cost := 0
	var skill_name := ""
	match family:
		"knives", "swords":
			skill_name = "Double Strike"
			cost = 15
		"axes":
			skill_name = "Cleave"
			cost = 20
		"maces", "warhammers":
			skill_name = "Heavy Strike"
			cost = 18
		"spears":
			skill_name = "Impaler"
			cost = 25
		"sticks":
			skill_name = "Elemental Bolt"
			cost = 12
		_:
			skill_name = "Fists of Fury"
			cost = 10

	var cast_successful := false
	var use_blood_magic := hero.has_keystone("blood_magic")

	if use_blood_magic:
		if hero.hp > cost:
			hero.hp -= cost
			cast_successful = true
	else:
		if hero.mana >= cost:
			hero.mana -= cost
			cast_successful = true

	if cast_successful:
		return {
			"name": skill_name,
			"damage": base_dmg,
			"cost": cost,
			"is_skill": true,
			"family": family,
			"element": "elemental" if family == "sticks" else "physical"
		}
	else:
		return {"name": "Attack", "damage": base_dmg, "is_skill": false, "element": "physical"}


func clear_wave() -> void:
	enemies.clear()
	enemy_types.clear()
	_slain_flags.clear()
	_hero_dead = false
	_finish_exchange()
	_sync_primary()


func _finish_exchange() -> void:
	_reset_melee()


func _reset_melee() -> void:
	_melee_phase = MeleePhase.IDLE
	_hero_swings_left = 0
	_pending_strike.clear()
	_pending_enemy_damage = 0.0


func _front_enemy() -> Enemy:
	for foe in enemies:
		if foe.hp > 0.0:
			return foe
	return null


func front_slot() -> int:
	return _front_slot()


func _front_slot() -> int:
	for i in enemies.size():
		if enemies[i].hp > 0.0:
			return i
	return -1


func _sync_primary() -> void:
	var front := _front_enemy()
	enemy = front if front != null else Enemy.new()


func _cleanup_dead() -> void:
	for i in enemies.size():
		if enemies[i].hp <= 0.0 and i < _slain_flags.size() and not _slain_flags[i]:
			_slain_flags[i] = true
			enemy_slain.emit(i)

	while enemies.size() > 0 and enemies[0].hp <= 0.0:
		var rewards := _collect_rewards(enemies[0])
		enemies.remove_at(0)
		if enemy_types.size() > 0:
			enemy_types.remove_at(0)
		if _slain_flags.size() > 0:
			_slain_flags.remove_at(0)
		enemy_defeated.emit(rewards)

	_sync_primary()


func _collect_rewards(foe: Enemy) -> Dictionary:
	if foe.hp > 0.0:
		return {
			"gold": 0,
			"xp": 0,
			"leveled": false,
			"item_dropped": false,
			"potion_dropped": false,
			"item": {},
			"potion": {},
		}

	var gold := int(round(float(foe.gold_reward) * (1.0 + hero.get_talent_gold_modifier())))
	var xp := int(round(float(foe.xp_reward) * (1.0 + hero.get_talent_xp_modifier())))
	hero.gold += gold
	var leveled := hero.add_xp(xp)
	var dropped_item: Dictionary = {}
	var dropped_potion: Dictionary = {}

	var pity_drop := GameState.should_pity_loot()
	var rolled_drop := GameBalanceScript.roll_kill_loot(foe.is_boss)
	if rolled_drop or pity_drop:
		var scroll_rng := randf()
		var std_chance := 0.15 if foe.is_boss else 0.04
		var bls_chance := 0.05 if foe.is_boss else 0.008
		
		if scroll_rng < bls_chance:
			dropped_item = ItemDataScript.make_consumable_stack("scrolls/upgrade-blessed", 1)
		elif scroll_rng < bls_chance + std_chance:
			dropped_item = ItemDataScript.make_consumable_stack("scrolls/upgrade-standard", 1)
		else:
			dropped_item = _roll_loot()
	else:
		GameState.record_kill_without_loot()

	if GameBalanceScript.should_drop_potion(foe.is_boss):
		dropped_potion = ItemDataScript.roll_potion_loot()

	return {
		"gold": gold,
		"xp": xp,
		"leveled": leveled,
		"item_dropped": false,
		"potion_dropped": false,
		"item_rolled": not dropped_item.is_empty(),
		"potion_rolled": not dropped_potion.is_empty(),
		"bag_full": false,
		"item": dropped_item,
		"potion": dropped_potion,
	}


func _enemy_strike_damage(foe: Enemy, _enemy_type: String) -> float:
	var dmg := foe.attack_damage
	if dmg <= 0.0:
		dmg = 2.0 + foe.level * 1.0
	return dmg


func _damage_enemy_at(foe: Enemy, amount: float, source: String) -> void:
	if amount <= 0.0:
		return
	foe.hp = maxf(0.0, foe.hp - amount)
	var slot := enemies.find(foe)
	if slot >= 0:
		enemy_damaged.emit(slot, amount, source)


func _roll_loot() -> Dictionary:
	return ItemDataScript.roll_loot_instance(ItemDataScript.current_ilvl())


func _process_hero_on_hit_magical_effects(primary_target: Enemy, raw_strike_damage: float) -> void:
	if hero == null:
		return
	for slot in hero.equipment.keys():
		var item: Variant = hero.equipment[slot]
		if item == null or typeof(item) != TYPE_DICTIONARY:
			continue
		
		var def := ItemDataScript.get_def(item.get("id", ""))
		if def.is_empty():
			continue
			
		# Check for fixed magical effect
		if def.has("magical_effect"):
			var effect: Dictionary = def.get("magical_effect")
			_trigger_magical_effect(effect, primary_target, raw_strike_damage, item)
			
		# Check for rolled modifiers
		var mods: Array = item.get("mods", [])
		if typeof(mods) == TYPE_ARRAY:
			for entry in mods:
				if typeof(entry) != TYPE_DICTIONARY:
					continue
				var mod_id := str(entry.get("mod", ""))
				var mod_def := ItemDataScript.get_modifier_def(mod_id)
				if mod_def.is_empty() or mod_def.get("stat", "") != "special_effect":
					continue
				
				# Build a temporary effect dictionary from the modifier details
				var value := float(entry.get("value", 0.0))
				var effect := {
					"id": "",
					"chance": 0.0,
					"value": value
				}
				if mod_id == "of_thunderbolts":
					effect["id"] = "lightning_strike"
					effect["chance"] = value / 100.0
					effect["base_damage"] = 5.0 + float(entry.get("tier", 1)) * 3.0
					effect["scaling_multiplier"] = 1.0 + float(entry.get("tier", 1)) * 0.2
					effect["description"] = "Lightning Strike"
				elif mod_id == "of_vampirism":
					effect["id"] = "lifesteal"
					effect["chance"] = 1.0 # Passive always triggers
					effect["value"] = value
					effect["description"] = "Lifesteal"
				
				if not effect["id"].is_empty():
					_trigger_magical_effect(effect, primary_target, raw_strike_damage, item)


func _trigger_magical_effect(effect: Dictionary, primary_target: Enemy, raw_strike_damage: float, item: Dictionary) -> void:
	var id := str(effect.get("id", ""))
	var chance := float(effect.get("chance", 1.0))
	if randf() > chance:
		return
		
	var upgrade := int(item.get("upgrade", 0))
	var multiplier := 1.0 + upgrade * 0.12
		
	match id:
		"lightning_strike":
			var base_dmg := float(effect.get("base_damage", 6.0)) * multiplier
			var mult := float(effect.get("scaling_multiplier", 1.0))
			var lightning_dmg := base_dmg + float(hero.spell_power) * mult
			
			var actual_target := primary_target
			if actual_target == null or actual_target.hp <= 0.0:
				actual_target = _front_enemy()
				
			if actual_target != null:
				_damage_enemy_at(actual_target, lightning_dmg, "Lightning Strike")
				combat_event.emit("Lightning Strike!")
				
				if living_count() > 1:
					var splash_dmg := lightning_dmg * 0.5
					for foe in enemies:
						if foe != actual_target and foe.hp > 0.0:
							_damage_enemy_at(foe, splash_dmg, "Chain Lightning")
							
		"lifesteal":
			var pct := float(effect.get("value", 0.0)) / 100.0
			if pct > 0.0:
				var heal_amt := float(round(raw_strike_damage * pct))
				if heal_amt > 0.0 and hero.hp > 0.0:
					var before := hero.hp
					hero.hp = minf(hero.max_hp, hero.hp + heal_amt)
					var actual_heal := hero.hp - before
					if actual_heal > 0.0:
						hero_healed.emit(actual_heal)
						combat_event.emit("Lifesteal! +%.0f HP" % actual_heal)


func _process_hero_on_defend_magical_effects() -> void:
	if hero == null:
		return
	var total_retaliation_damage := 0.0
	
	for slot in hero.equipment.keys():
		var item: Variant = hero.equipment[slot]
		if item == null or typeof(item) != TYPE_DICTIONARY:
			continue
		
		var def := ItemDataScript.get_def(item.get("id", ""))
		if def.is_empty():
			continue
			
		var upgrade := int(item.get("upgrade", 0))
		var multiplier := 1.0 + upgrade * 0.12
			
		if def.has("magical_effect"):
			var effect: Dictionary = def.get("magical_effect")
			if effect.get("id", "") == "thorns":
				total_retaliation_damage += float(effect.get("value", 0.0)) * multiplier
				
		var mods: Array = item.get("mods", [])
		if typeof(mods) == TYPE_ARRAY:
			for entry in mods:
				if typeof(entry) != TYPE_DICTIONARY:
					continue
				var mod_id := str(entry.get("mod", ""))
				var mod_def := ItemDataScript.get_modifier_def(mod_id)
				if mod_def.is_empty() or mod_def.get("stat", "") != "special_effect":
					continue
				
				if mod_id == "of_retaliation":
					var value := float(entry.get("value", 0.0))
					total_retaliation_damage += value * multiplier
					
	if total_retaliation_damage > 0.0:
		var front := _front_enemy()
		if front != null and front.hp > 0.0:
			_damage_enemy_at(front, total_retaliation_damage, "Retaliation")
			combat_event.emit("Retaliated!")
