import SwiftUI
import AppKit

// MARK: - Pomodoro Mascot Preset
enum PomodoroMascotPreset: Equatable {
    case focus       // 25m Focus
    case rest        // 15m Long Break / Zen Rest
    case shortBreak  // 5m Short Break / Cheerful Tea Break
    case custom      // Custom timer
    
    static func from(totalMinutes: Int) -> PomodoroMascotPreset {
        switch totalMinutes {
        case 25: return .focus
        case 15: return .rest
        case 5: return .shortBreak
        default: return .custom
        }
    }
}

// MARK: - Mascot Eye State
enum MascotEyeState: Equatable {
    case idle
    case batteryLow
    case batteryCharging
    case music(isPlaying: Bool)
    case pomodoro(preset: PomodoroMascotPreset, isPaused: Bool)
    case timesUp
    case videoRecording
    case tabVibe(tab: NotchTab)
    case petted
    case wink
}

// MARK: - Notch Pebble Body Shape (Pure 2D Vector)
struct NotchPebbleShape: Shape {
    init() {}
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: w * 0.36, y: h * 0.05))
        // Top edge to top-right rounded corner
        path.addCurve(
            to: CGPoint(x: w * 0.94, y: h * 0.36),
            control1: CGPoint(x: w * 0.76, y: h * 0.05),
            control2: CGPoint(x: w * 0.95, y: h * 0.16)
        )
        // Right edge to bottom-right rounded corner
        path.addCurve(
            to: CGPoint(x: w * 0.72, y: h * 0.96),
            control1: CGPoint(x: w * 0.93, y: h * 0.68),
            control2: CGPoint(x: w * 0.88, y: h * 0.94)
        )
        // Bottom edge to bottom-left rounded corner
        path.addCurve(
            to: CGPoint(x: w * 0.08, y: h * 0.68),
            control1: CGPoint(x: w * 0.44, y: h * 0.98),
            control2: CGPoint(x: w * 0.14, y: h * 0.90)
        )
        // Left edge to top-left rounded corner
        path.addCurve(
            to: CGPoint(x: w * 0.36, y: h * 0.05),
            control1: CGPoint(x: w * 0.04, y: h * 0.42),
            control2: CGPoint(x: w * 0.12, y: h * 0.10)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Notch Pebble Gloss Shape (Top Specular Reflection)
struct NotchPebbleGlossShape: Shape {
    init() {}
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: w * 0.32, y: h * 0.08))
        path.addCurve(
            to: CGPoint(x: w * 0.82, y: h * 0.28),
            control1: CGPoint(x: w * 0.60, y: h * 0.08),
            control2: CGPoint(x: w * 0.76, y: h * 0.15)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.24, y: h * 0.22),
            control1: CGPoint(x: w * 0.60, y: h * 0.35),
            control2: CGPoint(x: w * 0.38, y: h * 0.32)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Smiling / Zen Eye Arc (2D Vector Curve)
struct MascotEyeArcShape: Shape {
    var flipped: Bool // false: ⌒ rounded smile arch, true: ◡ zen/chill
    
    init(flipped: Bool = false) {
        self.flipped = flipped
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        if flipped {
            // Zen / Sleeping / Chill eye (crescent curving downwards ◡)
            path.move(to: CGPoint(x: 0, y: h * 0.35))
            path.addCurve(
                to: CGPoint(x: w, y: h * 0.35),
                control1: CGPoint(x: w * 0.25, y: h * 0.90),
                control2: CGPoint(x: w * 0.75, y: h * 0.90)
            )
        } else {
            // Happy smiling eye (soft rounded arch ⌒)
            path.move(to: CGPoint(x: 0, y: h * 0.75))
            path.addCurve(
                to: CGPoint(x: w, y: h * 0.75),
                control1: CGPoint(x: w * 0.22, y: h * 0.12),
                control2: CGPoint(x: w * 0.78, y: h * 0.12)
            )
        }
        return path
    }
}

