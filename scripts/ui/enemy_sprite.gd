extends AnimatedSprite2D

signal action_finished(anim_name: String)

const SpriteSheetFramesScript = preload("res://scripts/ui/sprite_sheet_frames.gd")
const StageDataScript = preload("res://scripts/game/stage_data.gd")
const FRAME := Vector2i(32, 32)
const WALK_SPEED_MUL := 1.25
const DEFAULT_RANGED_STANDOFF := 24.0

const ENEMY_POOL: PackedStringArray = [
	"adventurer",
	"gladiator",
	"incubus",
	"swampling",
	"bandit_necromancer",
	"cacodaemon",
	"kobold_priest",
	"goblin_mech",
	"ratfolk_mage",
	"akaname",
	"brain_mole",
	"leshy_ranger",
	"twig_blight",
	"intellect_devourer",
	"ghoul",
	"space_soldier",
	"cobra",
	"cyclops",
]

const TYPE_DEFS := {
	"gladiator": {
		"sheet": "res://assets/characters/enemy_gladiator_sheet.png",
		"rows": {
			"walk": {"row": 1, "frames": 8, "speed": 14.0, "loop": true},
			"attack": {"row": 2, "frames": 7, "speed": 16.0, "loop": false},
			"hurt": {"row": 3, "frames": 3, "speed": 14.0, "loop": false},
			"death": {"row": 4, "frames": 7, "speed": 12.0, "loop": false},
		},
	},
	"adventurer": {
		"sheet": "res://assets/characters/enemy_adventurer_sheet.png",
		"rows": {
			"walk": {"row": 1, "frames": 7, "speed": 15.0, "loop": true},
			"attack": {"row": 2, "frames": 8, "speed": 16.0, "loop": false},
			"hurt": {"row": 3, "frames": 4, "speed": 14.0, "loop": false},
			"death": {"row": 4, "frames": 7, "speed": 12.0, "loop": false},
		},
	},
	"incubus": {
		"sheet": "res://assets/characters/enemy_incubus_sheet.png",
		"frame_size": Vector2i(96, 64),
		"visual_height": 32,
		"contact_anchor_x": 31,
		"rows": {
			"walk": {"row": 1, "frames": 8, "speed": 14.0, "loop": true},
			"attack": {"row": 2, "frames": 8, "speed": 16.0, "loop": false},
			"hurt": {"row": 3, "frames": 5, "speed": 14.0, "loop": false},
			"death": {"row": 4, "frames": 7, "speed": 12.0, "loop": false},
		},
	},
	"swampling": {
		"sheet": "res://assets/characters/enemy_swampling_sheet.png",
		"rows": {
			"walk": {"row": 1, "frames": 8, "speed": 14.0, "loop": true},
			"attack": {"row": 2, "frames": 8, "speed": 16.0, "loop": false},
			"hurt": {"row": 3, "frames": 5, "speed": 14.0, "loop": false},
			"death": {"row": 4, "frames": 5, "speed": 12.0, "loop": false},
		},
	},
	"bandit_necromancer": {
		"sheet": "res://assets/characters/enemy_bandit_necromancer_sheet.png",
		"combat_role": "ranged",
		"ranged_standoff": 24.0,
		"rows": {
			"walk": {"row": 1, "frames": 8, "speed": 14.0, "loop": true},
			"attack": {"row": 3, "frames": 8, "speed": 16.0, "loop": false},
			"hurt": {"row": 4, "frames": 4, "speed": 14.0, "loop": false},
			"death": {"row": 5, "frames": 8, "speed": 12.0, "loop": false},
		},
	},
	"cacodaemon": {
		"sheet": "res://assets/characters/enemy_cacodaemon_sheet.png",
		"frame_size": Vector2i(64, 64),
		"rows": {
			"walk": {"row": 0, "frames": 6, "speed": 12.0, "loop": true},
			"attack": {"row": 1, "frames": 6, "speed": 14.0, "loop": false},
			"hurt": {"row": 2, "frames": 4, "speed": 14.0, "loop": false},
			"death": {"row": 3, "frames": 8, "speed": 12.0, "loop": false},
		},
	},
	"kobold_priest": {
		"sheet": "res://assets/characters/enemy_kobold_priest_sheet.png",
		"combat_role": "ranged",
		"ranged_standoff": 22.0,
		"rows": {
			"walk": {"row": 1, "frames": 8, "speed": 14.0, "loop": true},
			"attack": {"row": 2, "frames": 8, "speed": 16.0, "loop": false},
			"hurt": {"row": 3, "frames": 4, "speed": 14.0, "loop": false},
			"death": {"row": 4, "frames": 7, "speed": 12.0, "loop": false},
		},
	},
	"goblin_mech": {
		"sheet": "res://assets/characters/enemy_goblin_mech_sheet.png",
		"frame_size": Vector2i(128, 64),
		"rows": {
			"walk": {"row": 1, "frames": 8, "speed": 14.0, "loop": true},
			"attack": {"row": 2, "frames": 8, "speed": 16.0, "loop": false},
			"hurt": {"row": 3, "frames": 4, "speed": 14.0, "loop": false},
			"death": {"row": 4, "frames": 7, "speed": 12.0, "loop": false},
		},
	},
	"ratfolk_mage": {
		"sheet": "res://assets/characters/enemy_ratfolk_mage_sheet.png",
		"combat_role": "ranged",
		"ranged_standoff": 24.0,
		"rows": {
			"walk": {"row": 1, "frames": 8, "speed": 14.0, "loop": true},
			"attack": {"row": 2, "frames": 6, "speed": 16.0, "loop": false},
			"hurt": {"row": 4, "frames": 4, "speed": 14.0, "loop": false},
			"death": {"row": 5, "frames": 5, "speed": 12.0, "loop": false},
		},
	},
	"akaname": {
		"sheet": "res://assets/characters/enemy_akaname_sheet.png",
		"rows": {
			"walk": {"row": 1, "frames": 8, "speed": 14.0, "loop": true},
			"attack": {"row": 2, "frames": 8, "speed": 16.0, "loop": false},
			"hurt": {"row": 0, "frames": 5, "speed": 14.0, "loop": false},
			"death": {"row": 3, "frames": 6, "speed": 12.0, "loop": false},
		},
	},
	"brain_mole": {
		"sheet": "res://assets/characters/enemy_brain_mole_sheet.png",
		"combat_role": "charger",
		"rows": {
			"walk": {"row": 1, "frames": 4, "speed": 14.0, "loop": true},
			"attack": {"row": 3, "frames": 7, "speed": 18.0, "loop": false},
			"hurt": {"row": 2, "frames": 4, "speed": 14.0, "loop": false},
			"death": {"row": 2, "frames": 4, "speed": 12.0, "loop": false},
		},
	},
	"leshy_ranger": {
		"sheet": "res://assets/characters/enemy_leshy_ranger_sheet.png",
		"combat_role": "ranged",
		"ranged_standoff": 28.0,
		"rows": {
			"walk": {"row": 1, "frames": 8, "speed": 14.0, "loop": true},
			"attack": {"row": 2, "frames": 7, "speed": 14.0, "loop": false},
			"hurt": {"row": 4, "frames": 4, "speed": 14.0, "loop": false},
			"death": {"row": 5, "frames": 5, "speed": 12.0, "loop": false},
		},
	},
	"twig_blight": {
		"sheet": "res://assets/characters/enemy_twig_blight_sheet.png",
		"combat_role": "melee",
		"rows": {
			"walk": {"row": 1, "frames": 8, "speed": 14.0, "loop": true},
			"attack": {"row": 2, "frames": 6, "speed": 16.0, "loop": false},
			"hurt": {"row": 3, "frames": 5, "speed": 14.0, "loop": false},
			"death": {"row": 4, "frames": 5, "speed": 12.0, "loop": false},
		},
	},
	"intellect_devourer": {
		"sheet": "res://assets/characters/enemy_intellect_devourer_sheet.png",
		"combat_role": "melee",
		"rows": {
			"walk": {"row": 1, "frames": 8, "speed": 14.0, "loop": true},
			"attack": {"row": 2, "frames": 6, "speed": 16.0, "loop": false},
			"hurt": {"row": 4, "frames": 4, "speed": 14.0, "loop": false},
			"death": {"row": 5, "frames": 4, "speed": 12.0, "loop": false},
		},
	},
	"ghoul": {
		"sheet": "res://assets/characters/enemy_ghoul_sheet.png",
		"combat_role": "melee",
		"rows": {
			"walk": {"row": 1, "frames": 8, "speed": 14.0, "loop": true},
			"attack": {"row": 2, "frames": 6, "speed": 16.0, "loop": false},
			"hurt": {"row": 3, "frames": 4, "speed": 14.0, "loop": false},
			"death": {"row": 4, "frames": 6, "speed": 12.0, "loop": false},
		},
	},
	"space_soldier": {
		"sheet": "res://assets/characters/enemy_space_soldier_sheet.png",
		"combat_role": "ranged",
		"ranged_standoff": 26.0,
		"rows": {
			"walk": {"row": 1, "frames": 8, "speed": 14.0, "loop": true},
			"attack": {"row": 2, "frames": 5, "speed": 14.0, "loop": false},
			"hurt": {"row": 3, "frames": 4, "speed": 14.0, "loop": false},
			"death": {"row": 4, "frames": 8, "speed": 12.0, "loop": false},
		},
	},
	"cobra": {
		"sheet": "res://assets/characters/enemy_cobra_sheet.png",
		"combat_role": "melee",
		"rows": {
			"walk": {"row": 1, "frames": 8, "speed": 13.0, "loop": true},
			"attack": {"row": 2, "frames": 6, "speed": 15.0, "loop": false},
			"hurt": {"row": 3, "frames": 4, "speed": 14.0, "loop": false},
			"death": {"row": 4, "frames": 6, "speed": 12.0, "loop": false},
		},
	},
	"cyclops": {
		"sheet": "res://assets/characters/enemy_cyclops_sheet.png",
		"frame_size": Vector2i(64, 64),
		"scale_mul": 1.08,
		"combat_role": "ranged",
		"ranged_standoff": 32.0,
		"rows": {
			"walk": {"row": 1, "frames": 12, "speed": 12.0, "loop": true},
			"attack": {"row": 3, "frames": 11, "speed": 13.0, "loop": false},
			"hurt": {"row": 4, "frames": 4, "speed": 14.0, "loop": false},
			"death": {"row": 7, "frames": 7, "speed": 11.0, "loop": false},
		},
	},
}

