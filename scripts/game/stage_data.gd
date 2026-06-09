extends RefCounted
class_name StageData

const DEFAULT_PATH := "res://data/stages.json"

static var _biomes: Dictionary = {}
static var _enemy_defs: Dictionary = {}


static func load_document(path: String = DEFAULT_PATH) -> Array:
	_biomes.clear()
	_enemy_defs.clear()
	if not FileAccess.file_exists(path):
		push_error("Stage dosyasi bulunamadi: %s" % path)
		return []

	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("Stage JSON okunamadi: %s" % path)
		return []

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Stage JSON kok nesnesi olmali")
		return []

	_biomes = _parse_biomes(parsed.get("biomes", {}))
	_enemy_defs = _parse_enemy_defs(parsed.get("enemy_defs", {}))

	var raw: Array = parsed.get("stages", [])
	var stages: Array = []
	for i in raw.size():
		var entry: Variant = raw[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var stage: Dictionary = _normalize_stage(entry, i)
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


static func _normalize_stage(entry: Dictionary, progress_index: int = 0) -> Dictionary:
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

	waves = _expand_waves_for_progress(waves, progress_index)

	var biome := str(entry.get("biome", "desert"))

	return {
		"world": int(entry.get("world", 1)),
		"stage": int(entry.get("stage", 1)),
		"name": str(entry.get("name", "Bilinmeyen")),
		"biome": biome,
		"waves": waves,
	}


static func _expand_waves_for_progress(waves: Array, progress_index: int) -> Array:
	if progress_index <= 0 or waves.is_empty():
		return waves

	var expanded: Array = []
	for wave in waves:
		var enemies: Array = wave.get("enemies", [])
		expanded.append({"enemies": _expand_wave_enemies(enemies, progress_index)})

	var boss_idx := _boss_wave_index(expanded)
	var extra_waves := mini(progress_index / 2, 3)
	var insert_at := boss_idx if boss_idx >= 0 else expanded.size()
	var template_idx := clampi(insert_at - 1, 0, expanded.size() - 1)
	var filler_pool := _stage_filler_pool(waves)

	for i in extra_waves:
		var template: Array = expanded[template_idx].get("enemies", []).duplicate()
		if _enemies_contain_boss(template):
			template = expanded[clampi(template_idx, 0, expanded.size() - 1)].get("enemies", []).duplicate()
			template = template.filter(func(t): return not is_boss_type(str(t)))
		if template.is_empty() and not filler_pool.is_empty():
			template = [filler_pool[0]]
		elif not filler_pool.is_empty():
			template.append(filler_pool[(progress_index + i) % filler_pool.size()])
		expanded.insert(insert_at, {"enemies": template})

	return expanded


static func _expand_wave_enemies(enemies: Array, progress_index: int) -> Array:
	var result: Array = enemies.duplicate()
	if _enemies_contain_boss(result):
		return result

	var bonus := mini(progress_index / 3, 2)
	var pool := _non_boss_enemies(result)
	if pool.is_empty():
		pool = _stage_filler_pool([{"enemies": result}])
	if pool.is_empty():
		pool = ["gladiator"]

	for i in bonus:
		result.append(pool[(progress_index + i) % pool.size()])
	return result


static func _boss_wave_index(waves: Array) -> int:
	for i in waves.size():
		if _enemies_contain_boss(waves[i].get("enemies", [])):
			return i
	return -1


static func _enemies_contain_boss(enemies: Array) -> bool:
	for enemy_type in enemies:
		if is_boss_type(str(enemy_type)):
			return true
	return false


static func _non_boss_enemies(enemies: Array) -> Array:
	var pool: Array = []
	for enemy_type in enemies:
		var id := str(enemy_type)
		if not is_boss_type(id) and not pool.has(id):
			pool.append(id)
	return pool


static func _stage_filler_pool(waves: Array) -> Array:
	var pool: Array = []
	for wave in waves:
		for enemy_type in wave.get("enemies", []):
			var id := str(enemy_type)
			if is_boss_type(id) or pool.has(id):
				continue
			pool.append(id)
	return pool