// MARK: - Mascot Squinting Eye (> <) Shape for Petting & Happy Reactions
struct MascotSquintEyeShape: Shape {
    var isLeft: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        if isLeft {
            // ">" wedge pointing right
            path.move(to: CGPoint(x: w * 0.15, y: h * 0.22))
            path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.50))
            path.addLine(to: CGPoint(x: w * 0.15, y: h * 0.78))
        } else {
            // "<" wedge pointing left
            path.move(to: CGPoint(x: w * 0.85, y: h * 0.22))
            path.addLine(to: CGPoint(x: w * 0.12, y: h * 0.50))
            path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.78))
        }
        return path
    }
}

// MARK: - Mascot Star / Sparkle Eye Shape (✧ / ★) for Celebration & Charging
struct MascotStarEyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let rx = rect.width * 0.5
        let ry = rect.height * 0.5
        let inner = 0.28
        
        path.move(to: CGPoint(x: cx, y: cy - ry))
        path.addQuadCurve(to: CGPoint(x: cx + rx, y: cy), control: CGPoint(x: cx + rx * inner, y: cy - ry * inner))
        path.addQuadCurve(to: CGPoint(x: cx, y: cy + ry), control: CGPoint(x: cx + rx * inner, y: cy + ry * inner))
        path.addQuadCurve(to: CGPoint(x: cx - rx, y: cy), control: CGPoint(x: cx - rx * inner, y: cy + ry * inner))
        path.addQuadCurve(to: CGPoint(x: cx, y: cy - ry), control: CGPoint(x: cx - rx * inner, y: cy - ry * inner))
        path.closeSubpath()
        return path
    }
}

// MARK: - Mascot Sleepy / Low Battery Eye Shape (- -)
struct MascotSleepyEyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: 0, y: h * 0.55))
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.55),
            control1: CGPoint(x: w * 0.3, y: h * 0.48),
            control2: CGPoint(x: w * 0.7, y: h * 0.48)
        )
        return path
    }
}

// MARK: - Music Vibe Expressions (Lively cycling while listening to music)
enum MusicVibeState: CaseIterable {
    case happySmile     // ⌒ ⌒
    case wideEyes       // ● ●
    case leftWink       // ⌒ ●
    case rightWink      // ● ⌒
    case chillVibe      // ◡ ◡
}

// MARK: - Notch Mascot Eyes View (Compact Pill & Embedded)
struct NotchMascotEyesView: View {
    let state: MascotEyeState
    var eyeSize: CGSize = CGSize(width: 5.2, height: 9.5)
    var spacing: CGFloat = 4.2
    
    @State private var isBlinking: Bool = false
    @State private var musicBounce: Bool = false
    @State private var musicVibeState: MusicVibeState = .happySmile
    @State private var breakGlance: Bool = false
    @State private var zenBreath: Bool = false
    @State private var celebratePulse: Bool = false
    @State private var glanceOffset: CGFloat = 0
    @State private var pupilLookOffset: CGSize = .zero
    @State private var breathingPulse: Bool = false
    @State private var starTwinkle: Bool = false
    @State private var notesReadingOffset: CGFloat = 0
    
    // Natural randomized timer intervals
    private let blinkTimer = Timer.publish(every: 2.9, on: .main, in: .common).autoconnect()
    private let glanceTimer = Timer.publish(every: 4.4, on: .main, in: .common).autoconnect()
    private let breakTimer = Timer.publish(every: 2.2, on: .main, in: .common).autoconnect()
    private let musicVibeTimer = Timer.publish(every: 2.7, on: .main, in: .common).autoconnect()
    private let notesScanTimer = Timer.publish(every: 1.3, on: .main, in: .common).autoconnect()
    
    init(
        state: MascotEyeState,
        eyeSize: CGSize = CGSize(width: 5.2, height: 9.5),
        spacing: CGFloat = 4.2
    ) {
        self.state = state
        self.eyeSize = eyeSize
        self.spacing = spacing
    }
    
    // Warm luminous ivory colors matching LogoNotchify
    private let eyeWarmFill = Color(red: 1.0, green: 0.97, blue: 0.90)
    private let eyeInnerGleam = Color.white
    private let eyeGlowColor = Color(red: 1.0, green: 0.82, blue: 0.38)
    private let chargingGreenColor = Color(red: 0.40, green: 0.95, blue: 0.25)
    
