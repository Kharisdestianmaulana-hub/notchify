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
    case deepIdle
    case wakeUp
    case batteryLow
    case batteryCharging
    case music(isPlaying: Bool, isNewTrack: Bool = false)
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
            // ">" soft wedge pointing right
            path.move(to: CGPoint(x: w * 0.15, y: h * 0.22))
            path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.50))
            path.addLine(to: CGPoint(x: w * 0.15, y: h * 0.78))
        } else {
            // "<" soft wedge pointing left
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

// MARK: - Internal Real-Time Living Expression
enum LivingExpression: Equatable {
    case openLookCenter          // (● ●)
    case glanceClock             // (◄ ◄) Looking at Clock
    case glanceBattery           // (► ►) Looking at Battery
    case glanceDown              // (▼ ▼) Looking Down (DropZone)
    case happySmile              // (⌒ ⌒) Friendly Smile
    case zenRelax                // (◡ ◡) Zen Relax
    case winkLeft                // (⌒ ●)
    case winkRight               // (● ⌒)
    case sleepy                  // (- -)
    case deepSleep               // (◡ ◡) Sleeping
    case wakeUpShock             // (⊙ ⊙) Surprise Wakeup
    case celebrationHop          // (✧ ✧) Track change / Win
    case musicSmile              // (⌒ ⌒)
    case musicWide               // (● ●)
    case musicWinkLeft           // (⌒ ●)
    case musicWinkRight          // (● ⌒)
    case musicZen                // (◡ ◡)
    case musicPaused             // (● ⌒) Curious tilt
    case pettedSquint            // (> <)
    case sentinelWebcam          // (⊙ ⊙) Watching camera
    case pomodoroFocus           // (•̀ ⤙ •́)
}

// MARK: - Notch Mascot Eyes View (Compact Pill & Embedded)
struct NotchMascotEyesView: View {
    let state: MascotEyeState
    var eyeSize: CGSize = CGSize(width: 5.2, height: 9.5)
    var spacing: CGFloat = 4.2
    var cursorOffset: CGSize = .zero // Normalized cursor vector (-1...1, -1...1)
    
    // Living expression state
    @State private var currentExpression: LivingExpression = .openLookCenter
    @State private var isBlinking: Bool = false
    @State private var breathingPulse: Bool = false
    @State private var starTwinkle: Bool = false
    @State private var musicBeatBounce: Bool = false
    @State private var musicVibeIndex: Int = 0
    @State private var idleCycleIndex: Int = 0
    @State private var notesScanOffset: CGFloat = 0
    @State private var lastInteractionCheck: Date = Date()
    @State private var wakeUpJump: CGFloat = 0
    
    // Real-Time Timers (Agile & Apple-like)
    // Idle transitions every 2.8s (range 2.5 - 3.5s)
    private let idleTimer = Timer.publish(every: 2.85, on: .main, in: .common).autoconnect()
    // Music groove runs lively at 1.05s per beat
    private let musicTimer = Timer.publish(every: 1.08, on: .main, in: .common).autoconnect()
    // Organic blinking timer
    private let blinkTimer = Timer.publish(every: 2.8, on: .main, in: .common).autoconnect()
    // Notes reading scanner
    private let notesTimer = Timer.publish(every: 1.15, on: .main, in: .common).autoconnect()
    
    init(
        state: MascotEyeState,
        eyeSize: CGSize = CGSize(width: 5.2, height: 9.5),
        spacing: CGFloat = 4.2,
        cursorOffset: CGSize = .zero
    ) {
        self.state = state
        self.eyeSize = eyeSize
        self.spacing = spacing
        self.cursorOffset = cursorOffset
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
        .offset(x: notesScanOffset)
        .offset(y: currentEyeYOffset + wakeUpJump)
        .scaleEffect(
            currentExpression == .wakeUpShock
                ? 1.18
                : (currentExpression == .celebrationHop
                   ? 1.22
                   : (breathingPulse ? 1.03 : 0.97))
        )
        .rotationEffect(.degrees(currentOverallRotation))
        .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.72, blendDuration: 0.08), value: currentExpression)
        .onReceive(idleTimer) { _ in
            advanceLivingIdleLoop()
        }
        .onReceive(musicTimer) { _ in
            advanceLivingMusicLoop()
        }
        .onReceive(blinkTimer) { _ in
            triggerOrganicBlink()
        }
        .onReceive(notesTimer) { _ in
            if case .tabVibe(let tab) = state, tab == .notes {
                withAnimation(.easeInOut(duration: 0.4)) {
                    notesScanOffset = (notesScanOffset == -1.4) ? 1.4 : -1.4
                }
            } else {
                notesScanOffset = 0
            }
        }
        .onAppear {
            setupInitialLivingMotion()
        }
        .onChange(of: state) { newState in
            handleStateTransition(to: newState)
        }
    }
    
    // MARK: - Single Eye Rendering
    @ViewBuilder
    private func singleEyeView(isLeft: Bool) -> some View {
        Group {
            switch currentExpression {
            case .pettedSquint:
                squintEyeView(isLeft: isLeft)
                
            case .celebrationHop:
                starEyeView(isCelebration: true)
                
            case .wakeUpShock:
                // Big wide surprised eyes (⊙ ⊙)
                openCapsuleEyeView(isLeft: isLeft, lookOffset: .zero, forceWide: true)
                
            case .sleepy:
                sleepyEyeView()
                
            case .deepSleep:
                chillArcEyeView(zenSleep: true)
                
            case .zenRelax, .musicZen:
                chillArcEyeView(zenSleep: false)
                
            case .happySmile, .musicSmile:
                smilingArcEyeView()
                
            case .winkLeft:
                if isLeft {
                    smilingArcEyeView()
                } else {
                    openCapsuleEyeView(isLeft: isLeft, lookOffset: computedPupilOffset)
                }
                
            case .winkRight:
                if isLeft {
                    openCapsuleEyeView(isLeft: isLeft, lookOffset: computedPupilOffset)
                } else {
                    smilingArcEyeView()
                }
                
            case .glanceClock:
                openCapsuleEyeView(isLeft: isLeft, lookOffset: CGSize(width: -0.9, height: 0))
                
            case .glanceBattery:
                openCapsuleEyeView(isLeft: isLeft, lookOffset: CGSize(width: 0.9, height: 0))
                
            case .glanceDown:
                openCapsuleEyeView(isLeft: isLeft, lookOffset: CGSize(width: 0, height: 0.85))
                
            case .musicWinkLeft:
                if isLeft { smilingArcEyeView() } else { openCapsuleEyeView(isLeft: isLeft, lookOffset: computedPupilOffset) }
                
            case .musicWinkRight:
                if isLeft { openCapsuleEyeView(isLeft: isLeft, lookOffset: computedPupilOffset) } else { smilingArcEyeView() }
                
            case .musicPaused:
                if isLeft { openCapsuleEyeView(isLeft: isLeft, lookOffset: CGSize(width: -0.7, height: 0)) } else { smilingArcEyeView() }
                
            case .sentinelWebcam:
                openCapsuleEyeView(isLeft: isLeft, lookOffset: CGSize(width: 0, height: -0.75))
                
            case .pomodoroFocus:
                openCapsuleEyeView(isLeft: isLeft, lookOffset: .zero, isFocusedGaze: true)
                
            case .openLookCenter, .musicWide:
                openCapsuleEyeView(isLeft: isLeft, lookOffset: computedPupilOffset)
            }
        }
        .shadow(
            color: activeGlowColor.opacity(breathingPulse ? 0.85 : 0.45),
            radius: (currentExpression == .celebrationHop || state == .batteryCharging) ? 5 : 3,
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
    
    // MARK: - Dynamic Pupil Offset Calculation
    private var computedPupilOffset: CGSize {
        // If cursor tracking is provided (mode extend)
        if cursorOffset != .zero {
            return CGSize(
                width: max(-1.0, min(1.0, cursorOffset.width)),
                height: max(-0.9, min(0.9, cursorOffset.height))
            )
        }
        
        switch currentExpression {
        case .glanceClock:
            return CGSize(width: -0.9, height: 0)
        case .glanceBattery:
            return CGSize(width: 0.9, height: 0)
        case .glanceDown:
            return CGSize(width: 0, height: 0.8)
        case .sentinelWebcam:
            return CGSize(width: 0, height: -0.75)
        default:
            return .zero
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
    private func chillArcEyeView(zenSleep: Bool) -> some View {
        MascotEyeArcShape(flipped: true)
            .stroke(
                LinearGradient(
                    colors: [eyeWarmFill.opacity(zenSleep ? 0.85 : 1.0), eyeGlowColor.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                style: StrokeStyle(lineWidth: eyeSize.width * 0.42, lineCap: .round)
            )
            .frame(width: eyeSize.width * 1.2, height: eyeSize.height * 0.8)
            .scaleEffect(zenSleep ? (breathingPulse ? 1.08 : 0.94) : 1.0)
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
                    colors: [eyeWarmFill.opacity(0.85), eyeWarmFill.opacity(0.5)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: eyeSize.width * 0.42, lineCap: .round)
            )
            .frame(width: eyeSize.width * 1.2, height: eyeSize.height * 0.7)
    }
    
    @ViewBuilder
    private func openCapsuleEyeView(
        isLeft: Bool,
        lookOffset: CGSize,
        forceWide: Bool = false,
        isFocusedGaze: Bool = false
    ) -> some View {
        ZStack {
            // Base Capsule with dynamic light gradient center that shifts focal center
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
            width: eyeSize.width * (forceWide ? 1.22 : (isFocusedGaze ? 1.15 : 1.0)),
            height: max(1.2, eyeSize.height * (isBlinking ? 0.08 : (isFocusedGaze ? 0.76 : (forceWide ? 1.18 : 1.0))))
        )
    }
    
    // MARK: - Dynamic Motion & Rotation Offsets
    private var currentEyeYOffset: CGFloat {
        if isMusicActive {
            return musicBeatBounce ? -2.6 : 0.8
        }
        if currentExpression == .celebrationHop {
            return -4.5
        }
        if currentExpression == .wakeUpShock {
            return -3.0
        }
        return 0
    }
    
    private var currentOverallRotation: Double {
        if isMusicActive {
            return musicBeatBounce ? -3.5 : 3.5
        }
        switch currentExpression {
        case .musicPaused:
            return 4.0
        case .winkLeft:
            return 2.5
        case .winkRight:
            return -2.5
        case .pomodoroFocus:
            return 0
        case .glanceClock:
            return -1.5
        case .glanceBattery:
            return 1.5
        default:
            return 0
        }
    }
    
    private func individualEyeRotation(isLeft: Bool) -> Double {
        if currentExpression == .pomodoroFocus {
            return isLeft ? 5.5 : -5.5
        }
        return isLeft ? -3.0 : 3.0
    }
    
    private var activeGlowColor: Color {
        if state == .batteryCharging {
            return chargingGreenColor
        }
        if state == .timesUp || currentExpression == .celebrationHop {
            return Color.yellow
        }
        return eyeGlowColor
    }
    
    private var isMusicActive: Bool {
        if case .music(let isPlaying, _) = state {
            return isPlaying
        }
        return false
    }
    
    // MARK: - Real-Time Choreography Engines
    private func advanceLivingIdleLoop() {
        guard !isMusicActive, state != .petted, state != .videoRecording else { return }
        
        if state == .wakeUp {
            triggerWakeUpPerk()
            return
        }
        
        if state == .deepIdle {
            withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.70)) {
                currentExpression = .deepSleep
            }
            return
        }
        
        if state == .batteryLow {
            withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.70)) {
                currentExpression = .sleepy
            }
            return
        }
        
        if state == .batteryCharging {
            withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.65)) {
                currentExpression = .celebrationHop
            }
            return
        }
        
        if state == .timesUp {
            withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.55)) {
                currentExpression = .celebrationHop
            }
            return
        }
        
        if case .tabVibe(let tab) = state {
            handleTabVibe(tab: tab)
            return
        }
        
        if case .pomodoro(let preset, let isPaused) = state {
            if isPaused {
                withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.70)) {
                    currentExpression = .openLookCenter
                }
            } else {
                switch preset {
                case .focus:
                    currentExpression = .pomodoroFocus
                case .shortBreak:
                    currentExpression = (idleCycleIndex % 2 == 0) ? .happySmile : .openLookCenter
                case .rest:
                    currentExpression = .deepSleep
                case .custom:
                    currentExpression = .openLookCenter
                }
            }
            return
        }
        
        // Idle Sequence Loop (2.5 - 3.5s tempo, natural Apple flow)
        let hour = Calendar.current.component(.hour, from: Date())
        let isLateNight = (hour >= 22 || hour < 6)
        
        // Late night favors soothing zen and calm eyes
        let idlePool: [LivingExpression] = isLateNight
            ? [.openLookCenter, .zenRelax, .glanceClock, .zenRelax, .happySmile, .deepSleep]
            : [
                .openLookCenter,
                .glanceClock,
                .happySmile,
                .openLookCenter,
                .glanceBattery,
                .winkLeft,
                .zenRelax,
                .openLookCenter,
                .winkRight,
                .happySmile
            ]
        
        idleCycleIndex = (idleCycleIndex + 1) % idlePool.count
        let nextExp = idlePool[idleCycleIndex]
        
        withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.72, blendDuration: 0.08)) {
            currentExpression = nextExp
        }
    }
    
    private func advanceLivingMusicLoop() {
        guard isMusicActive else { return }
        
        // Check new track celebration override
        if case .music(_, let isNewTrack) = state, isNewTrack {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                currentExpression = .celebrationHop
            }
            return
        }
        
        // Alternate bounce
        withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.65)) {
            musicBeatBounce.toggle()
        }
        
        // Cycle lively music vibe expressions (1.0 - 1.2s per beat)
        let musicPool: [LivingExpression] = [
            .musicSmile,
            .musicWide,
            .musicWinkLeft,
            .musicSmile,
            .musicWinkRight,
            .musicZen
        ]
        
        musicVibeIndex = (musicVibeIndex + 1) % musicPool.count
        let nextVibe = musicPool[musicVibeIndex]
        
        withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.70)) {
            currentExpression = nextVibe
        }
    }
    
    private func handleTabVibe(tab: NotchTab) {
        switch tab {
        case .mirror:
            withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.72)) {
                currentExpression = .happySmile // Selfie ready!
            }
        case .dropzone:
            withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.72)) {
                currentExpression = .glanceDown // Anticipating files
            }
        case .notes:
            withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.72)) {
                currentExpression = .openLookCenter
            }
        case .weather:
            withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.72)) {
                currentExpression = (idleCycleIndex % 2 == 0) ? .openLookCenter : .happySmile
            }
        case .media:
            withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.72)) {
                currentExpression = .happySmile
            }
        default:
            withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.72)) {
                currentExpression = .openLookCenter
            }
        }
    }
    
    private func triggerWakeUpPerk() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.50)) {
            wakeUpJump = -4.0
            currentExpression = .wakeUpShock
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.60)) {
                self.wakeUpJump = 0
            }
        }
        
        // Follow up with a quick double-blink to clear sleep
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            self.triggerOrganicBlink()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.72)) {
                    self.currentExpression = .happySmile
                }
            }
        }
    }
    
    private func triggerOrganicBlink() {
        guard !isBlinking, currentExpression != .deepSleep, currentExpression != .pettedSquint else { return }
        
        withAnimation(.easeInOut(duration: 0.09)) {
            isBlinking = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.spring(response: 0.20, dampingFraction: 0.65)) {
                self.isBlinking = false
            }
            
            // 25% chance of realistic double-blink
            if Double.random(in: 0...1) < 0.25 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
                    withAnimation(.easeInOut(duration: 0.08)) {
                        self.isBlinking = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                        withAnimation(.spring(response: 0.18, dampingFraction: 0.65)) {
                            self.isBlinking = false
                        }
                    }
                }
            }
        }
    }
    
    private func setupInitialLivingMotion() {
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            breathingPulse = true
        }
        withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
            starTwinkle = true
        }
        handleStateTransition(to: state)
    }
    
    private func handleStateTransition(to newState: MascotEyeState) {
        switch newState {
        case .petted:
            withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.55)) {
                currentExpression = .pettedSquint
            }
        case .wakeUp:
            triggerWakeUpPerk()
        case .deepIdle:
            withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.70)) {
                currentExpression = .deepSleep
            }
        case .videoRecording:
            withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.72)) {
                currentExpression = .sentinelWebcam
            }
        case .timesUp:
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                currentExpression = .celebrationHop
            }
        case .music(let playing, let isNewTrack):
            if isNewTrack {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                    currentExpression = .celebrationHop
                }
            } else if playing {
                withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.70)) {
                    currentExpression = .musicSmile
                }
            } else {
                withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.72)) {
                    currentExpression = .musicPaused
                }
            }
        default:
            advanceLivingIdleLoop()
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
    @State private var cursorLookVector: CGSize = .zero
    
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
        if viewModel.mascotWakeUpTrigger {
            return .wakeUp
        }
        if viewModel.isDeepIdle {
            return .deepIdle
        }
        if viewModel.isPlaying {
            return .music(isPlaying: true, isNewTrack: viewModel.mascotNewTrackCelebration)
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
                
                // Embedded Mascot Eyes with cursor tracking
                NotchMascotEyesView(
                    state: currentMascotState,
                    eyeSize: CGSize(
                        width: size * (isHovered ? 0.18 : 0.16),
                        height: size * (isHovered ? 0.30 : 0.28)
                    ),
                    spacing: size * 0.12,
                    cursorOffset: cursorLookVector
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
            .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.60), value: isSquished)
            .animation(.interactiveSpring(response: 0.30, dampingFraction: 0.70), value: isHovered)
            .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true), value: viewModel.isPlaying)
        }
        .buttonStyle(PlainButtonStyle())
        .help(LanguageManager.tr("Notchify Companion"))
        .onHover { h in
            viewModel.notifyUserActivity()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                isHovered = h
                if h {
                    cursorLookVector = .zero // Look straight at user when directly hovered
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathing = true
            }
            startMouseTracking()
        }
    }
    
    private func startMouseTracking() {
        // Track local mouse movements to smoothly orient mascot eyes
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { event in
            if self.viewModel.isExpanded && !self.isHovered {
                let mouseX = event.locationInWindow.x
                let mouseY = event.locationInWindow.y
                let screenWidth = NSScreen.main?.frame.width ?? 1440
                
                // Normalize relative to notch right header
                let normX = (mouseX - (screenWidth * 0.5)) / (screenWidth * 0.3)
                let normY = (mouseY - 40) / 300.0
                
                let clampedX = CGFloat(max(-1.0, min(1.0, normX)))
                let clampedY = CGFloat(max(-0.9, min(0.9, -normY)))
                
                withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.75)) {
                    self.cursorLookVector = CGSize(width: clampedX * 0.85, height: clampedY * 0.85)
                }
            }
            return event
        }
    }
    
    private func performInteractiveReaction() {
        viewModel.notifyUserActivity()
        
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
