import SwiftUI
import AppKit

// MARK: - Volume HUD View
struct VolumeBlossomView: View {
    var volume: Float
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: volume == 0 ? "speaker.slash.fill" : (volume < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.3.fill"))
                .font(.system(size: 14))
                .foregroundColor(.white)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, geo.size.width * CGFloat(volume)), height: 6)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(width: 100)
        }
        .padding(.horizontal, 28)
        .frame(height: 44)
    }
}

// MARK: - Device HUD View
struct DeviceBlossomView: View {
    var message: String
    var iconName: String
    var isConnected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundColor(isConnected ? .green : .orange)
                
            Text(message)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 28)
        .frame(height: 44)
    }
}

// MARK: - Clipboard HUD View
struct ClipboardBlossomView: View {
    var message: String
    var iconName: String
    var isCut: Bool
    var colorSwatch: Color? = nil
    var accentColor: Color = .blue
    
    var body: some View {
        HStack(spacing: 8) {
            if let swatch = colorSwatch {
                Circle()
                    .fill(swatch)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                    .shadow(color: swatch.opacity(0.6), radius: 5, x: 0, y: 1)
            } else {
                Image(systemName: iconName)
                    .font(.system(size: 14))
                    .foregroundColor(isCut ? .orange : accentColor)
            }
                
            Text(message)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 28)
        .frame(height: 44)
    }
}

// MARK: - Compact Clock View
struct CompactClockView: View {
    @State private var timeString = ""
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 8) {
            Text(timeString)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            
            NotchMascotEyesView(state: .idle)
        }
        .onReceive(timer) { _ in updateTime() }
        .onAppear { updateTime() }
        .padding(.top, 4) // adjust to fit within 34px height, considering flares
        .frame(height: 34)
    }
    
    private func updateTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        timeString = formatter.string(from: Date())
    }
}

// MARK: - Compact Media View
struct CompactMediaView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var rotation: Double = 0
    
    var body: some View {
        HStack(spacing: 10) {
            // Vinyl spinning album art
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 24, height: 24)
                
                if let img = viewModel.artwork {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 22, height: 22)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                        )
                }
                
                // Vinyl center hole
                Circle()
                    .fill(Color.black)
                    .frame(width: 5, height: 5)
            }
            .rotationEffect(.degrees(rotation))
            .onChange(of: viewModel.isPlaying) { playing in
                if playing { startSpinning() }
            }
            .onAppear {
                if viewModel.isPlaying { startSpinning() }
            }
            
            MarqueeText(
                text: viewModel.currentSong,
                font: .system(size: 12, weight: .medium),
                color: .white
            )
            
            Spacer(minLength: 4)
            
            WaveformView(isPlaying: viewModel.isPlaying, color: viewModel.accentColor)
            
            NotchMascotEyesView(state: .music(isPlaying: viewModel.isPlaying))
        }
        .padding(.horizontal, 22)
        .frame(height: 34)
    }
    
    private func startSpinning() {
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }
}

// MARK: - Compact Pomodoro View (Main Notch Island)
struct CompactPomodoroView: View {
    @ObservedObject var viewModel: NotchViewModel
    
    private var progress: CGFloat {
        guard viewModel.pomodoroTotal > 0 else { return 0 }
        return CGFloat(viewModel.pomodoroRemaining / viewModel.pomodoroTotal)
    }
    
    private var sessionLabel: String {
        let totalMinutes = Int(round(viewModel.pomodoroTotal / 60))
        if totalMinutes == 25 {
            return LanguageManager.tr("Focus")
        } else if totalMinutes == 15 {
            return LanguageManager.tr("Rest")
        } else if totalMinutes == 5 {
            return LanguageManager.tr("Break")
        } else {
            return LanguageManager.tr("Custom")
        }
    }
    
    private var sessionIcon: String {
        let totalMinutes = Int(round(viewModel.pomodoroTotal / 60))
        if totalMinutes == 25 {
            return "brain.head.profile"
        } else if totalMinutes == 15 {
            return "leaf.fill"
        } else if totalMinutes == 5 {
            return "cup.and.saucer.fill"
        } else {
            return "slider.horizontal.3"
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // 1. Progress Bar Lingkaran
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 2.5)
                    .frame(width: 18, height: 18)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: viewModel.isPomodoroPaused ? [.yellow, .orange] : [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .frame(width: 18, height: 18)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: viewModel.pomodoroRemaining)
                
                Circle()
                    .fill(viewModel.isPomodoroPaused ? Color.yellow : Color.orange)
                    .frame(width: 4, height: 4)
            }
            
            // 2. Angka Timer
            Text(timeString(from: viewModel.pomodoroRemaining))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(viewModel.isPomodoroPaused ? .yellow : .white)
            
            // 3. Jenis Waktu Template Badge
            HStack(spacing: 4) {
                Image(systemName: sessionIcon)
                    .font(.system(size: 8, weight: .bold))
                Text(sessionLabel)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundColor(viewModel.isPomodoroPaused ? .yellow : .orange)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill((viewModel.isPomodoroPaused ? Color.yellow : Color.orange).opacity(0.15))
                    .overlay(
                        Capsule()
                            .stroke((viewModel.isPomodoroPaused ? Color.yellow : Color.orange).opacity(0.3), lineWidth: 0.5)
                    )
            )
            
