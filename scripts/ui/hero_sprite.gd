extends AnimatedSprite2D

const SpriteSheetFramesScript = preload("res://scripts/ui/sprite_sheet_frames.gd")
const FRAME := Vector2i(32, 32)

const ROWS := {
	"idle": {"row": 0, "frames": 12, "speed": 10.0, "loop": true},
	"walk": {"row": 1, "frames": 8, "speed": 15.0, "loop": true},
	"attack_down": {"row": 2, "frames": 10, "speed": 14.0, "loop": false},
	"attack_slash": {"row": 3, "frames": 10, "speed": 14.0, "loop": false},
	"attack_thrust": {"row": 4, "frames": 10, "speed": 14.0, "loop": false},
	"hurt": {"row": 6, "frames": 4, "speed": 12.0, "loop": false},
	"death": {"row": 7, "frames": 7, "speed": 10.0, "loop": false},
}

var _base_anim := "walk"


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = false
	flip_h = true
	sprite_frames = SpriteSheetFramesScript.build(
		"res://assets/characters/hero_sheet.png",
		FRAME,
		ROWS
	)
	animation_finished.connect(_on_animation_finished)
	play("walk")


func set_base_animation(anim: String) -> void:
	if sprite_frames != null and sprite_frames.has_animation(anim):
		_base_anim = anim
		if sprite_frames.get_animation_loop(anim) or animation != anim:
			play(anim)


func play_action(action: String) -> void:
	if sprite_frames == null or not sprite_frames.has_animation(action):
		return
	play(action)


func _on_animation_finished() -> void:
	if sprite_frames.get_animation_loop(animation):
		return
	play(_base_anim)
