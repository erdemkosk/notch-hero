extends RefCounted
class_name CombatBiome

const StageDataScript = preload("res://scripts/game/stage_data.gd")

const FALLBACK := {
	"desert": {
		"label": "Col",
		"sky": Color(0.58, 0.28, 0.22),
		"ground": Color(0.86, 0.76, 0.42),
		"ground_dark": Color(0.72, 0.6, 0.32),
		"accent": Color(0.2, 0.55, 0.25),
		"accent_dark": Color(0.12, 0.36, 0.16),
		"trunk": Color(0.45, 0.3, 0.15),
		"decor": "desert",
	},
}


static func resolve(biome_id: String) -> Dictionary:
	var from_json := StageDataScript.get_biome(biome_id)
	if not from_json.is_empty():
		return from_json
	if FALLBACK.has(biome_id):
		return FALLBACK[biome_id]
	return FALLBACK["desert"]


static func label_for(biome_id: String) -> String:
	return str(resolve(biome_id).get("label", biome_id))
