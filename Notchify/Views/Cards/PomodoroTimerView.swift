import SwiftUI

// MARK: - Pomodoro View
struct PomodoroTimerView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var selectedMinutes: Double = 25
    @State private var lastCustomMinutes: Double = 30
    @State private var customInputText: String = "25"
    @State private var isBlinking = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "stopwatch.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange)
                    Text(LanguageManager.tr("Focus Timer"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    if viewModel.isPomodoroActive {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                            .opacity(isBlinking ? 0.3 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(), value: isBlinking)
                            .onAppear { isBlinking = true }
                    }
                }
                
                Spacer()
                
                if viewModel.isPomodoroActive {
                    Text(LanguageManager.tr("Focus Session"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 2)
            
            if viewModel.isPomodoroActive {
                // ACTIVE STATE
                HStack(spacing: 16) {
                    // Circular Progress Ring
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 5)
                            .frame(width: 68, height: 68)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(viewModel.pomodoroTotal > 0 ? viewModel.pomodoroRemaining / viewModel.pomodoroTotal : 0))
                            .stroke(
                                LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .frame(width: 68, height: 68)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.5), value: viewModel.pomodoroRemaining)
                        
                        Text(timeString(from: viewModel.pomodoroRemaining))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    // Controls
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            // Pause / Resume Button
                            Button(action: {
                                if viewModel.isPomodoroPaused {
                                    viewModel.resumePomodoro()
                                } else {
                                    viewModel.pausePomodoro()
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: viewModel.isPomodoroPaused ? "play.fill" : "pause.fill")
                                        .font(.system(size: 10, weight: .bold))
                                    Text(viewModel.isPomodoroPaused ? LanguageManager.tr("Resume") : LanguageManager.tr("Pause"))
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.orange)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // +5 Min Button
                            Button(action: {
                                viewModel.addPomodoroMinutes(5)
                            }) {
                                Text("+5 " + LanguageManager.tr("min"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 7)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Stop Button
                            Button(action: {
                                withAnimation {
                                    viewModel.stopPomodoro()
                                }
                            }) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.red)
                                    .padding(8)
                                    .background(Color.red.opacity(0.15))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top, 4)
            } else {
                // INACTIVE / SELECTION STATE
                HStack(spacing: 8) {
                    // 4 Presets (3 Templates + 1 Custom)
                    HStack(spacing: 5) {
                        presetButton(minutes: 25, title: "25m", subtitle: "Focus", icon: "brain.head.profile")
                        presetButton(minutes: 15, title: "15m", subtitle: "Rest", icon: "leaf.fill")
                        presetButton(minutes: 5, title: "5m", subtitle: "Break", icon: "cup.and.saucer.fill")
                        customPresetButton()
                    }
                    
                    // Stepper / Custom Input & Start
                    VStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Button(action: {
                                if selectedMinutes > 1 {
                                    selectedMinutes -= 1
                                    if selectedMinutes != 25 && selectedMinutes != 15 && selectedMinutes != 5 {
                                        lastCustomMinutes = selectedMinutes
                                    }
                                    customInputText = "\(Int(selectedMinutes))"
                                }
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 20, height: 20)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help(LanguageManager.tr("Decrease (Right click for -5m)"))
                            .contextMenu {
                                Button("-5 " + LanguageManager.tr("min")) {
                                    selectedMinutes = max(1, selectedMinutes - 5)
                                    if selectedMinutes != 25 && selectedMinutes != 15 && selectedMinutes != 5 {
                                        lastCustomMinutes = selectedMinutes
                                    }
                                    customInputText = "\(Int(selectedMinutes))"
                                }
                                Button("-15 " + LanguageManager.tr("min")) {
                                    selectedMinutes = max(1, selectedMinutes - 15)
                                    if selectedMinutes != 25 && selectedMinutes != 15 && selectedMinutes != 5 {
                                        lastCustomMinutes = selectedMinutes
                                    }
                                    customInputText = "\(Int(selectedMinutes))"
                                }
                            }
                            
                            HStack(spacing: 1) {
                                TextField("", text: $customInputText, onCommit: {
                                    commitInputText()
                                })
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 26)
                                .onChange(of: customInputText) { newVal in
                                    let filtered = newVal.filter { "0123456789".contains($0) }
                                    if filtered != newVal {
                                        customInputText = filtered
                                    }
                                    if let val = Double(filtered), val >= 1, val <= 360 {
                                        selectedMinutes = val
                                        if val != 25 && val != 15 && val != 5 {
                                            lastCustomMinutes = val
                                        }
                                    }
                                }
                                
                                Text(LanguageManager.tr("min"))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isCustomSelected ? Color.orange.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 0.8)
                                    )
                            )
                            
                            Button(action: {
                                if selectedMinutes < 360 {
                                    selectedMinutes += 1
                                    if selectedMinutes != 25 && selectedMinutes != 15 && selectedMinutes != 5 {
                                        lastCustomMinutes = selectedMinutes
                                    }
                                    customInputText = "\(Int(selectedMinutes))"
                                }
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 20, height: 20)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help(LanguageManager.tr("Increase (Right click for +5m)"))
                            .contextMenu {
                                Button("+5 " + LanguageManager.tr("min")) {
                                    selectedMinutes = min(360, selectedMinutes + 5)
                                    if selectedMinutes != 25 && selectedMinutes != 15 && selectedMinutes != 5 {
                                        lastCustomMinutes = selectedMinutes
                                    }
                                    customInputText = "\(Int(selectedMinutes))"
                                }
                                Button("+15 " + LanguageManager.tr("min")) {
                                    selectedMinutes = min(360, selectedMinutes + 15)
                                    if selectedMinutes != 25 && selectedMinutes != 15 && selectedMinutes != 5 {
                                        lastCustomMinutes = selectedMinutes
                                    }
                                    customInputText = "\(Int(selectedMinutes))"
                                }
                                Button("+30 " + LanguageManager.tr("min")) {
                                    selectedMinutes = min(360, selectedMinutes + 30)
                                    if selectedMinutes != 25 && selectedMinutes != 15 && selectedMinutes != 5 {
                                        lastCustomMinutes = selectedMinutes
                                    }
                                    customInputText = "\(Int(selectedMinutes))"
                                }
                            }
                        }
                        
                        Button(action: {
                            commitInputText()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                viewModel.startPomodoro(minutes: selectedMinutes)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 8, weight: .bold))
                                Text(startButtonTitle)
                                    .font(.system(size: 10, weight: .bold))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(
                                LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .frame(width: 106)
                }
                .padding(.top, 4)
            }
        }
    }
    
    private var isCustomSelected: Bool {
        selectedMinutes != 25 && selectedMinutes != 15 && selectedMinutes != 5
    }
    
    private var customButtonTitle: String {
        if isCustomSelected {
            return "\(Int(selectedMinutes))m"
        } else {
            return "\(Int(lastCustomMinutes))m"
        }
    }
    
    private var startButtonTitle: String {
        if selectedMinutes == 25 {
            return LanguageManager.tr("Start Focus")
        } else if selectedMinutes == 15 {
            return LanguageManager.tr("Start Rest")
        } else if selectedMinutes == 5 {
            return LanguageManager.tr("Start Break")
        } else {
            return LanguageManager.tr("Start Timer")
        }
    }
    
    private func commitInputText() {
        if let val = Double(customInputText), val >= 1, val <= 360 {
            selectedMinutes = val
            if val != 25 && val != 15 && val != 5 {
                lastCustomMinutes = val
            }
        } else {
            customInputText = "\(Int(selectedMinutes))"
        }
    }
    
    private func customPresetButton() -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                selectedMinutes = lastCustomMinutes
                customInputText = "\(Int(lastCustomMinutes))"
            }
        }) {
            VStack(spacing: 3) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isCustomSelected ? .orange : .white.opacity(0.7))
                Text(customButtonTitle)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Text(LanguageManager.tr("Custom"))
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isCustomSelected ? Color.orange.opacity(0.2) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isCustomSelected ? Color.orange.opacity(0.6) : Color.white.opacity(0.08), lineWidth: isCustomSelected ? 1.5 : 0.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .help(LanguageManager.tr("Custom Timer"))
    }
    
    private func presetButton(minutes: Double, title: String, subtitle: String, icon: String) -> some View {
        let isSelected = selectedMinutes == minutes
        return Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                selectedMinutes = minutes
                customInputText = "\(Int(minutes))"
            }
        }) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSelected ? .orange : .white.opacity(0.7))
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Text(LanguageManager.tr(subtitle))
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.orange.opacity(0.2) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.orange.opacity(0.6) : Color.white.opacity(0.08), lineWidth: isSelected ? 1.5 : 0.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func timeString(from time: TimeInterval) -> String {
        let min = Int(time) / 60
        let sec = Int(time) % 60
        return String(format: "%02d:%02d", min, sec)
    }
}

