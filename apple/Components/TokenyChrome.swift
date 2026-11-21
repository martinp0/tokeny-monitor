import SwiftUI

/// Colors from the iOS redesign. Text stays on the system primary and secondary styles.
enum TokenyColor {
    static func accent(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x5B8CFF) : Color(hex: 0x2F6BFF)
    }

    static func positive(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x34D399) : Color(hex: 0x1FA971)
    }

    static func warning(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xFBBF24) : Color(hex: 0xE8A317)
    }

    static func danger(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xFF6369) : Color(hex: 0xE5484D)
    }

    static func base(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x0B0D12) : Color(hex: 0xF4F6FB)
    }

    static func card(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x1C1F26) : .white
    }

    /// Brand color for the circle tint and the share bar. Never used as text.
    static func provider(_ name: String) -> Color {
        let key = name.lowercased()
        if key.contains("openai") { return Color(hex: 0x10A37F) }
        if key.contains("anthropic") || key.contains("claude") { return Color(hex: 0xD97757) }
        if key.contains("openrouter") { return Color(hex: 0x6467F2) }
        return Color(hex: 0x5B8CFF)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity)
    }
}

/// Static mesh under every screen. Reduce Transparency drops the blobs and keeps the base.
struct TokenyBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            TokenyColor.base(scheme)
            if !reduceTransparency {
                blob(scheme == .dark ? Color(hex: 0x3B4BFF, opacity: 0.35) : Color(hex: 0x8FA2FF, opacity: 0.30), size: 420, x: -150, y: -300)
                blob(scheme == .dark ? Color(hex: 0x12B5A6, opacity: 0.25) : Color(hex: 0x7FE0D3, opacity: 0.25), size: 360, x: 170, y: 10)
                blob(scheme == .dark ? Color(hex: 0x7A3CFF, opacity: 0.20) : Color(hex: 0xC9B2FF, opacity: 0.20), size: 380, x: 10, y: 340)
            }
        }
        .ignoresSafeArea()
    }

    private func blob(_ color: Color, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: 120)
            .offset(x: x, y: y)
    }
}