var enemy_type := "gladiator"
var _base_anim := "walk"
var _queue_waiting := false


func set_queue_waiting(enabled: bool) -> void:
	if enabled == _queue_waiting:
		return
	if not enabled:
		_queue_waiting = false
		if sprite_frames != null and sprite_frames.has_animation("walk"):
			play("walk")
		return
	_queue_waiting = true
	if sprite_frames == null or not sprite_frames.has_animation("walk"):
		return
	_base_anim = "walk"
	play("walk")
	frame = 0
	pause()


static func _reference_height(def: Dictionary) -> int:
	if def.has("visual_height"):
		return int(def["visual_height"])
	var frame_size: Vector2i = def.get("frame_size", FRAME)
	return frame_size.y


static func display_scale_for(p_type: String, base_scale: float = 2.0) -> Vector2:
	var def: Dictionary = TYPE_DEFS.get(p_type, TYPE_DEFS["gladiator"])
	var ref_height := _reference_height(def)
	var factor := float(FRAME.y) / float(ref_height)
	var mul := float(def.get("scale_mul", 1.0))
	var s := base_scale * factor * mul
	s *= StageDataScript.enemy_scale_mul(p_type)
	return Vector2(s, s)


static func display_size_for(p_type: String, base_scale: float = 2.0) -> Vector2:
	var def: Dictionary = TYPE_DEFS.get(p_type, TYPE_DEFS["gladiator"])
	var frame_size: Vector2i = def.get("frame_size", FRAME)
	var scale := display_scale_for(p_type, base_scale)
	return Vector2(frame_size.x * scale.x, frame_size.y * scale.y)


