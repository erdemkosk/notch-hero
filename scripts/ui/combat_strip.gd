extends Control

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const HeroSpriteScript = preload("res://scripts/ui/hero_sprite.gd")
const EnemySpriteScript = preload("res://scripts/ui/enemy_sprite.gd")
const CombatEnemyActorScript = preload("res://scripts/ui/combat_enemy_actor.gd")
const CombatBiomeScript = preload("res://scripts/ui/combat_biome.gd")
const PortalSpriteScript = preload("res://scripts/ui/portal_sprite.gd")
const StageDataScript = preload("res://scripts/game/stage_data.gd")
const ItemDataScript = preload("res://scripts/game/item_data.gd")
const UiFont = preload("res://scripts/ui/ui_font.gd")
const StageMapDrawScript = preload("res://scripts/ui/stage_map_draw.gd")
const CombatOverlayDrawScript = preload("res://scripts/ui/combat_overlay_draw.gd")
const CombatPotionBarScript = preload("res://scripts/ui/combat_potion_bar.gd")
const InventorySlotDrawScript = preload("res://scripts/ui/inventory_slot_draw.gd")

const HP_ENEMY := Color(0.92, 0.28, 0.28)
const HP_ALLY := Color(0.35, 0.88, 0.45)

const FRAME := 32.0
const SPRITE_SCALE := UIScaleScript.SPRITE_SCALE
const SPRITE_W := FRAME * SPRITE_SCALE
const HERO_ANCHOR_X := 0.68
const SCROLL_SPEED := 147.5 * UIScaleScript.FACTOR
const APPROACH_SPEED := 122.5 * UIScaleScript.FACTOR
const ENEMY_SPAWN_X := -72.0 * UIScaleScript.FACTOR
const SLOT_GAP := 54.0 * UIScaleScript.FACTOR
const QUEUE_BACKOFF := 78.0 * UIScaleScript.FACTOR

const INTRO_HOLD := 1.45
const INTRO_FADE := 0.65
const RETRY_HOLD := 1.05
const RETRY_FADE := 0.5
const WAVE_PAUSE := 0.45
const PORTAL_SCALE := UIScaleScript.PORTAL_SCALE
const PORTAL_BEHIND_X := 82.0 * UIScaleScript.FACTOR
const PORTAL_GROW_MIN := 0.16

const BOSS_INTRO_HOLD := 1.75
const BOSS_STING_SEC := 0.38

const HP_BOSS := Color(0.98, 0.72, 0.22)

const STAGE_HUD_HEIGHT := 38.0 * UIScaleScript.FACTOR
const COMBAT_BADGE_FONT := UIScaleScript.FONT_UI
const COMBAT_BADGE_HEIGHT := 17.0
const HERO_ATTACK_ANIMS := ["attack_slash", "attack_down", "attack_thrust"]

const EQUIP_RARITY_RANK := {
	"basic": 0,
	"common": 1,
	"trade": 1,
	"rare": 2,
	"epic": 3,
	"unique": 4,
}

# Kahraman sola kosuyor; zemin ve dekor saga aksin (kamera player'da sabit).
func _parallax_offset(speed_mul: float, period: float) -> float:
	return fmod(_scroll_x * speed_mul, period)


func _parallax_x(speed_mul: float, spacing: float) -> float:
	return -spacing + _parallax_offset(speed_mul, spacing)


func _parallax_band_x(index: int, speed_mul: float, period: float) -> float:
	return (float(index) * period) + _parallax_offset(speed_mul, period) - period


func _shake_offset() -> Vector2:
	if _screen_shake <= 0.001:
		return Vector2.ZERO
	var s := _screen_shake
	return Vector2(
		sin(_shake_phase * 53.0) * s * 5.5,
		cos(_shake_phase * 41.0 + 1.2) * s * 4.0
	)


func _trigger_screen_shake(intensity: float) -> void:
	_screen_shake = clampf(maxf(_screen_shake, intensity), 0.0, 0.48)
	if intensity > 0.05:
		_shake_phase += randf_range(0.4, 2.2)


func _tick_screen_shake(delta: float) -> void:
	if _screen_shake <= 0.0:
		return
	_screen_shake = maxf(0.0, _screen_shake - delta * 3.2)
	_shake_phase += delta * 55.0


func _apply_shake_visuals() -> void:
	var off := _shake_offset()
	if is_instance_valid(_bars_layer):
		_bars_layer.position = off
	if is_instance_valid(_overlay_layer):
		_overlay_layer.position = off
	if _intro_phase in ["portal_hold", "portal_burst"]:
		return
	if is_instance_valid(_hero_sprite) and _intro_phase == "":
		_hero_sprite.position = _hero_anchor_pos() + off
	if is_instance_valid(_portal_sprite):
		_portal_sprite.position = _portal_anchor() + off


var _scroll_x := 0.0
var _flash := 0.0
var _loot_flash := 0.0
var _loot_flash_color := Color(1.0, 0.85, 0.35)
var _screen_shake := 0.0
var _shake_phase := 0.0
var _ground_y := 0.0
var _hero_x := 0.0
var _in_melee := false
var _combat_locked := false
var _scroll_frozen := false
var _intro_phase := ""
var _intro_timer := 0.0
var _pending_enemies: Array = []
var _intro_spawn_enemies: Array = []
var _intro_generation := 0
var _intro_finish_generation := 0
var _wave_advance_token := 0
var _banner_alpha := 0.0
var _banner_enter := 0.0
var _banner_title := ""
var _banner_subtitle := ""
var _banner_biome := ""
var _hud_stage_label := ""
var _hud_stage_name := ""
var _hud_wave_text := ""
var _hud_world := 1
var _stage_hud_hovered := false
var _biome: Dictionary = CombatBiomeScript.resolve("desert")
var _biome_id := "desert"
var _biome_particles: Array[Dictionary] = []
var _actors: Array[CombatEnemyActorScript] = []
var _sprites: Array[AnimatedSprite2D] = []

var _hero_sprite: AnimatedSprite2D
var _portal_sprite: AnimatedSprite2D
var _bars_layer: Control
var _overlay_layer: Control
var _portal_grow := 0.0
var _portal_scale_mul := 1.0
var _intro_hold_duration := INTRO_HOLD
var _hero_emerge := 0.0
var _damage_numbers: Array[Dictionary] = []
var _boss_display_name := ""
var _boss_intro_alpha := 0.0
var _boss_enter := 0.0
var _boss_shake := 0.0

var _queue_breath_time := 0.0
var _awaiting_enemy_strike := false
var _awaiting_hero_strike := false
var _attacking_enemy_slot := -1
var _pending_round_start := false
var _last_equip_stats: Dictionary = {}
var _equip_stats_ready := false
var _potion_use_flash := {"health": 0.0, "mana": 0.0}
var _potion_gain_flash := {"health": 0.0, "mana": 0.0}
var _potion_pulse := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_hero_sprite = AnimatedSprite2D.new()
	_hero_sprite.set_script(HeroSpriteScript)
	_hero_sprite.z_index = 5
	_hero_sprite.action_finished.connect(_on_hero_action_finished)
	add_child(_hero_sprite)

	_portal_sprite = AnimatedSprite2D.new()
	_portal_sprite.set_script(PortalSpriteScript)
	_portal_sprite.z_index = 3
	_portal_sprite.scale = Vector2(PORTAL_SCALE, PORTAL_SCALE)
	add_child(_portal_sprite)

	_bars_layer = Control.new()
	_bars_layer.name = "CombatBars"
	_bars_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bars_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars_layer.z_index = 10
	add_child(_bars_layer)
	_bars_layer.draw.connect(_draw_combat_bars)

	_overlay_layer = Control.new()
	_overlay_layer.name = "CombatOverlay"
	_overlay_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.z_index = 100
	_overlay_layer.z_as_relative = false
	add_child(_overlay_layer)
	_overlay_layer.draw.connect(_draw_combat_overlay)


	resized.connect(_layout_hero)
	call_deferred("_connect_game_state")
	call_deferred("_layout_hero")


func _connect_game_state() -> void:
	if GameState == null or GameState.combat == null:
		return
	GameState.combat.spell_cast.connect(_on_spell_cast)
	GameState.combat.hero_damaged.connect(_on_hero_damaged)
	GameState.combat.enemy_slain.connect(_on_enemy_slain)
	GameState.combat.enemy_damaged.connect(_on_enemy_damaged)
	GameState.combat.enemy_defeated.connect(_on_enemy_defeated)
	GameState.combat.wave_spawned.connect(_on_wave_spawned)
	GameState.combat.hero_died.connect(_on_hero_died)
	GameState.stage_runner.stage_entered.connect(_on_stage_entered)
	GameState.stage_info_changed.connect(_refresh_hud_label)
	GameState.state_changed.connect(_on_state_changed)
	GameState.potion_bar_used.connect(_on_potion_bar_used)
	if GameState.has_hero():
		_last_equip_stats = GameState.hero.equipment_stats().duplicate()
		_equip_stats_ready = true
		_sync_hero_equip_visual()


func _layout_hero() -> void:
	if size.x < 10.0:
		return
	var horizon := size.y * 0.42
	_ground_y = horizon + 8.0
	_hero_x = size.x * HERO_ANCHOR_X - SPRITE_W * 0.5
	if _intro_phase in ["portal_hold", "portal_burst"]:
		_sync_portal_intro_layout()
		return
	_hero_sprite.position = _hero_anchor_pos()
	_hero_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_sync_actor_positions()


func _hero_anchor_pos() -> Vector2:
	return Vector2(_hero_x, _ground_y - SPRITE_W)


func _hero_combat_center_x() -> float:
	return _hero_x + SPRITE_W * 0.5


func _portal_width() -> float:
	return 64.0 * PORTAL_SCALE * _portal_scale_mul


func _portal_center_x() -> float:
	return _hero_combat_center_x() + PORTAL_BEHIND_X


func _portal_anchor() -> Vector2:
	var w := _portal_width()
	return Vector2(_portal_center_x() - w * 0.5, _ground_y - w)


func _hero_spawn_x() -> float:
	var mouth := _portal_center_x() - _portal_width() * 0.1
	return mouth - SPRITE_W * 0.36


func _apply_portal_visual() -> void:
	if not is_instance_valid(_portal_sprite):
		return
	_portal_sprite.scale = Vector2(PORTAL_SCALE * _portal_scale_mul, PORTAL_SCALE * _portal_scale_mul)
	_portal_sprite.position = _portal_anchor()


func _sync_portal_intro_layout(hero_x: float = -1.0, hero_scale: float = -1.0) -> void:
	_apply_portal_visual()
	if not is_instance_valid(_hero_sprite):
		return
	var sc := hero_scale if hero_scale > 0.0 else SPRITE_SCALE
	var x := hero_x if hero_x >= 0.0 else _hero_spawn_x()
	_hero_sprite.position = Vector2(x, _ground_y - FRAME * sc)
	_hero_sprite.scale = Vector2(sc, sc)


func _contact_x_for_slot(slot: int, _enemy_type: String = "") -> float:
	return _contact_x() - float(slot) * SLOT_GAP


func _contact_x() -> float:
	# Kahramana bakan kenar (leading edge) temas cizgisi.
	return _hero_x - 14.0


