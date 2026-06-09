#include "notch_bridge.h"

#include <godot_cpp/classes/display_server.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/vector2.hpp>

#ifdef __APPLE__
#import <AppKit/AppKit.h>

using godot::DisplayServer;
using godot::Dictionary;

static NSWindow *notch_bridge_get_window(int64_t window_id) {
	DisplayServer *display_server = DisplayServer::get_singleton();
	if (display_server != nullptr) {
		const int64_t candidates[] = { window_id, 0 };
		for (int64_t candidate : candidates) {
			int64_t handle = display_server->window_get_native_handle(DisplayServer::WINDOW_HANDLE, candidate);
			if (handle != 0) {
				return (__bridge NSWindow *)(void *)(uintptr_t)handle;
			}
		}
	}

	NSApplication *app = NSApplication.sharedApplication;
	for (NSWindow *window in app.windows) {
		if (window.isVisible) {
			return window;
		}
	}

	return app.keyWindow ?: app.mainWindow;
}

static NSScreen *notch_bridge_find_notch_screen(void) {
	for (NSScreen *screen in [NSScreen screens]) {
		NSRect left = screen.auxiliaryTopLeftArea;
		NSRect right = screen.auxiliaryTopRightArea;
		if (left.size.width > 0.0 && right.size.width > 0.0 && right.origin.x > NSMaxX(left)) {
			return screen;
		}
	}
	return NSScreen.mainScreen;
}

static NSScreen *notch_bridge_screen_for_window(NSWindow *window) {
	NSScreen *notch_screen = notch_bridge_find_notch_screen();
	if (notch_screen != nil) {
		return notch_screen;
	}
	if (window != nil && window.screen != nil) {
		return window.screen;
	}
	return NSScreen.mainScreen;
}

static bool notch_bridge_read_notch(NSScreen *screen, CGFloat *r_notch_left, CGFloat *r_notch_right, CGFloat *r_top_inset) {
	if (screen == nil) {
		return false;
	}

	NSRect left = screen.auxiliaryTopLeftArea;
	NSRect right = screen.auxiliaryTopRightArea;
	if (left.size.width <= 0.0 || right.size.width <= 0.0 || right.origin.x <= NSMaxX(left)) {
		return false;
	}

	*r_notch_left = NSMaxX(left);
	*r_notch_right = right.origin.x;
	*r_top_inset = MAX(screen.safeAreaInsets.top, 32.0);
	return true;
}

static CGFloat notch_bridge_top_inset(NSScreen *screen) {
	CGFloat notch_left = 0.0;
	CGFloat notch_right = 0.0;
	CGFloat top_inset = 0.0;
	if (notch_bridge_read_notch(screen, &notch_left, &notch_right, &top_inset)) {
		return top_inset;
	}
	if (@available(macOS 12.0, *)) {
		return MAX(screen.safeAreaInsets.top, 24.0);
	}
	return 24.0;
}

static NSRect notch_bridge_panel_frame(NSScreen *screen, CGFloat wing_extension, CGFloat height, CGFloat width_override, bool *r_used_notch) {
	NSRect screen_frame = screen.frame;
	CGFloat notch_left = 0.0;
	CGFloat notch_right = 0.0;
	CGFloat top_inset = notch_bridge_top_inset(screen);
	bool has_notch = notch_bridge_read_notch(screen, &notch_left, &notch_right, &top_inset);

	if (r_used_notch != nullptr) {
		*r_used_notch = false;
	}

	if (has_notch) {
		CGFloat notch_width = notch_right - notch_left;
		CGFloat notch_center_local = notch_left + (notch_width * 0.5);
		CGFloat panel_width = width_override > 0.0 ? width_override : (notch_width + (wing_extension * 2.0));
		CGFloat panel_left_local = notch_center_local - (panel_width * 0.5);
		CGFloat global_x = screen_frame.origin.x + panel_left_local;
		// Panel centigin ALTINDAN baslar; yukari uzamaz.
		CGFloat global_y = NSMaxY(screen_frame) - top_inset - height;

		if (r_used_notch != nullptr) {
			*r_used_notch = true;
		}
		return NSMakeRect(global_x, global_y, panel_width, height);
	}

	CGFloat panel_width = width_override > 0.0 ? width_override : 260.0;
	CGFloat center_local = screen_frame.size.width * 0.5;
	CGFloat panel_left_local = center_local - (panel_width * 0.5);
	CGFloat global_x = screen_frame.origin.x + panel_left_local;
	CGFloat global_y = NSMaxY(screen_frame) - top_inset - height;
	return NSMakeRect(global_x, global_y, panel_width, height);
}

