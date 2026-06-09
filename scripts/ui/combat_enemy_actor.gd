extends RefCounted

const Enemy = preload("res://scripts/game/enemy.gd")

var enemy: Enemy
var enemy_type: String
var slot: int
var x: float
var alive := true


func _init(p_enemy: Enemy, p_type: String, p_slot: int, start_x: float) -> void:
	enemy = p_enemy
	enemy_type = p_type
	slot = p_slot
	x = start_x