func _target_x_for_slot(slot: int, enemy_type: String) -> float:
	var hero_line := _contact_x_for_slot(slot)
	if EnemySpriteScript.is_ranged(enemy_type):
		return hero_line - EnemySpriteScript.ranged_standoff_for(enemy_type)
	return hero_line


func _on_stage_entered(info: Dictionary) -> void:
	_cancel_pending_wave_advance()
	_stop_melee()
	_clear_visual_enemies()
	_damage_numbers.clear()
	_combat_locked = true
	_scroll_frozen = true
	_intro_phase = ""
	_intro_timer = 0.0
	_banner_alpha = 0.0
	_intro_generation += 1
	_intro_spawn_enemies = _resolve_wave_enemies(info)
	_pending_enemies = _intro_spawn_enemies.duplicate()
	_set_hero_intro_pose(true)

	var transition: String = str(info.get("transition", "wave"))
	var label: String = str(info.get("label", "?-?"))
	var stage_name: String = str(info.get("name", ""))
	var wave_index: int = int(info.get("wave_index", 0)) + 1
	var wave_count: int = int(info.get("wave_count", 1))
	var biome_id: String = str(info.get("biome", "desert"))

	if transition == "stage" or transition == "retry" or _biome_id != biome_id:
		GameState.combat.clear_wave()
		_biome_id = biome_id
		_biome = CombatBiomeScript.resolve(biome_id)
		_init_biome_particles()

	_banner_title = label
	_banner_biome = CombatBiomeScript.label_for(biome_id)
	match transition:
		"stage":
			_banner_subtitle = stage_name
		"retry":
			_banner_subtitle = "Try again"
		_:
			_banner_subtitle = "Wave %d/%d" % [wave_index, wave_count]

	_hud_world = int(info.get("world", _hud_world))
	_refresh_hud_label(label, wave_index, wave_count, stage_name)

	if transition == "stage":
		_start_portal_intro(INTRO_HOLD, INTRO_FADE)
	elif transition == "retry":
		_start_portal_intro(RETRY_HOLD, RETRY_FADE)
	else:
		if wave_index >= wave_count and _wave_has_boss(_pending_enemies):
			_start_boss_intro(_boss_name_from_enemies(_pending_enemies))
		else:
			_banner_alpha = 0.0
			_intro_phase = "wave_pause"
			_intro_timer = WAVE_PAUSE
			_mark_intro_finish_generation()


func _cancel_pending_wave_advance() -> void:
	_wave_advance_token += 1


func _resolve_wave_enemies(info: Dictionary) -> Array:
	var enemies: Array = []
	for enemy_type in info.get("enemies", []):
		if typeof(enemy_type) == TYPE_STRING:
			enemies.append(enemy_type)
	if enemies.is_empty() and GameState.stage_runner != null:
		for enemy_type in GameState.stage_runner.current_wave_enemies():
			if typeof(enemy_type) == TYPE_STRING:
				enemies.append(enemy_type)
	return enemies


func _mark_intro_finish_generation() -> void:
	_intro_finish_generation = _intro_generation


func _wave_has_boss(enemies: Array) -> bool:
	for enemy_type in enemies:
		if StageDataScript.is_boss_type(str(enemy_type)):
			return true
	return false


func _boss_name_from_enemies(enemies: Array) -> String:
	for enemy_type in enemies:
		var id := str(enemy_type)
		if StageDataScript.is_boss_type(id):
			return StageDataScript.enemy_name(id)
	return "BOSS"


func _start_boss_intro(boss_name: String) -> void:
	_boss_display_name = boss_name
	_boss_intro_alpha = 0.0
	_boss_enter = 0.0
	_boss_shake = 0.42
	_banner_alpha = 0.0
	_intro_phase = "boss_intro"
	_intro_timer = BOSS_INTRO_HOLD
	_combat_locked = true
	_scroll_frozen = true
	_mark_intro_finish_generation()
	_queue_overlay_redraw()




func _start_portal_intro(hold_sec: float, fade_sec: float) -> void:
	if size.x >= 10.0:
		var horizon := size.y * 0.42
		_ground_y = horizon + 8.0
		_hero_x = size.x * HERO_ANCHOR_X - SPRITE_W * 0.5
	_banner_alpha = 1.0
	_banner_enter = 0.0
	_intro_phase = "portal_hold"
	_intro_timer = hold_sec
	_intro_hold_duration = hold_sec
	_intro_fade_duration = fade_sec
	_mark_intro_finish_generation()
	_portal_grow = 0.0
	_portal_scale_mul = PORTAL_GROW_MIN
	_hero_emerge = 0.0
	_hero_sprite.visible = false
	_hero_sprite.modulate = Color(1, 1, 1, 1)
	_hero_sprite.z_index = 2
	_apply_portal_visual()
	_portal_sprite.play_open()
	_set_hero_intro_pose(true)
	_queue_overlay_redraw()
	queue_redraw()


var _intro_fade_duration := INTRO_FADE


func _begin_portal_burst() -> void:
	_intro_phase = "portal_burst"
	_hero_emerge = 0.0
	_hero_sprite.visible = true
	_hero_sprite.z_index = 5
	_hero_sprite.modulate = Color(1, 1, 1, 0)
	_sync_portal_intro_layout(_hero_spawn_x(), SPRITE_SCALE * 0.72)
	_hero_sprite.play("walk")
	_portal_sprite.play_close()


func _finish_intro() -> void:
	if _intro_finish_generation != _intro_generation:
		return

	_intro_phase = ""
	_banner_alpha = 0.0
	_scroll_frozen = false
	_combat_locked = false
	if is_instance_valid(_portal_sprite):
		_portal_sprite.hide_portal()
	if is_instance_valid(_hero_sprite):
		_hero_sprite.visible = true
		_hero_sprite.modulate = Color(1, 1, 1, 1)
	_layout_hero()
	_set_hero_intro_pose(false)

	var wave_enemies: Array = _intro_spawn_enemies.duplicate()
	if wave_enemies.is_empty() and not _pending_enemies.is_empty():
		wave_enemies = _pending_enemies.duplicate()
	if wave_enemies.is_empty() and GameState.stage_runner != null:
		wave_enemies = GameState.stage_runner.current_wave_enemies()
	if wave_enemies.is_empty():
		push_warning("CombatStrip: no enemies to spawn after intro")
		_pending_enemies.clear()
		_intro_spawn_enemies.clear()
		return

	_spawn_wave_types(wave_enemies)
	_pending_enemies.clear()
	_intro_spawn_enemies.clear()


func _set_hero_intro_pose(intro: bool) -> void:
	if not is_instance_valid(_hero_sprite) or _hero_sprite.sprite_frames == null:
		return
	if intro:
		if _hero_sprite.sprite_frames.has_animation("idle"):
			_hero_sprite.play("idle")
		else:
			_hero_sprite.play("walk")
			_hero_sprite.pause()
	else:
		_hero_sprite.play("walk")


func _spawn_wave_types(enemies: Array) -> void:
	if enemies.is_empty():
		return
	_clear_visual_enemies()
	var types := PackedStringArray()
	for enemy_type in enemies:
		if typeof(enemy_type) == TYPE_STRING:
			types.append(enemy_type)
	if types.is_empty():
		return
	GameState.combat.spawn_wave_with_types(types)


func _refresh_hud_label(
	label: String = "",
	wave_index: int = -1,
	wave_count: int = -1,
	stage_name: String = ""
) -> void:
	if label.is_empty() and GameState.stage_runner != null:
		var stage := GameState.stage_runner.current_stage()
		if stage.is_empty():
			_hud_stage_label = ""
			_hud_stage_name = ""
			_hud_wave_text = ""
			_hud_world = 1
			return
		label = GameState.stage_runner.current_label()
		wave_index = GameState.stage_runner.wave_index + 1
		wave_count = GameState.stage_runner.wave_count()
		stage_name = str(stage.get("name", ""))
		_hud_world = int(stage.get("world", 1))

	if label.is_empty():
		_hud_stage_label = ""
		_hud_stage_name = ""
		_hud_wave_text = ""
		_hud_world = 1
		return

	_hud_stage_label = label
	_hud_stage_name = stage_name
	_hud_wave_text = "Wave %d/%d" % [wave_index, wave_count]
	queue_redraw()


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
		sprite.action_finished.connect(_on_enemy_action_finished.bind(sprite))
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
	_damage_numbers.clear()


func _living_actor_count() -> int:
	var n := 0
	for actor in _actors:
		if actor.alive and actor.enemy.hp > 0.0:
			n += 1
	return n


func _process(delta: float) -> void:
	if GameState == null or not GameState.has_hero() or GameState.session_paused:
		return

	_update_damage_numbers(delta)
	_update_potion_flash(delta)
	_update_overlay_anim(delta)
	_update_biome_particles(delta)
	_queue_breath_time += delta

	if _intro_phase != "":
		_process_intro(delta)
	elif size.x >= 10.0:
		if _flash > 0.0:
			_flash -= delta
		if _loot_flash > 0.0:
			_loot_flash = maxf(0.0, _loot_flash - delta * (1.8 + _loot_flash * 0.6))
			_queue_bars_redraw()
			queue_redraw()

		if _combat_locked:
			if not _scroll_frozen:
				_scroll_x += delta * SCROLL_SPEED * _move_speed_mul()
		else:
			var approach := APPROACH_SPEED * _move_speed_mul()
			if not _scroll_frozen:
				var scroll_rate: float = SCROLL_SPEED if not _in_melee else SCROLL_SPEED * 0.35
				_scroll_x += delta * scroll_rate * _move_speed_mul()

			if not _in_melee:
				var front_actor := _front_living_actor()
				var front_ready := false
				for i in _actors.size():
					var actor: CombatEnemyActorScript = _actors[i]
					if not actor.alive or actor.enemy.hp <= 0.0:
						continue
					var target_x := _queue_target_x(actor)
					if actor.x < target_x:
						actor.x += delta * approach
					else:
						actor.x = target_x
					if actor == front_actor and actor.x >= target_x - 0.5:
						front_ready = true
				_ensure_walk()
				if front_ready and _living_actor_count() > 0:
					_start_melee()
			else:
				for actor in _actors:
					if not actor.alive or actor.enemy.hp <= 0.0:
						continue
					var target_x := _queue_target_x(actor)
					if actor.x < target_x:
						actor.x = minf(actor.x + delta * approach * 1.35, target_x)
					else:
						actor.x = target_x

		_tick_screen_shake(delta)
		_sync_actor_positions()
		_apply_shake_visuals()

	# stage hud hover check
	var hud_rect := Rect2(0.0, size.y - STAGE_HUD_HEIGHT, size.x, STAGE_HUD_HEIGHT)
	var local_mouse := get_local_mouse_position()
	var is_hovered := Rect2(Vector2.ZERO, size).has_point(local_mouse) and hud_rect.has_point(local_mouse)
	if is_instance_valid(_stage_popup) and _stage_popup.visible:
		is_hovered = false
	if is_hovered != _stage_hud_hovered:
		_stage_hud_hovered = is_hovered
		if _stage_hud_hovered:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			mouse_default_cursor_shape = Control.CURSOR_ARROW
		queue_redraw()

	queue_redraw()
	_queue_bars_redraw()


