extends Control

const HeroSpriteScript = preload("res://scripts/ui/hero_sprite.gd")
const EnemySpriteScript = preload("res://scripts/ui/enemy_sprite.gd")
const CombatEnemyActorScript = preload("res://scripts/ui/combat_enemy_actor.gd")

const SKY := Color(0.58, 0.28, 0.22)
const SAND := Color(0.86, 0.76, 0.42)
const SAND_DARK := Color(0.72, 0.6, 0.32)
const HP_ENEMY := Color(0.92, 0.28, 0.28)
const HP_ALLY := Color(0.35, 0.88, 0.45)
const TREE_TRUNK := Color(0.42, 0.28, 0.16)
const TREE_LEAF := Color(0.18, 0.48, 0.22)
const TREE_LEAF_D := Color(0.12, 0.36, 0.16)

const FRAME := 32.0
const SPRITE_SCALE := 2.0
const SPRITE_W := FRAME * SPRITE_SCALE
const HERO_ANCHOR_X := 0.68
const SCROLL_SPEED := 118.0
const APPROACH_SPEED := 98.0
const CONTACT_OVERLAP := 10.0
const ENEMY_SPAWN_X := -72.0
const SLOT_GAP := 54.0

var _scroll_x := 0.0
var _flash := 0.0
var _ground_y := 0.0
var _hero_x := 0.0
var _in_melee := false
var _wave_pause := 0.0
var _actors: Array[CombatEnemyActorScript] = []
var _sprites: Array[AnimatedSprite2D] = []

var _hero_sprite: AnimatedSprite2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_hero_sprite = AnimatedSprite2D.new()
	_hero_sprite.set_script(HeroSpriteScript)
	_hero_sprite.z_index = 4
	add_child(_hero_sprite)

	resized.connect(_layout_hero)
	GameState.combat.spell_cast.connect(_on_spell_cast)
	GameState.combat.hero_damaged.connect(_on_hero_damaged)
	GameState.combat.enemy_slain.connect(_on_enemy_slain)
	GameState.combat.enemy_defeated.connect(_on_enemy_defeated)
	GameState.combat.wave_spawned.connect(_on_wave_spawned)
	GameState.state_changed.connect(_on_state_changed)
	call_deferred("_layout_hero")
	call_deferred("_spawn_next_wave")


func _layout_hero() -> void:
	if size.x < 10.0:
		return
	var horizon := size.y * 0.42
	_ground_y = horizon + 8.0
	_hero_x = size.x * HERO_ANCHOR_X - SPRITE_W * 0.5
	_hero_sprite.position = Vector2(_hero_x, _ground_y - SPRITE_W)
	_hero_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_sync_actor_positions()


func _contact_x_for_slot(slot: int) -> float:
	return _contact_x() - float(slot) * SLOT_GAP


func _contact_x() -> float:
	return _hero_x - SPRITE_W + CONTACT_OVERLAP


func _pick_wave_size() -> int:
	var roll := randf()
	if roll < 0.14:
		return 3
	if roll < 0.42:
		return 2
	return 1


func _spawn_next_wave() -> void:
	_clear_visual_enemies()
	var count := _pick_wave_size()
	GameState.combat.spawn_wave(count)


func _on_wave_spawned(count: int, types: PackedStringArray) -> void:
	_clear_visual_enemies()
	for i in count:
		var actor: CombatEnemyActorScript = CombatEnemyActorScript.new(
			GameState.combat.enemies[i],
			types[i],
			i,
			ENEMY_SPAWN_X - float(i) * SLOT_GAP
		)
		var sprite := AnimatedSprite2D.new()
		sprite.set_script(EnemySpriteScript)
		sprite.setup(types[i])
		sprite.z_index = 1 + i
		add_child(sprite)
		_actors.append(actor)
		_sprites.append(sprite)
	_layout_hero()
	_in_melee = false
	GameState.set_melee_engaged(false)


func _clear_visual_enemies() -> void:
	for sprite in _sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	_actors.clear()
	_sprites.clear()


func _living_actor_count() -> int:
	var n := 0
	for actor in _actors:
		if actor.alive and actor.enemy.hp > 0.0:
			n += 1
	return n


