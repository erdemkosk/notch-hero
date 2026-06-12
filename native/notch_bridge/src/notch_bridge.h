#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/vector2.hpp>

namespace godot {

class NotchBridge : public Object {
	GDCLASS(NotchBridge, Object);

protected:
	static void _bind_methods();

public:
	NotchBridge();
	~NotchBridge();

	bool is_available() const;
	bool apply_native_overlay(int64_t window_id);
	Dictionary place_panel_at_notch(int64_t window_id, double wing_extension, double height, double width_override, bool capture_excluded);
	bool hide_panel(int64_t window_id);
	Dictionary get_notch_geometry() const;
	Dictionary get_notch_geometry_for_window(int64_t window_id) const;
	Vector2 get_notch_size() const;
	Vector2 get_mouse_local_on_notch_screen() const;

	bool set_dock_icon_visible(bool visible);
	bool create_tray_menu();
};

} // namespace godot