func _process_intro(delta: float) -> void:
	if _intro_phase == "boss_intro":
		_intro_timer -= delta
		var elapsed := BOSS_INTRO_HOLD - _intro_timer
		if elapsed < 0.28:
			_boss_intro_alpha = elapsed / 0.28
		elif _intro_timer < 0.5:
			_boss_intro_alpha = clampf(_intro_timer / 0.5, 0.0, 1.0)
		else:
			_boss_intro_alpha = 1.0
		_boss_shake = maxf(0.0, _boss_shake - delta * 1.35)
		if _intro_timer <= 0.0:
			_boss_intro_alpha = 0.0
			_finish_intro()
		_queue_overlay_redraw()
		queue_redraw()
		return

	if _intro_phase == "portal_hold":
		_intro_timer -= delta
		if _intro_hold_duration > 0.0:
			_portal_grow = 1.0 - clampf(_intro_timer / _intro_hold_duration, 0.0, 1.0)
		_portal_scale_mul = lerpf(PORTAL_GROW_MIN, 1.0, _portal_grow)
		_apply_portal_visual()
		if is_instance_valid(_hero_sprite):
			_hero_sprite.visible = false
		if _intro_timer <= 0.0:
			_begin_portal_burst()
		_queue_overlay_redraw()
		queue_redraw()
		return

	if _intro_phase == "portal_burst":
		if _intro_fade_duration > 0.0:
			_banner_alpha = maxf(0.0, _banner_alpha - delta / _intro_fade_duration)
		_apply_portal_visual()
		_hero_emerge = minf(1.0, _hero_emerge + delta / maxf(_intro_fade_duration, 0.01))
		var t := _hero_emerge
		var hero_x := lerpf(_hero_spawn_x(), _hero_x, t)
		var hero_sc := SPRITE_SCALE * lerpf(0.72, 1.0, t)
		if is_instance_valid(_hero_sprite):
			_hero_sprite.modulate.a = clampf(t * 1.35, 0.0, 1.0)
		_sync_portal_intro_layout(hero_x, hero_sc)
		if t >= 0.98 and _banner_alpha <= 0.02:
			_finish_intro()
		_queue_overlay_redraw()
		queue_redraw()
		return

	if _intro_phase == "hold":
		_intro_timer -= delta
		if _intro_timer <= 0.0:
			_intro_phase = "fade"
			_intro_timer = _intro_fade_duration
		_queue_overlay_redraw()
		queue_redraw()
		return

	if _intro_phase == "fade":
		_intro_timer -= delta
		_banner_alpha = clampf(_intro_timer / _intro_fade_duration, 0.0, 1.0)
		if _intro_timer <= 0.0:
			_finish_intro()
		_queue_overlay_redraw()
		queue_redraw()
		return

	if _intro_phase == "wave_pause":
		_intro_timer -= delta
		if _intro_timer <= 0.0:
			_finish_intro()
		_queue_overlay_redraw()
		queue_redraw()
		return


func _front_living_actor() -> CombatEnemyActorScript:
	for actor in _actors:
		if actor.alive and actor.enemy.hp > 0.0:
			return actor
	return null


func _front_slot_for(actor) -> int:
	var slot := 0
	for a in _actors:
		if not a.alive or a.enemy.hp <= 0.0:
			continue
		if a == actor:
			return slot
		slot += 1
	return 0


func _queue_target_x(actor: CombatEnemyActorScript) -> float:
	var qslot := _front_slot_for(actor)
	var front_line := _target_x_for_slot(0, actor.enemy_type)
	if qslot <= 0:
		return front_line
	return front_line - float(qslot) * QUEUE_BACKOFF


func _is_actor_queue_waiting(actor: CombatEnemyActorScript) -> bool:
	if not actor.alive or actor.enemy.hp <= 0.0:
		return false
	if _front_slot_for(actor) <= 0:
		return false
	return actor.x >= _queue_target_x(actor) - 1.5


func _sync_actor_positions() -> void:
	var shake_off := _shake_offset()
	var front_actor := _front_living_actor()
	for i in _actors.size():
		if i >= _sprites.size():
			continue
		var actor: CombatEnemyActorScript = _actors[i]
		var sprite: AnimatedSprite2D = _sprites[i]
		if not is_instance_valid(sprite):
			continue
		var waiting := _is_actor_queue_waiting(actor)
		if sprite.has_method("set_queue_waiting"):
			sprite.set_queue_waiting(waiting)
		var lane_y := float(i % 2) * 2.0
		if waiting:
			lane_y += sin(_queue_breath_time * 2.6 + float(i) * 0.9) * 1.8
		var pos := EnemySpriteScript.sprite_position_for(
			actor.enemy_type,
			actor.x,
			_ground_y,
			SPRITE_SCALE,
			lane_y
		)
		sprite.position = pos + shake_off
		sprite.scale = EnemySpriteScript.display_scale_for(actor.enemy_type, SPRITE_SCALE)
		sprite.visible = actor.alive and actor.enemy.hp > 0.0
		if waiting:
			var pulse := 0.035 * sin(_queue_breath_time * 3.2 + float(i) * 0.7)
			sprite.modulate = Color(0.86 + pulse, 0.86 + pulse, 0.92 + pulse, 0.9)
		elif actor == front_actor:
			sprite.modulate = Color(1, 1, 1, 1)
		else:
			sprite.modulate = Color(0.92, 0.92, 0.96, 0.96)


func _start_melee() -> void:
	if _in_melee:
		return
	_in_melee = true
	GameState.set_melee_engaged(true)
	_begin_combat_round()


func _stop_melee() -> void:
	if not _in_melee:
		return
	_in_melee = false
	_awaiting_enemy_strike = false
	_awaiting_hero_strike = false
	_attacking_enemy_slot = -1
	_pending_round_start = false
	GameState.combat.cancel_exchange()
	GameState.set_melee_engaged(false)


func _ensure_walk() -> void:
	if _scroll_frozen or _combat_locked:
		return
	if _hero_sprite.animation != "walk":
		var loop := _hero_sprite.sprite_frames.get_animation_loop(_hero_sprite.animation)
		if loop or _hero_sprite.animation == "idle":
			_hero_sprite.play("walk")
	for i in _sprites.size():
		if i >= _actors.size():
			continue
		if _is_actor_queue_waiting(_actors[i]):
			continue
		var sprite: AnimatedSprite2D = _sprites[i]
		if not is_instance_valid(sprite) or not sprite.visible:
			continue
		if sprite.animation != "walk":
			var loop2 := sprite.sprite_frames.get_animation_loop(sprite.animation)
			if loop2:
				sprite.play("walk")


func _on_spell_cast(_info: Dictionary) -> void:
	if not _in_melee:
		return
	_flash = 0.14
	_awaiting_hero_strike = true
	_hero_sprite.play_action("attack_slash")


func _on_hero_action_finished(anim_name: String) -> void:
	if not _in_melee or not _awaiting_hero_strike:
		return
	if HERO_ATTACK_ANIMS.has(anim_name):
		_resolve_hero_attack_hit()


func _resolve_hero_attack_hit() -> void:
	if not _in_melee or not _awaiting_hero_strike:
		return
	if not GameState.combat.is_hero_swing_pending():
		_awaiting_hero_strike = false
		return
	_awaiting_hero_strike = false
	var next_phase: String = GameState.combat.commit_hero_strike()
	GameState.state_changed.emit()
	_advance_melee_turn(next_phase)


func _play_front_enemy_attack() -> void:
	var slot := _combat_front_slot()
	if slot < 0 or slot >= _sprites.size():
		_finish_enemy_turn()
		return
	var sprite: AnimatedSprite2D = _sprites[slot]
	if not is_instance_valid(sprite) or not sprite.visible:
		_finish_enemy_turn()
		return

	_attacking_enemy_slot = slot
	_awaiting_enemy_strike = true

	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation("attack"):
		_finish_enemy_turn()
		return

	sprite.play_action("attack")


func _on_enemy_action_finished(anim_name: String, sprite: AnimatedSprite2D) -> void:
	if not _awaiting_enemy_strike or anim_name != "attack":
		return
	if _attacking_enemy_slot < 0 or _attacking_enemy_slot >= _sprites.size():
		return
	if _sprites[_attacking_enemy_slot] != sprite:
		return
	_awaiting_enemy_strike = false
	_attacking_enemy_slot = -1
	_finish_enemy_turn()


func _on_hero_damaged(amount: float) -> void:
	if not _in_melee:
		return
	_flash = 0.2
	_trigger_screen_shake(clampf(amount * 0.022 + 0.14, 0.14, 0.42))
	_spawn_damage_number(_popup_pos_for_hero(), amount, "hurt", true)
	if GameState.hero.hp > 0.0:
		_hero_sprite.play_action("hurt")
	else:
		_hero_sprite.play_action("death")


func _on_hero_died() -> void:
	_cancel_pending_wave_advance()
	_stop_melee()
	_combat_locked = true
	_scroll_frozen = true
	_flash = 0.35
	_trigger_screen_shake(0.48)
	if GameState.combat != null:
		GameState.combat.clear_wave()
	if is_instance_valid(_hero_sprite) and _hero_sprite.sprite_frames != null:
		if _hero_sprite.sprite_frames.has_animation("death"):
			_hero_sprite.play("death")


func _finish_enemy_turn() -> void:
	if not GameState.combat.is_enemy_swing_pending():
		return
	if not GameState.combat.commit_enemy_strike():
		return
	_awaiting_enemy_strike = false
	_attacking_enemy_slot = -1
	GameState.state_changed.emit()
	_schedule_next_combat_round()


func _schedule_next_combat_round() -> void:
	if _pending_round_start:
		return
	_pending_round_start = true
	call_deferred("_run_scheduled_combat_round")


func _run_scheduled_combat_round() -> void:
	_pending_round_start = false
	_begin_combat_round()


func _begin_combat_round() -> void:
	if not _in_melee or GameState.hero.hp <= 0.0:
		return
	if GameState.combat == null or GameState.combat.living_count() <= 0:
		return
	if not GameState.combat.is_melee_idle():
		return
	var next_phase: String = GameState.combat_begin_round()
	_advance_melee_turn(next_phase)


func _advance_melee_turn(phase: String) -> void:
	if not _in_melee or GameState.hero.hp <= 0.0:
		return
	match phase:
		"hero_swing":
			pass
		"enemy_turn":
			_play_front_enemy_attack()
		"idle", "none":
			pass


func _on_enemy_damaged(slot: int, amount: float, source: String) -> void:
	if not _in_melee or amount <= 0.0:
		return
	if slot != _combat_front_slot():
		return
	var kind := "deal"
	if slot < _sprites.size() and is_instance_valid(_sprites[slot]):
		var sprite: AnimatedSprite2D = _sprites[slot]
		if sprite.animation != "attack" and not _awaiting_enemy_strike:
			sprite.play_action("hurt")
	_spawn_damage_number(_popup_pos_for_enemy_slot(slot), amount, kind)


func _combat_front_slot() -> int:
	if GameState.combat == null:
		return 0
	return GameState.combat.front_slot()


