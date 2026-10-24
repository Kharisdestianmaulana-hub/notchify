import SwiftUI

struct SpeedTestView: View {
    @ObservedObject var manager = SpeedTestManager.shared
    
    private var formattedDate: String {
        guard manager.lastTimestamp > 0 else { return "" }
        let d = Date(timeIntervalSince1970: manager.lastTimestamp)
        let f = DateFormatter()
        f.dateFormat = "d MMM, HH:mm"
        return f.string(from: d)
    }
    
    var body: some View {
        VStack(spacing: 7) {
            if manager.phase == .idle {
                idleView
            } else if manager.phase == .completed {
                completedView
            } else if manager.phase == .failed {
                failedView
            } else {
                activeTestingView
            }
        }
        .frame(width: 336)
    }
    
    // 1. Idle View
    private var idleView: some View {
        VStack(spacing: 7) {
            if manager.lastDownload > 0 {
                // Last benchmark card
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.gray)
                        Text(LanguageManager.tr("Last Tested") + (formattedDate.isEmpty ? "" : " • \(formattedDate)"))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    
                    HStack(spacing: 6) {
                        resultMiniPill(icon: "arrow.down.circle.fill", label: "Down", value: String(format: "%.1f", manager.lastDownload), unit: "Mbps", color: .green)
                        resultMiniPill(icon: "arrow.up.circle.fill", label: "Up", value: String(format: "%.1f", manager.lastUpload), unit: "Mbps", color: .blue)
                        resultMiniPill(icon: "bolt.horizontal.fill", label: "Ping", value: "\(manager.lastPing)", unit: "ms", color: .orange)
                    }
                }
                .padding(7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                )
            } else {
                VStack(spacing: 3) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 24))
                        .foregroundColor(.cyan.opacity(0.8))
                        .padding(.top, 2)
                    Text(LanguageManager.tr("Ready to Test"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text(LanguageManager.tr("Check your current download and upload speeds."))
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 4)
            }
            
            // Start Test Button
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    manager.startTest()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(LanguageManager.tr("Start Speed Test"))
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.2, green: 0.9, blue: 0.7), Color(red: 0.1, green: 0.75, blue: 0.95)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color.cyan.opacity(0.3), radius: 5, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // 2. Active Testing View (Ping, Download, Upload)
    private var activeTestingView: some View {
        VStack(spacing: 6) {
            SpeedTestGaugeView(manager: manager)
                .padding(.top, 2)
            
            // Status and Cancel Button
            HStack {
                HStack(spacing: 5) {
                    Circle()
                        .fill(manager.phase == .downloading ? Color.green : (manager.phase == .uploading ? Color.blue : Color.orange))
                        .frame(width: 6, height: 6)
                    Text(manager.statusMessage)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        manager.cancelTest()
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                        Text(LanguageManager.tr("Cancel"))
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 6)
        }
    }
    
    // 3. Completed View
    private var completedView: some View {
        VStack(spacing: 7) {
            HStack(spacing: 6) {
                resultCard(
                    icon: "arrow.down.circle.fill",
                    label: LanguageManager.tr("Download"),
                    value: String(format: "%.1f", manager.downloadResultMbps),
                    unit: "Mbps",
                    color: .green
                )
                resultCard(
                    icon: "arrow.up.circle.fill",
                    label: LanguageManager.tr("Upload"),
                    value: String(format: "%.1f", manager.uploadResultMbps),
                    unit: "Mbps",
                    color: .blue
                )
                resultCard(
                    icon: "bolt.horizontal.fill",
                    label: LanguageManager.tr("Latency"),
                    value: "\(manager.pingResultMs)",
                    unit: "ms",
                    color: .orange
                )
            }
            
            // Retest Button
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    manager.startTest()
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .bold))
                    Text(LanguageManager.tr("Test Again"))
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // 4. Failed View
    private var failedView: some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundColor(.yellow)
            Text(LanguageManager.tr("Test Failed"))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
            Text(LanguageManager.tr("Please check your internet connection"))
                .font(.system(size: 9))
                .foregroundColor(.gray)
            
            Button(action: {
                manager.startTest()
            }) {
                Text(LanguageManager.tr("Test Again"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.15)))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
    }
    
    private func resultMiniPill(icon: String, label: String, value: String, unit: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(unit)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
    }
    
    private func resultCard(icon: String, label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(unit)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(color)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.25), lineWidth: 0.5))
        )
    }
}

struct NetworkCardView: View {
    @ObservedObject var viewModel: NotchViewModel
    @StateObject private var netManager = NetworkSpeedManager.shared
    @State private var subMode: NetworkSubMode = .radar
    @State private var showCopiedLocalIP = false
    @State private var showCopiedPublicIP = false
    
