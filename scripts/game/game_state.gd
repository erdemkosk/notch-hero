extends Node

signal state_changed
signal combat_event(text: String)

const Hero = preload("res://scripts/game/hero.gd")
const CombatEngineScript = preload("res://scripts/game/combat_engine.gd")
const MagicSchoolScript = preload("res://scripts/game/magic_school.gd")

const TICK_SEC := 0.32

var hero: Hero
var combat: CombatEngineScript
var market_prices := {
	"fire_crystal": 12.0,
	"ice_shard": 10.0,
	"arcane_dust": 15.0,
}
var recent_log: Array[String] = []
var total_kills: int = 0
var melee_engaged := false

var _tick_timer: Timer


func _ready() -> void:
	hero = Hero.new()
	combat = CombatEngineScript.new(hero)
	combat.spell_cast.connect(_on_spell_cast)
	combat.enemy_defeated.connect(_on_enemy_defeated)
	combat.combo_triggered.connect(_on_combo)

	_tick_timer = Timer.new()
	_tick_timer.wait_time = TICK_SEC
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)
	_tick_timer.start()


func set_school(school: int) -> void:
	hero.school = school as MagicSchoolScript.School
	_log("Ekol: %s" % MagicSchoolScript.NAMES[hero.school])
	state_changed.emit()


func set_melee_engaged(active: bool) -> void:
	if melee_engaged == active:
		return
	melee_engaged = active


func combat_melee_exchange() -> void:
	if not melee_engaged:
		return
	combat.tick_melee()
	state_changed.emit()


func combat_tick() -> void:
	if melee_engaged:
		combat.tick_melee()
	else:
		combat.tick_passive()
	_drift_market()
	state_changed.emit()


func forge_enchant() -> bool:
	var cost: int = 25 + hero.staff_enchant * 18
	if hero.gold < cost:
		_log("Ors: yetersiz altin (%d)" % cost)
		return false

	hero.gold -= cost
	if hero.staff_enchant >= 5 and randf() < 0.18 + hero.staff_enchant * 0.03:
		hero.staff_enchant = 0
		_log("Ors: asa YANDI! +0")
		state_changed.emit()
		return false

	hero.staff_enchant += 1
	_log("Ors: asa +%d oldu" % hero.staff_enchant)
	state_changed.emit()
	return true


func sell_item(index: int) -> bool:
	if index < 0 or index >= hero.inventory.size():
		return false
	var item: Dictionary = hero.inventory[index]
	var value := 8 + int(item.get("power", 1)) * 6
	hero.gold += value
	hero.inventory.remove_at(index)
	_log("Satildi: %s (+%d altin)" % [item.get("name", "?"), value])
	state_changed.emit()
	return true


func buy_crystal(key: String) -> bool:
	if not market_prices.has(key):
		return false
	var price: float = market_prices[key]
	var cost := int(round(price))
	if hero.gold < cost:
		_log("Pazar: yetersiz altin")
		return false
	hero.gold -= cost
	hero.add_loot({"name": key, "rarity": "trade", "power": 1})
	_log("Alindi: %s (-%d altin)" % [key, cost])
	state_changed.emit()
	return true


func _on_tick() -> void:
	combat_tick()


func _on_spell_cast(info: Dictionary) -> void:
	if info.get("combo", false):
		return
	var dmg: float = info.get("damage", 0.0)
	combat_event.emit("%s %.0f" % [info.get("name", "?"), dmg])


func _on_enemy_defeated(rewards: Dictionary) -> void:
	total_kills += 1
	var msg := "+%d XP, +%d altin" % [rewards.get("xp", 0), rewards.get("gold", 0)]
	if rewards.get("leveled", false):
		msg += " | SEVIYE ATLADI!"
	_log(msg)


func _on_combo(name: String, damage: float) -> void:
	_log("%s %.0f hasar!" % [name, damage])
	combat_event.emit(name)


func _drift_market() -> void:
	for key in market_prices.keys():
		market_prices[key] = maxf(5.0, market_prices[key] + randf_range(-1.2, 1.2))


func _log(text: String) -> void:
	recent_log.push_front(text)
	if recent_log.size() > 6:
		recent_log.resize(6)
	combat_event.emit(text)
