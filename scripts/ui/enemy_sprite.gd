extends AnimatedSprite2D

const SpriteSheetFramesScript = preload("res://scripts/ui/sprite_sheet_frames.gd")
const FRAME := Vector2i(32, 32)

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
}

var enemy_type := "gladiator"
var _base_anim := "walk"


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
	sprite_frames = SpriteSheetFramesScript.build(def["sheet"], FRAME, def["rows"])


func play_action(action: String) -> void:
	if sprite_frames == null or not sprite_frames.has_animation(action):
		return
	play(action)


func _on_animation_finished() -> void:
	if animation == "death":
		return
	if sprite_frames.get_animation_loop(animation):
		return
	play(_base_anim)
