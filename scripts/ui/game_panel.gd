extends Control

@onready var mini_hud: Control = $MiniHud
@onready var expanded_hud: Control = $ExpandedHud


func set_mode(mode: String) -> void:
	mini_hud.visible = mode == "mini"
	expanded_hud.visible = mode == "expanded"
	visible = mode != "hidden"


func fit_to(panel_size: Vector2) -> void:
	custom_minimum_size = panel_size
	size = panel_size
	mini_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	expanded_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