func _spawn_damage_number(at: Vector2, amount: float, kind: String, prefix_minus: bool = false) -> void:
	if amount <= 0.0:
		return
	var text := str(int(round(amount)))
	if prefix_minus:
		text = "-" + text
	_spawn_floating_text(at + Vector2(randf_range(-6.0, 6.0), 0.0), text, kind, 0.85)


func _spawn_floating_text(at: Vector2, text: String, kind: String, life: float = 1.05) -> void:
	if text.is_empty():
		return
	var vx := randf_range(-38.0, 38.0)
	var vy := randf_range(-105.0, -135.0)
	_damage_numbers.append({
		"text": text,
		"x": at.x,
		"y": at.y,
		"vx": vx,
		"vy": vy,
		"life": life,
		"max_life": life,
		"kind": kind,
	})


func _update_damage_numbers(delta: float) -> void:
	if _damage_numbers.is_empty():
		return
	var i := 0
	while i < _damage_numbers.size():
		var pop: Dictionary = _damage_numbers[i]
		pop["life"] = float(pop["life"]) - delta
		
		var gravity := 320.0
		pop["vy"] = float(pop["vy"]) + gravity * delta
		pop["x"] = float(pop["x"]) + float(pop["vx"]) * delta
		pop["y"] = float(pop["y"]) + float(pop["vy"]) * delta
		
		if float(pop["life"]) <= 0.0:
			_damage_numbers.remove_at(i)
		else:
			i += 1
	_queue_bars_redraw()


func _popup_pos_for_hero() -> Vector2:
	return Vector2(_hero_x + SPRITE_W * 0.5, _ground_y - SPRITE_W - 12.0)


func _popup_pos_for_enemy_slot(slot: int) -> Vector2:
	if slot < 0 or slot >= _actors.size():
		return Vector2.ZERO
	var actor: CombatEnemyActorScript = _actors[slot]
	var disp := EnemySpriteScript.display_size_for(actor.enemy_type, SPRITE_SCALE)
	var pos := EnemySpriteScript.sprite_position_for(
		actor.enemy_type,
		actor.x,
		_ground_y,
		SPRITE_SCALE,
		float(slot % 2) * 2.0
	)
	return Vector2(pos.x + disp.x * 0.5, pos.y - 6.0)


func _damage_color(kind: String, alpha: float) -> Color:
	match kind:
		"hurt":
			return Color(1.0, 0.38, 0.32, alpha)
		"dot":
			return Color(1.0, 0.62, 0.22, alpha)
		"buff_atk":
			return Color(1.0, 0.82, 0.42, alpha)
		"buff_armor":
			return Color(0.55, 0.88, 1.0, alpha)
		"potion_heal":
			return Color(0.42, 0.98, 0.52, alpha)
		"potion_mana":
			return Color(0.45, 0.78, 1.0, alpha)
		"potion_gain":
			return Color(0.98, 0.86, 0.42, alpha)
		"loot_basic":
			return Color(0.72, 0.74, 0.7, alpha)
		"loot_common":
			return Color(0.78, 0.92, 0.62, alpha)
		"loot_rare":
			return Color(0.45, 0.82, 1.0, alpha)
		"loot_unique":
			return Color(1.0, 0.82, 0.28, alpha)
		_:
			return Color(1.0, 0.92, 0.45, alpha)


func _draw_damage_numbers(canvas: CanvasItem) -> void:
	if _damage_numbers.is_empty():
		return
	var font: Font = UiFont.get_font()
	for pop in _damage_numbers:
		var life := float(pop["life"])
		var max_life := float(pop["max_life"])
		var alpha := clampf(life / max_life, 0.0, 1.0)
		var kind: String = str(pop["kind"])
		
		# Dynamic scale multiplier based on progress (pop-up scale animation)
		var progress := 1.0 - (life / max_life)
		var scale_f := 1.0
		if progress < 0.22:
			scale_f = lerpf(1.38, 1.0, progress / 0.22)
		else:
			scale_f = lerpf(1.0, 0.8, (progress - 0.22) / 0.78)
		
		var base_sz := 15
		if kind == "dot":
			base_sz = 11
		elif kind.begins_with("loot_unique"):
			base_sz = 13
		elif kind.begins_with("loot_rare"):
			base_sz = 12
		elif kind.begins_with("loot_"):
			base_sz = 10
		elif kind.begins_with("buff"):
			base_sz = 9
			
		var font_size := int(round(UIScaleScript.font(base_sz) * scale_f))
		var text: String = str(pop["text"])
		var x := float(pop["x"])
		var y := float(pop["y"])
		var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		var col := _damage_color(kind, alpha)
		canvas.draw_string(font, Vector2(x - tw * 0.5 + 1.0, y + 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, alpha * 0.55))
		canvas.draw_string(font, Vector2(x - tw * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


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


func _on_enemy_defeated(rewards: Dictionary) -> void:
	var has_loot := bool(rewards.get("item_rolled", false)) or bool(rewards.get("potion_rolled", false))
	var freed_sprite: AnimatedSprite2D = null
	if _sprites.size() > 0:
		freed_sprite = _sprites[0]
		_sprites.remove_at(0)

	if has_loot:
		_schedule_loot_after_death(freed_sprite, rewards)
		return

	if is_instance_valid(freed_sprite):
		get_tree().create_timer(0.45).timeout.connect(func() -> void:
			if is_instance_valid(freed_sprite):
				freed_sprite.queue_free()
		)

	if _actors.size() > 0:
		_actors.remove_at(0)

	if GameState.combat.living_count() > 0:
		return
	_advance_wave_after_pause()


func _advance_wave_after_pause() -> void:
	_stop_melee()
	_combat_locked = true
	_scroll_frozen = false
	var token := _wave_advance_token
	get_tree().create_timer(WAVE_PAUSE).timeout.connect(func() -> void:
		if token != _wave_advance_token:
			return
		if is_inside_tree():
			GameState.on_wave_cleared()
	)


func _celebrate_loot_drop(item: Dictionary) -> void:
	if item.is_empty():
		return

	var rarity := ItemDataScript.item_rarity(item)
	var rank := ItemDataScript.rarity_rank(rarity)
	var name := ItemDataScript.display_name(item)
	var label := ItemDataScript.rarity_name(rarity)
	var col: Color = ItemDataScript.RARITY_COLORS.get(rarity, ItemDataScript.RARITY_COLORS["common"])
	var kind := "loot_%s" % rarity
	var pos := _popup_pos_for_hero() + Vector2(0.0, -UIScaleScript.px(22.0))
	var life := 0.95 + float(rank) * 0.35

	_loot_flash_color = col
	_loot_flash = 0.12 + float(rank) * 0.14
	_trigger_screen_shake(0.06 + float(rank) * 0.11)

	match rank:
		0:
			_spawn_floating_text(pos, name, kind, 0.85)
		1:
			_spawn_floating_text(pos, name, kind, life)
		2:
			_spawn_floating_text(pos, "%s!" % label, kind, life)
			_spawn_floating_text(
				pos + Vector2(0.0, -UIScaleScript.px(16.0)),
				name,
				kind,
				life * 1.08
			)
		_:
			_spawn_floating_text(pos, "%s DROP!" % label.to_upper(), kind, life * 1.15)
			_spawn_floating_text(
				pos + Vector2(0.0, -UIScaleScript.px(18.0)),
				name,
				kind,
				life * 1.2
			)
			_loot_flash = maxf(_loot_flash, 0.38)
			_trigger_screen_shake(0.42)

	_queue_bars_redraw()
	queue_redraw()


func _schedule_loot_after_death(sprite: AnimatedSprite2D, rewards: Dictionary) -> void:
	var pending := (rewards as Dictionary).duplicate(true)
	var flow_token := _wave_advance_token

	var grant := func() -> void:
		if not is_inside_tree():
			return
		if flow_token != _wave_advance_token:
			if is_instance_valid(sprite):
				sprite.queue_free()
			return
		var granted := GameState.grant_kill_loot(pending)
		if granted.get("item_dropped", false):
			var dropped: Dictionary = pending.get("item", {}) as Dictionary
			_celebrate_loot_drop(dropped)
		if granted.get("potion_dropped", false):
			_spawn_floating_text(
				_popup_pos_for_hero() + Vector2(0.0, -UIScaleScript.px(10.0)),
				"Potion!",
				"potion_gain",
				0.95
			)
			_queue_bars_redraw()
		if _actors.size() > 0:
			_actors.remove_at(0)
		if is_instance_valid(sprite):
			sprite.queue_free()
		if GameState.combat.living_count() > 0:
			return
		_advance_wave_after_pause()

	if is_instance_valid(sprite) and sprite.sprite_frames != null and sprite.sprite_frames.has_animation("death"):
		sprite.action_finished.connect(func(anim_name: String) -> void:
			if anim_name != "death":
				return
			grant.call()
		, CONNECT_ONE_SHOT)
	else:
		get_tree().create_timer(0.55).timeout.connect(grant)


func _on_state_changed() -> void:
	_track_equip_changes()
	_sync_hero_equip_visual()
	queue_redraw()
	_queue_bars_redraw()


func _on_potion_bar_used(kind: String, applied: Dictionary) -> void:
	if not ItemDataScript.POTION_KINDS.has(kind):
		return
	_potion_use_flash[kind] = 1.0
	var layout := CombatPotionBarScript.combat_layout(_bars_layer.size, STAGE_HUD_HEIGHT)
	var slot_rect := CombatPotionBarScript.slot_rect(layout, kind)
	var center := slot_rect.get_center()
	var heal := float(applied.get("heal_hp", 0.0))
	var mana := float(applied.get("restore_mana", 0.0))
	if heal > 0.0:
		_spawn_floating_text(center + Vector2(0.0, -UIScaleScript.px(8.0)), "+%d HP" % int(round(heal)), "potion_heal", 0.95)
	elif mana > 0.0:
		_spawn_floating_text(center + Vector2(0.0, -UIScaleScript.px(8.0)), "+%d MP" % int(round(mana)), "potion_mana", 0.95)
	_queue_bars_redraw()


func _update_potion_flash(delta: float) -> void:
	var needs_redraw := false
	_potion_pulse += delta
	for kind in ItemDataScript.POTION_KINDS:
		var use_v: float = float(_potion_use_flash.get(kind, 0.0))
		if use_v > 0.0:
			_potion_use_flash[kind] = maxf(0.0, use_v - delta / 0.55)
			needs_redraw = true
		var gain_v: float = float(_potion_gain_flash.get(kind, 0.0))
		if gain_v > 0.0:
			_potion_gain_flash[kind] = maxf(0.0, gain_v - delta / 0.45)
			needs_redraw = true
	if needs_redraw:
		_queue_bars_redraw()


func _move_speed_mul() -> float:
	if GameState == null or GameState.hero == null:
		return 1.0
	return GameState.hero.move_speed_multiplier()


func _track_equip_changes() -> void:
	if GameState == null or not GameState.has_hero():
		return
	var stats := GameState.hero.equipment_stats()
	if not _equip_stats_ready:
		_last_equip_stats = stats.duplicate()
		_equip_stats_ready = true
		return

	var atk_old := float(_last_equip_stats.get("attack", 0.0))
	var atk_new := float(stats.get("attack", 0.0))
	var armor_old := float(_last_equip_stats.get("armor", 0.0))
	var armor_new := float(stats.get("armor", 0.0))
	var as_old := float(_last_equip_stats.get("attack_speed_pct", 0.0))
	var as_new := float(stats.get("attack_speed_pct", 0.0))
	var ms_old := float(_last_equip_stats.get("move_speed_pct", 0.0))
	var ms_new := float(stats.get("move_speed_pct", 0.0))
	var pos := _popup_pos_for_hero()
	if atk_new > atk_old:
		_spawn_floating_text(pos, "+%d ATK" % int(round(atk_new - atk_old)), "buff_atk")
	if armor_new > armor_old:
		_spawn_floating_text(pos + Vector2(0.0, -UIScaleScript.px(8.0)), "+%d ARM" % int(round(armor_new - armor_old)), "buff_armor")
	if as_new > as_old:
		_spawn_floating_text(pos + Vector2(0.0, -UIScaleScript.px(16.0)), "+%d%% AS" % int(round(as_new - as_old)), "buff_atk")
	if ms_new > ms_old:
		_spawn_floating_text(pos + Vector2(0.0, -UIScaleScript.px(24.0)), "+%d%% MS" % int(round(ms_new - ms_old)), "buff_armor")
	_last_equip_stats = stats.duplicate()


func _equip_glow_rank() -> int:
	if GameState == null or not GameState.has_hero():
		return 0
	return int(EQUIP_RARITY_RANK.get(_highest_equip_rarity(), 0))


func _highest_equip_rarity() -> String:
	if GameState == null or not GameState.has_hero():
		return "basic"
	var best := "basic"
	var best_rank := -1
	for item in GameState.hero.equipped_items():
		var rarity := ItemDataScript.item_rarity(item)
		var rank := int(EQUIP_RARITY_RANK.get(rarity, 0))
		if rank > best_rank:
			best_rank = rank
			best = rarity
	return best


func _equip_glow_color() -> Color:
	if GameState == null or not GameState.has_hero():
		return Color(0.82, 0.72, 0.55)
	var rarity_col: Color = ItemDataScript.RARITY_COLORS.get(_highest_equip_rarity(), Color(0.75, 0.75, 0.8)) as Color
	return Color(0.82, 0.72, 0.55).lerp(rarity_col, 0.48)


func _sync_hero_equip_visual() -> void:
	if not is_instance_valid(_hero_sprite):
		return
	var glow_col := _equip_glow_color()
	var rank := _equip_glow_rank()
	var tint := 1.0 + rank * 0.035
	_hero_sprite.modulate = Color(
		clampf(0.9 + glow_col.r * 0.12 * tint, 0.0, 1.25),
		clampf(0.9 + glow_col.g * 0.12 * tint, 0.0, 1.25),
		clampf(0.9 + glow_col.b * 0.12 * tint, 0.0, 1.25),
		1.0
	)
	if GameState.hero != null:
		_hero_sprite.speed_scale = clampf(GameState.hero.attack_speed_multiplier(), 0.75, 2.2)


func _queue_bars_redraw() -> void:
	if is_instance_valid(_bars_layer):
		_bars_layer.queue_redraw()


func _queue_overlay_redraw() -> void:
	if is_instance_valid(_overlay_layer):
		_overlay_layer.queue_redraw()


func _draw_combat_bars() -> void:
	if size.x < 10.0 or size.y < 10.0 or not is_instance_valid(_bars_layer):
		return
	var ground_y := _ground_y if _ground_y > 1.0 else size.y * 0.42 + 8.0
	_draw_actor_hp_bars(_bars_layer, ground_y)
	_draw_hero_hp(_bars_layer, ground_y)
	_draw_hero_equip_buffs(_bars_layer, ground_y)
	_draw_combat_potion_bar(_bars_layer)
	_draw_damage_numbers(_bars_layer)


func _draw() -> void:
	if GameState == null or not GameState.has_hero() or size.x < 10.0 or size.y < 10.0:
		return

	var shake_off := _shake_offset()
	if shake_off != Vector2.ZERO:
		draw_set_transform(shake_off, 0.0, Vector2.ONE)

	var horizon := size.y * 0.42
	var sky: Color = _biome.get("sky", Color(0.5, 0.5, 0.5))
	var ground: Color = _biome.get("ground", Color(0.6, 0.6, 0.5))

	# 1. Premium Multi-Color Sky Gradient
	var sky_top := sky.lightened(0.18)
	var sky_bottom := sky.darkened(0.08)
	
	match _biome_id:
		"desert":
			sky_top = Color(0.16, 0.1, 0.26) # Twilight Deep Violet
			sky_bottom = Color(0.85, 0.45, 0.22) # Warm Sunset Orange/Amber
		"forest":
			sky_top = Color(0.18, 0.32, 0.46) # Deep Morning Forest Blue
			sky_bottom = Color(0.48, 0.62, 0.55) # Soft Misty Green/Gold
		"water":
			sky_top = Color(0.25, 0.55, 0.78) # Bright Tropical Blue
			sky_bottom = Color(0.62, 0.82, 0.88) # Oasis Warm Cyan
		"lava":
			sky_top = Color(0.06, 0.04, 0.05) # Ash Obsidian Dark
			sky_bottom = Color(0.72, 0.16, 0.06) # Deep Red Magma Radiance
		"snow":
			sky_top = Color(0.12, 0.18, 0.35) # Polar Dusk Navy
			sky_bottom = Color(0.68, 0.78, 0.92) # Soft Arctic Glare
		"ruins":
			sky_top = Color(0.2, 0.18, 0.22) # Gloomy Stone Grey
			sky_bottom = Color(0.42, 0.38, 0.36) # Dusty Horizon Rose
		"industrial":
			sky_top = Color(0.1, 0.08, 0.12) # Smoggy Steel Black
			sky_bottom = Color(0.42, 0.22, 0.14) # Furnance Orange Glow
		"void":
			sky_top = Color(0.02, 0.01, 0.05) # Infinite Space Black
			sky_bottom = Color(0.22, 0.08, 0.38) # Neon Magenta Nebula

	var sky_poly := PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		Vector2(size.x, horizon),
		Vector2(0.0, horizon)
	])
	var sky_colors := PackedColorArray([sky_top, sky_top, sky_bottom, sky_bottom])
	draw_polygon(sky_poly, sky_colors)

	# 2. Perspective Depth Ground Gradient
	var ground_top := ground
	var ground_bottom := (_biome.get("ground_dark", ground.darkened(0.25)) as Color).darkened(0.15)
	
	var ground_poly := PackedVector2Array([
		Vector2(0.0, horizon),
		Vector2(size.x, horizon),
		Vector2(size.x, size.y),
		Vector2(0.0, size.y)
	])
	var ground_colors := PackedColorArray([ground_top, ground_top, ground_bottom, ground_bottom])
	draw_polygon(ground_poly, ground_colors)

	_draw_scrolling_ground(horizon)

	_draw_biome_decor(horizon)
	_draw_biome_particles()
	_draw_top_status_strip()
	_draw_stage_hud()

	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.95, 0.35, 0.3, _flash * 0.28), true)

	if _loot_flash > 0.0:
		var lc := _loot_flash_color
		draw_rect(
			Rect2(Vector2.ZERO, size),
			Color(lc.r, lc.g, lc.b, _loot_flash * 0.24),
			true
		)
		draw_rect(
			Rect2(Vector2.ZERO, size),
			Color(1.0, 1.0, 1.0, _loot_flash * 0.06),
			true
		)

	if shake_off != Vector2.ZERO:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_biome_decor(horizon: float) -> void:
	match str(_biome.get("decor", "desert")):
		"forest":
			_draw_scrolling_trees(horizon)
		"water":
			_draw_scrolling_water(horizon)
			_draw_scrolling_palms(horizon)
		"lava":
			_draw_scrolling_lava(horizon)
		"snow":
			_draw_scrolling_snow(horizon)
		"ruins":
			_draw_scrolling_ruins(horizon)
		"industrial":
			_draw_scrolling_industrial(horizon)
		"void":
			_draw_void_grid(horizon)
		_:
			_draw_scrolling_dunes(horizon)
			_draw_scrolling_palms(horizon)