    var body: some View {
        VStack(spacing: 7) {
            // Mode Switcher Header
            HStack {
                HStack(spacing: 4) {
                    ForEach(NetworkSubMode.allCases, id: \.self) { mode in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                subMode = mode
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: mode == .radar ? "waveform.path.ecg" : "bolt.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                Text(mode.localizedTitle)
                                    .font(.system(size: 11, weight: subMode == mode ? .bold : .medium))
                            }
                            .foregroundColor(subMode == mode ? .white : .gray)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(subMode == mode ? Color.white.opacity(0.18) : Color.clear)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(2)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                )
                
                Spacer()
            }
            .frame(width: 336)
            
            if subMode == .radar {
                radarContent
            } else {
                SpeedTestView()
            }
        }
        .onAppear {
            netManager.startMonitoring()
        }
        .onDisappear {
            netManager.stopMonitoring()
        }
    }
    
    private var radarContent: some View {
        VStack(spacing: 7) {
            // Top Row: Speedometers
            HStack(spacing: 10) {
                // Download Meter
                speedMeterCard(
                    title: LanguageManager.tr("Download"),
                    icon: "arrow.down.circle.fill",
                    color: Color.green,
                    bytesPerSec: netManager.downloadSpeed,
                    history: netManager.downloadHistory
                )
                
                // Upload Meter
                speedMeterCard(
                    title: LanguageManager.tr("Upload"),
                    icon: "arrow.up.circle.fill",
                    color: Color.blue,
                    bytesPerSec: netManager.uploadSpeed,
                    history: netManager.uploadHistory
                )
            }
            .frame(width: 336)
            
            // Middle Row: Wi-Fi, Signal & Ping
            HStack(spacing: 8) {
                // Wi-Fi SSID
                HStack(spacing: 5) {
                    Image(systemName: netManager.signalIcon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(netManager.wifiSSID)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(netManager.frequencyBand)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                )
                
                Spacer()
                
                // Ping Latency Pill
                HStack(spacing: 4) {
                    Circle()
                        .fill(netManager.pingColor)
                        .frame(width: 6, height: 6)
                    
                    Text("\(netManager.pingMs) ms")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text(LanguageManager.tr("Latency"))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                )
                
                // Refresh Button
                Button(action: {
                    netManager.testPing()
                    netManager.refreshIPs()
                    netManager.checkWiFi()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(6)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(PlainButtonStyle())
                .help(LanguageManager.tr("Re-testing network..."))
            }
            .frame(width: 336)
            
            // Bottom Row: Local & Public IP
            HStack(spacing: 8) {
                // Local IP Pill
                HStack(spacing: 5) {
                    Text(LanguageManager.tr("Local IP") + ":")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text(netManager.localIP)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button(action: {
                        copyToClipboard(netManager.localIP, isLocal: true)
                    }) {
                        Image(systemName: showCopiedLocalIP ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(showCopiedLocalIP ? .green : .white.opacity(0.6))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(LanguageManager.tr("IP Copied"))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                )
                
                // Public IP Pill
                HStack(spacing: 5) {
                    Text(LanguageManager.tr("Public IP") + ":")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text(netManager.publicIP)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button(action: {
                        copyToClipboard(netManager.publicIP, isLocal: false)
                    }) {
                        Image(systemName: showCopiedPublicIP ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(showCopiedPublicIP ? .green : .white.opacity(0.6))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(LanguageManager.tr("IP Copied"))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                )
            }
            .frame(width: 336)
        }
    }
    
    private func speedMeterCard(title: String, icon: String, color: Color, bytesPerSec: Double, history: [CGFloat]) -> some View {
        let fmt = NetworkSpeedManager.formatSpeed(bytesPerSec)
        
        return ZStack(alignment: .bottomTrailing) {
            // Background mini sparkline wave
            SparklineView(data: history, color: color.opacity(0.25))
                .frame(height: 34)
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(color)
                    Text(title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(fmt.value)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(fmt.unit)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(color)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(color.opacity(0.2), lineWidth: 0.5))
        )
    }
    
    private func copyToClipboard(_ text: String, isLocal: Bool) {
        let p = NSPasteboard.general
        p.clearContents()
        p.setString(text, forType: .string)
        if isLocal {
            withAnimation { showCopiedLocalIP = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showCopiedLocalIP = false }
            }
        } else {
            withAnimation { showCopiedPublicIP = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showCopiedPublicIP = false }
            }
        }
    }
}