    var body: some View {
        HStack(spacing: spacing) {
            singleEyeView(isLeft: true)
            singleEyeView(isLeft: false)
        }
        .offset(x: glanceOffset + notesReadingOffset)
        .offset(y: eyeYOffset)
        .scaleEffect(
            celebratePulse
                ? 1.20
                : (breathingPulse ? 1.04 : 0.97)
        )
        .rotationEffect(.degrees(overallRotation))
        .onReceive(blinkTimer) { _ in
            triggerNaturalBlink()
        }
        .onReceive(glanceTimer) { _ in
            triggerCuriousGlance()
        }
        .onReceive(breakTimer) { _ in
            if case .pomodoro(.shortBreak, _) = state {
                withAnimation(.easeInOut(duration: 0.35)) {
                    breakGlance.toggle()
                }
            }
        }
        .onReceive(musicVibeTimer) { _ in
            if isMusicActive {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.68)) {
                    cycleMusicVibe()
                }
            }
        }
        .onReceive(notesScanTimer) { _ in
            if case .tabVibe(let tab) = state, tab == .notes {
                withAnimation(.easeInOut(duration: 0.45)) {
                    notesReadingOffset = (notesReadingOffset == -1.2) ? 1.2 : -1.2
                }
            } else {
                notesReadingOffset = 0
            }
        }
        .onAppear {
            setupInitialAnimations()
        }
        .onChange(of: state) { newState in
            handleStateChange(to: newState)
        }
    }
    
    // MARK: - Single Eye Rendering
    @ViewBuilder
    private func singleEyeView(isLeft: Bool) -> some View {
        Group {
            switch state {
            case .petted:
                // Squinting / cute eye "> <"
                squintEyeView(isLeft: isLeft)
                
            case .timesUp:
                // Celebration Star eyes ★ ★
                starEyeView(isCelebration: true)
                
            case .batteryCharging:
                // Energized sparkle star eyes ✧ ✧
                starEyeView(isCelebration: false)
                
            case .batteryLow:
                // Sleepy / tired eyelids - -
                sleepyEyeView()
                
            case .videoRecording:
                // Inquisitive sentinel eye looking up towards the webcam
                openCapsuleEyeView(isLeft: isLeft, lookOffset: CGSize(width: 0, height: -0.7))
                
            case .music(let isPlaying):
                if isPlaying {
                    musicEyeView(isLeft: isLeft)
                } else {
                    // Paused: curious head-tilt, one eye open, one smiling
                    if isLeft {
                        openCapsuleEyeView(isLeft: isLeft, lookOffset: CGSize(width: -0.6, height: 0))
                    } else {
                        smilingArcEyeView()
                    }
                }
                
            case .pomodoro(let preset, _):
                pomodoroEyeView(preset: preset, isLeft: isLeft)
                
            case .tabVibe(let tab):
                tabSpecificEyeView(tab: tab, isLeft: isLeft)
                
            case .wink:
                if isLeft {
                    smilingArcEyeView()
                } else {
                    openCapsuleEyeView(isLeft: isLeft)
                }
                
            case .idle:
                openCapsuleEyeView(isLeft: isLeft, lookOffset: pupilLookOffset)
            }
        }
        .shadow(
            color: activeGlowColor.opacity(breathingPulse ? 0.85 : 0.45),
            radius: (state == .batteryCharging || state == .timesUp) ? 5 : 3,
            x: 0,
            y: 0
        )
        .shadow(
            color: activeGlowColor.opacity(0.30),
            radius: 6,
            x: 0,
            y: 0
        )
        .rotationEffect(.degrees(individualEyeRotation(isLeft: isLeft)))
    }
    
    // MARK: - Glow Color Resolution
    private var activeGlowColor: Color {
        if state == .batteryCharging {
            return chargingGreenColor
        }
        if state == .timesUp {
            return Color.yellow
        }
        return eyeGlowColor
    }
    
    // MARK: - Dynamic Music Eye Rendering
    @ViewBuilder
    private func musicEyeView(isLeft: Bool) -> some View {
        switch musicVibeState {
        case .happySmile:
            smilingArcEyeView()
        case .wideEyes:
            openCapsuleEyeView(isLeft: isLeft, lookOffset: pupilLookOffset)
        case .leftWink:
            if isLeft {
                smilingArcEyeView()
            } else {
                openCapsuleEyeView(isLeft: isLeft)
            }
        case .rightWink:
            if isLeft {
                openCapsuleEyeView(isLeft: isLeft)
            } else {
                smilingArcEyeView()
            }
        case .chillVibe:
            chillArcEyeView()
        }
    }
    
    // MARK: - Tab-Specific Expressions
    @ViewBuilder
    private func tabSpecificEyeView(tab: NotchTab, isLeft: Bool) -> some View {
        switch tab {
        case .mirror:
            // Selfie Smile (Happy arc eyes ready for photos)
            smilingArcEyeView()
            
        case .dropzone:
            // Looking down eagerly at the drop target
            openCapsuleEyeView(isLeft: isLeft, lookOffset: CGSize(width: 0, height: 0.85))
            
        case .notes:
            // Scanning eyes back and forth reading
            openCapsuleEyeView(isLeft: isLeft, lookOffset: CGSize(width: notesReadingOffset * 0.7, height: 0.1))
            
        case .weather:
            // Cheerful open eyes
            openCapsuleEyeView(isLeft: isLeft, lookOffset: pupilLookOffset)
            
        case .media:
            smilingArcEyeView()
            
        case .clipboard, .calculator, .agenda, .system, .network:
            openCapsuleEyeView(isLeft: isLeft, lookOffset: pupilLookOffset)
            
        case .pomodoro:
            openCapsuleEyeView(isLeft: isLeft, lookOffset: pupilLookOffset)
        }
    }
    
    // MARK: - Pomodoro Expressions
    @ViewBuilder
    private func pomodoroEyeView(preset: PomodoroMascotPreset, isLeft: Bool) -> some View {
        switch preset {
        case .focus:
            // Sharp focused concentration gaze
            openCapsuleEyeView(isLeft: isLeft, lookOffset: .zero)
        case .rest:
            // Zen sleep crescent
            chillArcEyeView()
        case .shortBreak:
            // Cheerful smile break
            smilingArcEyeView()
        case .custom:
            openCapsuleEyeView(isLeft: isLeft, lookOffset: pupilLookOffset)
        }
    }
    
    // MARK: - Shapes & Renderers
    @ViewBuilder
    private func smilingArcEyeView() -> some View {
        MascotEyeArcShape(flipped: false)
            .stroke(
                LinearGradient(
                    colors: [eyeWarmFill, eyeInnerGleam],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                style: StrokeStyle(lineWidth: eyeSize.width * 0.44, lineCap: .round)
            )
            .frame(width: eyeSize.width * 1.25, height: eyeSize.height * 0.85)
    }
    
    @ViewBuilder
    private func chillArcEyeView() -> some View {
        MascotEyeArcShape(flipped: true)
            .stroke(
                LinearGradient(
                    colors: [eyeWarmFill.opacity(zenBreath ? 1.0 : 0.75), eyeGlowColor.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                style: StrokeStyle(lineWidth: eyeSize.width * 0.42, lineCap: .round)
            )
            .frame(width: eyeSize.width * 1.2, height: eyeSize.height * 0.8)
            .scaleEffect(zenBreath ? 1.06 : 0.96)
    }
    
    @ViewBuilder
    private func squintEyeView(isLeft: Bool) -> some View {
        MascotSquintEyeShape(isLeft: isLeft)
            .stroke(
                LinearGradient(
                    colors: [eyeInnerGleam, eyeWarmFill],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                style: StrokeStyle(lineWidth: eyeSize.width * 0.42, lineCap: .round, lineJoin: .round)
            )
            .frame(width: eyeSize.width * 1.15, height: eyeSize.height * 0.82)
    }
    
    @ViewBuilder
    private func starEyeView(isCelebration: Bool) -> some View {
        MascotStarEyeShape()
            .fill(
                RadialGradient(
                    colors: isCelebration
                        ? [Color.white, Color(red: 1.0, green: 0.9, blue: 0.3)]
                        : [Color.white, chargingGreenColor],
                    center: .center,
                    startRadius: 0,
                    endRadius: eyeSize.height * 0.55
                )
            )
            .frame(width: eyeSize.width * 1.35, height: eyeSize.height * 1.1)
            .scaleEffect(starTwinkle ? 1.15 : 0.92)
            .rotationEffect(.degrees(starTwinkle ? 12 : -12))
    }
    
    @ViewBuilder
    private func sleepyEyeView() -> some View {
        MascotSleepyEyeShape()
            .stroke(
                LinearGradient(
                    colors: [eyeWarmFill.opacity(0.8), eyeWarmFill.opacity(0.5)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: eyeSize.width * 0.42, lineCap: .round)
            )
            .frame(width: eyeSize.width * 1.2, height: eyeSize.height * 0.7)
    }
    
    @ViewBuilder
    private func openCapsuleEyeView(isLeft: Bool, lookOffset: CGSize = .zero) -> some View {
        ZStack {
            // Base Capsule with dynamic light gradient center
            Capsule()
                .fill(
                    RadialGradient(
                        colors: [eyeInnerGleam, eyeWarmFill],
                        center: UnitPoint(
                            x: 0.5 + Double(lookOffset.width * 0.28),
                            y: 0.5 + Double(lookOffset.height * 0.28)
                        ),
                        startRadius: 0,
                        endRadius: eyeSize.height * 0.5
                    )
                )
            
            // Lively shining sparkle highlight (eye gleam dot)
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: eyeSize.width * 0.40, height: eyeSize.width * 0.40)
                .offset(
                    x: (isLeft ? -eyeSize.width * 0.12 : eyeSize.width * 0.12) + lookOffset.width * 1.4,
                    y: -eyeSize.height * 0.18 + lookOffset.height * 1.4
                )
        }
        .frame(
            width: eyeSize.width * eyeScaleX(isLeft: isLeft),
            height: max(1.2, eyeSize.height * (isBlinking ? 0.10 : eyeScaleY(isLeft: isLeft)))
        )
    }
    
    // MARK: - State Computed Properties
    private var isMusicActive: Bool {
        if case .music(let isPlaying) = state {
            return isPlaying
        }
        return false
    }
    
    private var isRestActive: Bool {
        if case .pomodoro(.rest, _) = state {
            return true
        }
        return false
    }
    
    private var eyeYOffset: CGFloat {
        if isMusicActive {
            return musicBounce ? -2.2 : 0.6
        }
        if state == .timesUp {
            return celebratePulse ? -3.0 : 0
        }
        return 0
    }
    
    private var overallRotation: Double {
        switch state {
        case .music(let playing):
            return playing ? (musicBounce ? -3.5 : 3.5) : -2.0
        case .pomodoro(.focus, let isPaused):
            return isPaused ? 6.0 : 0
        case .pomodoro(.shortBreak, _):
            return breakGlance ? 3.0 : -3.0
        case .pomodoro(.custom, let isPaused):
            return isPaused ? 4.0 : 0
        case .wink:
            return 3.0
        case .tabVibe(let tab):
            return (tab == .mirror) ? 2.5 : 0
        default:
            return 0
        }
    }
    
    private func eyeScaleX(isLeft: Bool) -> CGFloat {
        switch state {
        case .pomodoro(.focus, _):
            return 1.15 // Determined wide gaze
        case .timesUp:
            return 1.25
        case .videoRecording:
            return 1.10
        default:
            return 1.0
        }
    }
    
    private func eyeScaleY(isLeft: Bool) -> CGFloat {
        switch state {
        case .pomodoro(.focus, _):
            return 0.78 // Narrowed concentration focus
        case .timesUp:
            return 1.20
        case .batteryLow:
            return 0.65 // Heavy eyelids
        default:
            return 1.0
        }
    }
    
    private func individualEyeRotation(isLeft: Bool) -> Double {
        switch state {
        case .pomodoro(.focus, _):
            return isLeft ? 5.5 : -5.5
        case .pomodoro(.shortBreak, _):
            return breakGlance ? (isLeft ? 2 : 4) : (isLeft ? -4 : -2)
        default:
            return isLeft ? -3.0 : 3.0
        }
    }
    
    // MARK: - Natural Animations & Micro-Life Engine
    private func cycleMusicVibe() {
        let sequence: [MusicVibeState] = [.happySmile, .wideEyes, .leftWink, .happySmile, .rightWink, .wideEyes, .chillVibe]
        if let currentIdx = sequence.firstIndex(of: musicVibeState) {
            let nextIdx = (currentIdx + 1) % sequence.count
            musicVibeState = sequence[nextIdx]
        } else {
            musicVibeState = .happySmile
        }
    }
    
    private func triggerNaturalBlink() {
        guard !isBlinking && !isRestActive && state != .timesUp && state != .petted else { return }
        if isMusicActive && musicVibeState != .wideEyes { return }
        
        withAnimation(.easeInOut(duration: 0.10)) {
            isBlinking = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.65)) {
                self.isBlinking = false
            }
            
            // 25% chance of realistic double-blink
            if Double.random(in: 0...1) < 0.25 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.easeInOut(duration: 0.08)) {
                        self.isBlinking = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                        withAnimation(.spring(response: 0.20, dampingFraction: 0.65)) {
                            self.isBlinking = false
                        }
                    }
                }
            }
        }
    }
    
    private func triggerCuriousGlance() {
        guard state == .idle || (isMusicActive && musicVibeState == .wideEyes) else { return }
        
        // Randomly pick: glance left (towards clock), glance right (towards battery), or center
        let choices: [(offset: CGFloat, pupil: CGSize)] = [
            (-1.8, CGSize(width: -0.85, height: 0)), // Look left
            (1.8, CGSize(width: 0.85, height: 0)),   // Look right
            (0, CGSize(width: 0, height: 0.4)),      // Look slightly down
            (0, .zero)                               // Look straight ahead
        ]
        
        guard let choice = choices.randomElement() else { return }
        
        withAnimation(.easeInOut(duration: 0.35)) {
            glanceOffset = choice.offset
            pupilLookOffset = choice.pupil
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            withAnimation(.easeInOut(duration: 0.35)) {
                self.glanceOffset = 0
                self.pupilLookOffset = .zero
            }
        }
    }
    
    private func setupInitialAnimations() {
        // Subtle constant breathing
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            breathingPulse = true
        }
        // Twinkle for stars
        withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
            starTwinkle = true
        }
        handleStateChange(to: state)
    }
    
    private func handleStateChange(to newState: MascotEyeState) {
        switch newState {
        case .music(let isPlaying):
            if isPlaying {
                withAnimation(.easeInOut(duration: 0.38).repeatForever(autoreverses: true)) {
                    musicBounce = true
                }
            } else {
                musicBounce = false
                musicVibeState = .happySmile
            }
        case .pomodoro(.rest, _):
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                zenBreath = true
            }
        case .timesUp:
            withAnimation(.easeInOut(duration: 0.26).repeatForever(autoreverses: true)) {
                celebratePulse = true
            }
        default:
            musicBounce = false
            zenBreath = false
            celebratePulse = false
        }
    }
}

