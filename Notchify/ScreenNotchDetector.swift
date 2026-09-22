import AppKit

struct ScreenNotchDetector {
    static var hasPhysicalNotch: Bool {
        guard let screen = NSScreen.main else { return false }
        if #available(macOS 12.0, *) {
            // safeAreaInsets.top is usually > 0 if there's a notch
            return screen.safeAreaInsets.top > 0
        }
        return false
    }
    
    static var topOffset: CGFloat {
        // If there's a notch, it attaches to the top edge.
        // If there's no notch, we might want it to float slightly below the menu bar,
        // or just stick to the top like a notch anyway. 
        // The user said: "menempel di bawah notch hardware jika ada, atau menjadi floating pill kapsul jika di monitor standar".
        return hasPhysicalNotch ? 0 : 30
    }
    
    static var menuBarHeight: CGFloat {
        guard let screen = NSScreen.main else { return 24 }
        return screen.frame.height - screen.visibleFrame.height - screen.visibleFrame.origin.y
    }
}
