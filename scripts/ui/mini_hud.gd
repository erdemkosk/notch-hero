extends Control

const Hero = preload("res://scripts/game/hero.gd")
const StatBarControl = preload("res://scripts/ui/stat_bar.gd")
const Enemy = preload("res://scripts/game/enemy.gd")

@onready var wizard_sprite: ColorRect = $HBox/WizardSprite
@onready var hp_bar: StatBarControl = $HBox/Bars/HPBar
@onready var mp_bar: StatBarControl = $HBox/Bars/MPBar
@onready var enemy_label: Label = $HBox/EnemyBox/EnemyLabel
@onready var spell_flash: Label = $SpellFlash

var _flash_timer := 0.0


func _ready() -> void:
	GameState.state_changed.connect(refresh)
	GameState.combat_event.connect(_on_combat_event)
	refresh()


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		spell_flash.modulate.a = clampf(_flash_timer * 2.0, 0.0, 1.0)
	else:
		spell_flash.modulate.a = 0.0


func refresh() -> void:
	var hero: Hero = GameState.hero
	var enemy: Enemy = GameState.combat.enemy
	wizard_sprite.color = Color(0.82, 0.72, 0.55)
	hp_bar.bar_color = Color(0.95, 0.28, 0.35)
	mp_bar.bar_color = Color(0.35, 0.55, 1.0)
	hp_bar.set_value(hero.hp, hero.max_hp)
	mp_bar.set_value(hero.mana, hero.max_mana)

	enemy_label.text = "%s  %.0f/%.0f" % [enemy.name, enemy.hp, enemy.max_hp]
	if enemy.status != Enemy.Status.NONE:
		var status_name := "YAN" if enemy.status == Enemy.Status.BURNING else "DON"
		enemy_label.text += " [%s]" % status_name


func _on_combat_event(text: String) -> void:
	spell_flash.text = text
	_flash_timer = 0.6
