import SwiftUI
import AppKit

// MARK: - Detached Pomodoro Island
struct DetachedPomodoroView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 6) {
            // Main Timer Display Button (Click opens Pomodoro tab in Notch)
            Button(action: {
                withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.76, blendDuration: 0.08)) {
                    viewModel.selectedTab = .pomodoro
                    viewModel.isExpanded = true
                }
            }) {
                HStack(spacing: 5) {
                    ZStack {
                        // Background circular track
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 2.2)
                            .frame(width: 15, height: 15)
                        
                        // Active progress ring
                        Circle()
                            .trim(from: 0, to: CGFloat(viewModel.pomodoroTotal > 0 ? viewModel.pomodoroRemaining / viewModel.pomodoroTotal : 0))
                            .stroke(
                                viewModel.isPomodoroPaused ? Color.yellow : Color(red: 1.0, green: 0.584, blue: 0.0),
                                style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                            )
                            .frame(width: 15, height: 15)
                            .rotationEffect(.degrees(-90))
                    }
                    
                    Text(timeString(from: viewModel.pomodoroRemaining))
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundColor(viewModel.isPomodoroPaused ? .yellow : .white)
                    
                    let totalMinutes = Int(round(viewModel.pomodoroTotal / 60))
                    let preset = PomodoroMascotPreset.from(totalMinutes: totalMinutes)
                    NotchMascotEyesView(
                        state: .pomodoro(preset: preset, isPaused: viewModel.isPomodoroPaused),
                        eyeSize: CGSize(width: 3.5, height: 6.8),
                        spacing: 2.6
                    )
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Micro-Peek Inline Controls (Slides in on hover)
            if isHovered {
                HStack(spacing: 4) {
                    // Pause / Resume Button
                    Button(action: {
                        withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.76)) {
                            if viewModel.isPomodoroPaused {
                                viewModel.resumePomodoro()
                            } else {
                                viewModel.pausePomodoro()
                            }
                        }
                    }) {
                        Image(systemName: viewModel.isPomodoroPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(viewModel.isPomodoroPaused ? .yellow : Color(red: 1.0, green: 0.584, blue: 0.0))
                            .frame(width: 18, height: 18)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.12))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(viewModel.isPomodoroPaused ? LanguageManager.tr("Resume") : LanguageManager.tr("Pause"))
                    
                    // Stop Button
                    Button(action: {
                        withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.76, blendDuration: 0.08)) {
                            viewModel.stopPomodoro()
                        }
                    }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))
                            .frame(width: 18, height: 18)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.12))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(LanguageManager.tr("Stop"))
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity).combined(with: .scale(scale: 0.7)),
                    removal: .move(edge: .leading).combined(with: .opacity).combined(with: .scale(scale: 0.7))
                ))
            }
        }
        .padding(.horizontal, isHovered ? 8 : 9)
        .frame(height: 26)
        .background(Color.black)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(isHovered ? 0.22 : 0.12), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 5, x: 0, y: 2)
        .onHover { hovering in
            withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.76)) {
                isHovered = hovering
            }
        }
        .help(LanguageManager.tr("Focus Timer: Click to open"))
        .contextMenu {
            Button(viewModel.isPomodoroPaused ? LanguageManager.tr("Resume") : LanguageManager.tr("Pause")) {
                if viewModel.isPomodoroPaused {
                    viewModel.resumePomodoro()
                } else {
                    viewModel.pausePomodoro()
                }
            }
            Divider()
            Button(LanguageManager.tr("Stop")) {
                withAnimation {
                    viewModel.stopPomodoro()
                }
            }
        }
    }
    
    private func timeString(from time: TimeInterval) -> String {
        let min = Int(time) / 60
        let sec = Int(time) % 60
        return String(format: "%02d:%02d", min, sec)
    }
}




// MARK: - Meeting Alert Side Island (1-Click Auto-Joiner)
struct MeetingAlertIslandView: View {
    @ObservedObject var viewModel: NotchViewModel
    let event: CustomEvent
    @State private var isPulsing: Bool = false
    @State private var isHovered: Bool = false
    @State private var remainingText: String = ""
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 8) {
            // Video Camera Icon with Breathing Animation
            Image(systemName: "video.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.45))
                .scaleEffect(isPulsing ? 1.15 : 0.92)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isPulsing)
                .onAppear { isPulsing = true }
            
            // Meeting Title + Countdown (Clicking opens Notch Agenda tab)
            Button(action: {
                withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.76, blendDuration: 0.08)) {
                    viewModel.selectedTab = .agenda
                    viewModel.isExpanded = true
                }
            }) {
                HStack(spacing: 5) {
                    Text(event.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 105, alignment: .leading)
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.35))
                        .font(.system(size: 10))
                    
                    Text(remainingText)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.45))
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // 1-Click Direct Join Action Button
            if let meetingURL = event.meetingLink {
                Button(action: {
                    NSWorkspace.shared.open(meetingURL)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        viewModel.dismissMeetingAlert(id: event.id)
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 8, weight: .bold))
                        Text(LanguageManager.tr("Join Now"))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.2, green: 0.9, blue: 0.45))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .shadow(color: Color(red: 0.2, green: 0.9, blue: 0.45).opacity(0.4), radius: 4, x: 0, y: 1)
            }
            
            // Dismiss Button
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    viewModel.dismissMeetingAlert(id: event.id)
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(PlainButtonStyle())
            .help(LanguageManager.tr("Dismiss meeting alert"))
        }
        .padding(.horizontal, 9)
        .frame(height: 26)
        .background(Color.black)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color(red: 0.2, green: 0.9, blue: 0.45).opacity(isHovered ? 0.4 : 0.2), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 5, x: 0, y: 2)
        .onAppear {
            updateRemaining()
        }
        .onReceive(timer) { _ in
            updateRemaining()
        }
    }
    
    private func updateRemaining() {
        let diff = event.date.timeIntervalSince(Date())
        if diff > 0 {
            let m = Int(diff) / 60
            let s = Int(diff) % 60
            remainingText = String(format: "%02d:%02d", m, s)
        } else {
            remainingText = LanguageManager.tr("In Progress")
        }
    }
}


