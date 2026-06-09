import AppKit
import Foundation

struct NotchGeometry: Codable {
    let has_notch: Bool
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let center_x: Double
    let global_center_x: Double
    let screen_width: Double
    let screen_height: Double
    let screen_origin_x: Double
    let screen_origin_y: Double
    let top_inset: Double
    let scale: Double
}

func geometry(for screen: NSScreen) -> NotchGeometry {
    let frame = screen.frame
    let left = screen.auxiliaryTopLeftArea ?? .zero
    let right = screen.auxiliaryTopRightArea ?? .zero
    let scale = screen.backingScaleFactor
    let topInset = screen.safeAreaInsets.top

    let hasNotch = left.size.width > 0.0 && right.size.width > 0.0 && right.origin.x > left.maxX
    if !hasNotch {
        let centerX = frame.width / 2.0
        return NotchGeometry(
            has_notch: false,
            x: centerX - 92.0,
            y: 0.0,
            width: 184.0,
            height: 32.0,
            center_x: centerX,
            global_center_x: frame.origin.x + centerX,
            screen_width: frame.width,
            screen_height: frame.height,
            screen_origin_x: frame.origin.x,
            screen_origin_y: frame.origin.y,
            top_inset: topInset,
            scale: scale
        )
    }

    let localX = left.maxX
    let notchWidth = right.minX - left.maxX
    let centerX = localX + (notchWidth / 2.0)

    return NotchGeometry(
        has_notch: true,
        x: localX,
        y: 0.0,
        width: notchWidth,
        height: max(topInset, 32.0),
        center_x: centerX,
        global_center_x: frame.origin.x + centerX,
        screen_width: frame.width,
        screen_height: frame.height,
        screen_origin_x: frame.origin.x,
        screen_origin_y: frame.origin.y,
        top_inset: topInset,
        scale: scale
    )
}

func findNotchScreen() -> NSScreen? {
    for screen in NSScreen.screens {
        let left = screen.auxiliaryTopLeftArea ?? .zero
        let right = screen.auxiliaryTopRightArea ?? .zero
        if left.size.width > 0.0 && right.size.width > 0.0 && right.origin.x > left.maxX {
            return screen
        }
    }
    return NSScreen.main
}

guard let screen = findNotchScreen() else {
    fputs("{\"error\":\"no_main_screen\"}\n", stderr)
    exit(1)
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
if let data = try? encoder.encode(geometry(for: screen)),
   let json = String(data: data, encoding: .utf8) {
    print(json)
} else {
    fputs("{\"error\":\"encode_failed\"}\n", stderr)
    exit(1)
}
