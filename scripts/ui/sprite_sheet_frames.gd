class_name SpriteSheetFrames
extends RefCounted

## rows: anim_name -> { row, frames, speed, loop }
static func build(sheet_path: String, frame_size: Vector2i, rows: Dictionary) -> SpriteFrames:
	var sheet: Texture2D = load(sheet_path)
	var sprite_frames := SpriteFrames.new()
	for anim_name in rows.keys():
		var spec: Dictionary = rows[anim_name]
		sprite_frames.add_animation(anim_name)
		sprite_frames.set_animation_speed(anim_name, spec["speed"])
		sprite_frames.set_animation_loop(anim_name, spec["loop"])
		for col in range(spec["frames"]):
			sprite_frames.add_frame(
				anim_name,
				_atlas_frame(sheet, frame_size, spec["row"], col),
				1.0
			)
	return sprite_frames


static func _atlas_frame(sheet: Texture2D, frame_size: Vector2i, row: int, col: int) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = sheet
	tex.region = Rect2i(col * frame_size.x, row * frame_size.y, frame_size.x, frame_size.y)
	return tex
