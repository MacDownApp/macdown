import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// An sRGB color with alpha, parsed from a hex string such as `#RGB`,
/// `#RRGGBB` or `#RRGGBBAA`.
struct ThemeColor: Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespaces)
        guard text.hasPrefix("#") else { return nil }
        text.removeFirst()
        if text.count == 3 {
            text = text.map { "\($0)\($0)" }.joined()
        }
        guard text.count == 6 || text.count == 8, let value = UInt64(text, radix: 16) else {
            return nil
        }
        if text.count == 6 {
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
        } else {
            red = Double((value >> 24) & 0xFF) / 255
            green = Double((value >> 16) & 0xFF) / 255
            blue = Double((value >> 8) & 0xFF) / 255
            alpha = Double(value & 0xFF) / 255
        }
    }

    func withAlpha(_ alpha: Double) -> ThemeColor {
        ThemeColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    #if canImport(AppKit)
    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }
    #endif

    /// 0 (black) to 1 (white). Used to tell dark themes from light ones.
    var luminance: Double { 0.2126 * red + 0.7152 * green + 0.0722 * blue }

    /// CSS color string, for the preview.
    var cssString: String {
        func byte(_ v: Double) -> Int { Int((v * 255).rounded()) }
        if alpha >= 1 {
            return String(format: "#%02x%02x%02x", byte(red), byte(green), byte(blue))
        }
        return "rgba(\(byte(red)), \(byte(green)), \(byte(blue)), \((alpha * 1000).rounded() / 1000))"
    }
}
