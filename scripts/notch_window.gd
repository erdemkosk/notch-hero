extends Node

enum PanelState { HIDDEN, OPEN }

const PANEL_HEIGHT := 160.0
const PANEL_SCALE := 2.0
const WING_EXTENSION := 40.0
const HIDE_DELAY := 0.12
const MOUSE_POLL_SEC := 0.033

@onready var visual_root: Control = $CanvasLayer/VisualRoot
@onready var panel: PanelContainer = $CanvasLayer/VisualRoot/Panel
@onready var notch_panel: Control = $CanvasLayer/VisualRoot/Panel/NotchPanelUI

var _geometry: NotchGeometry
var _state := PanelState.HIDDEN
var _panel_width := 265.0
var _game_window: Window
var _window_id: int
var _hide_timer: Timer
var _mouse_timer: Timer
var _startup_done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game_window = get_window()
	_window_id = _game_window.get_window_id()
	_geometry = NotchGeometry.probe()
	_panel_width = (_geometry.width + (WING_EXTENSION * 2.0)) * PANEL_SCALE
	_setup_timers()
	_setup_window_flags()
	call_deferred("_startup_sequence")


func _setup_timers() -> void:
	_hide_timer = Timer.new()
	_hide_timer.one_shot = true
	_hide_timer.wait_time = HIDE_DELAY
	_hide_timer.timeout.connect(_on_hide_timer_timeout)
	add_child(_hide_timer)

	_mouse_timer = Timer.new()
	_mouse_timer.wait_time = MOUSE_POLL_SEC
	_mouse_timer.timeout.connect(_on_mouse_poll)
	add_child(_mouse_timer)


func _startup_sequence() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	if not NotchBridgeService.is_native_available():
		push_error("NotchBridge gerekli. ./native/build_all.sh calistirin.")
		return

	NotchBridgeService.apply_to_window(_window_id)
	_anchor_panel_hidden()

	print("NotchHero panel=%.0fx%.0f geometri=%s" % [_panel_width, PANEL_HEIGHT, _geometry.source])

	_mouse_timer.start()
	_startup_done = true


func _anchor_panel_hidden() -> void:
	_place_panel(false)
	NotchBridgeService.hide_panel(_window_id)
	visual_root.visible = false
	_game_window.mouse_passthrough = true


func _setup_window_flags() -> void:
	_game_window.borderless = true
	_game_window.unresizable = true
	_game_window.mouse_passthrough = true
	get_viewport().transparent_bg = false

	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true, _window_id)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, _window_id)


func _on_mouse_poll() -> void:
	if not _startup_done:
		return

	var local_mouse: Vector2 = NotchBridgeService.get_mouse_local_on_notch_screen()

	if _is_in_hover_zone(local_mouse):
		_hide_timer.stop()
		if _state != PanelState.OPEN:
			_set_state(PanelState.OPEN)
	elif _state == PanelState.OPEN and _hide_timer.is_stopped():
		_hide_timer.start()


func _panel_top_y() -> float:
	return _geometry.height


func _notch_hover_max_y() -> float:
	return _geometry.height + 8.0


func _panel_hover_max_y() -> float:
	return _panel_top_y() + PANEL_HEIGHT + 8.0


func _is_in_hover_zone(local_mouse: Vector2) -> bool:
	var half_band: float = _panel_width * 0.5
	if absf(local_mouse.x - _geometry.center_x) > half_band:
		return false

	if local_mouse.y <= _notch_hover_max_y():
		return true

	if _state == PanelState.OPEN and local_mouse.y <= _panel_hover_max_y():
		return true

	return false


func _on_hide_timer_timeout() -> void:
	_set_state(PanelState.HIDDEN)


func _set_state(next_state: PanelState) -> void:
	if _state == next_state:
		return
	_state = next_state

	match next_state:
		PanelState.HIDDEN:
			NotchBridgeService.hide_panel(_window_id)
			visual_root.visible = false
			_game_window.mouse_passthrough = true
		PanelState.OPEN:
			_place_panel(true)
			_game_window.mouse_passthrough = false
			visual_root.visible = true


func _place_panel(visible: bool) -> void:
	var frame: Dictionary = NotchBridgeService.place_panel_at_notch(
		_window_id, WING_EXTENSION, PANEL_HEIGHT, _panel_width, true
	)
	if frame.is_empty() or not bool(frame.get("ok", false)):
		return

	_panel_width = float(frame.get("width", _panel_width))
	_sync_godot_window_size()
	# window_set_size konumu kaydirabilir — native cerceveyi hemen geri uygula.
	frame = NotchBridgeService.place_panel_at_notch(
		_window_id, WING_EXTENSION, PANEL_HEIGHT, _panel_width, true
	)
	if not frame.is_empty() and bool(frame.get("ok", false)):
		_panel_width = float(frame.get("width", _panel_width))

	_fit_visual(Vector2(_panel_width, PANEL_HEIGHT))
	call_deferred("_fit_visual", Vector2(_panel_width, PANEL_HEIGHT))

	if not visible:
		return


func _sync_godot_window_size() -> void:
	var target := Vector2i(int(_panel_width), int(PANEL_HEIGHT))
	DisplayServer.window_set_size(target, _window_id)


func _fit_visual(size: Vector2) -> void:
	var vp_size := get_viewport().get_visible_rect().size
	if vp_size.x < 1.0 or vp_size.y < 1.0:
		vp_size = size

	_stretch_to_viewport(visual_root)
	_stretch_to_viewport(panel)
	notch_panel.fit_to(vp_size)


func _stretch_to_viewport(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL
