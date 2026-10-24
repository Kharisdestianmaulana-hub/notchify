import SwiftUI
import AVKit

struct InTabVideoPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?
    @State private var loopObserver: Any?
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .frame(width: 360, height: 195)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black)
                    .frame(width: 360, height: 195)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    )
            }
        }
        .onAppear {
            let p = AVPlayer(url: url)
            self.player = p
            p.play()
            
            self.loopObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: p.currentItem,
                queue: .main
            ) { _ in
                p.seek(to: .zero)
                p.play()
            }
        }
        .onDisappear {
            if let observer = loopObserver {
                NotificationCenter.default.removeObserver(observer)
                loopObserver = nil
            }
            player?.pause()
            player = nil
        }
    }
}

struct MirrorCardView: View {
    @ObservedObject var viewModel: NotchViewModel
    @StateObject private var cameraManager = CameraMirrorManager.shared
    @State private var isViewingMedia = false
    @State private var showCopiedFeedback = false
    @State private var copiedFeedbackText = ""
    @State private var recBlink = false
    
    var body: some View {
        VStack(spacing: 8) {
            if cameraManager.permissionGranted {
                if isViewingMedia {
                    mediaViewerContainer
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                } else {
                    mirrorContainer
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                }
            } else {
                permissionNeededCard
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            cameraManager.checkPermissionAndStart()
            cameraManager.loadLatestMedia()
        }
        .onDisappear {
            if !cameraManager.isRecordingVideo {
                cameraManager.stopSession()
            }
            isViewingMedia = false
        }
        .onReceive(cameraManager.$shouldOpenMediaViewer) { shouldOpen in
            if shouldOpen {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    isViewingMedia = true
                }
                cameraManager.shouldOpenMediaViewer = false
            }
        }
    }
    
    private var mirrorContainer: some View {
        VStack(spacing: 8) {
            // Top Mode Switcher Bar
            HStack {
                // Mode Switcher: Photo | Video
                HStack(spacing: 2) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            cameraManager.captureMode = .photo
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text(LanguageManager.tr("Photo"))
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(cameraManager.captureMode == .photo ? .white : .gray)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(cameraManager.captureMode == .photo ? Color.white.opacity(0.2) : Color.clear)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(cameraManager.isRecordingVideo)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            cameraManager.captureMode = .video
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text(LanguageManager.tr("Video"))
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(cameraManager.captureMode == .video ? .white : .gray)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(cameraManager.captureMode == .video ? Color.red.opacity(0.85) : Color.clear)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(cameraManager.isRecordingVideo)
                }
                .padding(2)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                
                Spacer()
                
                // Sub-mode options (Right)
                if cameraManager.captureMode == .video {
                    // Duration Presets: 15s | 30s | 60s | 3m | 5m
                    HStack(spacing: 2) {
                        ForEach(VideoDurationPreset.allCases) { preset in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    cameraManager.selectedDurationPreset = preset
                                }
                            }) {
                                Text(preset.label)
                                    .font(.system(size: 10, weight: cameraManager.selectedDurationPreset == preset ? .bold : .medium))
                                    .foregroundColor(cameraManager.selectedDurationPreset == preset ? .white : .gray)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(cameraManager.selectedDurationPreset == preset ? Color.white.opacity(0.25) : Color.clear)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(cameraManager.isRecordingVideo)
                        }
                    }
                    .padding(2)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                } else {
                    // Photo Timer Toggle: Instant / 3s
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            cameraManager.isTimerEnabled.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.system(size: 10, weight: .semibold))
                            Text(cameraManager.isTimerEnabled ? "3s" : LanguageManager.tr("Off"))
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(cameraManager.isTimerEnabled ? .yellow : .white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(cameraManager.isTimerEnabled ? Color.yellow.opacity(0.2) : Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(LanguageManager.tr("Timer: 3 seconds delay"))
                }
            }
            .frame(width: 360)
            
            // Camera Video Preview Box
            ZStack {
                CameraPreviewView(
                    session: cameraManager.session,
                    isMirrored: cameraManager.isMirrored,
                    isFrozen: cameraManager.isFrozen
                )
                .frame(width: 360, height: 195)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Elegant Border
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    .frame(width: 360, height: 195)
                
                // Screen Flash Animation (Photo)
                if cameraManager.showFlash {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .frame(width: 360, height: 195)
                        .transition(.opacity)
                }
                
                // Countdown Overlay (3.. 2.. 1..)
                if cameraManager.isCountingDown {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.65))
                            .frame(width: 68, height: 68)
                        
