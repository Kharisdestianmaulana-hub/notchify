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
    case music(isPlaying: Bool)
    case pomodoro(preset: PomodoroMascotPreset, isPaused: Bool)
    case timesUp
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
    var flipped: Bool // false: ^_^ happy, true: ◡ zen/sleepy
    
    init(flipped: Bool = false) {
        self.flipped = flipped
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        if flipped {
            // Zen / Sleeping eye (crescent curving downwards)
            path.move(to: CGPoint(x: 0, y: h * 0.35))
            path.addQuadCurve(to: CGPoint(x: w, y: h * 0.35), control: CGPoint(x: w * 0.5, y: h * 0.95))
        } else {
            // Happy smiling eye (anime/kawaii ^ curve)
            path.move(to: CGPoint(x: 0, y: h * 0.75))
            path.addQuadCurve(to: CGPoint(x: w, y: h * 0.75), control: CGPoint(x: w * 0.5, y: h * 0.08))
        }
        return path
    }
}

// MARK: - Notch Mascot Eyes View (Compact Pill & Embedded)
struct NotchMascotEyesView: View {
    let state: MascotEyeState
    var eyeSize: CGSize = CGSize(width: 5.2, height: 9.5)
    var spacing: CGFloat = 4.2
    
    @State private var isBlinking: Bool = false
    @State private var musicBounce: Bool = false
    @State private var breakGlance: Bool = false
    @State private var zenBreath: Bool = false
    @State private var celebratePulse: Bool = false
    @State private var glanceOffset: CGFloat = 0
    
    // Timer for natural periodic blinks
    private let blinkTimer = Timer.publish(every: 3.8, on: .main, in: .common).autoconnect()
    // Timer for idle micro-glance
    private let glanceTimer = Timer.publish(every: 5.2, on: .main, in: .common).autoconnect()
    // Timer for break glance
    private let breakTimer = Timer.publish(every: 2.2, on: .main, in: .common).autoconnect()
    
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
    
