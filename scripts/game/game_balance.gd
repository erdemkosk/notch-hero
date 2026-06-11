extends RefCounted
class_name GameBalance

const CONFIG_PATH := "res://data/game_config.json"

const DEFAULTS := {
	"hero": {
		"base_attack": 3,
		"base_max_hp": 10,
		"hp_mul": 5.0,
		"base_max_mana": 40,
		"base_spell_power": 0,
		"level_hp_gain": 2,
		"level_attack_gain": 1,
		"level_spell_power_gain": 1,
		"staff_enchant_attack": 1.0,
		"min_damage_taken": 1,
	},
	"combat": {
		"armor_reduction_divisor": 40.0,
		"armor_max_reduction_pct": 60.0,
		"double_attack_speed_pct": 75.0,
	},
	"stages": {
		"stages_per_world": 3,
		"layer_scale_base": 0.65,
		"layer_scale_per_layer": 0.035,
		"layer_scale_per_wave": 0.012,
		"enemy_level_hp_mul": 0.04,
		"enemy_level_atk_mul": 0.04,
		"enemy_boss_level_hp_mul": 0.06,
		"enemy_boss_level_atk_mul": 0.06,
		"enemy_role_hp_mod": {
			"melee": 1.0,
			"ranged": 0.85,
			"charger": 1.28,
		},
		"enemy_role_atk_mod": {
			"melee": 1.0,
			"ranged": 1.18,
			"charger": 1.12,
		},
		"multi_enemy_hp_mul": 0.88,
		"first_layer_boss_factor": 0.72,
		"early_layer_boss_factor": 0.88,
		"boss_hp_base": 32.0,
		"boss_atk_base": 3.5,
		"boss_scale_per_layer": 0.28,
		"enemy_hp_mul": 5.0,
		"enemy_damage_mul": 2.0,
	},
	"loot": {
		"drop_chance": 0.05,
		"boss_drop_chance": 0.15,
		"potion_drop_chance": 0.10,
		"boss_potion_drop_chance": 0.20,
		"rarity_unique": 0.012,
		"rarity_rare": 0.08,
		"rarity_common": 0.30,
		"pity_kills": 28,
	},
	"inventory": {
		"base_bag_slots": 9,
	},
	"consumables": {
		"max_stack": 5,
		"auto_hp_threshold": 0.5,
		"auto_mana_threshold": 0.25,
		"use_cooldown_ticks": 1,
		"starter_health": 0,
	},
}

static var _config: Dictionary = {}
static var _loaded := false


static func load_config() -> void:
	_config = DEFAULTS.duplicate(true)
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("Game config not found, using defaults: %s" % CONFIG_PATH)
		_loaded = true
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_error("Failed to parse game config JSON")
		_loaded = true
		return

	_merge_section("hero", parsed)
	_merge_section("combat", parsed)
	_merge_section("stages", parsed)
	_merge_section("loot", parsed)
	_merge_section("inventory", parsed)
	_merge_section("consumables", parsed)
	_loaded = true


static func _merge_section(key: String, parsed: Dictionary) -> void:
	if not parsed.has(key) or typeof(parsed[key]) != TYPE_DICTIONARY:
		return
	var section: Dictionary = _config.get(key, {}) as Dictionary
	for entry_key in (parsed[key] as Dictionary).keys():
		section[entry_key] = parsed[key][entry_key]
	_config[key] = section


static func hero_cfg() -> Dictionary:
	if not _loaded:
		load_config()
	return _config.get("hero", DEFAULTS["hero"]) as Dictionary


static func hero_hp_mul() -> float:
	return maxf(0.1, float(hero_cfg().get("hp_mul", 1.0)))


static func enemy_hp_mul() -> float:
	return maxf(0.1, float(stage_cfg().get("enemy_hp_mul", 1.0)))


static func enemy_damage_mul() -> float:
	return maxf(0.1, float(stage_cfg().get("enemy_damage_mul", 1.0)))


static func combat_cfg() -> Dictionary:
	if not _loaded:
		load_config()
	return _config.get("combat", DEFAULTS["combat"]) as Dictionary


static func stage_cfg() -> Dictionary:
	if not _loaded:
		load_config()
	return _config.get("stages", DEFAULTS["stages"]) as Dictionary


static func stages_per_world() -> int:
	return maxi(1, int(stage_cfg().get("stages_per_world", 3)))


static func progression_layer(world: int, stage_num: int) -> int:
	return maxi(0, (maxi(1, world) - 1) * stages_per_world() + maxi(1, stage_num) - 1)


