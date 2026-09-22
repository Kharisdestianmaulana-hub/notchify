import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NotchPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize the panel
        let notchPanel = NotchPanel()
        self.panel = notchPanel
        
        let containerView = NotchContainerView()
        
        // Wrap SwiftUI view in NSHostingView
        let hostingView = NSHostingView(rootView: containerView)
        // Ensure hosting view background is clear
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.wantsLayer = true
        
        notchPanel.contentView = hostingView
        
        // Calculate screen frame and show
        if let screen = NSScreen.main {
            // Give it a fixed large frame at the top center of the screen
            // so we don't need to resize the window (which causes lag).
            // We just animate the SwiftUI view inside this large clear window.
            let panelWidth: CGFloat = 600
            let panelHeight: CGFloat = 300 // Large enough for expanded state
            
            let screenRect = screen.frame
            let x = (screenRect.width - panelWidth) / 2
            let y = screenRect.height - panelHeight // Top of the screen
            
            notchPanel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        }
        
        notchPanel.makeKeyAndOrderFront(nil)
    }
}