static Dictionary notch_bridge_frame_dict(NSScreen *screen, NSRect frame, bool used_notch) {
	Dictionary result;
	NSRect screen_frame = screen.frame;
	CGFloat notch_left = 0.0;
	CGFloat notch_right = 0.0;
	CGFloat top_inset = 0.0;
	bool has_notch = notch_bridge_read_notch(screen, &notch_left, &notch_right, &top_inset);

	result["ok"] = true;
	result["used_notch"] = used_notch;
	result["frame_x"] = frame.origin.x;
	result["frame_y"] = frame.origin.y;
	result["width"] = frame.size.width;
	result["height"] = frame.size.height;
	result["godot_x"] = frame.origin.x - screen_frame.origin.x;
	result["godot_y"] = NSMaxY(screen_frame) - NSMaxY(frame);
	result["panel_top_y"] = notch_bridge_top_inset(screen);
	result["screen_top_y"] = NSMaxY(screen_frame);

	// Fare hit testi icin centik merkezi — AppKit geometrisinden (ekran-global koordinat).
	if (has_notch) {
		CGFloat notch_width = notch_right - notch_left;
		CGFloat center_local = notch_left + (notch_width * 0.5);
		result["global_center_x"] = screen_frame.origin.x + center_local;
	} else {
		result["global_center_x"] = frame.origin.x + (frame.size.width * 0.5);
	}

	return result;
}

static Dictionary notch_bridge_geometry_for_screen(NSScreen *screen) {
	Dictionary geometry;
	if (screen == nil) {
		return geometry;
	}

	NSRect frame = screen.frame;
	CGFloat notch_left = 0.0;
	CGFloat notch_right = 0.0;
	CGFloat top_inset = 0.0;
	bool has_notch = notch_bridge_read_notch(screen, &notch_left, &notch_right, &top_inset);

	geometry["has_notch"] = has_notch;
	geometry["screen_width"] = frame.size.width;
	geometry["screen_height"] = frame.size.height;
	geometry["screen_origin_x"] = frame.origin.x;
	geometry["screen_origin_y"] = frame.origin.y;
	geometry["scale"] = screen.backingScaleFactor;
	geometry["top_inset"] = top_inset;

	if (has_notch) {
		CGFloat notch_width = notch_right - notch_left;
		CGFloat center_local = notch_left + (notch_width * 0.5);
		geometry["x"] = notch_left;
		geometry["y"] = 0.0;
		geometry["width"] = notch_width;
		geometry["height"] = top_inset;
		geometry["center_x"] = center_local;
		geometry["global_center_x"] = frame.origin.x + center_local;
	} else {
		CGFloat center_local = frame.size.width * 0.5;
		geometry["x"] = center_local - 92.0;
		geometry["y"] = 0.0;
		geometry["width"] = 184.0;
		geometry["height"] = 32.0;
		geometry["center_x"] = center_local;
		geometry["global_center_x"] = frame.origin.x + center_local;
	}

	return geometry;
}

static godot::Vector2 notch_bridge_mouse_local(NSScreen *screen) {
	NSRect frame = screen.frame;
	NSPoint mouse = NSEvent.mouseLocation;
	CGFloat local_x = mouse.x - frame.origin.x;
	CGFloat local_y = NSMaxY(frame) - mouse.y;
	return godot::Vector2((real_t)local_x, (real_t)local_y);
}

static void notch_bridge_apply_overlay(NSWindow *window, bool capture_excluded) {
	if (window == nil) {
		return;
	}

	window.level = NSMainMenuWindowLevel + 2;
	window.collectionBehavior =
			NSWindowCollectionBehaviorCanJoinAllSpaces |
			NSWindowCollectionBehaviorStationary |
			NSWindowCollectionBehaviorIgnoresCycle |
			NSWindowCollectionBehaviorFullScreenAuxiliary;
	window.styleMask |= NSWindowStyleMaskNonactivatingPanel;
	window.hidesOnDeactivate = NO;
	window.hasShadow = NO;
	window.opaque = NO;
	window.backgroundColor = NSColor.clearColor;
	window.alphaValue = 1.0;
	window.sharingType = capture_excluded ? NSWindowSharingNone : NSWindowSharingReadOnly;
}
#endif