func _draw_scrolling_ground(horizon: float) -> void:
	var stripe: Color = (_biome.get("ground_dark", Color(0.5, 0.5, 0.5)) as Color).darkened(0.04)
	var spacing := 58.0
	var x := _parallax_x(1.05, spacing)
	while x < size.x + spacing:
		draw_rect(Rect2(x, horizon + 10, spacing * 0.42, 2), stripe)
		draw_rect(Rect2(x + spacing * 0.18, horizon + 26, spacing * 0.3, 2), stripe.lightened(0.05))
		draw_rect(Rect2(x + spacing * 0.55, horizon + 44, spacing * 0.22, 2), stripe.darkened(0.06))
		x += spacing

	var x_fast := _parallax_x(1.65, spacing * 0.72)
	while x_fast < size.x + spacing:
		draw_rect(Rect2(x_fast, horizon + 18, spacing * 0.2, 1), stripe.lightened(0.08))
		x_fast += spacing * 0.72


func _draw_scrolling_trees(horizon: float) -> void:
	var spacing := size.x * 0.22
	var leaf: Color = _biome.get("accent", Color.GREEN)
	var leaf_d: Color = _biome.get("accent_dark", Color.DARK_GREEN)
	var trunk: Color = _biome.get("trunk", Color(0.4, 0.25, 0.12))
	var x: float = _parallax_x(0.55, spacing)
	while x < size.x + spacing:
		_draw_tree(x, horizon, 1.0, trunk, leaf, leaf_d)
		_draw_tree(x + spacing * 0.45, horizon - 6.0, 0.72, trunk, leaf, leaf_d)
		x += spacing


func _draw_tree(x: float, horizon: float, scale: float, trunk: Color, leaf: Color, leaf_d: Color) -> void:
	var h := 28.0 * scale
	var w := 18.0 * scale
	var trunk_w := 5.0 * scale
	var base_y := horizon + 4.0
	
	# Wind sway animation using global time
	var time := Time.get_ticks_msec() * 0.0016
	var sway := sin(time + x * 0.035) * 3.2 * scale

	# Swaying trunk
	var pts_trunk := PackedVector2Array([
		Vector2(x + w * 0.5 - trunk_w * 0.5, base_y),
		Vector2(x + w * 0.5 + trunk_w * 0.5, base_y),
		Vector2(x + w * 0.5 + trunk_w * 0.5 + sway * 0.3, base_y - h * 0.35),
		Vector2(x + w * 0.5 - trunk_w * 0.5 + sway * 0.3, base_y - h * 0.35)
	])
	draw_polygon(pts_trunk, [trunk])

	# Organic circular layered foliage (overlapping circles with highlight and shadow)
	var leaf_center := Vector2(x + w * 0.5 + sway, base_y - h * 0.55)
	# Shadow/back layer
	draw_circle(leaf_center + Vector2(-1.5 * scale, -1.5 * scale), w * 0.55, leaf_d)
	# Mid/main foliage
	draw_circle(leaf_center, w * 0.48, leaf)
	# Highlight/top layer
	draw_circle(leaf_center + Vector2(2.0 * scale, -2.5 * scale), w * 0.32, leaf.lightened(0.18))


