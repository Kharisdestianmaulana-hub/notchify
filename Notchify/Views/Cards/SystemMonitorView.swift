import SwiftUI

// MARK: - System Monitor View
struct SystemMonitorView: View {
    @ObservedObject var viewModel: NotchViewModel
    let timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 11) {
            cpuRow
            memRow
            batteryRow
        }
        .onAppear { refreshStats() }
        .onReceive(timer) { _ in refreshStats() }
    }
    
    private var cpuRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "cpu")
                    .font(.system(size: 13))
                    .foregroundColor(.cyan)
                Text("CPU")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(String(format: "%.0f%%", viewModel.cpuUsage))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(cpuColor)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 6)
                    Capsule().fill(cpuColor).frame(width: max(0, geo.size.width * CGFloat(viewModel.cpuUsage / 100)), height: 6)
                        .animation(.easeInOut(duration: 0.5), value: viewModel.cpuUsage)
                }
            }
            .frame(height: 6)
        }
    }
    
    private var memRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "memorychip")
                    .font(.system(size: 13))
                    .foregroundColor(.purple)
                Text("RAM")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(viewModel.memUsed) / \(viewModel.memTotal)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 6)
                    Capsule().fill(memColor).frame(width: max(0, geo.size.width * CGFloat(viewModel.memUsage / 100)), height: 6)
                        .animation(.easeInOut(duration: 0.5), value: viewModel.memUsage)
                }
            }
            .frame(height: 6)
        }
    }
    
    private var batteryRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: (viewModel.isBatteryCharging || viewModel.isACConnected) ? "bolt.batteryblock.fill" : "battery.75")
                    .font(.system(size: 13))
                    .foregroundColor((viewModel.isBatteryCharging || viewModel.isACConnected) ? Color.green : .yellow)
                Text(LanguageManager.tr("Battery"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Text(viewModel.isACConnected ? (viewModel.batteryLevel >= 100 ? "• \(LanguageManager.tr("Fully Charged"))" : "• \(LanguageManager.tr("Charging"))") : "• \(LanguageManager.tr("On Battery"))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(viewModel.batteryLevel)%")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(batteryColor)
                
                // Test Charging Animation Button
                Button(action: {
                    viewModel.triggerBatteryHUD(isAC: true, isCharging: true, level: viewModel.batteryLevel)
                }) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                        .padding(3)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .help(LanguageManager.tr("Test Charging Animation"))
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 6)
                    Capsule().fill(batteryColor).frame(width: max(0, geo.size.width * CGFloat(Double(viewModel.batteryLevel) / 100.0)), height: 6)
                        .animation(.easeInOut(duration: 0.5), value: viewModel.batteryLevel)
                }
            }
            .frame(height: 6)
        }
    }
    
    private var cpuColor: Color {
        viewModel.cpuUsage > 80 ? .red : (viewModel.cpuUsage > 50 ? .orange : .green)
    }
    
    private var memColor: Color {
        viewModel.memUsage > 80 ? .red : (viewModel.memUsage > 60 ? .orange : .purple)
    }
    
    private var batteryColor: Color {
        if viewModel.isACConnected || viewModel.isBatteryCharging {
            return .green
        } else if viewModel.batteryLevel <= 20 {
            return .red
        } else if viewModel.batteryLevel <= 40 {
            return .orange
        } else {
            return .green
        }
    }
    
    private func refreshStats() {
        DispatchQueue.main.async {
            viewModel.cpuUsage = SystemMonitor.getCPUUsage()
            let mem = SystemMonitor.getMemoryUsage()
            viewModel.memUsage = mem.percent
            viewModel.memUsed = SystemMonitor.formatBytes(mem.used)
            viewModel.memTotal = SystemMonitor.formatBytes(mem.total)
            
            let pwr = BatteryMonitor.shared.readPowerInfo()
            viewModel.isACConnected = pwr.isAC
            viewModel.isBatteryCharging = pwr.isCharging
            viewModel.batteryLevel = pwr.level
        }
    }
}