static func enemy_difficulty_mul_for_layer(layer: int, wave_index: int = 0) -> float:
	var cfg := stage_cfg()
	var base := float(cfg.get("layer_scale_base", 0.65))
	var per_layer := float(cfg.get("layer_scale_per_layer", 0.035))
	var per_wave := float(cfg.get("layer_scale_per_wave", 0.012))
	return maxf(0.35, base + layer * per_layer + wave_index * per_wave)


static func enemy_difficulty_mul(stage_index: int, wave_index: int = 0) -> float:
	return enemy_difficulty_mul_for_layer(stage_index, wave_index)


static func boss_difficulty_factor(layer: int) -> float:
	var cfg := stage_cfg()
	if layer <= 0:
		return float(cfg.get("first_layer_boss_factor", cfg.get("first_stage_boss_factor", 0.72)))
	if layer <= 2:
		return float(cfg.get("early_layer_boss_factor", cfg.get("early_boss_factor", 0.88)))
	return 1.0


static func loot_cfg() -> Dictionary:
	if not _loaded:
		load_config()
	return _config.get("loot", DEFAULTS["loot"]) as Dictionary


static func inventory_cfg() -> Dictionary:
	if not _loaded:
		load_config()
	return _config.get("inventory", DEFAULTS["inventory"]) as Dictionary


static func base_bag_slots() -> int:
	return maxi(1, int(inventory_cfg().get("base_bag_slots", 9)))


static func consumables_cfg() -> Dictionary:
	if not _loaded:
		load_config()
	return _config.get("consumables", DEFAULTS["consumables"]) as Dictionary


static func consumable_max_stack() -> int:
	return maxi(1, int(consumables_cfg().get("max_stack", 5)))


static func auto_hp_threshold() -> float:
	return clampf(float(consumables_cfg().get("auto_hp_threshold", 0.5)), 0.05, 0.95)


static func auto_mana_threshold() -> float:
	return clampf(float(consumables_cfg().get("auto_mana_threshold", 0.25)), 0.05, 0.95)


static func potion_use_cooldown_ticks() -> int:
	return maxi(0, int(consumables_cfg().get("use_cooldown_ticks", 1)))


static func starter_health_potions() -> int:
	return maxi(0, int(consumables_cfg().get("starter_health", 0)))


static func _normalize_chance(value: float) -> float:
	if value > 1.0:
		return clampf(value / 100.0, 0.0, 1.0)
	return clampf(value, 0.0, 1.0)


static func drop_chance(is_boss: bool) -> float:
	var loot := loot_cfg()
	if is_boss:
		return _normalize_chance(float(loot.get("boss_drop_chance", 0.40)))
	return _normalize_chance(float(loot.get("drop_chance", 0.12)))


static func should_drop_item(is_boss: bool) -> bool:
	return randf() < drop_chance(is_boss)


static func pity_kills() -> int:
	var loot := loot_cfg()
	return maxi(1, int(loot.get("pity_kills", 18)))


static func roll_kill_loot(is_boss: bool) -> bool:
	return should_drop_item(is_boss)


static func potion_drop_chance(is_boss: bool) -> float:
	var loot := loot_cfg()
	if is_boss:
		return _normalize_chance(float(loot.get("boss_potion_drop_chance", 0.20)))
	return _normalize_chance(float(loot.get("potion_drop_chance", 0.10)))


static func should_drop_potion(is_boss: bool) -> bool:
	return randf() < potion_drop_chance(is_boss)


static func roll_rarity() -> String:
	var loot := loot_cfg()
	var unique := clampf(float(loot.get("rarity_unique", 0.03)), 0.0, 1.0)
	var rare := clampf(float(loot.get("rarity_rare", 0.12)), 0.0, 1.0)
	var common := clampf(float(loot.get("rarity_common", 0.35)), 0.0, 1.0)
	var roll := randf()
	if roll < unique:
		return "unique"
	if roll < unique + rare:
		return "rare"
	if roll < unique + rare + common:
		return "common"
	return "basic"


static func apply_armor(raw_damage: float, armor: float) -> float:
	var min_dmg := float(hero_cfg().get("min_damage_taken", 1.0))
	if armor <= 0.0:
		return maxf(min_dmg, raw_damage)

	var cfg := combat_cfg()
	var divisor := maxf(1.0, float(cfg.get("armor_reduction_divisor", 40.0)))
	var max_pct := clampf(float(cfg.get("armor_max_reduction_pct", 60.0)), 0.0, 95.0) / 100.0
	var reduction := clampf(armor / (armor + divisor), 0.0, max_pct)
	return maxf(min_dmg, raw_damage * (1.0 - reduction))