func _process(delta: float) -> void:
	if size.x < 10.0:
		return

	if _wave_pause > 0.0:
		_wave_pause -= delta
		_scroll_x += delta * SCROLL_SPEED
		_sync_actor_positions()
		queue_redraw()
		return

	var scroll_rate := SCROLL_SPEED if not _in_melee else SCROLL_SPEED * 0.35
	_scroll_x += delta * scroll_rate

	if not _in_melee:
		var any_contact := false
		for i in _actors.size():
			var actor: CombatEnemyActorScript = _actors[i]
			if not actor.alive or actor.enemy.hp <= 0.0:
				continue
			var target_x := _contact_x_for_slot(_front_slot_for(actor))
			if actor.x < target_x:
				actor.x += delta * APPROACH_SPEED
			else:
				actor.x = target_x
				any_contact = true
		_ensure_walk()
		if any_contact and _living_actor_count() > 0:
			_start_melee()
	else:
		for actor in _actors:
			if actor.alive and actor.enemy.hp > 0.0:
				actor.x = _contact_x_for_slot(_front_slot_for(actor))

	if _flash > 0.0:
		_flash -= delta

	_sync_actor_positions()
	queue_redraw()


func _front_slot_for(actor) -> int:
	var slot := 0
	for a in _actors:
		if not a.alive or a.enemy.hp <= 0.0:
			continue
		if a == actor:
			return slot
		slot += 1
	return 0


func _sync_actor_positions() -> void:
	for i in _actors.size():
		if i >= _sprites.size():
			continue
		var actor: CombatEnemyActorScript = _actors[i]
		var sprite: AnimatedSprite2D = _sprites[i]
		if not is_instance_valid(sprite):
			continue
		var lane_y := _ground_y - SPRITE_W + float(i % 2) * 2.0
		sprite.position = Vector2(actor.x, lane_y)
		sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
		sprite.visible = actor.alive and actor.enemy.hp > 0.0


func _start_melee() -> void:
	if _in_melee:
		return
	_in_melee = true
	GameState.set_melee_engaged(true)
	GameState.combat_melee_exchange()


func _stop_melee() -> void:
	if not _in_melee:
		return
	_in_melee = false
	GameState.set_melee_engaged(false)


func _ensure_walk() -> void:
	if _hero_sprite.animation != "walk":
		var loop := _hero_sprite.sprite_frames.get_animation_loop(_hero_sprite.animation)
		if loop or _hero_sprite.animation == "idle":
			_hero_sprite.play("walk")
	for sprite in _sprites:
		if not is_instance_valid(sprite) or not sprite.visible:
			continue
		if sprite.animation != "walk":
			var loop2 := sprite.sprite_frames.get_animation_loop(sprite.animation)
			if loop2:
				sprite.play("walk")


func _on_spell_cast(info: Dictionary) -> void:
	if not _in_melee or info.get("combo", false):
		return
	_flash = 0.14
	var element: String = info.get("element", "physical")
	var anim := "attack_slash"
	match element:
		"fire":
			anim = "attack_down"
		"ice":
			anim = "attack_thrust"
	_hero_sprite.play_action(anim)
	_flash_front_enemy("hurt")


func _on_hero_damaged(_amount: float) -> void:
	if not _in_melee:
		return
	_flash = 0.2
	for sprite in _sprites:
		if is_instance_valid(sprite) and sprite.visible:
			sprite.play_action("attack")
	if GameState.hero.hp > 0.0:
		_hero_sprite.play_action("hurt")
	else:
		_hero_sprite.play_action("death")


func _flash_front_enemy(action: String) -> void:
	for i in _actors.size():
		var actor: CombatEnemyActorScript = _actors[i]
		if actor.alive and actor.enemy.hp > 0.0:
			if i < _sprites.size() and is_instance_valid(_sprites[i]):
				_sprites[i].play_action(action)
			return


func _on_enemy_slain(slot: int) -> void:
	if slot < 0 or slot >= _actors.size():
		return
	var actor = _actors[slot]
	actor.alive = false
	if slot < _sprites.size() and is_instance_valid(_sprites[slot]):
		_sprites[slot].play_action("death")


func _on_enemy_defeated(_rewards: Dictionary) -> void:
	if _actors.size() > 0:
		_actors.remove_at(0)
	var freed_sprite: AnimatedSprite2D = null
	if _sprites.size() > 0:
		freed_sprite = _sprites[0]
		_sprites.remove_at(0)
		if is_instance_valid(freed_sprite):
			get_tree().create_timer(0.45).timeout.connect(func() -> void:
				if is_instance_valid(freed_sprite):
					freed_sprite.queue_free()
			)

	if GameState.combat.living_count() > 0:
		return
	_stop_melee()
	_wave_pause = 0.55
	get_tree().create_timer(0.55).timeout.connect(func() -> void:
		if is_inside_tree():
			_spawn_next_wave()
			_hero_sprite.play_action("walk")
	)


