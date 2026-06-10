extends RefCounted

const StageDataScript = preload("res://scripts/game/stage_data.gd")

enum Status { NONE, BURNING, FROZEN }

var name: String = "Goblin Stajyeri"
var level: int = 1
var hp: float = 30.0
var max_hp: float = 30.0
var attack_damage: float = 3.0
var is_boss: bool = false
var status: Status = Status.NONE
var status_ticks: int = 0
var gold_reward: int = 5
var xp_reward: int = 8


func reset_for_level(player_level: int) -> void:
	apply_type_def("gladiator", player_level)


func apply_type_def(type_id: String, player_level: int, difficulty_mul: float = 1.0) -> void:
	var def: Dictionary = StageDataScript.get_enemy_def(type_id)
	level = maxi(1, player_level + randi_range(-1, 1))
	is_boss = bool(def.get("boss", false))

	var hp_base := float(def.get("hp", 28.0))
	var atk_base := float(def.get("attack", 3.0))
	var level_mul := 1.0 + float(level - 1) * (0.12 if is_boss else 0.08)
	var diff := maxf(0.25, difficulty_mul)

	max_hp = hp_base * level_mul * diff
	hp = max_hp
	attack_damage = atk_base * level_mul * diff
	gold_reward = int(round(float(def.get("gold", 5)) * (1.4 if is_boss else 1.0)))
	xp_reward = int(round(float(def.get("xp", 8)) * (1.5 if is_boss else 1.0)))

	status = Status.NONE
	status_ticks = 0

	if def.has("name"):
		name = str(def["name"])
	elif is_boss:
		name = "%s BOSS" % type_id.capitalize()
	else:
		name = _pick_name(level)


func tick_status() -> float:
	if status == Status.NONE:
		return 0.0

	status_ticks -= 1
	var dot := 0.0
	if status == Status.BURNING:
		dot = 2.0 + level * 0.5

	if status_ticks <= 0:
		status = Status.NONE
	return dot


func is_frozen() -> bool:
	return status == Status.FROZEN


func apply_status(new_status: Status, duration: int = 4) -> void:
	status = new_status
	status_ticks = duration


static func _pick_name(enemy_level: int) -> String:
	var pool := [
		"Excel Imp",
		"Slack Ghoul",
		"Standup Specter",
		"Jira Wraith",
		"Teams Phantom",
	]
	if enemy_level >= 5:
		pool.append("Patron Lich")
	if enemy_level >= 8:
		pool.append("OKR Dragon")
	return pool[randi() % pool.size()]
