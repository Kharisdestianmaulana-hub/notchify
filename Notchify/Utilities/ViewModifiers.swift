import SwiftUI

// MARK: - Performance Optimized Glow Shadow Extension
extension View {
    @ViewBuilder
    func notchGlowShadow(enableGlow: Bool, isPlaying: Bool, accentColor: Color) -> some View {
        if enableGlow && isPlaying && accentColor != .clear {
            self.shadow(color: accentColor.opacity(0.45), radius: 24, x: 0, y: 8)
        } else {
            self
        }
    }
}
