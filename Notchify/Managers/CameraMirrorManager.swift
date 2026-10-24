import Foundation
import AVFoundation
import AppKit
import SwiftUI

// MARK: - Mirror & Camera Manager
class CameraMirrorManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {
    static let shared = CameraMirrorManager()
    
    @Published var isRunning = false
    @Published var permissionGranted = false
    @Published var isMirrored = true
    @Published var isFrozen = false
    
    // Mode
    @Published var captureMode: CameraCaptureMode = .photo {
        didSet {
            updateOutputsForMode(captureMode)
        }
    }
    
    // Photo capture states
    @Published var isTimerEnabled = false // false = instant, true = 3s
    @Published var isCountingDown = false
    @Published var countdownSeconds = 3
    @Published var isCapturing = false
    @Published var showFlash = false
    @Published var lastCapturedPhotoURL: URL?
    @Published var lastCapturedThumbnail: NSImage?
    @Published var lastCapturedImage: NSImage?
    @Published var savedFeedbackMessage: String?
    
    // Video capture states
    @Published var selectedDurationPreset: VideoDurationPreset = .sec30
    @Published var isRecordingVideo = false
    @Published var recordingElapsedSeconds: Int = 0
    @Published var isMicMuted: Bool = false
    @Published var lastCapturedVideoURL: URL?
    @Published var lastCapturedMediaType: CameraCaptureMode = .photo
    @Published var shouldOpenMediaViewer: Bool = false
    
