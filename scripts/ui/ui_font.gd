extends RefCounted

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const FALLBACK_NAMES: Array[String] = [
	"Press Start 2P",
	"Courier New",
	"Menlo",
	"Monaco",
]

static var _game_font: Font
static var _font_ready := false


static func setup() -> void:
	if _font_ready:
		return

	if ResourceLoader.exists(FONT_PATH):
		var file := load(FONT_PATH) as FontFile
		if file != null:
			_game_font = file
			ThemeDB.fallback_font = _game_font
			_font_ready = true
			return

	var system := SystemFont.new()
	system.font_names = PackedStringArray(FALLBACK_NAMES)
	system.font_weight = 400
	system.font_stretch = 100
	_game_font = system
	ThemeDB.fallback_font = _game_font
	_font_ready = true


static func get_font() -> Font:
	if not _font_ready:
		setup()
	return _game_font if _game_font != null else ThemeDB.fallback_font