static func contact_leading_x_for(p_type: String) -> int:
	var def: Dictionary = TYPE_DEFS.get(p_type, TYPE_DEFS["gladiator"])
	if def.has("contact_anchor_x"):
		return int(def["contact_anchor_x"])
	var frame_size: Vector2i = def.get("frame_size", FRAME)
	return int(round(float(frame_size.x) * 0.78))


static func contact_anchor_x_for(p_type: String) -> int:
	return contact_leading_x_for(p_type)


static func contact_advance_for(p_type: String) -> int:
	return 0


static func combat_role_for(p_type: String) -> String:
	var def: Dictionary = TYPE_DEFS.get(p_type, TYPE_DEFS["gladiator"])
	return str(def.get("combat_role", "melee"))


static func is_ranged(p_type: String) -> bool:
	return combat_role_for(p_type) == "ranged"


static func ranged_standoff_for(p_type: String) -> float:
	var def: Dictionary = TYPE_DEFS.get(p_type, TYPE_DEFS["gladiator"])
	return float(def.get("ranged_standoff", DEFAULT_RANGED_STANDOFF))


static func visual_top_y_for(
	p_type: String,
	ground_y: float,
	base_scale: float = 2.0,
	lane_offset_y: float = 0.0
) -> float:
	var def: Dictionary = TYPE_DEFS.get(p_type, TYPE_DEFS["gladiator"])
	var scale := display_scale_for(p_type, base_scale)
	var ref_h := _reference_height(def)
	return ground_y - float(ref_h) * scale.y + lane_offset_y


