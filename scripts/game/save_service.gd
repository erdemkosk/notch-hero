extends RefCounted
class_name SaveService

const SAVE_PATH := "user://save.json"
const VERSION := 1


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


static func save_game(data: Dictionary) -> bool:
	var payload := data.duplicate(true)
	payload["version"] = VERSION
	var json := JSON.stringify(payload, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Save failed: %s" % SAVE_PATH)
		return false
	file.store_string(json)
	return true


static func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save parse failed")
		return {}

	var data: Dictionary = parsed
	if int(data.get("version", 0)) != VERSION:
		push_warning("Save version mismatch")
		return {}

	return data


static func build_payload() -> Dictionary:
	if typeof(GameState) == TYPE_NIL or GameState.hero == null:
		return {}

	var hero := GameState.hero
	return {
		"player_name": hero.player_name,
		"hero": hero.to_dict(),
		"stage_index": GameState.stage_runner.stage_index,
		"wave_index": GameState.stage_runner.wave_index,
		"total_kills": GameState.total_kills,
		"kills_without_loot": GameState.kills_without_loot,
		"market_prices": GameState.market_prices.duplicate(),
		"save_timestamp": Time.get_unix_time_from_system(),
	}