            // 4. Mascot Eyes (4 preset animated states)
            let totalMinutes = Int(round(viewModel.pomodoroTotal / 60))
            let preset = PomodoroMascotPreset.from(totalMinutes: totalMinutes)
            NotchMascotEyesView(
                state: .pomodoro(preset: preset, isPaused: viewModel.isPomodoroPaused)
            )
        }
        .padding(.horizontal, 16)
        .frame(height: 34)
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

// MARK: - Blossom Animations
struct DropFileBlossomView: View {
    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 0.8
    @State private var pulseOpacity: Double = 0.35
    @State private var arrowOffset: CGFloat = -3
    @State private var sparkleScale: CGFloat = 0.85
    
    var body: some View {
        HStack(spacing: 12) {
            // Portal Vortex Ring
            ZStack {
                // Outer rotating accretion ring
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                .cyan,
                                .blue,
                                .purple,
                                .pink,
                                .cyan
                            ]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 2, dash: [4, 3])
                    )
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(rotation))
                
                // Pulsing suction wave
                Circle()
                    .stroke(Color.cyan.opacity(pulseOpacity), lineWidth: 1.5)
                    .frame(width: 26, height: 26)
                    .scaleEffect(pulseScale)
                
                // Deep gravitational core
                Circle()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: 20, height: 20)
                
                // Suction arrow bobbing towards the center
                Image(systemName: "arrow.down")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.cyan)
                    .offset(y: arrowOffset)
            }
            .frame(width: 34, height: 34)
            
            // Typography
            VStack(alignment: .leading, spacing: 2) {
                Text(LanguageManager.tr("Drop to Absorb"))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                HStack(spacing: 4) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 9))
                    Text(LanguageManager.tr("Temporary Shelf"))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                .foregroundColor(Color.cyan.opacity(0.85))
            }
            
            Spacer(minLength: 0)
            
            // Sparkle suction accent
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.purple.opacity(0.9))
                .scaleEffect(sparkleScale)
                .opacity(sparkleScale)
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
                pulseOpacity = 0.85
                arrowOffset = 2
            }
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                sparkleScale = 1.2
            }
        }
    }
}

struct DropSuccessBlossomView: View {
    @State private var checkScale: CGFloat = 0.5
    @State private var glowOpacity: Double = 0.2
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(glowOpacity))
                    .frame(width: 26, height: 26)
                    .blur(radius: 4)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.green)
            }
            .scaleEffect(checkScale)
            
            Text(LanguageManager.tr("File Stashed!"))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
        .onAppear {
            withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.5, blendDuration: 0)) {
                checkScale = 1.05
                glowOpacity = 0.65
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    checkScale = 1.0
                }
            }
        }
    }
}

struct TimesUpBlossomView: View {
    @State private var scale: CGFloat = 0.4
    @State private var rotation: Double = -15
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .font(.system(size: 24))
                .foregroundColor(.orange)
                .rotationEffect(.degrees(rotation), anchor: .top)
            
            Text(LanguageManager.tr("TIME'S UP!"))
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(height: 64)
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.35, blendDuration: 0)) {
                scale = 1.0
            }
            withAnimation(.easeInOut(duration: 0.1).repeatForever(autoreverses: true)) {
                rotation = 15
            }
        }
    }
}

// MARK: - Battery HUD View
struct BatteryBlossomView: View {
    var level: Int
    var isCharging: Bool
    var isAC: Bool
    
    @State private var boltPulse = false
    
    var body: some View {
        HStack(spacing: 9) {
            // Battery Capsule Icon
            HStack(spacing: 1.5) {
                ZStack(alignment: .leading) {
                    // Outer border
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1.2)
                        .frame(width: 27, height: 14)
                    
                    // Fill
                    RoundedRectangle(cornerRadius: 2.2)
                        .fill(fillGradient)
                        .frame(width: max(2, 23 * CGFloat(min(100, max(0, level))) / 100), height: 10)
                        .padding(.leading, 2)
                }
                
                // Terminal tip (right end of battery)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 2, height: 5.5)
            }
            .frame(width: 32, height: 16)
            
            // Lightning Bolt indicator
            if isCharging || isAC {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.green)
                    .scaleEffect(boltPulse ? 1.2 : 0.9)
                    .shadow(color: Color.green.opacity(0.8), radius: 5)
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: boltPulse)
                    .onAppear { boltPulse = true }
            }
            
            // Battery Percentage & Status
            HStack(spacing: 5) {
                Text("\(level)%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("•")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                
                Text(statusText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 22)
        .frame(height: 44)
    }
    
    private var fillGradient: LinearGradient {
        if isAC || isCharging {
            return LinearGradient(
                colors: [Color.green.opacity(0.9), Color.green],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if level <= 20 {
            return LinearGradient(
                colors: [Color.red.opacity(0.9), Color.orange],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [Color.white.opacity(0.85), Color.white],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    private var statusText: String {
        if isAC {
            if level >= 100 {
                return LanguageManager.tr("Fully Charged")
            } else {
                return LanguageManager.tr("Charging")
            }
        } else {
            return LanguageManager.tr("On Battery")
        }
    }
}



// MARK: - Agenda Blossom View
struct AgendaBlossomView: View {
    var message: String
    @State private var scale: CGFloat = 0.4
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 20))
            Text(message)
                .font(.system(size: 14, weight: .bold))
        }
        .frame(height: 44)
        .foregroundColor(.white)
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                scale = 1.0
            }
        }
    }
}