func _draw_scrolling_dunes(horizon: float) -> void:
	var dune: Color = _biome.get("ground_dark", Color(0.7, 0.6, 0.3))
	var period := size.x * 0.58
	
	# Two layers of scrolling sand dunes with different heights and speeds for parallax depth
	for layer in range(2):
		var speed := 0.25 + layer * 0.15
		var height_offset := 3.0 + layer * 7.0
		var color := dune if layer == 0 else dune.darkened(0.12)
		var spacing := size.x * (0.52 - layer * 0.08)
		
		var pts := PackedVector2Array()
		var start_x := -40.0
		var end_x := size.x + 40.0
		var step := 15.0
		
		var x_off := _parallax_x(speed, spacing)
		var curr_x := start_x
		while curr_x <= end_x:
			var relative_x := curr_x - x_off
			# Smooth rolling dunes using sine wave
			var dune_y := horizon + height_offset + sin(relative_x * 0.015) * 6.5
			pts.append(Vector2(curr_x, dune_y))
			curr_x += step
			
		pts.append(Vector2(end_x, size.y))
		pts.append(Vector2(start_x, size.y))
		draw_colored_polygon(pts, color)


func _draw_scrolling_palms(horizon: float) -> void:
	var spacing := size.x * 0.32
	var trunk: Color = _biome.get("trunk", Color(0.45, 0.3, 0.15))
	var leaf: Color = _biome.get("accent", Color(0.2, 0.55, 0.25))
	var x: float = _parallax_x(0.85, spacing)
	
	var time := Time.get_ticks_msec() * 0.0012
	while x < size.x + spacing:
		var sway := sin(time * 2.0 + x * 0.05) * 2.6
		var base_y := horizon + 2.0
		var trunk_h := 24.0
		
		# Curved/bent palm trunk
		var pts_trunk := PackedVector2Array([
			Vector2(x - 1.5, base_y),
			Vector2(x - 1.0 + sway * 0.4, base_y - trunk_h * 0.5),
			Vector2(x - 0.8 + sway, base_y - trunk_h),
			Vector2(x + 0.8 + sway, base_y - trunk_h),
			Vector2(x + 1.0 + sway * 0.4, base_y - trunk_h * 0.5),
			Vector2(x + 1.5, base_y)
		])
		draw_polygon(pts_trunk, [trunk])
		
		# Curved palm leaf stems
		var leaf_center := Vector2(x + sway, base_y - trunk_h)
		# Left drooping leaves
		draw_line(leaf_center, leaf_center + Vector2(-9.0, 3.5 + sway * 0.25), leaf, 1.8)
		draw_line(leaf_center, leaf_center + Vector2(-6.0, 6.0), leaf.darkened(0.15), 1.2)
		# Right drooping leaves
		draw_line(leaf_center, leaf_center + Vector2(9.0, 3.5 - sway * 0.25), leaf, 1.8)
		draw_line(leaf_center, leaf_center + Vector2(6.0, 6.0), leaf.darkened(0.15), 1.2)
		# Center top sprout
		draw_line(leaf_center, leaf_center + Vector2(sway * 0.2, -6.5), leaf.lightened(0.12), 1.5)
		
		x += spacing


func _draw_scrolling_water(horizon: float) -> void:
	var water: Color = _biome.get("accent", Color(0.22, 0.62, 0.72))
	var time := Time.get_ticks_msec() * 0.001
	
	# Ripple layers moving at different parallax speeds to simulate liquid flow
	for layer in range(2):
		var color := water.darkened(0.08) if layer == 0 else water.lightened(0.12)
		color.a = 0.58 if layer == 0 else 0.35
		var speed := 0.35 + layer * 0.25
		var height_offset := 5.0 + layer * 7.0
		var spacing := size.x * 0.38
		
		var pts := PackedVector2Array()
		var start_x := -25.0
		var end_x := size.x + 25.0
		var step := 12.0
		
		var x_off := _parallax_x(speed, spacing)
		var curr_x := start_x
		while curr_x <= end_x:
			var relative_x := curr_x - x_off
			# Undulating water ripples
			var wave_y := horizon + height_offset + sin(relative_x * 0.03 + time * 3.2) * 2.8
			pts.append(Vector2(curr_x, wave_y))
			curr_x += step
			
		pts.append(Vector2(end_x, horizon + 22.0))
		pts.append(Vector2(start_x, horizon + 22.0))
		draw_polygon(pts, [color])


func _draw_scrolling_lava(horizon: float) -> void:
	var glow: Color = _biome.get("accent", Color(0.95, 0.42, 0.12))
	var crack: Color = _biome.get("ground_dark", Color(0.18, 0.1, 0.08))
	var time := Time.get_ticks_msec() * 0.001
	
	# Liquid molten magma base wave
	var pts := PackedVector2Array()
	var start_x := -30.0
	var end_x := size.x + 30.0
	var step := 10.0
	
	var x_off := _parallax_x(0.42, size.x * 0.5)
	var curr_x := start_x
	while curr_x <= end_x:
		var relative_x := curr_x - x_off
		# Flowing magma waves
		var wave_y := horizon + 4.0 + sin(relative_x * 0.038 + time * 4.2) * 3.0
		pts.append(Vector2(curr_x, wave_y))
		curr_x += step
		
	pts.append(Vector2(end_x, horizon + 18.0))
	pts.append(Vector2(start_x, horizon + 18.0))
	draw_polygon(pts, [glow])
	
	# Floating basalt chunks/rocks moving along the lava
	var period := size.x * 0.48
	for i in range(-1, 3):
		var base_x := _parallax_band_x(i, 0.42, period)
		var float_y := horizon + 6.0 + sin((base_x + time * 35.0) * 0.035) * 1.2
		draw_rect(Rect2(base_x + 18, float_y, 38, 4), crack)
		draw_rect(Rect2(base_x + 75, float_y + 1.5, 28, 3.5), crack.darkened(0.18))


func _draw_scrolling_snow(horizon: float) -> void:
	var spacing := size.x * 0.28
	var trunk: Color = _biome.get("trunk", Color(0.32, 0.24, 0.18))
	var pine: Color = _biome.get("accent_dark", Color(0.28, 0.42, 0.58))
	var x: float = _parallax_x(0.6, spacing)
	
	var time := Time.get_ticks_msec() * 0.001
	while x < size.x + spacing:
		var sway := sin(time * 1.4 + x * 0.035) * 2.2
		var base_y := horizon + 3.0
		
		# Trunk
		draw_rect(Rect2(x + 6 + sway * 0.15, base_y - 12, 4, 12), trunk)
		
		# Layered pine branches (triangles) with snow caps
		# Bottom tier
		var branch_y1 := base_y - 10
		var pts_tier1 := PackedVector2Array([
			Vector2(x - 2 + sway, branch_y1),
			Vector2(x + 18 + sway, branch_y1),
			Vector2(x + 8 + sway * 0.8, branch_y1 - 12)
		])
		draw_polygon(pts_tier1, [pine])
		# Snow cap tier 1
		var pts_snow1 := PackedVector2Array([
			Vector2(x + 3 + sway, branch_y1 - 6),
			Vector2(x + 13 + sway, branch_y1 - 6),
			Vector2(x + 8 + sway * 0.8, branch_y1 - 12)
		])
		draw_polygon(pts_snow1, [Color(0.95, 0.96, 1.0)])

		# Top tier
		var branch_y2 := branch_y1 - 8
		var pts_tier2 := PackedVector2Array([
			Vector2(x + 2 + sway * 0.8, branch_y2),
			Vector2(x + 14 + sway * 0.8, branch_y2),
			Vector2(x + 8 + sway * 0.5, branch_y2 - 10)
		])
		draw_polygon(pts_tier2, [pine.lightened(0.12)])
		# Snow cap tier 2
		var pts_snow2 := PackedVector2Array([
			Vector2(x + 5 + sway * 0.8, branch_y2 - 5),
			Vector2(x + 11 + sway * 0.8, branch_y2 - 5),
			Vector2(x + 8 + sway * 0.5, branch_y2 - 10)
		])
		draw_polygon(pts_snow2, [Color(0.95, 0.96, 1.0)])
		
		x += spacing


func _draw_scrolling_ruins(horizon: float) -> void:
	var stone: Color = _biome.get("accent", Color(0.62, 0.58, 0.52))
	var shadow: Color = _biome.get("accent_dark", Color(0.42, 0.38, 0.34))
	var spacing := 96.0
	var x: float = _parallax_x(0.48, spacing)
	while x < size.x + 100:
		# Draw structured pillars/arches
		# Main Left Column
		draw_rect(Rect2(x, horizon - 32, 10, 32), stone)
		draw_rect(Rect2(x - 2, horizon - 36, 14, 4), stone.lightened(0.1))
		# Cracked lines on stone columns
		draw_line(Vector2(x, horizon - 12), Vector2(x + 10, horizon - 12), shadow, 1.0)
		draw_line(Vector2(x, horizon - 24), Vector2(x + 10, horizon - 24), shadow, 1.0)
		
		# Broken right pillar
		draw_rect(Rect2(x + 36, horizon - 18, 10, 18), stone.darkened(0.08))
		draw_rect(Rect2(x + 34, horizon - 22, 14, 4), stone.darkened(0.04))
		draw_line(Vector2(x + 36, horizon - 8), Vector2(x + 46, horizon - 8), shadow.darkened(0.1), 1.0)
		
		# Background crumbling archway shadow
		var arch_pts := PackedVector2Array([
			Vector2(x - 4, horizon - 36),
			Vector2(x + 14, horizon - 36),
			Vector2(x + 24, horizon - 26),
			Vector2(x - 14, horizon - 26)
		])
		draw_polygon(arch_pts, [shadow])
		
		x += spacing


func _draw_scrolling_industrial(horizon: float) -> void:
	var pipe: Color = _biome.get("accent_dark", Color(0.48, 0.28, 0.12))
	var glow: Color = _biome.get("accent", Color(0.78, 0.48, 0.18))
	var spacing := 110.0
	var x: float = _parallax_x(0.52, spacing)
	
	var time := Time.get_ticks_msec() * 0.001
	while x < size.x + 120:
		# Main vertical factory pipe
		draw_rect(Rect2(x, horizon - 36, 14, 36), pipe)
		# Flanges (bolted ring brackets)
		draw_rect(Rect2(x - 2, horizon - 26, 18, 4), pipe.darkened(0.16))
		draw_rect(Rect2(x - 2, horizon - 12, 18, 4), pipe.darkened(0.16))
		
		# Tiny rivet details on flanges
		draw_rect(Rect2(x - 1, horizon - 25, 2, 2), Color.BLACK)
		draw_rect(Rect2(x + 13, horizon - 25, 2, 2), Color.BLACK)
		draw_rect(Rect2(x - 1, horizon - 11, 2, 2), Color.BLACK)
		draw_rect(Rect2(x + 13, horizon - 11, 2, 2), Color.BLACK)

		# Horizontal pipe structure running behind
		draw_rect(Rect2(x - 40, horizon - 22, 120, 8), pipe.darkened(0.22))

		# Glowing steam pressure release valve
		var valve_center := Vector2(x + 7, horizon - 36)
		var pulse_glow := glow.lightened(sin(time * 6.0 + x) * 0.18)
		draw_circle(valve_center, 4.2, pipe.lightened(0.12))
		draw_circle(valve_center, 2.2, pulse_glow)

		x += spacing


