extends Control

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const HeroSpriteScript = preload("res://scripts/ui/hero_sprite.gd")
const EnemySpriteScript = preload("res://scripts/ui/enemy_sprite.gd")
const CombatEnemyActorScript = preload("res://scripts/ui/combat_enemy_actor.gd")
const CombatBiomeScript = preload("res://scripts/ui/combat_biome.gd")
const PortalSpriteScript = preload("res://scripts/ui/portal_sprite.gd")
const StageDataScript = preload("res://scripts/game/stage_data.gd")
const ItemDataScript = preload("res://scripts/game/item_data.gd")
const MagicSchoolScript = preload("res://scripts/game/magic_school.gd")
const NavIconsScript = preload("res://scripts/ui/nav_icons.gd")
const UiFont = preload("res://scripts/ui/ui_font.gd")
const StageMapDrawScript = preload("res://scripts/ui/stage_map_draw.gd")
const CombatOverlayDrawScript = preload("res://scripts/ui/combat_overlay_draw.gd")
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

var _scroll_x := 0.0
var _flash := 0.0
var _ground_y := 0.0
var _hero_x := 0.0
var _in_melee := false
var _combat_locked := false
var _scroll_frozen := false
var _intro_phase := ""
var _intro_timer := 0.0
var _pending_enemies: Array = []
var _banner_alpha := 0.0
var _banner_enter := 0.0
var _banner_title := ""
var _banner_subtitle := ""
var _banner_biome := ""
var _hud_stage_label := ""
var _hud_stage_name := ""
var _hud_wave_text := ""
var _hud_world := 1
var _biome: Dictionary = CombatBiomeScript.resolve("desert")
var _actors: Array[CombatEnemyActorScript] = []
var _sprites: Array[AnimatedSprite2D] = []

var _hero_sprite: AnimatedSprite2D
var _portal_sprite: AnimatedSprite2D
var _bars_layer: Control
var _portal_grow := 0.0
var _portal_scale_mul := 1.0
var _intro_hold_duration := INTRO_HOLD
var _hero_emerge := 0.0
var _damage_numbers: Array[Dictionary] = []
var _boss_display_name := ""
var _boss_intro_alpha := 0.0
var _boss_enter := 0.0
var _boss_shake := 0.0
var _boss_sting_player: AudioStreamPlayer
var _queue_breath_time := 0.0
var _last_equip_stats: Dictionary = {}
var _equip_stats_ready := false
var _equip_glow_pulse := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_hero_sprite = AnimatedSprite2D.new()
	_hero_sprite.set_script(HeroSpriteScript)
	_hero_sprite.z_index = 5
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

	_boss_sting_player = AudioStreamPlayer.new()
	_boss_sting_player.name = "BossSting"
	add_child(_boss_sting_player)

	resized.connect(_layout_hero)
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
	_last_equip_stats = GameState.hero.equipment_stats().duplicate()
	_equip_stats_ready = true
	_sync_hero_equip_visual()
	call_deferred("_layout_hero")


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
	_stop_melee()
	_clear_visual_enemies()
	_damage_numbers.clear()
	_combat_locked = true
	_scroll_frozen = true
	_set_hero_intro_pose(true)

	var transition: String = str(info.get("transition", "wave"))
	var label: String = str(info.get("label", "?-?"))
	var stage_name: String = str(info.get("name", ""))
	var wave_index: int = int(info.get("wave_index", 0)) + 1
	var wave_count: int = int(info.get("wave_count", 1))
	var biome_id: String = str(info.get("biome", "desert"))

	if transition == "stage" or transition == "retry":
		_biome = CombatBiomeScript.resolve(biome_id)

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
	_pending_enemies = info.get("enemies", [])

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
	_play_boss_sting()
	queue_redraw()