// MARK: - Notch Pebble Body View (Pure 2D Vector)
struct NotchPebbleBodyView: View {
    var size: CGFloat = 32
    var isHovered: Bool = false
    
    init(size: CGFloat = 32, isHovered: Bool = false) {
        self.size = size
        self.isHovered = isHovered
    }
    
    var body: some View {
        ZStack {
            // 1. Base Obsidian Glass Pebble
            NotchPebbleShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.14, blue: 0.18),
                            Color(red: 0.05, green: 0.06, blue: 0.08),
                            Color(red: 0.02, green: 0.03, blue: 0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 2. Left Electric Lime-Green Rim Glow (From LogoNotchify)
            NotchPebbleShape()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.38, green: 0.95, blue: 0.18).opacity(0.85),
                            Color(red: 0.28, green: 0.85, blue: 0.12).opacity(0.40),
                            Color.clear
                        ],
                        center: .init(x: 0.08, y: 0.58),
                        startRadius: 1,
                        endRadius: size * 0.65
                    )
                )
                .blendMode(.screen)
            
            // 3. Bottom-Right Amber/Orange Rim Glow (From LogoNotchify)
            NotchPebbleShape()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.58, blue: 0.0).opacity(0.92),
                            Color(red: 1.0, green: 0.38, blue: 0.0).opacity(0.45),
                            Color.clear
                        ],
                        center: .init(x: 0.88, y: 0.86),
                        startRadius: 1,
                        endRadius: size * 0.68
                    )
                )
                .blendMode(.screen)
            
            // 4. Specular Top Glass Reflection
            NotchPebbleGlossShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.42),
                            Color.white.opacity(0.12),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(size * 0.04)
            
            // 5. Crisp Outer Glass Rim Stroke
            NotchPebbleShape()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        }
        .frame(width: size, height: size * 0.94)
        .shadow(color: Color.black.opacity(0.45), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Notch Mascot Companion View (Extended Mode Header Bar)
struct NotchMascotCompanionView: View {
    @ObservedObject var viewModel: NotchViewModel
    var size: CGFloat = 30
    
    @State private var isHovered: Bool = false
    @State private var isSquished: Bool = false
    @State private var isPetted: Bool = false
    @State private var breathing: Bool = false
    
    init(viewModel: NotchViewModel, size: CGFloat = 30) {
        self.viewModel = viewModel
        self.size = size
    }
    
    // Resolve dynamic mascot state based on current activity & context
    private var currentMascotState: MascotEyeState {
        if isPetted {
            return .petted
        }
        if viewModel.showTimesUp {
            return .timesUp
        }
        if CameraMirrorManager.shared.isRecordingVideo {
            return .videoRecording
        }
        if viewModel.isPlaying {
            return .music(isPlaying: true)
        }
        if viewModel.isPomodoroActive {
            let totalMinutes = Int(round(viewModel.pomodoroTotal / 60))
            let preset = PomodoroMascotPreset.from(totalMinutes: totalMinutes)
            return .pomodoro(preset: preset, isPaused: viewModel.isPomodoroPaused)
        }
        if viewModel.batteryLevel <= 20 && !viewModel.isBatteryCharging {
            return .batteryLow
        }
        if viewModel.isBatteryCharging {
            return .batteryCharging
        }
        return .tabVibe(tab: viewModel.selectedTab)
    }
    
    var body: some View {
        Button(action: {
            performInteractiveReaction()
        }) {
            ZStack {
                // 2D Pebble Body
                NotchPebbleBodyView(size: size, isHovered: isHovered)
                
                // Embedded Mascot Eyes
                NotchMascotEyesView(
                    state: currentMascotState,
                    eyeSize: CGSize(
                        width: size * (isHovered ? 0.18 : 0.16),
                        height: size * (isHovered ? 0.30 : 0.28)
                    ),
                    spacing: size * 0.12
                )
                .offset(y: -size * 0.02)
            }
            .scaleEffect(
                isSquished
                    ? CGSize(width: 1.25, height: 0.78)
                    : (isHovered
                       ? CGSize(width: 1.08, height: 1.08)
                       : (breathing ? CGSize(width: 1.02, height: 1.02) : CGSize(width: 0.98, height: 0.98)))
            )
            .rotationEffect(.degrees(viewModel.isPlaying ? (breathing ? -2.5 : 2.5) : (isHovered ? -1.5 : 0)))
            .animation(.spring(response: 0.32, dampingFraction: 0.55), value: isSquished)
            .animation(.easeInOut(duration: 0.18), value: isHovered)
            .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true), value: viewModel.isPlaying)
        }
        .buttonStyle(PlainButtonStyle())
        .help(LanguageManager.tr("Notchify Companion"))
        .onHover { h in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                isHovered = h
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }
    
    private func performInteractiveReaction() {
        // Haptic feedback
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        NSSound(named: "Tink")?.play()
        
        // Squish & Pet bounce
        isSquished = true
        isPetted = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.50)) {
                self.isSquished = false
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation(.easeInOut(duration: 0.25)) {
                self.isPetted = false
            }
        }
    }
}
