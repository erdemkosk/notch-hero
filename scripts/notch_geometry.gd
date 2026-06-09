class_name NotchGeometry
extends RefCounted

var has_notch: bool = false
var x: float = 0.0
var y: float = 0.0
var width: float = 184.0
var height: float = 32.0
var center_x: float = 0.0
var global_center_x: float = 0.0
var screen_width: float = 0.0
var screen_height: float = 0.0
var screen_origin_x: float = 0.0
var scale: float = 1.0
var source: String = "unknown"


static func probe() -> NotchGeometry:
	var result: NotchGeometry = NotchGeometry.new()

	if OS.get_name() == "macOS":
		var probe_path := ProjectSettings.globalize_path("res://bin/notch_probe")
		if FileAccess.file_exists(probe_path):
			var output: Array = []
			var exit_code := OS.execute(probe_path, [], output, true, false)
			if exit_code == 0 and not output.is_empty():
				var parsed: Variant = JSON.parse_string(output[0].strip_edges())
				if typeof(parsed) == TYPE_DICTIONARY:
					result._load_from_dict(parsed)
					result.source = "macos_probe"
					return result
			push_warning("notch_probe basarisiz (exit=%d)." % exit_code)
		else:
			push_warning("notch_probe bulunamadi. ./native/build_probe.sh calistirin.")

	result._fallback_from_displayserver()
	result.source = "displayserver_fallback"
	return result


func panel_rect(panel_height: float, wing_extension: float, width_override: float = 0.0) -> Rect2:
	var panel_w := width_override if width_override > 0.0 else width + (wing_extension * 2.0)
	var panel_x := center_x - (panel_w * 0.5)
	return Rect2(panel_x, 0.0, panel_w, panel_height)


func mouse_local_on_screen(global_mouse: Vector2, screen_index: int) -> Vector2:
	var screen_pos := Vector2(DisplayServer.screen_get_position(screen_index))
	var local := global_mouse - screen_pos

	if scale <= 1.0:
		return local

	# Retina: Godot piksel, probe point olabilir — centige en yakin olani sec.
	var as_points := local / scale
	if absf(as_points.x - center_x) < absf(local.x - center_x):
		return as_points

	return local


func find_screen_index() -> int:
	for i in DisplayServer.get_screen_count():
		var size := DisplayServer.screen_get_size(i)
		var pos := DisplayServer.screen_get_position(i)
		if (
			absf(float(size.x) - screen_width) < 2.0
			and absf(float(pos.x) - screen_origin_x) < 2.0
		):
			return i
	return DisplayServer.SCREEN_OF_MAIN_WINDOW


func horizontal_half_band(wing_extension: float) -> float:
	return (width * 0.5) + wing_extension


func _fallback_from_displayserver() -> void:
	var screen_size := DisplayServer.screen_get_size(DisplayServer.SCREEN_OF_MAIN_WINDOW)
	screen_width = float(screen_size.x)
	screen_height = float(screen_size.y)
	screen_origin_x = 0.0
	center_x = screen_width * 0.5
	global_center_x = center_x
	x = center_x - 92.0
	y = 0.0
	width = 184.0
	height = 32.0
	scale = float(DisplayServer.screen_get_scale(DisplayServer.SCREEN_OF_MAIN_WINDOW))
	has_notch = false


func _load_from_dict(data: Dictionary) -> void:
	has_notch = bool(data.get("has_notch", false))
	x = float(data.get("x", 0.0))
	y = float(data.get("y", 0.0))
	width = float(data.get("width", 184.0))
	height = float(data.get("height", 32.0))
	center_x = float(data.get("center_x", x + width * 0.5))
	screen_width = float(data.get("screen_width", 0.0))
	screen_height = float(data.get("screen_height", 0.0))
	screen_origin_x = float(data.get("screen_origin_x", 0.0))
	scale = float(data.get("scale", 1.0))
	global_center_x = float(
		data.get("global_center_x", screen_origin_x + center_x)
	)
