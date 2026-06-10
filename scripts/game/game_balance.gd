extends RefCounted
class_name GameBalance

const CONFIG_PATH := "res://data/game_config.json"

const DEFAULTS := {
	"hero": {
		"base_attack": 3,
		"base_max_hp": 10,
		"base_max_mana": 40,
		"base_spell_power": 0,
		"level_hp_gain": 2,
		"level_spell_power_gain": 1,
		"staff_enchant_attack": 1.0,
		"min_damage_taken": 1,
	},
	"combat": {
		"armor_blocks_per_point": 1.0,
	},
	"stages": {
		"enemy_scale_base": 0.58,
		"enemy_scale_per_stage": 0.11,
		"first_stage_boss_factor": 0.48,
		"early_boss_factor": 0.72,
	},
	"loot": {
		"drop_chance": 0.08,
		"boss_drop_chance": 0.22,
		"rarity_unique": 0.012,
		"rarity_rare": 0.08,
		"rarity_common": 0.30,
		"pity_kills": 18,
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


static func combat_cfg() -> Dictionary:
	if not _loaded:
		load_config()
	return _config.get("combat", DEFAULTS["combat"]) as Dictionary


static func stage_cfg() -> Dictionary:
	if not _loaded:
		load_config()
	return _config.get("stages", DEFAULTS["stages"]) as Dictionary


static func enemy_difficulty_mul(stage_index: int) -> float:
	var cfg := stage_cfg()
	var base := float(cfg.get("enemy_scale_base", 0.58))
	var per := float(cfg.get("enemy_scale_per_stage", 0.11))
	return maxf(0.35, base + stage_index * per)


static func boss_difficulty_factor(stage_index: int) -> float:
	var cfg := stage_cfg()
	if stage_index <= 0:
		return float(cfg.get("first_stage_boss_factor", 0.48))
	if stage_index <= 2:
		return float(cfg.get("early_boss_factor", 0.72))
	return 1.0


static func loot_cfg() -> Dictionary:
	if not _loaded:
		load_config()
	return _config.get("loot", DEFAULTS["loot"]) as Dictionary


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
	var blocks := float(combat_cfg().get("armor_blocks_per_point", 1.0))
	var min_dmg := float(hero_cfg().get("min_damage_taken", 1.0))
	return maxf(min_dmg, raw_damage - armor * blocks)
