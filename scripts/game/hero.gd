extends RefCounted

const MagicSchoolScript = preload("res://scripts/game/magic_school.gd")
const ItemDataScript = preload("res://scripts/game/item_data.gd")

var school: MagicSchoolScript.School = MagicSchoolScript.School.PYROMANCY
var level: int = 1
var xp: int = 0
var xp_to_next: int = 40
var gold: int = 0

var hp: float = 100.0
var max_hp: float = 100.0
var mana: float = 60.0
var max_mana: float = 60.0

var intelligence: int = 5
var spell_power: int = 5
var mana_regen: float = 3.0

var staff_enchant: int = 0
var inventory: Array[Dictionary] = []
var equipment: Dictionary = {}

signal loot_added(item: Dictionary)


func _init() -> void:
	_reset_equipment()


func _reset_equipment() -> void:
	equipment.clear()
	for slot in ItemDataScript.EQUIP_SLOTS:
		equipment[slot] = null


func xp_progress() -> float:
	if xp_to_next <= 0:
		return 1.0
	return clampf(float(xp) / float(xp_to_next), 0.0, 1.0)


func add_xp(amount: int) -> bool:
	xp += amount
	var leveled := false
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		leveled = true
		_on_level_up()
	return leveled


func _on_level_up() -> void:
	xp_to_next = 35 + level * 18
	intelligence += 1
	spell_power += 2
	max_hp += 12.0
	max_mana += 8.0
	hp = max_hp
	mana = max_mana


func regen_mana(delta_scale: float = 1.0) -> void:
	mana = minf(max_mana, mana + mana_regen * delta_scale)


func take_damage(amount: float) -> void:
	hp = maxf(0.0, hp - amount)


func heal_to_full() -> void:
	hp = max_hp


func school_bonus_for(element: String) -> float:
	match school:
		MagicSchoolScript.School.PYROMANCY:
			return 1.25 if element == "fire" else 1.0
		MagicSchoolScript.School.CRYOMANCY:
			return 1.25 if element == "ice" else 1.0
		MagicSchoolScript.School.ARCANE:
			return 1.25 if element == "arcane" else 1.0
	return 1.0


func add_loot(item: Dictionary) -> void:
	inventory.append(item)
	loot_added.emit(item)


func staff_damage() -> float:
	return 4.0 + staff_enchant * 1.5 + spell_power * 0.4


func equipped_items() -> Array:
	var items: Array = []
	for slot in equipment.keys():
		var item: Variant = equipment[slot]
		if item != null and typeof(item) == TYPE_DICTIONARY:
			items.append(item)
	return items


func equipment_stats() -> Dictionary:
	return ItemDataScript.aggregate_stats(equipped_items())


func weapon_damage() -> float:
	return staff_damage() + equipment_stats().get("attack", 0.0)
