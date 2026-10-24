import SwiftUI

// MARK: - Waveform View
// MARK: - Siri-Style Fluid Waveform Shape
struct SiriWaveCurve: Shape {
    var phase: Double
    var amplitude: CGFloat
    var frequency: CGFloat = 1.4
    
    var animatableData: AnimatablePair<Double, CGFloat> {
        get { AnimatablePair(phase, amplitude) }
        set {
            phase = newValue.first
            amplitude = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midY = height / 2
        
        guard width > 0 && height > 0 else { return path }
        
        path.move(to: CGPoint(x: 0, y: midY))
        
        let step: CGFloat = 1.0
        for x in stride(from: 0, through: width, by: step) {
            let relativeX = x / width
            // Bell curve envelope: clamps smoothly to 0 at edges, max in the middle
            let envelope = sin(relativeX * .pi)
            let y = midY + sin(relativeX * 2 * .pi * frequency + phase) * amplitude * envelope
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        return path
    }
}

// MARK: - Waveform View (Fluid Siri Multi-Color Wave)
struct WaveformView: View {
    var isPlaying: Bool
    var color: Color = .orange
    
    @State private var animatedAmplitude: CGFloat = 0.0
    
    private var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.18, green: 0.85, blue: 1.0),   // Neon Cyan
                Color(red: 0.65, green: 0.35, blue: 1.0),   // Vibrant Violet
                Color(red: 1.0, green: 0.28, blue: 0.70),   // Hot Pink
                Color(red: 1.0, green: 0.62, blue: 0.18)    // Amber Gold
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var secondaryGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.25, blue: 0.85).opacity(0.65),
                Color(red: 0.20, green: 0.75, blue: 1.0).opacity(0.65)
            ],
            startPoint: .trailing,
            endPoint: .leading
        )
    }
    
    private func computeWave1(time: Double) -> (phase: Double, amplitude: CGFloat) {
        let phase = time * 5.2
        let rawAmp = isPlaying ? (5.5 + sin(time * 3.5) * 1.5) : 0.0
        let amp = CGFloat(rawAmp) * animatedAmplitude
        return (phase, amp)
    }
    
    private func computeWave2(time: Double) -> (phase: Double, amplitude: CGFloat) {
        let phase = -time * 4.0 + 1.2
        let rawAmp = isPlaying ? (4.0 + cos(time * 2.8) * 1.2) : 0.0
        let amp = CGFloat(rawAmp) * animatedAmplitude
        return (phase, amp)
    }
    
    var body: some View {
        TimelineView(.animation(paused: !isPlaying && animatedAmplitude == 0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let w1 = computeWave1(time: time)
            let w2 = computeWave2(time: time)
            
            ZStack {
                // Secondary Harmonic Wave (Depth layer)
                SiriWaveCurve(phase: w2.phase, amplitude: w2.amplitude, frequency: 1.8)
                    .stroke(secondaryGradient, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .blur(radius: 0.5)
                
                // Primary Vibrant Siri Wave
                SiriWaveCurve(phase: w1.phase, amplitude: w1.amplitude, frequency: 1.3)
                    .stroke(primaryGradient, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .shadow(color: Color(red: 0.65, green: 0.35, blue: 1.0).opacity(0.45), radius: 3, x: 0, y: 0)
            }
        }
        .frame(width: 28, height: 16)
        .onAppear {
            if isPlaying {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                    animatedAmplitude = 1.0
                }
            }
        }
        .onChange(of: isPlaying) { playing in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                animatedAmplitude = playing ? 1.0 : 0.0
            }
        }
    }
}

