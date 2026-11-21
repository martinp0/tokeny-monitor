import SwiftUI

/// Liquid Glass card. Reduce Transparency uses the solid card color instead of a material.
struct TokenyGlassModifier: ViewModifier {
    var radius: CGFloat = 24
    var interactive: Bool = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if reduceTransparency {
            content.background(TokenyColor.card(scheme), in: shape)
        } else if interactive {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content.glassEffect(.regular, in: shape)
        }
    }
}

extension View {
    func tokenyGlass(radius: CGFloat = 24, interactive: Bool = false) -> some View {
        modifier(TokenyGlassModifier(radius: radius, interactive: interactive))
    }

    func tokenyScreen() -> some View {
        background { TokenyBackdrop() }
    }
}

extension TokenyColor {
    /// Budget bar on the hero. Over 100 % is danger, over 90 % is warning, otherwise the accent.
    static func budgetTint(fraction: Double, scheme: ColorScheme) -> Color {
        if fraction >= 1 { return danger(scheme) }
        if fraction >= 0.9 { return warning(scheme) }
        return accent(scheme)
    }
}
