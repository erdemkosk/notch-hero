extends RefCounted

enum Status { NONE, BURNING, FROZEN }

var name: String = "Goblin Stajyeri"
var level: int = 1
var hp: float = 30.0
var max_hp: float = 30.0
var status: Status = Status.NONE
var status_ticks: int = 0
var gold_reward: int = 5
var xp_reward: int = 8


func reset_for_level(player_level: int) -> void:
	level = maxi(1, player_level + randi_range(-1, 1))
	max_hp = 24.0 + (level * 11.0)
	hp = max_hp
	status = Status.NONE
	status_ticks = 0
	gold_reward = 4 + level * 2
	xp_reward = 6 + level * 3
	name = _pick_name(level)


func apply_status(new_status: Status, duration: int = 4) -> void:
	status = new_status
	status_ticks = duration


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