func _draw_void_grid(horizon: float) -> void:
	var neon_col: Color = _biome.get("accent", Color(0.52, 0.28, 0.72))
	
	# Horizontal lines of the grid scrolling forward
	# Translate _scroll_x to grid movement
	var time_offset := fmod(_scroll_x * 0.85, 30.0)
	
	var y := horizon + 1.0
	var spacing := 5.0
	while y < size.y:
		# Depth ratio from horizon to bottom of screen for perspective fade
		var depth := (y - horizon) / (size.y - horizon)
		
		# Draw horizontal grid line with exponential scaling for 3D depth spacing
		var line_y := horizon + pow(depth, 1.8) * (size.y - horizon) + time_offset * depth * 0.35
		if line_y < size.y and line_y > horizon:
			var line_col := Color(neon_col.r, neon_col.g, neon_col.b, neon_col.a * 0.16 * depth)
			draw_line(Vector2(0.0, line_y), Vector2(size.x, line_y), line_col, 1.0)
		y += spacing
		
	# Vertical grid lines radiating from the horizon center (Perspective convergence)
	var cx := size.x * 0.5
	var line_count := 12
	var max_spread := size.x * 0.8
	for i in range(line_count + 1):
		var ratio := float(i) / float(line_count)
		var x_bottom := cx + (ratio - 0.5) * max_spread * 2.5
		
		var line_col := Color(neon_col.r, neon_col.g, neon_col.b, neon_col.a * 0.14)
		draw_line(Vector2(cx, horizon + 2.0), Vector2(x_bottom, size.y), line_col, 1.0)


func _draw_actor_hp_bars(canvas: CanvasItem, ground_y: float) -> void:
	for i in _actors.size():
		if i >= _sprites.size():
			continue
		var actor: CombatEnemyActorScript = _actors[i]
		var sprite: AnimatedSprite2D = _sprites[i]
		if not actor.alive or actor.enemy.hp <= 0.0:
			continue
		if not is_instance_valid(sprite) or not sprite.visible:
			continue

		var is_boss := actor.enemy.is_boss or StageDataScript.is_boss_type(actor.enemy_type)
		var ratio := clampf(actor.enemy.hp / maxf(actor.enemy.max_hp, 1.0), 0.0, 1.0)
		var lane_y := float(i % 2) * 2.0
		var disp := EnemySpriteScript.display_size_for(actor.enemy_type, SPRITE_SCALE)
		var disp_w := disp.x
		var bar_w := (disp_w + UIScaleScript.px(14.0)) if is_boss else maxf(SPRITE_W + 8.0, disp_w + 6.0)
		var pos := EnemySpriteScript.sprite_position_for(
			actor.enemy_type,
			actor.x,
			ground_y,
			SPRITE_SCALE,
			lane_y
		)
		var visual_top := EnemySpriteScript.visual_top_y_for(
			actor.enemy_type,
			ground_y,
			SPRITE_SCALE,
			lane_y
		)
		var bar_h := UIScaleScript.px(6.0) if is_boss else UIScaleScript.px(4.0)
		var x := pos.x + (disp_w - bar_w) * 0.5
		var y := visual_top - UIScaleScript.px(8.0)
		if is_boss:
			y = maxf(y, UIScaleScript.px(36.0))
		var fill := HP_BOSS if is_boss else HP_ENEMY
		_draw_hp_bar(canvas, x, y, bar_w, ratio, fill, bar_h)
		_draw_enemy_atk_badge(canvas, x, y, bar_w, actor.enemy.attack_damage)
		if is_boss:
			var font := ThemeDB.fallback_font
			canvas.draw_string(
				font,
				Vector2(x, y - UIScaleScript.px(9.0)),
				"BOSS",
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				UIScaleScript.font_caption(),
				HP_BOSS
			)


func _draw_hero_hp(canvas: CanvasItem, ground_y: float) -> void:
	if GameState == null or not GameState.has_hero():
		return
	if not is_instance_valid(_hero_sprite) or not _hero_sprite.visible:
		return
	var hero := GameState.hero
	var ratio := clampf(hero.hp / maxf(hero.max_hp, 1.0), 0.0, 1.0)
	var bar_w := SPRITE_W + 8.0
	var x := _hero_x
	var y := ground_y - SPRITE_W - 10.0
	_draw_hp_bar(canvas, x, y, bar_w, ratio, HP_ALLY, UIScaleScript.px(4.0))


func _draw_combat_potion_bar(canvas: CanvasItem) -> void:
	if GameState == null or not GameState.has_hero():
		return
	var metrics := CombatPotionBarScript.combat_layout(canvas.size, STAGE_HUD_HEIGHT)
	CombatPotionBarScript.draw(
		canvas,
		metrics,
		GameState.hero,
		_potion_use_flash,
		_potion_gain_flash,
		_potion_pulse
	)


func _draw_enemy_atk_badge(canvas: CanvasItem, bar_x: float, bar_y: float, bar_w: float, attack_damage: float) -> void:
	var atk := maxi(1, int(round(attack_damage)))
	var font: Font = UiFont.get_font()
	var fs := UIScaleScript.font(COMBAT_BADGE_FONT)
	var label := "ATK %d" % atk
	var pad_x := UIScaleScript.px(8.0)
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + pad_x * 2.0
	var badge_h := UIScaleScript.px(COMBAT_BADGE_HEIGHT)
	var rect := Rect2(bar_x + bar_w - tw, bar_y - badge_h - UIScaleScript.px(3.0), tw, badge_h)
	var r := minf(badge_h * 0.32, UIScaleScript.px(5.0))
	InventorySlotDrawScript._draw_rounded_fill(canvas, rect, r, Color(0.12, 0.06, 0.06, 0.92))
	InventorySlotDrawScript._draw_rounded_stroke(canvas, rect, r, Color(0.85, 0.32, 0.28, 0.85), UIScaleScript.px(1.0))
	canvas.draw_string(
		font,
		Vector2(rect.position.x + pad_x, rect.position.y + badge_h * 0.74),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fs,
		Color(1.0, 0.55, 0.45)
	)