func _play_boss_sting() -> void:
	if not is_instance_valid(_boss_sting_player):
		return
	var sample := AudioStreamWAV.new()
	sample.format = AudioStreamWAV.FORMAT_16_BITS
	sample.mix_rate = 22050
	sample.stereo = false
	var duration := BOSS_STING_SEC
	var count: int = int(22050.0 * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / 22050.0
		var env := 1.0 - (t / duration)
		var freq := 92.0 + 48.0 * (1.0 - t / duration)
		var s := int(clampf(sin(t * freq * TAU) * env * 9000.0, -32768.0, 32767.0))
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	sample.data = data
	_boss_sting_player.stream = sample
	_boss_sting_player.volume_db = -8.0
	_boss_sting_player.play()


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
	_portal_grow = 0.0
	_portal_scale_mul = PORTAL_GROW_MIN
	_hero_emerge = 0.0
	_hero_sprite.visible = false
	_hero_sprite.modulate = Color(1, 1, 1, 1)
	_hero_sprite.z_index = 2
	_apply_portal_visual()
	_portal_sprite.play_open()
	_set_hero_intro_pose(true)
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
	_spawn_wave_types(_pending_enemies)
	_pending_enemies.clear()


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
	_clear_visual_enemies()
	var types := PackedStringArray()
	for enemy_type in enemies:
		if typeof(enemy_type) == TYPE_STRING:
			types.append(enemy_type)
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
	if size.x < 10.0:
		return

	_update_damage_numbers(delta)
	_update_overlay_anim(delta)
	_queue_breath_time += delta
	_equip_glow_pulse += delta
	if _equip_glow_rank() >= 1:
		_queue_bars_redraw()

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
		_hero_sprite.modulate.a = clampf(t * 1.35, 0.0, 1.0)
		_sync_portal_intro_layout(hero_x, hero_sc)
		if t >= 0.98 and _banner_alpha <= 0.02:
			_finish_intro()
		queue_redraw()
		return

	if _intro_phase == "hold":
		_intro_timer -= delta
		if _intro_timer <= 0.0:
			_intro_phase = "fade"
			_intro_timer = _intro_fade_duration
		queue_redraw()
		return

	if _intro_phase == "fade":
		_intro_timer -= delta
		_banner_alpha = clampf(_intro_timer / _intro_fade_duration, 0.0, 1.0)
		if _intro_timer <= 0.0:
			_finish_intro()
		queue_redraw()
		return

	if _intro_phase == "wave_pause":
		_intro_timer -= delta
		if _intro_timer <= 0.0:
			_finish_intro()
		queue_redraw()
		return

	if _combat_locked:
		if not _scroll_frozen and _intro_phase.is_empty():
			_scroll_x += delta * SCROLL_SPEED
		queue_redraw()
		return

	if not _scroll_frozen:
		var scroll_rate: float = SCROLL_SPEED if not _in_melee else SCROLL_SPEED * 0.35
		_scroll_x += delta * scroll_rate

	if not _in_melee:
		var front_actor := _front_living_actor()
		var front_ready := false
		for i in _actors.size():
			var actor: CombatEnemyActorScript = _actors[i]
			if not actor.alive or actor.enemy.hp <= 0.0:
				continue
			var target_x := _queue_target_x(actor)
			if actor.x < target_x:
				actor.x += delta * APPROACH_SPEED
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
				actor.x = minf(actor.x + delta * APPROACH_SPEED * 1.35, target_x)
			else:
				actor.x = target_x

	if _flash > 0.0:
		_flash -= delta

	_sync_actor_positions()
	queue_redraw()
	_queue_bars_redraw()


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
		sprite.position = pos
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
	GameState.combat_melee_exchange()


func _stop_melee() -> void:
	if not _in_melee:
		return
	_in_melee = false
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


func _on_hero_damaged(amount: float) -> void:
	if not _in_melee:
		return
	_flash = 0.2
	_spawn_damage_number(_popup_pos_for_hero(), amount, "hurt")
	_flash_front_enemy("attack")
	if GameState.hero.hp > 0.0:
		_hero_sprite.play_action("hurt")
	else:
		_hero_sprite.play_action("death")


func _on_hero_died() -> void:
	_stop_melee()
	_combat_locked = true
	_scroll_frozen = true
	_flash = 0.35


func _on_enemy_damaged(slot: int, amount: float, source: String) -> void:
	if not _in_melee or amount <= 0.0:
		return
	if slot != _combat_front_slot():
		return
	var kind := "dot" if source == "Burn" else "deal"
	if slot < _sprites.size() and is_instance_valid(_sprites[slot]):
		_sprites[slot].play_action("hurt")
	_spawn_damage_number(_popup_pos_for_enemy_slot(slot), amount, kind)


func _combat_front_slot() -> int:
	if GameState.combat == null:
		return 0
	return GameState.combat.front_slot()


func _spawn_damage_number(at: Vector2, amount: float, kind: String) -> void:
	if amount <= 0.0:
		return
	_spawn_floating_text(at + Vector2(randf_range(-6.0, 6.0), 0.0), str(int(round(amount))), kind, 0.85)


func _spawn_floating_text(at: Vector2, text: String, kind: String, life: float = 1.05) -> void:
	if text.is_empty():
		return
	_damage_numbers.append({
		"text": text,
		"x": at.x,
		"y": at.y,
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
		pop["y"] = float(pop["y"]) - 34.0 * delta
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
		var font_size := UIScaleScript.font(15)
		if kind == "dot":
			font_size = UIScaleScript.font(11)
		elif kind.begins_with("buff"):
			font_size = UIScaleScript.font(9)
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
	_combat_locked = true
	_scroll_frozen = false
	get_tree().create_timer(WAVE_PAUSE).timeout.connect(func() -> void:
		if is_inside_tree():
			GameState.on_wave_cleared()
	)


func _on_state_changed() -> void:
	_track_equip_changes()
	_sync_hero_equip_visual()
	queue_redraw()
	_queue_bars_redraw()


func _track_equip_changes() -> void:
	var stats := GameState.hero.equipment_stats()
	if not _equip_stats_ready:
		_last_equip_stats = stats.duplicate()
		_equip_stats_ready = true
		return

	var atk_old := float(_last_equip_stats.get("attack", 0.0))
	var atk_new := float(stats.get("attack", 0.0))
	var armor_old := float(_last_equip_stats.get("armor", 0.0))
	var armor_new := float(stats.get("armor", 0.0))
	var pos := _popup_pos_for_hero()
	if atk_new > atk_old:
		_spawn_floating_text(pos, "+%d ATK" % int(round(atk_new - atk_old)), "buff_atk")
	if armor_new > armor_old:
		_spawn_floating_text(pos + Vector2(0.0, -UIScaleScript.px(8.0)), "+%d ARM" % int(round(armor_new - armor_old)), "buff_armor")
	_last_equip_stats = stats.duplicate()


func _equip_glow_rank() -> int:
	return int(EQUIP_RARITY_RANK.get(_highest_equip_rarity(), 0))


func _highest_equip_rarity() -> String:
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
	var school: Color = MagicSchoolScript.COLORS.get(GameState.hero.school, Color(1.0, 0.7, 0.5)) as Color
	var rarity_col: Color = ItemDataScript.RARITY_COLORS.get(_highest_equip_rarity(), Color(0.75, 0.75, 0.8)) as Color
	return school.lerp(rarity_col, 0.48)


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


func _queue_bars_redraw() -> void:
	if is_instance_valid(_bars_layer):
		_bars_layer.queue_redraw()


func _draw_combat_bars() -> void:
	if size.x < 10.0 or size.y < 10.0 or not is_instance_valid(_bars_layer):
		return
	var ground_y := size.y * 0.42 + 8.0
	_draw_hero_equip_glow(_bars_layer, ground_y)
	_draw_actor_hp_bars(_bars_layer, ground_y)
	_draw_hero_hp(_bars_layer, ground_y)
	_draw_hero_equip_buffs(_bars_layer, ground_y)
	_draw_damage_numbers(_bars_layer)


func _draw() -> void:
	if size.x < 10.0 or size.y < 10.0:
		return

	var horizon := size.y * 0.42
	var sky: Color = _biome.get("sky", Color(0.5, 0.5, 0.5))
	var ground: Color = _biome.get("ground", Color(0.6, 0.6, 0.5))
	draw_rect(Rect2(Vector2.ZERO, size), sky, true)
	draw_rect(Rect2(0, horizon, size.x, size.y - horizon), ground, true)
	_draw_scrolling_ground(horizon)

	_draw_biome_decor(horizon)
	_draw_top_status_strip()
	_draw_stage_hud()
	_draw_stage_banner()
	_draw_boss_intro()

	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.95, 0.35, 0.3, _flash * 0.28), true)


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
	draw_rect(Rect2(x + w * 0.5 - trunk_w * 0.5, base_y - h * 0.35, trunk_w, h * 0.38), trunk)
	draw_rect(Rect2(x, base_y - h, w, h * 0.55), leaf)
	draw_rect(Rect2(x + w * 0.15, base_y - h * 0.82, w * 0.7, h * 0.28), leaf_d)


func _draw_scrolling_dunes(horizon: float) -> void:
	var dune: Color = _biome.get("ground_dark", Color(0.7, 0.6, 0.3))
	var period := size.x * 0.55
	for i in range(-1, 3):
		var base_x := _parallax_band_x(i, 0.35, period)
		var pts := PackedVector2Array([
			Vector2(base_x, horizon + 6),
			Vector2(base_x + size.x * 0.22, horizon - 4),
			Vector2(base_x + size.x * 0.42, horizon + 8),
			Vector2(base_x + size.x * 0.58, horizon + 2),
			Vector2(base_x + size.x * 0.58, size.y),
			Vector2(base_x, size.y),
		])
		draw_colored_polygon(pts, dune)


func _draw_scrolling_palms(horizon: float) -> void:
	var spacing := size.x * 0.32
	var trunk: Color = _biome.get("trunk", Color(0.45, 0.3, 0.15))
	var leaf: Color = _biome.get("accent", Color(0.2, 0.55, 0.25))
	var x: float = _parallax_x(0.85, spacing)
	while x < size.x + spacing:
		draw_rect(Rect2(x - 2, horizon - 18, 4, 18), trunk)
		draw_rect(Rect2(x - 10, horizon - 20, 8, 4), leaf)
		draw_rect(Rect2(x + 2, horizon - 18, 8, 4), leaf)
		x += spacing


func _draw_scrolling_water(horizon: float) -> void:
	var water: Color = _biome.get("accent", Color(0.22, 0.62, 0.72))
	var period := size.x * 0.5
	for i in range(-1, 3):
		var base_x := _parallax_band_x(i, 0.5, period)
		draw_rect(Rect2(base_x, horizon + 2, size.x * 0.48, 10), water.darkened(0.08))
		draw_rect(Rect2(base_x + 18, horizon + 10, size.x * 0.32, 6), water.lightened(0.08))


func _draw_scrolling_lava(horizon: float) -> void:
	var glow: Color = _biome.get("accent", Color(0.95, 0.42, 0.12))
	var crack: Color = _biome.get("ground_dark", Color(0.18, 0.1, 0.08))
	var period := size.x * 0.45
	for i in range(-1, 3):
		var base_x := _parallax_band_x(i, 0.42, period)
		draw_rect(Rect2(base_x + 20, horizon + 4, 36, 5), glow)
		draw_rect(Rect2(base_x + 80, horizon + 8, 48, 4), crack)
		draw_rect(Rect2(base_x + 140, horizon + 3, 28, 6), glow.darkened(0.15))


func _draw_scrolling_snow(horizon: float) -> void:
	var spacing := size.x * 0.28
	var trunk: Color = _biome.get("trunk", Color(0.32, 0.24, 0.18))
	var pine: Color = _biome.get("accent_dark", Color(0.28, 0.42, 0.58))
	var x: float = _parallax_x(0.6, spacing)
	while x < size.x + spacing:
		draw_rect(Rect2(x + 6, horizon - 16, 4, 16), trunk)
		draw_rect(Rect2(x, horizon - 24, 16, 10), pine)
		draw_rect(Rect2(x + 3, horizon - 32, 10, 8), pine.lightened(0.08))
		x += spacing


func _draw_scrolling_ruins(horizon: float) -> void:
	var stone: Color = _biome.get("accent", Color(0.62, 0.58, 0.52))
	var shadow: Color = _biome.get("accent_dark", Color(0.42, 0.38, 0.34))
	var spacing := 72.0
	var x: float = _parallax_x(0.48, spacing)
	while x < size.x + 80:
		draw_rect(Rect2(x, horizon - 28, 14, 28), stone)
		draw_rect(Rect2(x + 4, horizon - 36, 8, 8), shadow)
		draw_rect(Rect2(x + 28, horizon - 20, 10, 20), stone.darkened(0.08))
		x += spacing


func _draw_scrolling_industrial(horizon: float) -> void:
	var pipe: Color = _biome.get("accent_dark", Color(0.48, 0.28, 0.12))
	var glow: Color = _biome.get("accent", Color(0.78, 0.48, 0.18))
	var spacing := 86.0
	var x: float = _parallax_x(0.52, spacing)
	while x < size.x + 90:
		draw_rect(Rect2(x, horizon - 34, 12, 34), pipe)
		draw_rect(Rect2(x - 4, horizon - 38, 20, 6), pipe.darkened(0.12))
		draw_rect(Rect2(x + 2, horizon - 42, 6, 8), glow)
		x += spacing


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

		var ratio := clampf(actor.enemy.hp / maxf(actor.enemy.max_hp, 1.0), 0.0, 1.0)
		var disp_w := EnemySpriteScript.display_size_for(actor.enemy_type, SPRITE_SCALE).x
		var bar_w := (disp_w + 14.0) if actor.enemy.is_boss else maxf(SPRITE_W + 8.0, disp_w + 6.0)
		var pos := EnemySpriteScript.sprite_position_for(
			actor.enemy_type,
			actor.x,
			ground_y,
			SPRITE_SCALE,
			float(i % 2) * 2.0
		)
		var bar_h := 5.0 if actor.enemy.is_boss else 4.0
		var x := pos.x + (disp_w - bar_w) * 0.5
		var y := pos.y - 7.0
		var fill := HP_BOSS if actor.enemy.is_boss else HP_ENEMY
		_draw_hp_bar(canvas, x, y, bar_w, ratio, fill, bar_h)
		if actor.enemy.is_boss:
			var font := ThemeDB.fallback_font
			canvas.draw_string(
				font,
				Vector2(x, y - UIScaleScript.px(9.0)),
				"BOSS",
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				UIScaleScript.font(9),
				HP_BOSS
			)


func _draw_hero_hp(canvas: CanvasItem, ground_y: float) -> void:
	if not is_instance_valid(_hero_sprite) or not _hero_sprite.visible:
		return
	var hero := GameState.hero
	var ratio := clampf(hero.hp / maxf(hero.max_hp, 1.0), 0.0, 1.0)
	var bar_w := SPRITE_W + 8.0
	var x := _hero_x
	var y := ground_y - SPRITE_W - 10.0
	_draw_hp_bar(canvas, x, y, bar_w, ratio, HP_ALLY, UIScaleScript.px(4.0))


func _draw_hero_equip_glow(canvas: CanvasItem, ground_y: float) -> void:
	if not is_instance_valid(_hero_sprite) or not _hero_sprite.visible:
		return
	var rank := _equip_glow_rank()
	if rank < 1:
		return
	var col := _equip_glow_color()
	var pulse := 0.62 + 0.38 * sin(_equip_glow_pulse * 3.1)
	var alpha := (0.07 + rank * 0.035) * pulse
	var cx := _hero_x + SPRITE_W * 0.5
	var cy := ground_y - SPRITE_W * 0.52
	var rad := SPRITE_W * (0.5 + rank * 0.05)
	canvas.draw_circle(Vector2(cx, cy), rad, Color(col.r, col.g, col.b, alpha))
	canvas.draw_circle(Vector2(cx, cy), rad * 0.68, Color(col.r, col.g, col.b, alpha * 0.45))


func _draw_hero_equip_buffs(canvas: CanvasItem, ground_y: float) -> void:
	if not is_instance_valid(_hero_sprite) or not _hero_sprite.visible:
		return
	var stats := GameState.hero.equipment_stats()
	var atk := int(round(float(stats.get("attack", 0.0))))
	var armor := int(round(float(stats.get("armor", 0.0))))
	if atk <= 0 and armor <= 0:
		return

	var bar_y := ground_y - SPRITE_W - 10.0
	var badge_h := UIScaleScript.px(11.0)
	var gap := UIScaleScript.px(3.0)
	var font: Font = UiFont.get_font()
	var fs := UIScaleScript.font(7)
	var entries: Array[Dictionary] = []
	if atk > 0:
		entries.append({"text": str(atk), "col": Color(1.0, 0.78, 0.38), "kind": "atk"})
	if armor > 0:
		entries.append({"text": str(armor), "col": Color(0.52, 0.84, 1.0), "kind": "armor"})

	var widths: Array[float] = []
	var total_w := 0.0
	for entry in entries:
		var tw: float = font.get_string_size(str(entry["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + UIScaleScript.px(14.0)
		widths.append(tw)
		total_w += tw
	total_w += gap * maxf(0.0, float(entries.size() - 1))

	var x := _hero_x + (SPRITE_W + 8.0) * 0.5 - total_w * 0.5
	var y := bar_y - badge_h - UIScaleScript.px(3.0)
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var w := widths[i]
		var rect := Rect2(x, y, w, badge_h)
		var entry_col: Color = entry["col"] as Color
		canvas.draw_rect(rect, Color(0.08, 0.06, 0.1, 0.88), true)
		canvas.draw_rect(rect, entry_col.darkened(0.25), false, 1.0)
		var icon_c := Vector2(rect.position.x + UIScaleScript.px(6.0), rect.position.y + badge_h * 0.52)
		var icon_s := badge_h * 0.22
		if str(entry["kind"]) == "armor":
			_draw_mini_shield(canvas, icon_c, icon_s, entry_col)
		else:
			NavIconsScript.draw(canvas, icon_c, 0, entry_col, icon_s)
		var tx: float = rect.position.x + UIScaleScript.px(12.0)
		var ty: float = rect.position.y + badge_h - UIScaleScript.px(2.0)
		canvas.draw_string(font, Vector2(tx, ty), str(entry["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, entry_col.lightened(0.12))
		x += w + gap


func _draw_mini_shield(canvas: CanvasItem, center: Vector2, scale: float, col: Color) -> void:
	var s := scale
	var w := maxf(1.0, s * 0.12)
	var top := center + Vector2(0.0, -s * 0.34)
	var left := center + Vector2(-s * 0.28, s * 0.1)
	var right := center + Vector2(s * 0.28, s * 0.1)
	var bottom := center + Vector2(0.0, s * 0.36)
	canvas.draw_line(top, left, col, w)
	canvas.draw_line(top, right, col, w)
	canvas.draw_line(left, bottom, col, w)
	canvas.draw_line(right, bottom, col, w)
	canvas.draw_line(left, right, col, w * 0.85)


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
		hero.xp_to_next
	)


func _draw_stage_banner() -> void:
	if _banner_alpha <= 0.01:
		return
	CombatOverlayDrawScript.draw_banner_card(
		self,
		size,
		_banner_alpha,
		_banner_enter,
		_banner_title,
		_banner_subtitle,
		_banner_biome,
		_biome
	)


func _draw_boss_intro() -> void:
	if _boss_intro_alpha <= 0.01:
		return
	var shake_x := sin(_boss_shake * 48.0) * _boss_shake * 5.0
	CombatOverlayDrawScript.draw_boss_card(
		self,
		size,
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