namespace godot {

void NotchBridge::_bind_methods() {
	ClassDB::bind_method(D_METHOD("is_available"), &NotchBridge::is_available);
	ClassDB::bind_method(D_METHOD("apply_native_overlay", "window_id"), &NotchBridge::apply_native_overlay);
	ClassDB::bind_method(D_METHOD("place_panel_at_notch", "window_id", "wing_extension", "height", "width_override", "capture_excluded"), &NotchBridge::place_panel_at_notch);
	ClassDB::bind_method(D_METHOD("hide_panel", "window_id"), &NotchBridge::hide_panel);
	ClassDB::bind_method(D_METHOD("get_notch_geometry"), &NotchBridge::get_notch_geometry);
	ClassDB::bind_method(D_METHOD("get_notch_geometry_for_window", "window_id"), &NotchBridge::get_notch_geometry_for_window);
	ClassDB::bind_method(D_METHOD("get_notch_size"), &NotchBridge::get_notch_size);
	ClassDB::bind_method(D_METHOD("get_mouse_local_on_notch_screen"), &NotchBridge::get_mouse_local_on_notch_screen);
}

bool NotchBridge::is_available() const {
#ifdef __APPLE__
	return true;
#else
	return false;
#endif
}

bool NotchBridge::apply_native_overlay(int64_t window_id) {
#ifdef __APPLE__
	NSWindow *window = notch_bridge_get_window(window_id);
	if (window == nil) {
		return false;
	}

	notch_bridge_apply_overlay(window, false);
	[window orderFrontRegardless];
	return true;
#else
	return false;
#endif
}

Dictionary NotchBridge::place_panel_at_notch(int64_t window_id, double wing_extension, double height, double width_override, bool capture_excluded) {
#ifdef __APPLE__
	NSWindow *window = notch_bridge_get_window(window_id);
	if (window == nil) {
		return Dictionary();
	}

	NSScreen *screen = notch_bridge_screen_for_window(window);
	bool used_notch = false;
	NSRect target_frame = notch_bridge_panel_frame(screen, (CGFloat)wing_extension, (CGFloat)height, (CGFloat)width_override, &used_notch);

	notch_bridge_apply_overlay(window, capture_excluded);
	[window setFrame:target_frame display:YES];
	[window setIsVisible:YES];
	[window orderFrontRegardless];

	// Godot DisplayServer sync konumu bozuyor (Retina'da ~2x sapma). Hedef cerceveyi don.
	return notch_bridge_frame_dict(screen, target_frame, used_notch);
#else
	return Dictionary();
#endif
}

bool NotchBridge::hide_panel(int64_t window_id) {
#ifdef __APPLE__
	NSWindow *window = notch_bridge_get_window(window_id);
	if (window == nil) {
		return false;
	}

	[window orderOut:nil];
	return true;
#else
	return false;
#endif
}

Dictionary NotchBridge::get_notch_geometry() const {
#ifdef __APPLE__
	return notch_bridge_geometry_for_screen(NSScreen.mainScreen);
#else
	Dictionary geometry;
	geometry["has_notch"] = false;
	return geometry;
#endif
}

Dictionary NotchBridge::get_notch_geometry_for_window(int64_t window_id) const {
#ifdef __APPLE__
	NSWindow *window = notch_bridge_get_window(window_id);
	return notch_bridge_geometry_for_screen(notch_bridge_screen_for_window(window));
#else
	Dictionary geometry;
	geometry["has_notch"] = false;
	return geometry;
#endif
}

Vector2 NotchBridge::get_notch_size() const {
#ifdef __APPLE__
	NSScreen *screen = notch_bridge_find_notch_screen();
	CGFloat notch_left = 0.0;
	CGFloat notch_right = 0.0;
	CGFloat top_inset = 0.0;
	if (notch_bridge_read_notch(screen, &notch_left, &notch_right, &top_inset)) {
		return Vector2((real_t)(notch_right - notch_left), (real_t)top_inset);
	}
	return Vector2(0.0, 0.0);
#else
	return Vector2(0.0, 0.0);
#endif
}

Vector2 NotchBridge::get_mouse_local_on_notch_screen() const {
#ifdef __APPLE__
	NSScreen *screen = notch_bridge_find_notch_screen();
	if (screen == nil) {
		return Vector2(0.0, 0.0);
	}
	return notch_bridge_mouse_local(screen);
#else
	return Vector2(0.0, 0.0);
#endif
}

} // namespace godot