func _draw_hero_equip_buffs(canvas: CanvasItem, ground_y: float) -> void:
	if not is_instance_valid(_hero_sprite) or not _hero_sprite.visible:
		return
	var hero := GameState.hero
	var atk := int(round(hero.attack_power()))
	var armor_val := int(round(hero.armor()))
	if atk <= 0 and armor_val <= 0:
		return

	var bar_y := ground_y - SPRITE_W - 10.0
	var badge_h := UIScaleScript.px(COMBAT_BADGE_HEIGHT)
	var gap := UIScaleScript.px(4.0)
	var font: Font = UiFont.get_font()
	var fs := UIScaleScript.font(COMBAT_BADGE_FONT)
	var pad_x := UIScaleScript.px(7.0)
	var entries: Array[Dictionary] = []
	entries.append({"text": "ATK %d" % atk, "col": Color(1.0, 0.78, 0.38), "kind": "atk"})
	if armor_val > 0:
		entries.append({"text": "DEF %d" % armor_val, "col": Color(0.52, 0.84, 1.0), "kind": "armor"})

	var widths: Array[float] = []
	var total_w := 0.0
	for entry in entries:
		var tw: float = font.get_string_size(str(entry["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + pad_x * 2.0
		widths.append(tw)
		total_w += tw
	total_w += gap * maxf(0.0, float(entries.size() - 1))

	var x := _hero_x + (SPRITE_W + 8.0) * 0.5 - total_w * 0.5
	var y := bar_y - badge_h - UIScaleScript.px(4.0)
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var w := widths[i]
		var rect := Rect2(x, y, w, badge_h)
		var entry_col: Color = entry["col"] as Color
		var r := minf(badge_h * 0.32, UIScaleScript.px(5.0))
		InventorySlotDrawScript._draw_rounded_fill(canvas, rect, r, Color(0.08, 0.06, 0.1, 0.92))
		InventorySlotDrawScript._draw_rounded_stroke(canvas, rect, r, entry_col.darkened(0.25), UIScaleScript.px(1.0))
		var tx: float = rect.position.x + pad_x
		var ty: float = rect.position.y + badge_h * 0.74
		canvas.draw_string(font, Vector2(tx, ty), str(entry["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, entry_col.lightened(0.12))
		x += w + gap


func _draw_stage_hud() -> void:
	if _hud_stage_label.is_empty() or GameState.stage_runner == null:
		return

	var box_h := STAGE_HUD_HEIGHT
	var bounds := Rect2(0.0, size.y - box_h, size.x, box_h)
	StageMapDrawScript.draw(self, bounds, {
		"wave_index": GameState.stage_runner.wave_index,
		"wave_count": GameState.stage_runner.wave_count(),
		"stage_label": _hud_stage_label,
		"stage_name": _hud_stage_name,
		"world": _hud_world,
		"biome": _biome,
		"hovered": _stage_hud_hovered,
	})


func _update_overlay_anim(delta: float) -> void:
	if _banner_alpha > 0.02:
		_banner_enter = minf(1.0, _banner_enter + delta / 0.34)
	elif _banner_enter > 0.0:
		_banner_enter = maxf(0.0, _banner_enter - delta * 5.0)

	if _boss_intro_alpha > 0.02:
		_boss_enter = minf(1.0, _boss_enter + delta / 0.38)
	elif _boss_enter > 0.0:
		_boss_enter = 0.0


func _draw_top_status_strip() -> void:
	var hero := GameState.hero
	CombatOverlayDrawScript.draw_top_strip(
		self,
		size,
		hero.level,
		hero.gold,
		hero.xp,
		hero.xp_to_next,
		hero.player_name
	)


func _draw_combat_overlay() -> void:
	if not is_instance_valid(_overlay_layer):
		return
	var overlay_size := _overlay_layer.size
	if overlay_size.x < 10.0 or overlay_size.y < 10.0:
		return
	_draw_stage_banner(_overlay_layer, overlay_size)
	_draw_boss_intro(_overlay_layer, overlay_size)


func _draw_stage_banner(canvas: CanvasItem, viewport: Vector2) -> void:
	if _banner_alpha <= 0.01:
		return
	CombatOverlayDrawScript.draw_banner_card(
		canvas,
		viewport,
		_banner_alpha,
		_banner_enter,
		_banner_title,
		_banner_subtitle,
		_banner_biome,
		_biome
	)


func _draw_boss_intro(canvas: CanvasItem, viewport: Vector2) -> void:
	if _boss_intro_alpha <= 0.01:
		return
	var shake_x := sin(_boss_shake * 48.0) * _boss_shake * 5.0
	CombatOverlayDrawScript.draw_boss_card(
		canvas,
		viewport,
		_boss_intro_alpha,
		_boss_enter,
		_boss_display_name,
		shake_x
	)


func _draw_hp_bar(canvas: CanvasItem, x: float, y: float, width: float, ratio: float, fill: Color, height: float = 4.0) -> void:
	var rect := Rect2(x, y, width, height)
	var r := minf(height * 0.5, UIScaleScript.px(2.5))
	InventorySlotDrawScript._draw_rounded_fill(canvas, rect, r, Color(0.08, 0.06, 0.1, 0.92))
	if ratio > 0.01:
		var fill_rect := Rect2(x, y, width * clampf(ratio, 0.0, 1.0), height)
		InventorySlotDrawScript._draw_rounded_fill(canvas, fill_rect, r, fill)
		canvas.draw_rect(
			Rect2(x + r, y + UIScaleScript.px(0.5), maxf(0.0, fill_rect.size.x - r * 2.0), UIScaleScript.px(1.0)),
			Color(fill.r, fill.g, fill.b, 0.35),
			true
		)
	InventorySlotDrawScript._draw_rounded_stroke(canvas, rect, r, Color(0.22, 0.18, 0.14, 0.85), UIScaleScript.px(0.75))


func _init_biome_particles() -> void:
	_biome_particles.clear()
	var max_particles := 0
	match _biome_id:
		"lava": max_particles = 45
		"snow": max_particles = 65
		"void": max_particles = 40
		"forest": max_particles = 30
	
	if max_particles > 0:
		for i in range(max_particles / 2):
			_spawn_biome_particle(true)


func _spawn_biome_particle(random_y: bool) -> void:
	var w := size.x if size.x > 10.0 else 400.0
	var h := size.y if size.y > 10.0 else 144.0
	
	var px := randf_range(0.0, w)
	var py := 0.0
	var vx := 0.0
	var vy := 0.0
	var color := Color.WHITE
	var size_px := 2.0
	var life := randf_range(2.0, 5.0)
	var p_seed := randf() * 100.0
	
	match _biome_id:
		"lava":
			py = h if not random_y else randf_range(0.0, h)
			vx = randf_range(-15.0, 15.0)
			vy = randf_range(-40.0, -85.0)
			var r := randf()
			if r < 0.33:
				color = Color(1.0, 0.82, 0.15, randf_range(0.6, 0.95))
			elif r < 0.66:
				color = Color(1.0, 0.45, 0.05, randf_range(0.6, 0.9))
			else:
				color = Color(0.92, 0.15, 0.05, randf_range(0.5, 0.85))
			size_px = randf_range(1.0, 2.5)
			life = randf_range(1.5, 3.0)
		"snow":
			py = 0.0 if not random_y else randf_range(0.0, h)
			vx = randf_range(-8.0, 8.0)
			vy = randf_range(18.0, 38.0)
			color = Color(0.92, 0.96, 1.0, randf_range(0.5, 0.9))
			size_px = randf_range(1.5, 3.0)
			life = randf_range(3.5, 6.0)
		"void":
			px = randf_range(0.0, w)
			py = randf_range(0.0, h)
			vx = randf_range(-8.0, 8.0)
			vy = randf_range(-8.0, 8.0)
			var r := randf()
			if r < 0.5:
				color = Color(0.62, 0.28, 0.88, randf_range(0.35, 0.75))
			else:
				color = Color(0.32, 0.58, 0.95, randf_range(0.35, 0.75))
			size_px = randf_range(1.2, 3.0)
			life = randf_range(2.5, 5.0)
		"forest":
			py = 0.0 if not random_y else randf_range(0.0, h)
			vx = randf_range(-12.0, 20.0)
			vy = randf_range(15.0, 32.0)
			var r := randf()
			if r < 0.4:
				color = Color(0.38, 0.65, 0.22, randf_range(0.5, 0.85))
			elif r < 0.8:
				color = Color(0.52, 0.58, 0.15, randf_range(0.5, 0.8))
			else:
				color = Color(0.68, 0.45, 0.18, randf_range(0.4, 0.75))
			size_px = randf_range(1.5, 3.0)
			life = randf_range(3.0, 5.5)

	_biome_particles.append({
		"pos": Vector2(px, py),
		"vel": Vector2(vx, vy),
		"color": color,
		"size": size_px,
		"life": life,
		"max_life": life,
		"seed": p_seed
	})


func _update_biome_particles(delta: float) -> void:
	var max_particles := 0
	match _biome_id:
		"lava": max_particles = 45
		"snow": max_particles = 65
		"void": max_particles = 40
		"forest": max_particles = 30

	var i := 0
	while i < _biome_particles.size():
		var p: Dictionary = _biome_particles[i]
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			_biome_particles.remove_at(i)
		else:
			p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
			if _biome_id == "snow":
				p["pos"].x += sin((p["life"] as float) * 2.0 + (p["seed"] as float)) * 12.0 * delta
			elif _biome_id == "forest":
				p["pos"].x += cos((p["life"] as float) * 1.5 + (p["seed"] as float)) * 8.0 * delta
			i += 1

	if _biome_particles.size() < max_particles:
		var spawn_count := randi() % 3 + 1
		for j in spawn_count:
			if _biome_particles.size() >= max_particles:
				break
			_spawn_biome_particle(false)


func _draw_biome_particles() -> void:
	for p in _biome_particles:
		var pos: Vector2 = p["pos"]
		var size_px: float = p["size"]
		var color: Color = p["color"]
		var life: float = p["life"]
		var max_life: float = p["max_life"]
		
		var alpha_mult := 1.0
		if life < 0.5:
			alpha_mult = life / 0.5
		elif (max_life - life) < 0.5:
			alpha_mult = (max_life - life) / 0.5
		
		var draw_color := Color(color.r, color.g, color.b, color.a * alpha_mult)
		
		if _biome_id == "void":
			draw_circle(pos, size_px * 1.5, Color(draw_color.r, draw_color.g, draw_color.b, draw_color.a * 0.35))
		
		draw_circle(pos, size_px, draw_color)


var _stage_popup: PanelContainer = null
var _stage_popup_backdrop: ColorRect = null

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hud_rect := Rect2(0.0, size.y - STAGE_HUD_HEIGHT, size.x, STAGE_HUD_HEIGHT)
		if hud_rect.has_point(event.position):
			if is_instance_valid(_stage_popup) and _stage_popup.visible:
				_close_stage_selector()
			else:
				_show_stage_selector()
			accept_event()


func _close_stage_selector() -> void:
	if is_instance_valid(_stage_popup):
		_stage_popup.queue_free()
		_stage_popup = null
	if is_instance_valid(_stage_popup_backdrop):
		_stage_popup_backdrop.queue_free()
		_stage_popup_backdrop = null
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	_stage_hud_hovered = false
	queue_redraw()


func _show_stage_selector() -> void:
	_close_stage_selector()

	_stage_popup_backdrop = ColorRect.new()
	_stage_popup_backdrop.name = "StageSelectorBackdrop"
	_stage_popup_backdrop.color = Color(0.0, 0.0, 0.0, 0.45)
	_stage_popup_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage_popup_backdrop.z_index = 119
	_stage_popup_backdrop.z_as_relative = false
	_stage_popup_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage_popup_backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_stage_selector()
			get_viewport().set_input_as_handled()
	)
	add_child(_stage_popup_backdrop)

	_stage_popup = PanelContainer.new()
	_stage_popup.name = "StageSelectorPopup"
	_stage_popup.z_index = 120
	_stage_popup.z_as_relative = false
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.08, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.92, 0.74, 0.38) # Gold
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	_stage_popup.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(UIScaleScript.px(12.0)))
	margin.add_theme_constant_override("margin_top", int(UIScaleScript.px(10.0)))
	margin.add_theme_constant_override("margin_right", int(UIScaleScript.px(12.0)))
	margin.add_theme_constant_override("margin_bottom", int(UIScaleScript.px(10.0)))
	_stage_popup.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(UIScaleScript.px(6.0)))
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title_lbl := Label.new()
	title_lbl.text = "SELECT STAGE"
	title_lbl.add_theme_font_override("font", UiFont.get_font())
	title_lbl.add_theme_font_size_override("font_size", UIScaleScript.font_emphasis())
	title_lbl.add_theme_color_override("font_color", Color(0.92, 0.74, 0.38))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)

	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = Color(0.24, 0.22, 0.20)
	vbox.add_child(div)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, UIScaleScript.px(130.0))
	vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(UIScaleScript.px(6.0)))
	grid.add_theme_constant_override("v_separation", int(UIScaleScript.px(6.0)))
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	var runner := GameState.stage_runner
	var max_stage := clampi(GameState.max_unlocked_stage, 0, runner.stages.size() - 1)
	
	for idx in range(max_stage + 1):
		var stage_data: Dictionary = runner.stages[idx]
		var btn := Button.new()
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.text = "%d-%d: %s" % [int(stage_data.get("world", 1)), int(stage_data.get("stage", 1)), str(stage_data.get("name", ""))]
		btn.add_theme_font_override("font", UiFont.get_font())
		btn.add_theme_font_size_override("font_size", UIScaleScript.font_caption())
		
		var btn_style := StyleBoxFlat.new()
		btn_style.corner_radius_top_left = 4
		btn_style.corner_radius_top_right = 4
		btn_style.corner_radius_bottom_right = 4
		btn_style.corner_radius_bottom_left = 4
		
		if idx == runner.stage_index:
			btn_style.bg_color = Color(0.42, 0.32, 0.18)
			btn_style.border_width_left = 1
			btn_style.border_width_top = 1
			btn_style.border_width_right = 1
			btn_style.border_width_bottom = 1
			btn_style.border_color = Color(0.92, 0.74, 0.38)
		else:
			btn_style.bg_color = Color(0.12, 0.10, 0.15)
			btn_style.border_width_left = 1
			btn_style.border_width_top = 1
			btn_style.border_width_right = 1
			btn_style.border_width_bottom = 1
			btn_style.border_color = Color(0.25, 0.22, 0.28)
			
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.custom_minimum_size = Vector2(UIScaleScript.px(140.0), UIScaleScript.px(24.0))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		btn.pressed.connect(func() -> void:
			runner.stage_index = idx
			runner._begin_current_stage(GameState.hero)
			GameState.request_save()
			queue_redraw()
			GameState.state_changed.emit()
			_close_stage_selector()
		)
		grid.add_child(btn)

	var footer := HBoxContainer.new()
	vbox.add_child(footer)
	
	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(filler)

	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.add_theme_font_override("font", UiFont.get_font())
	close_btn.add_theme_font_size_override("font_size", UIScaleScript.font_caption())
	
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.18, 0.15, 0.12)
	btn_normal.border_width_left = 1
	btn_normal.border_width_top = 1
	btn_normal.border_width_right = 1
	btn_normal.border_width_bottom = 1
	btn_normal.border_color = Color(0.85, 0.72, 0.45)
	btn_normal.corner_radius_top_left = 4
	btn_normal.corner_radius_top_right = 4
	btn_normal.corner_radius_bottom_right = 4
	btn_normal.corner_radius_bottom_left = 4
	close_btn.add_theme_stylebox_override("normal", btn_normal)
	close_btn.custom_minimum_size = Vector2(UIScaleScript.px(80.0), UIScaleScript.px(24.0))

	close_btn.pressed.connect(func() -> void:
		_close_stage_selector()
	)
	footer.add_child(close_btn)

	add_child(_stage_popup)
	
	var popup_w := UIScaleScript.px(340.0)
	var popup_h := UIScaleScript.px(220.0)
	_stage_popup.size = Vector2(popup_w, popup_h)
	_stage_popup.position = (size - _stage_popup.size) * 0.5