static func sprite_position_for(
	p_type: String,
	contact_x: float,
	ground_y: float,
	base_scale: float = 2.0,
	lane_offset_y: float = 0.0
) -> Vector2:
	var scale := display_scale_for(p_type, base_scale)
	var disp := display_size_for(p_type, base_scale)
	var anchor_x := contact_anchor_x_for(p_type)
	return Vector2(
		contact_x - float(anchor_x) * scale.x,
		ground_y - disp.y + lane_offset_y
	)


func setup(p_type: String) -> void:
	enemy_type = p_type if TYPE_DEFS.has(p_type) else "gladiator"


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = false
	flip_h = false
	_apply_sheet()
	animation_finished.connect(_on_animation_finished)
	play("walk")


func _apply_sheet() -> void:
	var def: Dictionary = TYPE_DEFS[enemy_type]
	var frame_size: Vector2i = def.get("frame_size", FRAME)
	sprite_frames = SpriteSheetFramesScript.build(def["sheet"], frame_size, def["rows"])
	if sprite_frames.has_animation("walk"):
		var walk_speed := sprite_frames.get_animation_speed("walk") * WALK_SPEED_MUL
		sprite_frames.set_animation_speed("walk", walk_speed)


func play_action(action: String) -> void:
	if sprite_frames == null or not sprite_frames.has_animation(action):
		return
	_queue_waiting = false
	play(action)


func _on_animation_finished() -> void:
	var finished := animation
	if finished == "death":
		action_finished.emit("death")
		return
	if sprite_frames.get_animation_loop(finished):
		return
	if finished == "attack":
		action_finished.emit(finished)
	if _queue_waiting:
		play("walk")
		frame = 0
		pause()
		return
	play(_base_anim)
