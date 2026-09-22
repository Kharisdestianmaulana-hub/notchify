import SwiftUI
import AppKit

class NotchViewModel: ObservableObject {
    @Published var isExpanded: Bool = false
    @Published var clipboardItems: [String] = []
    
    // For media info (dummy data for now)
    @Published var currentSong: String = "AirPods Pro"
    @Published var currentArtist: String = "L 80%   R 78%   Case 100%"
    
    private var clipboardTimer: Timer?
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int = 0
    
    init() {
        startClipboardPolling()
    }
    
    func startClipboardPolling() {
        lastChangeCount = pasteboard.changeCount
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    private func checkClipboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        
        if let string = pasteboard.string(forType: .string) {
            DispatchQueue.main.async {
                // Avoid duplicates at the top
                if self.clipboardItems.first != string {
                    self.clipboardItems.insert(string, at: 0)
                    if self.clipboardItems.count > 3 {
                        self.clipboardItems.removeLast()
                    }
                }
            }
        }
    }
}
