import AppKit

class NotchPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
    }
    
    // Allow the panel to become key for certain interactions if needed, though usually false for overlays
    override var canBecomeKey: Bool {
        return true
    }
    
    // To ensure the mouse passes through the transparent areas of the large window frame.
    // If alpha is 0, we ignore the click so the app below receives it.
    // However, NSHostingView sometimes intercepts all hits. 
    // Wait, let's just rely on default clear background behavior first.
    // Usually, NSHostingView with clear background will pass hits for areas where SwiftUI renders nothing.
}
