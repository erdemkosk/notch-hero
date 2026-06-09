extends RefCounted

const Hero = preload("res://scripts/game/hero.gd")
const Enemy = preload("res://scripts/game/enemy.gd")
const MagicSchoolScript = preload("res://scripts/game/magic_school.gd")

signal spell_cast(info: Dictionary)
signal enemy_defeated(rewards: Dictionary)
signal enemy_slain(slot: int)
signal wave_spawned(count: int, types: PackedStringArray)
signal hero_damaged(amount: float)
signal combo_triggered(name: String, damage: float)

var hero: Hero
var enemy: Enemy
var enemies: Array[Enemy] = []
var enemy_types: PackedStringArray = []
var last_spell_name := "Asa"
var combo_flash := ""
var _slain_flags: Array[bool] = []


func _init(p_hero: Hero) -> void:
	hero = p_hero


func spawn_wave(count: int) -> void:
	enemies.clear()
	enemy_types.clear()
	_slain_flags.clear()
	count = clampi(count, 1, 3)

	for i in count:
		var foe := Enemy.new()
		foe.reset_for_level(hero.level)
		if count > 1:
			foe.max_hp *= 0.72
			foe.hp = foe.max_hp
		enemies.append(foe)
		enemy_types.append("adventurer" if randf() < 0.42 else "gladiator")
		_slain_flags.append(false)

	_sync_primary()
	wave_spawned.emit(count, enemy_types)


func living_count() -> int:
	var n := 0
	for foe in enemies:
		if foe.hp > 0.0:
			n += 1
	return n


func tick_passive() -> void:
	hero.regen_mana(0.45)


func tick_melee() -> void:
	if enemies.is_empty() or living_count() <= 0:
		return

	combo_flash = ""
	hero.regen_mana()

	for foe in enemies:
		if foe.hp <= 0.0:
			continue
		var dot := foe.tick_status()
		if dot > 0.0:
			_damage_enemy_at(foe, dot, "Yanma", false)

	var target := _front_enemy()
	if target == null or target.hp <= 0.0:
		_cleanup_dead()
		return

	var cast := _cast_next_spell()
	if not cast.is_empty():
		var dmg: float = cast.get("damage", 0.0)
		last_spell_name = cast.get("name", "?")
		_damage_enemy_at(target, dmg, last_spell_name, cast.get("show_combo", false))

	_cleanup_dead()
	if living_count() <= 0:
		return

	_all_enemies_strike()


func tick() -> void:
	tick_melee()


func _front_enemy() -> Enemy:
	for foe in enemies:
		if foe.hp > 0.0:
			return foe
	return null


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
	var gold := foe.gold_reward
	var xp := foe.xp_reward
	hero.gold += gold
	var leveled := hero.add_xp(xp)
	hero.add_loot(_roll_loot())
	return {"gold": gold, "xp": xp, "leveled": leveled}


func _all_enemies_strike() -> void:
	var total := 0.0
	for foe in enemies:
		if foe.hp <= 0.0 or foe.is_frozen():
			continue
		total += 2.0 + foe.level * 1.0

	if total <= 0.0:
		return

	hero.take_damage(total)
	hero_damaged.emit(total)
	if hero.hp <= 0.0:
		hero.heal_to_full()


func _cast_next_spell() -> Dictionary:
	if hero.mana >= 20.0:
		return _cast_arcane_bolt()
	if hero.mana >= 15.0 and (hero.school == MagicSchoolScript.School.PYROMANCY or randf() > 0.45):
		return _cast_fireball()
	if hero.mana >= 12.0:
		return _cast_frostbolt()
	return _cast_staff()


func _cast_staff() -> Dictionary:
	var dmg := hero.staff_damage()
	spell_cast.emit({"name": "Asa", "damage": dmg, "element": "physical"})
	return {"name": "Asa", "damage": dmg}


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
	spell_cast.emit({"name": "Ates Topu", "damage": dmg, "element": "fire", "combo": combo})
	return {"name": "Ates Topu", "damage": dmg, "show_combo": combo}


func _cast_frostbolt() -> Dictionary:
	hero.mana -= 12.0
	var target := _front_enemy()
	var dmg := (7.0 + hero.spell_power * 1.1) * hero.school_bonus_for("ice")
	if target != null:
		target.apply_status(Enemy.Status.FROZEN, 4)
	spell_cast.emit({"name": "Buz Oku", "damage": dmg, "element": "ice"})
	return {"name": "Buz Oku", "damage": dmg}


func _cast_arcane_bolt() -> Dictionary:
	hero.mana -= 20.0
	var dmg := (9.0 + hero.spell_power * 1.3) * hero.school_bonus_for("arcane")
	spell_cast.emit({"name": "Kadim Isin", "damage": dmg, "element": "arcane"})
	return {"name": "Kadim Isin", "damage": dmg}


func _damage_enemy_at(foe: Enemy, amount: float, _source: String, _combo: bool) -> void:
	foe.hp = maxf(0.0, foe.hp - amount)


func _roll_loot() -> Dictionary:
	var roll := randf()
	if roll > 0.92:
		return {"name": "Epik Asa", "rarity": "epic", "power": 4}
	if roll > 0.78:
		return {"name": "Nadir Pelerin", "rarity": "rare", "power": 2}
	if roll > 0.55:
		return {"name": "Tilsim Parcasi", "rarity": "common", "power": 1}
	return {"name": "Altin Tozu", "rarity": "common", "power": 0}