    let session = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()
    let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "notchify.mirror.sessionQueue")
    private var isConfigured = false
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var countdownTimer: Timer?
    private var recordingTimer: Timer?
    
    override init() {
        super.init()
    }
    
    func checkPermissionAndStart() {
        // Request audio access if needed
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                if granted {
                    self?.sessionQueue.async {
                        guard let self = self, self.isConfigured, self.audioInput == nil else { return }
                        if let audioDevice = AVCaptureDevice.default(for: .audio),
                           let aInput = try? AVCaptureDeviceInput(device: audioDevice) {
                            self.session.beginConfiguration()
                            if self.session.canAddInput(aInput) {
                                self.session.addInput(aInput)
                                self.audioInput = aInput
                            }
                            self.session.commitConfiguration()
                        }
                    }
                }
            }
        }
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { self.permissionGranted = true }
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.permissionGranted = granted
                    if granted {
                        self.startSession()
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async { self.permissionGranted = false }
        @unknown default:
            break
        }
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.session.isRunning else { return }
            if !self.isConfigured {
                self.setupSession()
            }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isRunning = self.session.isRunning
                PrivacyMonitor.shared.isCameraActive = self.session.isRunning
            }
        }
    }
    
    func stopSession() {
        cancelCountdown()
        if isRecordingVideo {
            stopVideoRecording()
        }
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
                PrivacyMonitor.shared.isCameraActive = false
                PrivacyMonitor.shared.isMicActive = false
            }
        }
    }
    
    private func setupSession() {
        session.beginConfiguration()
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        } else if session.canSetSessionPreset(.medium) {
            session.sessionPreset = .medium
        }
        
        // Video Input
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        let device = AVCaptureDevice.default(for: .video) ?? discoverySession.devices.first
        if let camera = device, let input = try? AVCaptureDeviceInput(device: camera) {
            if session.canAddInput(input) {
                session.addInput(input)
                self.videoInput = input
            }
        }
        
        // Audio Input
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let aInput = try? AVCaptureDeviceInput(device: audioDevice) {
            if session.canAddInput(aInput) {
                session.addInput(aInput)
                self.audioInput = aInput
            }
        }
        
        // Configure output based on current mode
        movieOutput.maxRecordedDuration = CMTime(seconds: 300, preferredTimescale: 600)
        if captureMode == .video {
            if session.canAddOutput(movieOutput) {
                session.addOutput(movieOutput)
            }
        } else {
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
        }
        
        session.commitConfiguration()
        self.isConfigured = true
    }
    
    func updateOutputsForMode(_ mode: CameraCaptureMode) {
        guard isConfigured else { return }
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            if mode == .video {
                if self.session.outputs.contains(self.photoOutput) {
                    self.session.removeOutput(self.photoOutput)
                }
                if !self.session.outputs.contains(self.movieOutput) {
                    self.movieOutput.maxRecordedDuration = CMTime(seconds: 300, preferredTimescale: 600)
                    if self.session.canAddOutput(self.movieOutput) {
                        self.session.addOutput(self.movieOutput)
                    }
                }
            } else {
                if self.session.outputs.contains(self.movieOutput) {
                    self.session.removeOutput(self.movieOutput)
                }
                if !self.session.outputs.contains(self.photoOutput) {
                    if self.session.canAddOutput(self.photoOutput) {
                        self.session.addOutput(self.photoOutput)
                    }
                }
            }
            self.session.commitConfiguration()
        }
    }
    
    // MARK: - Capture Sequence
    func triggerCaptureSequence() {
        guard !isCapturing && !isCountingDown else { return }
        if isTimerEnabled {
            startCountdown()
        } else {
            performCapture()
        }
    }
    
    func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        isCountingDown = false
    }
    
    private func startCountdown() {
        countdownSeconds = 3
        isCountingDown = true
        countdownTimer?.invalidate()
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            if self.countdownSeconds > 1 {
                self.countdownSeconds -= 1
                NSSound(named: "Tink")?.play()
            } else {
                timer.invalidate()
                self.countdownTimer = nil
                self.isCountingDown = false
                self.performCapture()
            }
        }
    }
    
    private func performCapture() {
        isCapturing = true
        
        // Visual Screen Flash
        withAnimation(.easeIn(duration: 0.08)) {
            self.showFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeOut(duration: 0.25)) {
                self.showFlash = false
            }
        }
        
        // Shutter Sound
        let playSound = UserDefaults.standard.object(forKey: "playShutterSound") as? Bool ?? true
        if playSound {
            AudioServicesPlaySystemSound(1108)
        }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let photoSettings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        DispatchQueue.main.async {
            self.isCapturing = false
        }
        
        if let error = error {
            print("Notchify camera error: \(error)")
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let originalImage = NSImage(data: data) else {
            return
        }
        
        let finalImage = self.isMirrored ? mirrorImage(originalImage) : originalImage
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateStr = formatter.string(from: Date())
        let filename = "Notchify_\(dateStr).png"
        
        let targetDirectory = PhotoStorageManager.getPhotosDirectory()
        let fileURL = targetDirectory.appendingPathComponent(filename)
        
        if let tiff = finalImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            do {
                try pngData.write(to: fileURL)
                let thumb = makeThumbnail(image: finalImage, targetSize: NSSize(width: 32, height: 32))
                
                DispatchQueue.main.async {
                    self.lastCapturedPhotoURL = fileURL
                    self.lastCapturedThumbnail = thumb
                    self.lastCapturedImage = finalImage
                    self.lastCapturedMediaType = .photo
                    self.savedFeedbackMessage = LanguageManager.tr("Saved!")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        if self.savedFeedbackMessage == LanguageManager.tr("Saved!") {
                            self.savedFeedbackMessage = nil
                        }
                    }
                }
            } catch {
                print("Failed to write photo: \(error)")
            }
        }
    }
    
    // MARK: - Video Recording
    func toggleMicMute() {
        isMicMuted.toggle()
        if let audioConn = movieOutput.connection(with: .audio) {
            audioConn.isEnabled = !isMicMuted
        }
    }
    
    func startVideoRecording() {
        guard !isRecordingVideo else { return }
        
        // Ensure movieOutput is attached to session
        if !session.outputs.contains(movieOutput) {
            session.beginConfiguration()
            if session.outputs.contains(photoOutput) {
                session.removeOutput(photoOutput)
            }
            if session.canAddOutput(movieOutput) {
                movieOutput.maxRecordedDuration = CMTime(seconds: 300, preferredTimescale: 600)
                session.addOutput(movieOutput)
            }
            session.commitConfiguration()
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateStr = formatter.string(from: Date())
        let filename = "Notchify_Video_\(dateStr).mov"
        let targetDirectory = PhotoStorageManager.getPhotosDirectory()
        let fileURL = targetDirectory.appendingPathComponent(filename)
        
        try? FileManager.default.removeItem(at: fileURL)
        
        // Configure mirroring
        if let videoConn = movieOutput.connection(with: .video) {
            if videoConn.isVideoMirroringSupported {
                videoConn.automaticallyAdjustsVideoMirroring = false
                videoConn.isVideoMirrored = self.isMirrored
            }
        }
        
        // Configure audio
        if let audioConn = movieOutput.connection(with: .audio) {
            audioConn.isEnabled = !self.isMicMuted
        }
        
        movieOutput.startRecording(to: fileURL, recordingDelegate: self)
        
        isRecordingVideo = true
        recordingElapsedSeconds = 0
        PrivacyMonitor.shared.isMicActive = !self.isMicMuted
        
        NSSound(named: "Tink")?.play()
        
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            self.recordingElapsedSeconds += 1
            if self.recordingElapsedSeconds >= self.selectedDurationPreset.seconds {
                self.stopVideoRecording()
            }
        }
    }
    
    func stopVideoRecording() {
        guard isRecordingVideo else { return }
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Immediate UI feedback on main thread
        DispatchQueue.main.async {
            self.isRecordingVideo = false
            PrivacyMonitor.shared.isMicActive = false
        }
        
        if movieOutput.isRecording {
            movieOutput.stopRecording()
        }
    }
    
    // MARK: - AVCaptureFileOutputRecordingDelegate
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
            self.isRecordingVideo = false
            PrivacyMonitor.shared.isMicActive = false
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
            
            if let error = error {
                let nsError = error as NSError
                let success = (nsError.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool) ?? false
                if !success {
                    print("Video recording failed: \(error)")
                    return
                }
            }
            
            self.lastCapturedVideoURL = outputFileURL
            self.lastCapturedMediaType = .video
            self.generateVideoThumbnail(for: outputFileURL)
            self.savedFeedbackMessage = LanguageManager.tr("Video Saved!")
            self.shouldOpenMediaViewer = true
            
            NSSound(named: "Pop")?.play()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if self.savedFeedbackMessage == LanguageManager.tr("Video Saved!") {
                    self.savedFeedbackMessage = nil
                }
            }
        }
    }
    
    private func generateVideoThumbnail(for url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let time = CMTime(seconds: 0.2, preferredTimescale: 600)
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                let img = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                let thumb = self.makeThumbnail(image: img, targetSize: NSSize(width: 32, height: 32))
                DispatchQueue.main.async {
                    self.lastCapturedThumbnail = thumb
                }
            }
        }
    }
    
    func loadLatestMedia() {
        guard lastCapturedPhotoURL == nil && lastCapturedVideoURL == nil else { return }
        let dir = PhotoStorageManager.getPhotosDirectory()
        let fileManager = FileManager.default
        if let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) {
            let mediaFiles = files.filter {
                let ext = $0.pathExtension.lowercased()
                return ext == "png" || ext == "mp4" || ext == "mov"
            }.sorted { (u1, u2) -> Bool in
                let d1 = (try? u1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                let d2 = (try? u2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                return d1 > d2
            }
            
            if let latest = mediaFiles.first {
                let ext = latest.pathExtension.lowercased()
                if ext == "mp4" || ext == "mov" {
                    self.lastCapturedVideoURL = latest
                    self.lastCapturedMediaType = .video
                    self.generateVideoThumbnail(for: latest)
                } else if ext == "png" {
                    if let img = NSImage(contentsOf: latest) {
                        self.lastCapturedPhotoURL = latest
                        self.lastCapturedMediaType = .photo
                        self.lastCapturedImage = img
                        self.lastCapturedThumbnail = self.makeThumbnail(image: img, targetSize: NSSize(width: 32, height: 32))
                    }
                }
            }
        }
    }
    
    func loadLatestPhoto() {
        loadLatestMedia()
    }
    
    private func mirrorImage(_ image: NSImage) -> NSImage {
        let size = image.size
        let mirrored = NSImage(size: size)
        mirrored.lockFocus()
        let transform = NSAffineTransform()
        transform.translateX(by: size.width, yBy: 0)
        transform.scaleX(by: -1, yBy: 1)
        transform.concat()
        image.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1.0)
        mirrored.unlockFocus()
        return mirrored
    }
    
    private func makeThumbnail(image: NSImage, targetSize: NSSize) -> NSImage {
        let thumb = NSImage(size: targetSize)
        thumb.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize), from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)
        thumb.unlockFocus()
        return thumb
    }
}
