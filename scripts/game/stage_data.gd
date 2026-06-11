extends RefCounted
class_name StageData

const DEFAULT_PATH := "res://data/stages.json"

static var _biomes: Dictionary = {}
static var _enemy_defs: Dictionary = {}


static func load_document(path: String = DEFAULT_PATH) -> Array:
	_biomes.clear()
	_enemy_defs.clear()
	if not FileAccess.file_exists(path):
		push_error("Stage file not found: %s" % path)
		return []

	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("Failed to parse stage JSON: %s" % path)
		return []

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Stage JSON root must be an object")
		return []

	_biomes = _parse_biomes(parsed.get("biomes", {}))
	_enemy_defs = _parse_enemy_defs(parsed.get("enemy_defs", {}))

	var raw: Array = parsed.get("stages", [])
	var stages: Array = []
	for i in raw.size():
		var entry: Variant = raw[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var stage: Dictionary = _normalize_stage(entry)
		if not stage.is_empty():
			stages.append(stage)
	return stages


static func load_stages(path: String = DEFAULT_PATH) -> Array:
	return load_document(path)


static func get_biome(biome_id: String) -> Dictionary:
	return _biomes.get(biome_id, {})


static func biome_ids() -> Array:
	return _biomes.keys()


static func get_enemy_def(type_id: String) -> Dictionary:
	if _enemy_defs.has(type_id):
		return _enemy_defs[type_id]
	return {
		"hp": 28.0,
		"attack": 3.0,
		"gold": 5,
		"xp": 8,
		"scale": 1.0,
		"boss": false,
		"role": "melee",
	}


static func enemy_scale_mul(type_id: String) -> float:
	return float(get_enemy_def(type_id).get("scale", 1.0))


static func is_boss_type(type_id: String) -> bool:
	return bool(get_enemy_def(type_id).get("boss", false))


static func enemy_name(type_id: String) -> String:
	return str(get_enemy_def(type_id).get("name", type_id.capitalize()))


static func _parse_enemy_defs(raw: Variant) -> Dictionary:
	var defs := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return defs

	for type_id in raw.keys():
		var entry: Variant = raw[type_id]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		defs[str(type_id)] = {
			"name": str(entry.get("name", str(type_id).capitalize())),
			"role": str(entry.get("role", "melee")),
			"hp": float(entry.get("hp", 28.0)),
			"attack": float(entry.get("attack", 3.0)),
			"gold": int(entry.get("gold", 5)),
			"xp": int(entry.get("xp", 8)),
			"scale": float(entry.get("scale", 1.0)),
			"boss": bool(entry.get("boss", false)),
		}
	return defs


static func label_for(stage: Dictionary) -> String:
	return "%d-%d" % [int(stage.get("world", 1)), int(stage.get("stage", 1))]


static func _parse_biomes(raw: Variant) -> Dictionary:
	var biomes := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return biomes

	for biome_id in raw.keys():
		var entry: Variant = raw[biome_id]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var parsed: Dictionary = _normalize_biome(str(biome_id), entry)
		if not parsed.is_empty():
			biomes[biome_id] = parsed
	return biomes


static func _normalize_biome(biome_id: String, entry: Dictionary) -> Dictionary:
	return {
		"label": str(entry.get("label", biome_id)),
		"sky": _color_from(entry.get("sky", [0.5, 0.5, 0.5])),
		"ground": _color_from(entry.get("ground", [0.6, 0.6, 0.5])),
		"ground_dark": _color_from(entry.get("ground_dark", [0.4, 0.4, 0.35])),
		"accent": _color_from(entry.get("accent", [0.5, 0.5, 0.5])),
		"accent_dark": _color_from(entry.get("accent_dark", [0.3, 0.3, 0.3])),
		"trunk": _color_from(entry.get("trunk", [0.35, 0.25, 0.15])),
		"decor": str(entry.get("decor", biome_id)),
	}


static func _color_from(value: Variant) -> Color:
	if typeof(value) == TYPE_STRING:
		var text: String = value.strip_edges()
		if text.begins_with("#"):
			return Color.html(text)
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		var alpha := 1.0
		if value.size() > 3:
			alpha = float(value[3])
		return Color(float(value[0]), float(value[1]), float(value[2]), alpha)
	return Color(0.5, 0.5, 0.5)


static func _normalize_stage(entry: Dictionary) -> Dictionary:
	var waves_raw: Array = entry.get("waves", [])
	var waves: Array = []
	for wave_entry in waves_raw:
		if typeof(wave_entry) != TYPE_DICTIONARY:
			continue
		var enemies: Array = []
		for enemy_type in wave_entry.get("enemies", []):
			if typeof(enemy_type) == TYPE_STRING:
				enemies.append(enemy_type)
		if enemies.is_empty():
			continue
		waves.append({"enemies": enemies})

	if waves.is_empty():
		return {}

	var biome := str(entry.get("biome", "desert"))

	return {
		"world": int(entry.get("world", 1)),
		"stage": int(entry.get("stage", 1)),
		"name": str(entry.get("name", "Bilinmeyen")),
		"biome": biome,
		"waves": waves,
	}