    var body: some View {
        HStack(spacing: spacing) {
            singleEyeView(isLeft: true)
            singleEyeView(isLeft: false)
        }
        .offset(x: glanceOffset)
        .offset(y: eyeYOffset)
        .scaleEffect(celebratePulse ? 1.18 : 1.0)
        .rotationEffect(.degrees(overallRotation))
        .onReceive(blinkTimer) { _ in
            triggerBlink()
        }
        .onReceive(glanceTimer) { _ in
            triggerGlance()
        }
        .onReceive(breakTimer) { _ in
            if case .pomodoro(.shortBreak, _) = state {
                withAnimation(.easeInOut(duration: 0.35)) {
                    breakGlance.toggle()
                }
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
        let isWinkingEye = (state == .wink && isLeft)
        let isMusicHappy = isMusicActive
        let isZenRest = isRestActive
        
        Group {
            if isMusicHappy {
                // Happy upward arc ^_^ bouncing to music
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
            } else if isZenRest {
                // Peaceful sleeping crescent ◡ ◡ for 15m rest
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
            } else if isWinkingEye {
                // Winking eye (left eye winks shut)
                MascotEyeArcShape(flipped: false)
                    .stroke(
                        eyeWarmFill,
                        style: StrokeStyle(lineWidth: eyeSize.width * 0.44, lineCap: .round)
                    )
                    .frame(width: eyeSize.width * 1.2, height: eyeSize.height * 0.8)
            } else {
                // Glowing Capsule Eye (Open eye)
                Capsule()
                    .fill(
                        RadialGradient(
                            colors: [eyeInnerGleam, eyeWarmFill],
                            center: .center,
                            startRadius: 0,
                            endRadius: eyeSize.height * 0.5
                        )
                    )
                    .frame(
                        width: eyeSize.width * eyeScaleX(isLeft: isLeft),
                        height: max(1.2, eyeSize.height * (isBlinking ? 0.12 : eyeScaleY(isLeft: isLeft)))
                    )
            }
        }
        .shadow(color: eyeGlowColor.opacity(0.75), radius: 3, x: 0, y: 0)
        .shadow(color: eyeGlowColor.opacity(0.35), radius: 6, x: 0, y: 0)
        .rotationEffect(.degrees(individualEyeRotation(isLeft: isLeft)))
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
            return celebratePulse ? -2.5 : 0
        }
        return 0
    }
    
    private var overallRotation: Double {
        switch state {
        case .music(let playing):
            return playing ? (musicBounce ? -4.0 : 4.0) : -2.0
        case .pomodoro(.focus, let isPaused):
            return isPaused ? 7.0 : 0
        case .pomodoro(.shortBreak, _):
            return breakGlance ? 3.0 : -3.0
        case .pomodoro(.custom, let isPaused):
            return isPaused ? 5.0 : 0
        case .wink:
            return 3.0
        default:
            return 0
        }
    }
    
    private func eyeScaleX(isLeft: Bool) -> CGFloat {
        switch state {
        case .pomodoro(.focus, _):
            return 1.12 // Slightly broader determined gaze
        case .pomodoro(.shortBreak, _):
            return 1.05
        case .timesUp:
            return 1.2
        default:
            return 1.0
        }
    }
    
    private func eyeScaleY(isLeft: Bool) -> CGFloat {
        switch state {
        case .pomodoro(.focus, _):
            return 0.78 // Narrowed concentration gaze
        case .timesUp:
            return 1.15
        default:
            return 1.0
        }
    }
    
    private func individualEyeRotation(isLeft: Bool) -> Double {
        switch state {
        case .pomodoro(.focus, _):
            // Angle slightly inwards for intense focus
            return isLeft ? 5.0 : -5.0
        case .pomodoro(.shortBreak, _):
            return breakGlance ? (isLeft ? 2 : 4) : (isLeft ? -4 : -2)
        default:
            // Natural slight splay like LogoNotchify
            return isLeft ? -3.0 : 3.0
        }
    }
    
    // MARK: - Animations
    private func triggerBlink() {
        guard !isBlinking && !isMusicActive && !isRestActive && state != .timesUp else { return }
        withAnimation(.easeInOut(duration: 0.10)) {
            isBlinking = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.65)) {
                isBlinking = false
            }
        }
    }
    
    private func triggerGlance() {
        guard state == .idle else { return }
        let directions: [CGFloat] = [-1.5, 0, 1.5, 0]
        let target = directions.randomElement() ?? 0
        withAnimation(.easeInOut(duration: 0.4)) {
            glanceOffset = target
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.4)) {
                glanceOffset = 0
            }
        }
    }
    
    private func setupInitialAnimations() {
        handleStateChange(to: state)
    }
    
    private func handleStateChange(to newState: MascotEyeState) {
        switch newState {
        case .music(let isPlaying):
            if isPlaying {
                withAnimation(.easeInOut(duration: 0.42).repeatForever(autoreverses: true)) {
                    musicBounce = true
                }
            } else {
                musicBounce = false
            }
        case .pomodoro(.rest, _):
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                zenBreath = true
            }
        case .timesUp:
            withAnimation(.easeInOut(duration: 0.28).repeatForever(autoreverses: true)) {
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
    @State private var isWinking: Bool = false
    @State private var breathing: Bool = false
    
    init(viewModel: NotchViewModel, size: CGFloat = 30) {
        self.viewModel = viewModel
        self.size = size
    }
    
    // Resolve mascot eye state based on app activity
    private var currentMascotState: MascotEyeState {
        if isWinking {
            return .wink
        }
        if viewModel.showTimesUp {
            return .timesUp
        }
        if viewModel.isPlaying {
            return .music(isPlaying: true)
        }
        if viewModel.isPomodoroActive {
            let totalMinutes = Int(round(viewModel.pomodoroTotal / 60))
            let preset = PomodoroMascotPreset.from(totalMinutes: totalMinutes)
            return .pomodoro(preset: preset, isPaused: viewModel.isPomodoroPaused)
        }
        return .idle
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
                    eyeSize: CGSize(width: size * 0.16, height: size * 0.28),
                    spacing: size * 0.12
                )
                .offset(y: -size * 0.02)
            }
            .scaleEffect(
                isSquished
                    ? CGSize(width: 1.22, height: 0.82)
                    : (isHovered ? CGSize(width: 1.08, height: 1.08) : (breathing ? CGSize(width: 1.02, height: 1.02) : CGSize(width: 0.98, height: 0.98)))
            )
            .animation(.spring(response: 0.32, dampingFraction: 0.58), value: isSquished)
            .animation(.easeInOut(duration: 0.18), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .help(LanguageManager.tr("Notchify Companion"))
        .onHover { h in
            isHovered = h
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }
    
    private func performInteractiveReaction() {
        // Haptic feedback
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        
        // Squish bounce
        isSquished = true
        isWinking = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            isSquished = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            isWinking = false
        }
    }
}
