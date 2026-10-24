import SwiftUI

// MARK: - Network Radar Views & Manager
struct SparklineView: View {
    let data: [CGFloat]
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let maxVal = max(data.max() ?? 1, 1024)
            
            Path { path in
                guard data.count > 1 else { return }
                let step = w / CGFloat(data.count - 1)
                for (idx, val) in data.enumerated() {
                    let normY = h - (CGFloat(val) / maxVal) * (h - 4) - 2
                    let pt = CGPoint(x: CGFloat(idx) * step, y: max(min(normY, h), 0))
                    if idx == 0 {
                        path.move(to: pt)
                    } else {
                        path.addLine(to: pt)
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}



struct SpeedTestGaugeView: View {
    @ObservedObject var manager: SpeedTestManager
    
    private var gaugeColor: Color {
        switch manager.phase {
        case .downloading: return .green
        case .uploading: return .blue
        case .pinging: return .orange
        case .completed: return .teal
        default: return .cyan
        }
    }
    
    private var gaugeTrim: CGFloat {
        switch manager.phase {
        case .pinging: return 0.2
        case .downloading, .uploading:
            return CGFloat(min(max(manager.progress, 0.05), 1.0))
        case .completed: return 1.0
        default: return 0.0
        }
    }
    
    var body: some View {
        ZStack {
            // Background Track Arc
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 88, height: 88)
                .rotationEffect(.degrees(90))
            
            // Active Progress Arc
            Circle()
                .trim(from: 0.15, to: 0.15 + (0.70 * gaugeTrim))
                .stroke(
                    LinearGradient(
                        colors: [gaugeColor.opacity(0.7), gaugeColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 88, height: 88)
                .rotationEffect(.degrees(90))
                .animation(.easeInOut(duration: 0.25), value: gaugeTrim)
            
            // Center Metrics
            VStack(spacing: 1) {
                if manager.phase == .pinging {
                    Text("Ping")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.orange)
                    Text("...")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                } else if manager.phase == .downloading || manager.phase == .uploading {
                    Text(String(format: "%.1f", manager.liveSpeedMbps))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Mbps")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(gaugeColor)
                } else if manager.phase == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                    Text("Done")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