func _on_state_changed() -> void:
	queue_redraw()


func _draw() -> void:
	if size.x < 10.0 or size.y < 10.0:
		return

	var horizon := size.y * 0.42
	draw_rect(Rect2(Vector2.ZERO, size), SKY, true)
	draw_rect(Rect2(0, horizon, size.x, size.y - horizon), SAND, true)

	_draw_scrolling_trees(horizon)
	_draw_scrolling_dunes(horizon)
	_draw_scrolling_palms(horizon)
	_draw_actor_hp_bars(horizon + 8.0)
	_draw_hero_hp(horizon + 8.0)

	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.95, 0.35, 0.3, _flash * 0.28), true)


func _draw_scrolling_trees(horizon: float) -> void:
	var spacing := size.x * 0.22
	var offset := fmod(_scroll_x * 0.55, spacing)
	var x: float = -spacing + offset
	while x < size.x + spacing:
		_draw_tree(x, horizon, 1.0)
		_draw_tree(x + spacing * 0.45, horizon - 6.0, 0.72)
		x += spacing


func _draw_tree(x: float, horizon: float, scale: float) -> void:
	var h := 28.0 * scale
	var w := 18.0 * scale
	var trunk_w := 5.0 * scale
	var base_y := horizon + 4.0
	draw_rect(Rect2(x + w * 0.5 - trunk_w * 0.5, base_y - h * 0.35, trunk_w, h * 0.38), TREE_TRUNK)
	draw_rect(Rect2(x, base_y - h, w, h * 0.55), TREE_LEAF)
	draw_rect(Rect2(x + w * 0.15, base_y - h * 0.82, w * 0.7, h * 0.28), TREE_LEAF_D)


func _draw_scrolling_dunes(horizon: float) -> void:
	var offset := fmod(_scroll_x * 0.35, size.x)
	for i in range(-1, 3):
		var base_x := (i * size.x * 0.55) - offset
		var pts := PackedVector2Array([
			Vector2(base_x, horizon + 6),
			Vector2(base_x + size.x * 0.22, horizon - 4),
			Vector2(base_x + size.x * 0.42, horizon + 8),
			Vector2(base_x + size.x * 0.58, horizon + 2),
			Vector2(base_x + size.x * 0.58, size.y),
			Vector2(base_x, size.y),
		])
		draw_colored_polygon(pts, SAND_DARK)


func _draw_scrolling_palms(horizon: float) -> void:
	var spacing := size.x * 0.32
	var offset := fmod(_scroll_x * 0.85, spacing)
	var start: float = -spacing + offset
	var x: float = start
	while x < size.x + spacing:
		_draw_palm(x, horizon)
		x += spacing


func _draw_palm(x: float, horizon: float) -> void:
	draw_rect(Rect2(x - 2, horizon - 18, 4, 18), Color(0.45, 0.3, 0.15))
	draw_rect(Rect2(x - 10, horizon - 20, 8, 4), Color(0.2, 0.55, 0.25))
	draw_rect(Rect2(x + 2, horizon - 18, 8, 4), Color(0.2, 0.55, 0.25))


func _draw_actor_hp_bars(ground_y: float) -> void:
	if not _in_melee:
		return
	for i in _actors.size():
		if i >= _sprites.size():
			continue
		var actor: CombatEnemyActorScript = _actors[i]
		if not actor.alive or actor.enemy.hp <= 0.0:
			continue
		var ratio := clampf(actor.enemy.hp / maxf(actor.enemy.max_hp, 1.0), 0.0, 1.0)
		var bar_w := SPRITE_W + 6.0
		var x := actor.x
		var y := ground_y - SPRITE_W - 10.0 + float(i % 2) * 2.0
		_draw_hp_bar(x, y, bar_w, ratio, HP_ENEMY)


func _draw_hero_hp(ground_y: float) -> void:
	var hero := GameState.hero
	var ratio := clampf(hero.hp / maxf(hero.max_hp, 1.0), 0.0, 1.0)
	var bar_w := SPRITE_W + 8.0
	var x := _hero_x
	var y := ground_y - SPRITE_W - 10.0
	_draw_hp_bar(x, y, bar_w, ratio, HP_ALLY)


func _draw_hp_bar(x: float, y: float, width: float, ratio: float, fill: Color) -> void:
	draw_rect(Rect2(x, y, width, 4), Color(0.12, 0.1, 0.1, 0.85))
	draw_rect(Rect2(x, y, width * ratio, 4), fill)
