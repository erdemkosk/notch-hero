extends AnimatedSprite2D

const SpriteSheetFramesScript = preload("res://scripts/ui/sprite_sheet_frames.gd")
const FRAME := Vector2i(64, 64)

const ROWS := {
	"idle": {"row": 0, "frames": 8, "speed": 12.0, "loop": true},
	"open": {"row": 1, "frames": 8, "speed": 14.0, "loop": false},
	"close": {"row": 2, "frames": 6, "speed": 14.0, "loop": false},
}

signal open_finished
signal close_finished


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = false
	sprite_frames = SpriteSheetFramesScript.build(
		"res://assets/effects/portal/purple_portal_sheet.png",
		FRAME,
		ROWS
	)
	animation_finished.connect(_on_animation_finished)
	visible = false


func play_open() -> void:
	visible = true
	play("open")


func play_close() -> void:
	if not visible:
		return
	play("close")


func hide_portal() -> void:
	visible = false
	stop()


func _on_animation_finished() -> void:
	if animation == "open":
		play("idle")
		open_finished.emit()
	elif animation == "close":
		hide_portal()
		close_finished.emit()