struct PrivacyIndicatorView: View {
    @ObservedObject var privacy = PrivacyMonitor.shared
    @State private var isBlinking = false
    @State private var isHovered = false
    @State private var detectedAppName: String = ""
    
    var body: some View {
        Button(action: {
            withAnimation {
                privacy.toggleCamera()
            }
        }) {
            ZStack(alignment: .trailing) {
                // Background Island Capsule
                Capsule()
                    .fill(Color.black)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(isHovered ? 0.22 : 0.12), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 5, x: 0, y: 2)
                
                HStack(spacing: 6) {
                    // Micro-Peek App Name (Expands smoothly to the left on hover)
                    if isHovered && !detectedAppName.isEmpty {
                        HStack(spacing: 4) {
                            Text(detectedAppName)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Circle()
                                .fill(Color.white.opacity(0.35))
                                .frame(width: 3, height: 3)
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.8)),
                            removal: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.8))
                        ))
                    }
                    
                    // Indicator Dots (Anchored to trailing)
                    HStack(spacing: 5) {
                        if privacy.isCameraActive {
                            Circle()
                                .fill(Color(red: 0.2, green: 0.9, blue: 0.45))
                                .frame(width: 7, height: 7)
                                .opacity(isBlinking ? 0.35 : 1.0)
                        }
                        if privacy.isMicActive {
                            Circle()
                                .fill(Color(red: 1.0, green: 0.584, blue: 0.0))
                                .frame(width: 7, height: 7)
                                .opacity(isBlinking ? 0.35 : 1.0)
                        }
                    }
                }
                .padding(.horizontal, isHovered ? 9 : 8)
            }
            .frame(height: 26)
            .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            if hovering {
                detectedAppName = privacy.resolveActiveApp()
            }
            withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.76)) {
                isHovered = hovering
            }
        }
        .help(tooltipText)
        .contextMenu {
            Button(LanguageManager.tr("Toggle Camera Indicator")) {
                withAnimation { privacy.toggleCamera() }
            }
            Button(LanguageManager.tr("Toggle Mic Indicator")) {
                withAnimation { privacy.toggleMic() }
            }
        }
        .onAppear {
            isBlinking = true
        }
    }
    
    private var tooltipText: String {
        let app = privacy.resolveActiveApp()
        let prefix = LanguageManager.tr("In use by:")
        if privacy.isCameraActive && privacy.isMicActive {
            return "\(prefix) \(app) (\(LanguageManager.tr("Camera & Microphone")))"
        } else if privacy.isCameraActive {
            return "\(prefix) \(app) (\(LanguageManager.tr("Camera")))"
        } else {
            return "\(prefix) \(app) (\(LanguageManager.tr("Microphone")))"
        }
    }
}

// MARK: - Detached Video Recording Island (Left Island)
struct VideoRecordingIslandView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var cameraManager = CameraMirrorManager.shared
    @State private var isPulsing: Bool = false
    @State private var isHovered: Bool = false
    @State private var isStopHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 7) {
            // Main Button: Click expands Notch into Mirror tab
            Button(action: {
                withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.76, blendDuration: 0.08)) {
                    viewModel.selectedTab = .mirror
                    viewModel.isExpanded = true
                }
            }) {
                HStack(spacing: 6) {
                    // Glowing / Pulsing Red Recording Dot
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isPulsing ? 1.15 : 0.85)
                        .opacity(isPulsing ? 1.0 : 0.4)
                        .shadow(color: Color.red.opacity(isPulsing ? 0.7 : 0.2), radius: 3)
                        .animation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true), value: isPulsing)
                    
                    // Recording Duration (mm:ss)
                    Text(timeString(from: cameraManager.recordingElapsedSeconds))
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundColor(.white)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Stop Recording Button
            Button(action: {
                withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.76, blendDuration: 0.08)) {
                    cameraManager.stopVideoRecording()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(isStopHovered ? Color.red.opacity(0.35) : Color.white.opacity(0.12))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(Color.red.opacity(isStopHovered ? 0.6 : 0.25), lineWidth: 0.5)
                        )
                    
                    Image(systemName: "stop.fill")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(isStopHovered ? .white : Color(red: 1.0, green: 0.35, blue: 0.35))
                }
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
                .scaleEffect(isStopHovered ? 1.08 : 1.0)
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { h in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isStopHovered = h
                }
            }
            .help(LanguageManager.tr("Stop Recording"))
        }
        .padding(.horizontal, 9)
        .frame(height: 26)
        .background(Color.black)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.red.opacity(isHovered ? 0.45 : 0.22), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 5, x: 0, y: 2)
        .onAppear {
            isPulsing = true
        }
        .onHover { hovering in
            withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.76)) {
                isHovered = hovering
            }
        }
        .help(LanguageManager.tr("Recording: Click to view, or stop"))
        .contextMenu {
            Button(LanguageManager.tr("Open Camera")) {
                withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.76, blendDuration: 0.08)) {
                    viewModel.selectedTab = .mirror
                    viewModel.isExpanded = true
                }
            }
            Divider()
            Button(LanguageManager.tr("Stop Recording")) {
                withAnimation {
                    cameraManager.stopVideoRecording()
                }
            }
        }
    }
    
    private func timeString(from seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

