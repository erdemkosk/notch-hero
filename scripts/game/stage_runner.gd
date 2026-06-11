extends RefCounted
class_name StageRunner

signal stage_entered(info: Dictionary)

const Hero = preload("res://scripts/game/hero.gd")
const StageDataScript = preload("res://scripts/game/stage_data.gd")
const GameBalanceScript = preload("res://scripts/game/game_balance.gd")

var stages: Array = []
var stage_index := 0
var wave_index := 0
var _checkpoint: Dictionary = {}


func load(path: String = StageDataScript.DEFAULT_PATH) -> void:
	stages = StageDataScript.load_document(path)


func start_run(hero: Hero) -> void:
	stage_index = 0
	wave_index = 0
	_begin_current_stage(hero)


func restore_from_save(hero: Hero, stage_idx: int, wave_idx: int) -> void:
	if stages.is_empty():
		return
	stage_index = clampi(stage_idx, 0, maxi(0, stages.size() - 1))
	wave_index = maxi(0, wave_idx)
	wave_index = mini(wave_index, maxi(0, wave_count() - 1))
	_checkpoint = _snapshot_hero(hero)
	_refill_hero(hero)
	_emit_wave(hero, "wave")


func current_stage() -> Dictionary:
	if stages.is_empty():
		return {}
	return stages[stage_index]


func current_label() -> String:
	var stage := current_stage()
	if stage.is_empty():
		return "?-?"
	return StageDataScript.label_for(stage)


func wave_count() -> int:
	var stage := current_stage()
	if stage.is_empty():
		return 0
	return stage.get("waves", []).size()


func current_wave_enemies() -> Array:
	var stage := current_stage()
	if stage.is_empty():
		return []
	var waves: Array = stage.get("waves", [])
	if wave_index < 0 or wave_index >= waves.size():
		return []
	var wave: Dictionary = waves[wave_index]
	var enemies: Array = []
	for enemy_type in wave.get("enemies", []):
		if typeof(enemy_type) == TYPE_STRING:
			enemies.append(enemy_type)
	return enemies


func enemy_difficulty_for(type_id: String) -> float:
	var mul := GameBalanceScript.enemy_difficulty_mul(stage_index, wave_index)
	if StageDataScript.is_boss_type(type_id):
		mul *= GameBalanceScript.boss_difficulty_factor(stage_index)
	return mul


func on_wave_cleared(hero: Hero) -> void:
	if stages.is_empty():
		return

	wave_index += 1
	var waves: Array = current_stage().get("waves", [])
	if wave_index < waves.size():
		_emit_wave(hero, "wave")
		return

	stage_index += 1
	if stage_index >= stages.size():
		stage_index = 0
	_begin_current_stage(hero)


func on_hero_died(hero: Hero) -> void:
	if stages.is_empty():
		return
	_restore_hero(hero)
	wave_index = 0
	_refill_hero(hero)
	_emit_wave(hero, "retry")


func _begin_current_stage(hero: Hero) -> void:
	_refill_hero(hero)
	_checkpoint = _snapshot_hero(hero)
	wave_index = 0
	_emit_wave(hero, "stage")


func _emit_wave(hero: Hero, transition: String) -> void:
	var stage := current_stage()
	if stage.is_empty():
		return

	var waves: Array = stage.get("waves", [])
	if wave_index < 0 or wave_index >= waves.size():
		return

	var wave: Dictionary = waves[wave_index]
	var biome: String = str(stage.get("biome", "desert"))
	stage_entered.emit({
		"label": StageDataScript.label_for(stage),
		"name": stage.get("name", ""),
		"biome": biome,
		"world": stage.get("world", 1),
		"stage": stage.get("stage", 1),
		"wave_index": wave_index,
		"wave_count": waves.size(),
		"enemies": wave.get("enemies", []),
		"transition": transition,
	})


func _snapshot_hero(hero: Hero) -> Dictionary:
	return {
		"school": hero.school,
		"level": hero.level,
		"xp": hero.xp,
		"xp_to_next": hero.xp_to_next,
		"gold": hero.gold,
		"hp": hero.hp,
		"max_hp": hero.max_hp,
		"mana": hero.mana,
		"max_mana": hero.max_mana,
		"intelligence": hero.intelligence,
		"spell_power": hero.spell_power,
		"mana_regen": hero.mana_regen,
		"staff_enchant": hero.staff_enchant,
		"level_hp_bonus": hero.level_hp_bonus,
		"level_spell_power_bonus": hero.level_spell_power_bonus,
	}


func _refill_hero(hero: Hero) -> void:
	hero.refresh_combat_stats()
	hero.heal_to_full()
	hero.mana = hero.max_mana


func _restore_hero(hero: Hero) -> void:
	if _checkpoint.is_empty():
		return

	hero.school = _checkpoint.get("school", hero.school)
	hero.level = _checkpoint.get("level", hero.level)
	hero.xp = _checkpoint.get("xp", hero.xp)
	hero.xp_to_next = _checkpoint.get("xp_to_next", hero.xp_to_next)
	hero.gold = _checkpoint.get("gold", hero.gold)
	hero.intelligence = _checkpoint.get("intelligence", hero.intelligence)
	hero.mana_regen = _checkpoint.get("mana_regen", hero.mana_regen)
	hero.staff_enchant = _checkpoint.get("staff_enchant", hero.staff_enchant)
	hero.level_hp_bonus = float(_checkpoint.get("level_hp_bonus", hero.level_hp_bonus))
	hero.level_spell_power_bonus = int(_checkpoint.get("level_spell_power_bonus", hero.level_spell_power_bonus))
	hero.refresh_combat_stats()
