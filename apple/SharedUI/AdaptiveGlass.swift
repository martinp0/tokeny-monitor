import SwiftUI

/// Liquid Glass where the system effect is available, and an opaque material when the user
/// asks for less transparency. Deployment is iOS 26 / macOS 26, so `glassEffect` is the supported path.
struct AdaptiveGlass<S: InsettableShape>: ViewModifier {
    var shape: S
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(.regularMaterial, in: shape)
        } else {
            content.glassEffect(.regular, in: shape)
        }
    }
}

extension View {
    func adaptiveGlass<S: InsettableShape>(in shape: S) -> some View {
        modifier(AdaptiveGlass(shape: shape))
    }
}
