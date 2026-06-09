extends RefCounted
class_name NotchBridgeService

static var _bridge: Object


static func get_bridge() -> Object:
	if _bridge != null:
		return _bridge
	if ClassDB.class_exists("NotchBridge"):
		_bridge = ClassDB.instantiate("NotchBridge")
	return _bridge


static func is_native_available() -> bool:
	var bridge := get_bridge()
	return bridge != null and bridge.is_available()


static func _for_window(window_id: int, method: Callable) -> bool:
	var bridge := get_bridge()
	if bridge == null:
		return false
	for candidate in [window_id, 0]:
		if method.call(candidate):
			return true
	return false


static func apply_to_window(window_id: int) -> bool:
	return _for_window(
		window_id,
		func(candidate: int) -> bool:
			return get_bridge().apply_native_overlay(candidate)
	)


static func place_panel_at_notch(
	window_id: int,
	wing_extension: float,
	height: float,
	width_override: float = 0.0,
	capture_excluded: bool = true
) -> Dictionary:
	var bridge := get_bridge()
	if bridge == null or not bridge.is_available():
		return {}

	for candidate in [window_id, 0]:
		var result: Dictionary = bridge.place_panel_at_notch(
			candidate, wing_extension, height, width_override, capture_excluded
		)
		if not result.is_empty() and bool(result.get("ok", false)):
			return result

	return {}


static func hide_panel(window_id: int) -> bool:
	return _for_window(
		window_id,
		func(candidate: int) -> bool:
			return get_bridge().hide_panel(candidate)
	)


static func get_geometry_for_window(window_id: int) -> Dictionary:
	var bridge := get_bridge()
	if bridge == null or not bridge.is_available():
		return {}
	return bridge.get_notch_geometry_for_window(window_id)


static func get_notch_size() -> Vector2:
	var bridge := get_bridge()
	if bridge == null or not bridge.is_available():
		return Vector2.ZERO
	return bridge.get_notch_size()


static func get_mouse_local_on_notch_screen() -> Vector2:
	var bridge := get_bridge()
	if bridge == null or not bridge.is_available():
		return Vector2.ZERO
	return bridge.get_mouse_local_on_notch_screen()
