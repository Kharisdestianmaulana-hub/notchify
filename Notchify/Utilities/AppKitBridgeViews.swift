import SwiftUI
import AppKit
import AVFoundation

// MARK: - Hover Tracking View for Background Apps
struct HoverTrackingView: NSViewRepresentable {
    var onHoverStateChanged: (Bool) -> Void
    
    func makeNSView(context: Context) -> TrackingNSView {
        let view = TrackingNSView()
        view.onHoverStateChanged = onHoverStateChanged
        return view
    }
    
    func updateNSView(_ nsView: TrackingNSView, context: Context) {}
}

class TrackingNSView: NSView {
    var onHoverStateChanged: ((Bool) -> Void)?
    var trackingArea: NSTrackingArea?
    private var isMouseInside = false
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
        
        // Fix for missing mouseExited during resize animations
        if isMouseInside {
            if let window = self.window {
                let mouseLocation = window.mouseLocationOutsideOfEventStream

                let localPoint = self.convert(mouseLocation, from: nil)
                
                let isOutsideBounds = !self.bounds.contains(localPoint)
                let isOutsideHorizontally = localPoint.x < 0 || localPoint.x > self.bounds.maxX
                let isAtTopEdge = localPoint.y >= self.bounds.maxY - 2 && !isOutsideHorizontally
                
                if isOutsideBounds && !isAtTopEdge {
                    isMouseInside = false
                    DispatchQueue.main.async {
                        self.onHoverStateChanged?(false)
                    }
                }
            }
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        if !isMouseInside {
            isMouseInside = true
            onHoverStateChanged?(true)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        // Prevent false exits ONLY when cursor hits the absolute TOP edge of the screen
        if let window = self.window {
            let mouseLocation = window.mouseLocationOutsideOfEventStream
            let localPoint = self.convert(mouseLocation, from: nil)
            
            let isOutsideHorizontally = localPoint.x < 0 || localPoint.x > self.bounds.maxX
            
            // macOS sometimes fires mouseExited when hitting the menu bar area
            if localPoint.y >= self.bounds.maxY - 2 && !isOutsideHorizontally {
                return // False alarm, cursor is at the very top edge, but still within our width
            }
        }
        
        if isMouseInside {
            isMouseInside = false
            onHoverStateChanged?(false)
        }
    }
}

// MARK: - Drop Tracking View
struct DropTrackingView: NSViewRepresentable {
    var onDragEntered: () -> Void
    var onDragExited: () -> Void
    var onDrop: ([URL]) -> Void
    
    func makeNSView(context: Context) -> DropNSView {
        let view = DropNSView()
        view.onDragEntered = onDragEntered
        view.onDragExited = onDragExited
        view.onDrop = onDrop
        return view
    }
    
    func updateNSView(_ nsView: DropNSView, context: Context) {}
}

class DropNSView: NSView {
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?
    var onDrop: (([URL]) -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragEntered?()
        return .copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragExited?()
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            onDrop?(urls)
            return true
        }
        return false
    }
}

// MARK: - Drag Source View
struct DragSourceOverlay: NSViewRepresentable {
    var url: URL
    var onDragSuccess: () -> Void
    
    func makeNSView(context: Context) -> DragSourceNSView {
        let view = DragSourceNSView()
        view.url = url
        view.onDragSuccess = onDragSuccess
        return view
    }
    
    func updateNSView(_ nsView: DragSourceNSView, context: Context) {
        nsView.url = url
        nsView.onDragSuccess = onDragSuccess
    }
}

class DragSourceNSView: NSView, NSDraggingSource {
    var url: URL?
    var onDragSuccess: (() -> Void)?
    
    override func mouseDown(with event: NSEvent) {
        // Needs to be implemented to catch mouseDragged
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let url = url else { return }
        
        let draggingItem = NSDraggingItem(pasteboardWriter: url as NSURL)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 32, height: 32)
        
        let draggingFrame = NSRect(x: (self.bounds.width - 32) / 2, y: (self.bounds.height - 32) / 2, width: 32, height: 32)
        draggingItem.setDraggingFrame(draggingFrame, contents: icon)
        
        self.beginDraggingSession(with: [draggingItem], event: event, source: self)
    }
    
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
    
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if operation != [] {
            DispatchQueue.main.async {
                self.onDragSuccess?()
            }
        }
    }
}




class CameraPreviewNSView: NSView {
    var previewLayer: AVCaptureVideoPreviewLayer {
        return (layer as? AVCaptureVideoPreviewLayer) ?? AVCaptureVideoPreviewLayer()
    }
    
    private var currentMirrored: Bool = true
    private var currentFrozen: Bool = false
    
    override func makeBackingLayer() -> CALayer {
        let pLayer = AVCaptureVideoPreviewLayer()
        pLayer.cornerRadius = 16
        pLayer.masksToBounds = true
        return pLayer
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        previewLayer.frame = bounds
        applySettings()
    }
    
    func updateSettings(isMirrored: Bool, isFrozen: Bool) {
        self.currentMirrored = isMirrored
        self.currentFrozen = isFrozen
        applySettings()
    }
    
    private func applySettings() {
        guard let conn = previewLayer.connection else { return }
        if conn.isVideoMirroringSupported {
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = currentMirrored
        }
        conn.isEnabled = !currentFrozen
    }
}

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    var isMirrored: Bool
    var isFrozen: Bool
    
    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.updateSettings(isMirrored: isMirrored, isFrozen: isFrozen)
        return view
    }
    
    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        if nsView.previewLayer.session != session {
            nsView.previewLayer.session = session
        }
        nsView.updateSettings(isMirrored: isMirrored, isFrozen: isFrozen)
    }
}