                        Text("\(cameraManager.countdownSeconds)")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundColor(.yellow)
                    }
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
                
                // Video Recording HUD (Top-left & Bottom progress bar)
                if cameraManager.isRecordingVideo {
                    VStack {
                        HStack {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .opacity(recBlink ? 1.0 : 0.2)
                                    .animation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: recBlink)
                                    .onAppear { recBlink = true }
                                
                                Text(LanguageManager.tr("REC"))
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundColor(.red)
                                
                                Text("\(formatSeconds(cameraManager.recordingElapsedSeconds)) / \(formatSeconds(cameraManager.selectedDurationPreset.seconds))")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.75))
                            .clipShape(Capsule())
                            .padding(.leading, 10)
                            .padding(.top, 10)
                            
                            Spacer()
                        }
                        
                        Spacer()
                        
                        // Bottom Progress Bar
                        GeometryReader { geo in
                            let progress = min(1.0, max(0.0, Double(cameraManager.recordingElapsedSeconds) / Double(max(1, cameraManager.selectedDurationPreset.seconds))))
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 3)
                                
                                Rectangle()
                                    .fill(Color.red)
                                    .frame(width: geo.size.width * CGFloat(progress), height: 3)
                                    .animation(.linear(duration: 1.0), value: progress)
                            }
                        }
                        .frame(width: 360, height: 3)
                        .clipShape(RoundedRectangle(cornerRadius: 1.5))
                        .padding(.bottom, 6)
                    }
                    .frame(width: 360, height: 195)
                }
                
                // Frozen Overlay Badge
                if cameraManager.isFrozen && !cameraManager.isCountingDown && !cameraManager.isRecordingVideo {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "pause.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(LanguageManager.tr("Preview Paused"))
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.65))
                        .clipShape(Capsule())
                        .padding(.bottom, 8)
                    }
                    .frame(width: 360, height: 195)
                }
                
                // Saved Feedback Toast
                if let msg = cameraManager.savedFeedbackMessage {
                    VStack {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 12, weight: .bold))
                            Text(msg)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Capsule())
                        .padding(.top, 10)
                        Spacer()
                    }
                    .frame(width: 360, height: 195)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(width: 360, height: 195)
            
            // Floating Toolbar Controls
            HStack(spacing: 14) {
                // 1. Left auxiliary button
                if cameraManager.captureMode == .video {
                    // Mic mute/unmute toggle
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            cameraManager.toggleMicMute()
                        }
                    }) {
                        Image(systemName: cameraManager.isMicMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(cameraManager.isMicMuted ? .red : .white)
                            .frame(width: 30, height: 30)
                            .background(cameraManager.isMicMuted ? Color.red.opacity(0.2) : Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(cameraManager.isMicMuted ? LanguageManager.tr("Microphone Muted") : LanguageManager.tr("Microphone Active"))
                } else {
                    // Freeze frame button (Photo mode)
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            cameraManager.isFrozen.toggle()
                        }
                    }) {
                        Image(systemName: cameraManager.isFrozen ? "play.fill" : "pause.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(cameraManager.isFrozen ? .yellow : .white)
                            .frame(width: 30, height: 30)
                            .background(cameraManager.isFrozen ? Color.yellow.opacity(0.2) : Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(LanguageManager.tr("Freeze frame to check details"))
                }
                
                // 2. Flip Mirror / Audience View
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        cameraManager.isMirrored.toggle()
                    }
                }) {
                    Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(cameraManager.isRecordingVideo)
                .help(cameraManager.isMirrored ? LanguageManager.tr("Mirrored (Click for True View)") : LanguageManager.tr("True View (Click for Mirrored)"))
                
                // 3. MAIN ACTION BUTTON (Center)
                if cameraManager.captureMode == .video {
                    if cameraManager.isRecordingVideo {
                        // STOP RECORDING BUTTON
                        Button(action: {
                            cameraManager.stopVideoRecording()
                        }) {
                            ZStack {
                                Circle()
                                    .stroke(Color.red, lineWidth: 2.5)
                                    .frame(width: 36, height: 36)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.red)
                                    .frame(width: 15, height: 15)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(LanguageManager.tr("Stop Recording"))
                    } else {
                        // START RECORDING BUTTON
                        Button(action: {
                            cameraManager.startVideoRecording()
                        }) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white, lineWidth: 2.5)
                                    .frame(width: 36, height: 36)
                                
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 26, height: 26)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(LanguageManager.tr("Record Video"))
                    }
                } else {
                    // PHOTO SHUTTER BUTTON
                    Button(action: {
                        cameraManager.triggerCaptureSequence()
                    }) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 2.5)
                                .frame(width: 36, height: 36)
                            
                            Circle()
                                .fill(cameraManager.isCountingDown ? Color.yellow : Color.white)
                                .frame(width: 26, height: 26)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(cameraManager.isCapturing || cameraManager.isCountingDown)
                    .help(LanguageManager.tr("Take Photo"))
                }
                
                // 4. Freeze button in Video Mode
                if cameraManager.captureMode == .video {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            cameraManager.isFrozen.toggle()
                        }
                    }) {
                        Image(systemName: cameraManager.isFrozen ? "play.fill" : "pause.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(cameraManager.isFrozen ? .yellow : .white)
                            .frame(width: 30, height: 30)
                            .background(cameraManager.isFrozen ? Color.yellow.opacity(0.2) : Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(cameraManager.isRecordingVideo)
                    .help(LanguageManager.tr("Freeze frame to check details"))
                }
                
                // 5. Last Media Thumbnail or Open Folder Button
                if let thumb = cameraManager.lastCapturedThumbnail {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isViewingMedia = true
                        }
                    }) {
                        ZStack(alignment: .bottomTrailing) {
                            Image(nsImage: thumb)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 30, height: 30)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 1.5)
                                )
                            
                            if cameraManager.lastCapturedMediaType == .video {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(2)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 2, y: 2)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(cameraManager.isRecordingVideo)
                    .help(LanguageManager.tr("View latest media"))
                } else {
                    Button(action: {
                        PhotoStorageManager.openPhotosFolder()
                    }) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(cameraManager.isRecordingVideo)
                    .help(LanguageManager.tr("Open Photos Folder"))
                }
            }
            .frame(width: 360)
        }
    }
    
    private var mediaViewerContainer: some View {
        VStack(spacing: 10) {
            // Media Preview Box (Matches 360 x 195 frame)
            ZStack {
                if cameraManager.lastCapturedMediaType == .video, let videoURL = cameraManager.lastCapturedVideoURL {
                    InTabVideoPlayerView(url: videoURL)
                } else if let image = cameraManager.lastCapturedImage ?? (cameraManager.lastCapturedPhotoURL.flatMap { NSImage(contentsOf: $0) }) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 360, height: 195)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 360, height: 195)
                        .overlay(
                            Text(LanguageManager.tr("No Media"))
                                .foregroundColor(.gray)
                                .font(.system(size: 12))
                        )
                }
                
                // Border
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    .frame(width: 360, height: 195)
                
                // Copied Toast Overlay
                if showCopiedFeedback {
                    VStack {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 12, weight: .bold))
                            Text(copiedFeedbackText)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.85))
                        .clipShape(Capsule())
                        .padding(.top, 10)
                        Spacer()
                    }
                    .frame(width: 360, height: 195)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(width: 360, height: 195)
            
            // Media Viewer Toolbar (Back, Copy Image/Video, Open Folder)
            HStack(spacing: 10) {
                // Back to Camera
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isViewingMedia = false
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text(LanguageManager.tr("Camera"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .help(LanguageManager.tr("Back to Camera"))
                
                Spacer()
                
                // Copy Media Button
                Button(action: {
                    copyMediaToClipboard()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10, weight: .semibold))
                        Text(cameraManager.lastCapturedMediaType == .video ? LanguageManager.tr("Copy Video") : LanguageManager.tr("Copy Image"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .help(cameraManager.lastCapturedMediaType == .video ? LanguageManager.tr("Copy video to clipboard") : LanguageManager.tr("Copy photo to clipboard"))
                
                // Open Folder Button
                Button(action: {
                    let targetURL = cameraManager.lastCapturedMediaType == .video ? cameraManager.lastCapturedVideoURL : cameraManager.lastCapturedPhotoURL
                    if let url = targetURL {
                        PhotoStorageManager.revealPhotoInFinder(url: url)
                    } else {
                        PhotoStorageManager.openPhotosFolder()
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "folder")
                            .font(.system(size: 10, weight: .semibold))
                        Text(LanguageManager.tr("Open Folder"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .help(LanguageManager.tr("Open in Finder"))
            }
            .frame(width: 360)
        }
    }
    
    private func copyMediaToClipboard() {
        if cameraManager.lastCapturedMediaType == .video {
            guard let url = cameraManager.lastCapturedVideoURL else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([url as NSURL])
            copiedFeedbackText = LanguageManager.tr("Video Copied to Clipboard")
        } else {
            guard let image = cameraManager.lastCapturedImage ?? (cameraManager.lastCapturedPhotoURL.flatMap { NSImage(contentsOf: $0) }) else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
            copiedFeedbackText = LanguageManager.tr("Image Copied to Clipboard")
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showCopiedFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.2)) {
                showCopiedFeedback = false
            }
        }
    }
    
    private func formatSeconds(_ secs: Int) -> String {
        let m = secs / 60
        let s = secs % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    private var permissionNeededCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 36))
                .foregroundColor(.orange)
            
            Text(LanguageManager.tr("Camera Access Needed"))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            
            Text(LanguageManager.tr("Notchify needs camera access to show your quick webcam mirror preview."))
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Button(action: {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Text(LanguageManager.tr("Open System Settings"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(width: 360, height: 230)
    }
}

struct LiveScrubberView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var localElapsed: Double = 0
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 6) {
            Text(formatTime(localElapsed))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
            
            Slider(value: Binding(
                get: { localElapsed },
                set: { newValue in
                    localElapsed = newValue
                    viewModel.elapsed = newValue
                    viewModel.seek(to: newValue)
                }
            ), in: 0...(viewModel.duration > 0 ? viewModel.duration : 1))
            .controlSize(.mini)
            .tint(.white)
            
            Text(formatTime(viewModel.duration))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
        }
        .onAppear { localElapsed = viewModel.elapsed }
        .onReceive(timer) { _ in
            if viewModel.isPlaying {
                localElapsed = viewModel.elapsed
            }
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        guard time.isFinite && !time.isNaN else { return "0:00" }
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
