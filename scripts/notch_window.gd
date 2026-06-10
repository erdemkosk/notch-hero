extends Node

const UIScaleScript = preload("res://scripts/ui/ui_scale.gd")
const InventorySlotMetricsScript = preload("res://scripts/ui/inventory_slot_metrics.gd")

enum PanelState { HIDDEN, OPENING, OPEN, CLOSING }

const PANEL_HEIGHT := UIScaleScript.PANEL_HEIGHT
const PANEL_SCALE := UIScaleScript.PANEL_WIDTH_SCALE
const WING_EXTENSION := 70.0
const HIDE_DELAY := 0.14
const MOUSE_POLL_SEC := 0.033
const OPEN_DURATION := 0.34
const CLOSE_DURATION := 0.26
const SLIDE_PX := 24.0
const SCALE_MIN := 0.94

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
var _anim_progress := 0.0
var _anim_target := 0.0
var _top_glow: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game_window = get_window()
	_window_id = _game_window.get_window_id()
	_geometry = NotchGeometry.probe()
	_panel_width = InventorySlotMetricsScript.design_panel_width() * PANEL_SCALE
	_setup_timers()
	_setup_window_flags()
	_setup_top_glow()
	call_deferred("_startup_sequence")


func _process(delta: float) -> void:
	if not _startup_done:
		return
	if is_equal_approx(_anim_progress, _anim_target):
		return

	var duration := OPEN_DURATION if _anim_target > _anim_progress else CLOSE_DURATION
	var step := delta / maxf(duration, 0.001)
	if _anim_target > _anim_progress:
		_anim_progress = minf(_anim_progress + step, _anim_target)
	else:
		_anim_progress = maxf(_anim_progress - step, _anim_target)

	_apply_panel_visual(_anim_progress)

	if is_equal_approx(_anim_progress, 1.0) and _state == PanelState.OPENING:
		_state = PanelState.OPEN
	elif is_equal_approx(_anim_progress, 0.0) and _state == PanelState.CLOSING:
		_finish_hide()


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
		push_error("NotchBridge required. Run ./native/build_all.sh")
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
	_state = PanelState.HIDDEN
	_anim_progress = 0.0
	_anim_target = 0.0
	_reset_panel_visual()


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
		_request_open()
	elif _is_panel_active() and _hide_timer.is_stopped():
		_hide_timer.start()


func _panel_top_y() -> float:
	return _geometry.height


func _notch_hover_max_y() -> float:
	return _geometry.height + 8.0


func _panel_hover_max_y() -> float:
	return _panel_top_y() + PANEL_HEIGHT + 8.0


func _is_panel_active() -> bool:
	return _state != PanelState.HIDDEN


func _is_in_hover_zone(local_mouse: Vector2) -> bool:
	var half_band: float = _panel_width * 0.5
	if absf(local_mouse.x - _geometry.center_x) > half_band:
		return false

	if local_mouse.y <= _notch_hover_max_y():
		return true

	if _is_panel_active() and local_mouse.y <= _panel_hover_max_y():
		return true

	return false


func _on_hide_timer_timeout() -> void:
	_request_close()


func _request_open() -> void:
	if _state == PanelState.OPEN and is_equal_approx(_anim_progress, 1.0):
		return

	if _state == PanelState.HIDDEN:
		_place_panel(true)
		_game_window.mouse_passthrough = false
		visual_root.visible = true
		_anim_progress = 0.0
		_apply_panel_visual(0.0)

	_state = PanelState.OPENING
	_anim_target = 1.0


func _request_close() -> void:
	if _state == PanelState.HIDDEN or _state == PanelState.CLOSING:
		return

	_state = PanelState.CLOSING
	_anim_target = 0.0
	_game_window.mouse_passthrough = true


func _finish_hide() -> void:
	_state = PanelState.HIDDEN
	NotchBridgeService.hide_panel(_window_id)
	visual_root.visible = false
	_reset_panel_visual()


func _place_panel(visible: bool) -> void:
	var frame: Dictionary = NotchBridgeService.place_panel_at_notch(
		_window_id, WING_EXTENSION, PANEL_HEIGHT, _panel_width, true
	)
	if frame.is_empty() or not bool(frame.get("ok", false)):
		return

	_panel_width = float(frame.get("width", _panel_width))
	_sync_godot_window_size()
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
	panel.pivot_offset = Vector2(vp_size.x * 0.5, 0.0)
	notch_panel.fit_to(vp_size)
	if _is_panel_active():
		_apply_panel_visual(_anim_progress)


func _stretch_to_viewport(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _setup_top_glow() -> void:
	_top_glow = Control.new()
	_top_glow.name = "TopGlow"
	_top_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_top_glow.offset_left = 0.0
	_top_glow.offset_top = 0.0
	_top_glow.offset_right = 0.0
	_top_glow.offset_bottom = 0.0
	_top_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_glow.z_index = 80
	visual_root.add_child(_top_glow)
	_top_glow.draw.connect(_draw_top_glow)


func _draw_top_glow() -> void:
	if _anim_progress <= 0.01 or not is_instance_valid(_top_glow):
		return

	var opening := _anim_target > _anim_progress or _state == PanelState.OPENING
	var eased := _ease_out_back(_anim_progress) if opening else (1.0 - _ease_in_cubic(1.0 - _anim_progress))
	var width := _top_glow.size.x
	if width < 1.0:
		return

	var glow_h := UIScaleScript.px(30.0)
	var peak := eased * 0.62
	var bands := 7
	for i in bands:
		var frac := float(i) / float(bands)
		var band_a := peak * (1.0 - frac) * 0.38
		_top_glow.draw_rect(
			Rect2(0.0, float(i) * glow_h / float(bands), width, glow_h / float(bands)),
			Color(0.95, 0.78, 0.42, band_a),
			true
		)

	_top_glow.draw_rect(Rect2(0.0, 0.0, width, UIScaleScript.px(2.0)), Color(1.0, 0.92, 0.65, peak * 0.9), true)
	var center_w := width * 0.42
	_top_glow.draw_rect(
		Rect2((width - center_w) * 0.5, 0.0, center_w, UIScaleScript.px(3.0)),
		Color(1.0, 0.96, 0.82, peak * 0.55),
		true
	)


func _apply_panel_visual(open_amount: float) -> void:
	var opening := _anim_target > _anim_progress
	var eased := _ease_out_back(open_amount) if opening else (1.0 - _ease_in_cubic(1.0 - open_amount))
	var slide := UIScaleScript.px(SLIDE_PX) * (1.0 - eased)
	var scale := lerpf(SCALE_MIN, 1.0, eased)
	var alpha := lerpf(0.0, 1.0, eased)

	panel.offset_top = -slide
	panel.scale = Vector2(scale, scale)
	panel.modulate = Color(1.0, 1.0, 1.0, alpha)
	if is_instance_valid(_top_glow):
		_top_glow.queue_redraw()


func _reset_panel_visual() -> void:
	panel.offset_top = 0.0
	panel.scale = Vector2.ONE
	panel.modulate = Color.WHITE


func _ease_out_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var u := clampf(t, 0.0, 1.0)
	return 1.0 + c3 * pow(u - 1.0, 3.0) + c1 * pow(u - 1.0, 2.0)


func _ease_in_cubic(t: float) -> float:
	var u := clampf(t, 0.0, 1.0)
	return u * u * u
