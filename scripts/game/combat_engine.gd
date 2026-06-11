extends RefCounted

const Hero = preload("res://scripts/game/hero.gd")
const Enemy = preload("res://scripts/game/enemy.gd")
const MagicSchoolScript = preload("res://scripts/game/magic_school.gd")
const EnemySpriteScript = preload("res://scripts/ui/enemy_sprite.gd")
const StageDataScript = preload("res://scripts/game/stage_data.gd")
const GameBalanceScript = preload("res://scripts/game/game_balance.gd")

signal spell_cast(info: Dictionary)
signal enemy_defeated(rewards: Dictionary)
signal enemy_slain(slot: int)
signal enemy_damaged(slot: int, amount: float, source: String)
signal wave_spawned(count: int, types: PackedStringArray)
signal hero_damaged(amount: float)
signal hero_died
signal combo_triggered(name: String, damage: float)

var hero: Hero
var enemy: Enemy
var enemies: Array[Enemy] = []
var enemy_types: PackedStringArray = []
var last_spell_name := "Staff"
var combo_flash := ""
var _slain_flags: Array[bool] = []
var _hero_dead := false
var _exchange_busy := false
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


func is_exchange_busy() -> bool:
	return _exchange_busy


func tick_melee() -> void:
	begin_melee_exchange()


func begin_melee_exchange() -> bool:
	if _exchange_busy:
		return false
	if hero.hp <= 0.0:
		return false
	if enemies.is_empty() or living_count() <= 0:
		return false

	combo_flash = ""
	hero.regen_mana()

	var front := _front_enemy()
	if front != null and front.hp > 0.0:
		var dot := front.tick_status()
		if dot > 0.0:
			_damage_enemy_at(front, dot, "Burn", false)

	front = _front_enemy()
	if front == null or front.hp <= 0.0:
		_cleanup_dead()
		return false

	var cast := _cast_next_spell()
	if cast.is_empty():
		return false

	last_spell_name = str(cast.get("name", "Staff"))
	_pending_strike = cast.duplicate()
	_pending_enemy_damage = 0.0
	_exchange_busy = true

	spell_cast.emit({
		"name": last_spell_name,
		"damage": cast.get("damage", 0.0),
		"element": cast.get("element", "physical"),
		"combo": cast.get("show_combo", false),
	})
	return true


func commit_hero_strike() -> void:
	if not _exchange_busy or _pending_strike.is_empty():
		return

	var front := _front_enemy()
	var dmg: float = float(_pending_strike.get("damage", 0.0))
	var source: String = str(_pending_strike.get("name", last_spell_name))
	var show_combo: bool = bool(_pending_strike.get("show_combo", false))
	_pending_strike.clear()

	if front != null and front.hp > 0.0 and dmg > 0.0:
		_damage_enemy_at(front, dmg, source, show_combo)

	_cleanup_dead()


func prepare_enemy_counter() -> bool:
	if not _exchange_busy:
		return false
	if living_count() <= 0 or hero.hp <= 0.0:
		_finish_exchange()
		return false

	var slot := _front_slot()
	if slot < 0 or slot >= enemies.size():
		_finish_exchange()
		return false

	var foe: Enemy = enemies[slot]
	if foe.hp <= 0.0 or foe.is_frozen():
		_finish_exchange()
		return false

	var enemy_type := "gladiator"
	if slot < enemy_types.size():
		enemy_type = enemy_types[slot]
	var dmg := _enemy_strike_damage(foe, enemy_type)
	if dmg <= 0.0:
		_finish_exchange()
		return false

	_pending_enemy_damage = dmg
	return true


func commit_enemy_strike() -> void:
	if not _exchange_busy:
		return

	var dmg := _pending_enemy_damage
	_pending_enemy_damage = 0.0

	if dmg > 0.0 and hero.hp > 0.0:
		var taken := hero.take_damage(dmg)
		hero_damaged.emit(taken)
		if hero.hp <= 0.0 and not _hero_dead:
			_hero_dead = true
			hero_died.emit()

	_finish_exchange()


func cancel_exchange() -> void:
	_finish_exchange()


func clear_wave() -> void:
	enemies.clear()
	enemy_types.clear()
	_slain_flags.clear()
	_hero_dead = false
	_finish_exchange()
	_sync_primary()


func _finish_exchange() -> void:
	_exchange_busy = false
	_pending_strike.clear()
	_pending_enemy_damage = 0.0


func tick() -> void:
	tick_melee()


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
		return {"gold": 0, "xp": 0, "leveled": false, "item_dropped": false, "item": {}}

	var gold := foe.gold_reward
	var xp := foe.xp_reward
	hero.gold += gold
	var leveled := hero.add_xp(xp)
	var item_dropped := false
	var dropped_item: Dictionary = {}

	var pity_drop := GameState.should_pity_loot()
	var rolled_drop := GameBalanceScript.roll_kill_loot(foe.is_boss)
	if rolled_drop or pity_drop:
		dropped_item = _roll_loot()
		if hero.add_loot(dropped_item):
			item_dropped = true
		else:
			dropped_item = {}
	else:
		GameState.record_kill_without_loot()

	return {
		"gold": gold,
		"xp": xp,
		"leveled": leveled,
		"item_dropped": item_dropped,
		"bag_full": (rolled_drop or pity_drop) and not item_dropped,
		"item": dropped_item,
	}


func _enemy_strike_damage(foe: Enemy, _enemy_type: String) -> float:
	var dmg := foe.attack_damage
	if dmg <= 0.0:
		dmg = 2.0 + foe.level * 1.0
	return dmg


func _cast_next_spell() -> Dictionary:
	if hero.mana >= 20.0:
		return _cast_arcane_bolt()
	if hero.mana >= 15.0 and (hero.school == MagicSchoolScript.School.PYROMANCY or randf() > 0.45):
		return _cast_fireball()
	if hero.mana >= 12.0:
		return _cast_frostbolt()
	return _cast_staff()


func _cast_staff() -> Dictionary:
	var dmg := hero.weapon_damage()
	return {"name": "Staff", "damage": dmg, "element": "physical"}


func _cast_fireball() -> Dictionary:
	hero.mana -= 15.0
	var target := _front_enemy()
	var dmg := (10.0 + hero.spell_power * 1.4) * hero.school_bonus_for("fire")
	var combo := false
	if target != null and target.is_frozen():
		dmg *= 3.0
		combo = true
		combo_flash = "Thermal Shock!"
		combo_triggered.emit(combo_flash, dmg)
	if target != null:
		target.apply_status(Enemy.Status.BURNING, 5)
	return {"name": "Fireball", "damage": dmg, "element": "fire", "show_combo": combo}


func _cast_frostbolt() -> Dictionary:
	hero.mana -= 12.0
	var target := _front_enemy()
	var dmg := (7.0 + hero.spell_power * 1.1) * hero.school_bonus_for("ice")
	if target != null:
		target.apply_status(Enemy.Status.FROZEN, 4)
	return {"name": "Frostbolt", "damage": dmg, "element": "ice"}


func _cast_arcane_bolt() -> Dictionary:
	hero.mana -= 20.0
	var dmg := (9.0 + hero.spell_power * 1.3) * hero.school_bonus_for("arcane")
	return {"name": "Arcane Bolt", "damage": dmg, "element": "arcane"}


func _damage_enemy_at(foe: Enemy, amount: float, source: String, _combo: bool) -> void:
	if amount <= 0.0:
		return
	foe.hp = maxf(0.0, foe.hp - amount)
	var slot := enemies.find(foe)
	if slot >= 0:
		enemy_damaged.emit(slot, amount, source)


func _roll_loot() -> Dictionary:
	const ItemDataScript = preload("res://scripts/game/item_data.gd")
	return ItemDataScript.roll_loot_instance(ItemDataScript.current_ilvl())
