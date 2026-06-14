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
	_pending_strike.clear()

	if front != null and front.hp > 0.0 and dmg > 0.0:
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
	var dmg := hero.weapon_damage()
	if dmg <= 0.0:
		dmg = 1.0
	return {"name": "Attack", "damage": dmg, "element": "physical"}


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
