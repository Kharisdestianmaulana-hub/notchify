import SwiftUI
import AppKit
import AVFoundation
import AudioToolbox
import AVKit
import CoreWLAN
import Network
import SystemConfiguration

// MARK: - Models
enum NotchTab: String, CaseIterable, Identifiable, Codable {
    case media = "music.note"
    case clipboard = "doc.on.clipboard"
    case dropzone = "tray.and.arrow.down.fill"
    case pomodoro = "timer"
    case calculator = "plus.forwardslash.minus"
    case weather = "cloud.sun.fill"
    case system = "gauge"
    case agenda = "calendar"
    case mirror = "camera.fill"
    case notes = "note.text"
    case network = "network"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .media: return LanguageManager.tr("Media (Music)")
        case .clipboard: return LanguageManager.tr("Clipboard Manager")
        case .dropzone: return LanguageManager.tr("Dropzone")
        case .pomodoro: return LanguageManager.tr("Pomodoro Timer")
        case .calculator: return LanguageManager.tr("Calculator")
        case .weather: return LanguageManager.tr("Weather")
        case .system: return LanguageManager.tr("System Monitor")
        case .agenda: return LanguageManager.tr("Agenda & Events")
        case .mirror: return LanguageManager.tr("Mirror")
        case .notes: return LanguageManager.tr("Scratchpad & Tasks")
        case .network: return LanguageManager.tr("Network Radar")
        }
    }
    
    static func from(string: String) -> NotchTab? {
        if let match = NotchTab(rawValue: string) { return match }
        switch string.lowercased() {
        case "media", "music": return .media
        case "clipboard": return .clipboard
        case "dropzone": return .dropzone
        case "pomodoro", "timer": return .pomodoro
        case "calculator": return .calculator
        case "weather": return .weather
        case "system": return .system
        case "agenda": return .agenda
        case "mirror", "camera": return .mirror
        case "notes", "note", "todo", "tasks": return .notes
        case "network", "wifi", "speed": return .network
        default: return nil
        }
    }
}

// MARK: - Notch ViewModel
class NotchViewModel: ObservableObject {
    @Published var isExpanded: Bool = false
    @Published var isPinningExpansion: Bool = false
    @Published var clipboardItems: [String] = []
    @Published var pinnedClipboardItems: [String] = []
    
    // Media States
    @Published var currentSong: String = "No Media Playing"
    @Published var currentArtist: String = ""
    @Published var artwork: NSImage? = nil
    @Published var isPlaying: Bool = false
    @Published var showClock: Bool = true
    @Published var playerBundleId: String? = nil
    @Published var playerAppName: String = ""
    
    var playerAppIcon: NSImage? {
        guard let bundleId = playerBundleId,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
    
    @Published var duration: Double = 0.0
    var elapsed: Double = 0.0
    
    // DropZone States
    @Published var stagedFiles: [URL] = []
    @Published var isHoveringWithFile: Bool = false
    @Published var showDropSuccessHUD: Bool = false
    
    // Pomodoro States
    @Published var isPomodoroActive: Bool = false
    @Published var isPomodoroPaused: Bool = false
    @Published var pomodoroRemaining: TimeInterval = 0
    @Published var pomodoroTotal: TimeInterval = 0
    @Published var showTimesUp: Bool = false
    private var pomodoroTimer: Timer?
    
    // Calculator State
    @Published var calcInput: String = "0"
    @Published var calcPrevious: Double? = nil
    @Published var calcOperator: String? = nil
    @Published var calcExpression: String = ""
    @Published var calcIsNewInput: Bool = false
    
    // HUD States
    @Published var showVolumeHUD: Bool = false
    @Published var currentVolume: Float = 0.5
    
    @Published var showDeviceHUD: Bool = false
    @Published var deviceMessage: String = ""
    @Published var deviceIcon: String = ""
    @Published var isDeviceConnected: Bool = true
    @Published var showClipboardHUD: Bool = false
    @Published var clipboardMessage: String = ""
    @Published var clipboardIcon: String = ""
    @Published var clipboardIsCut: Bool = false
    @Published var clipboardColorSwatch: Color? = nil
    @Published var clipboardAccentColor: Color = .blue
    
    // Battery HUD State
    @Published var showBatteryHUD: Bool = false
    @Published var batteryLevel: Int = 100
    @Published var isBatteryCharging: Bool = false
    @Published var isACConnected: Bool = true
    
    private var lastActionWasCut = false
    private var lastActionTime = Date()
    
    private var hudDismissTimer: Timer?
    
    @Published var selectedTab: NotchTab = .media
    
    // Lyrics State
    @Published var lyrics: [LyricLine] = []
    @Published var currentLyricIndex: Int = -1
    
    // Album Art Glow
    @Published var accentColor: Color = .clear
    
    // Weather State
    @Published var weatherTemp: String = "--"
    @Published var weatherCondition: String = "Memuat..."
    @Published var weatherIcon: String = "cloud.fill"
    @Published var weatherCity: String = ""
    
    // System Monitor State
    @Published var cpuUsage: Double = 0
    @Published var memUsage: Double = 0
    @Published var memUsed: String = ""
    @Published var memTotal: String = ""
    
    // Agenda State
    @Published var agendaDateOffset: Int = 0 // 0 = today, -1 = yesterday, 1 = tomorrow
    @Published var agendaEvents: [CustomEvent] = []
    @Published var showAgendaHUD: Bool = false
    @Published var agendaHUDMessage: String = ""
    
    private var clipboardTimer: Timer?
    private var mediaTimer: Timer?
    private var pauseTimer: Timer?
    private var agendaTimer: Timer?
    private var progressTimer: Timer?
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int = 0
    
    func startPomodoro(minutes: Double) {
        pomodoroTotal = minutes * 60
        pomodoroRemaining = minutes * 60
        isPomodoroActive = true
        isPomodoroPaused = false
        showTimesUp = false
        
        pomodoroTimer?.invalidate()
        pomodoroTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.pomodoroRemaining > 0 {
                self.pomodoroRemaining -= 1
            } else {
                self.stopPomodoro()
                self.showTimesUp = true
                NSSound(named: "Glass")?.play()
                
                // Trigger times up notification
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    self.showTimesUp = false
                }
            }
        }
    }
    
    func pausePomodoro() {
        guard isPomodoroActive, !isPomodoroPaused else { return }
        isPomodoroPaused = true
        pomodoroTimer?.invalidate()
        pomodoroTimer = nil
    }
    
    func resumePomodoro() {
        guard isPomodoroActive, isPomodoroPaused else { return }
        isPomodoroPaused = false
        pomodoroTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.pomodoroRemaining > 0 {
                self.pomodoroRemaining -= 1
            } else {
                self.stopPomodoro()
                self.showTimesUp = true
                NSSound(named: "Glass")?.play()
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    self.showTimesUp = false
                }
            }
        }
    }
    
    func addPomodoroMinutes(_ minutes: Double) {
        guard isPomodoroActive else { return }
        let extra = minutes * 60
        pomodoroTotal += extra
        pomodoroRemaining += extra
    }
    
    func stopPomodoro() {
        isPomodoroActive = false
        isPomodoroPaused = false
        pomodoroTimer?.invalidate()
        pomodoroTimer = nil
    }
    
    init() {
        startClipboardPolling()
        startMediaPolling()
        startAgendaPolling()
        
        // HUD Hooks
        VolumeManager.shared.onVolumeChanged = { [weak self] volume in
            self?.triggerVolumeHUD(volume: volume)
        }
        VolumeManager.shared.start()
        
        HardwareMonitor.shared.onDeviceConnected = { [weak self] name in
            self?.triggerDeviceHUD(name: name, connected: true)
        }
        HardwareMonitor.shared.onDeviceDisconnected = { [weak self] name in
            self?.triggerDeviceHUD(name: name, connected: false)
        }
        HardwareMonitor.shared.start()
        
        BatteryMonitor.shared.onPowerStateChanged = { [weak self] isAC, isCharging, level in
            self?.triggerBatteryHUD(isAC: isAC, isCharging: isCharging, level: level)
        }
        BatteryMonitor.shared.start()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let initialPower = BatteryMonitor.shared.readPowerInfo()
            self.isACConnected = initialPower.isAC
            self.isBatteryCharging = initialPower.isCharging
            self.batteryLevel = initialPower.level
        }
    }
    
    func triggerVolumeHUD(volume: Float) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            self.currentVolume = volume
            self.showVolumeHUD = true
            self.showBatteryHUD = false
            self.showDeviceHUD = false
            self.showTimesUp = false
        }
        scheduleHUDDismiss()
    }
    
    func triggerDeviceHUD(name: String, connected: Bool) {
        let lowerName = name.lowercased()
        
        var category = "Perangkat"
        var icon = "link"
        
        if lowerName.contains("mouse") || lowerName.contains("receiver") || lowerName.contains("dongle") {
            category = "Mouse"
            icon = "magicmouse.fill"
        } else if lowerName.contains("keyboard") {
            category = "Keyboard"
            icon = "keyboard"
        } else if lowerName.contains("airpods") {
            category = "AirPods"
            icon = "airpodspro"
        } else if lowerName.contains("headphone") || lowerName.contains("headset") || lowerName.contains("earpods") {
            category = "Headphone"
            icon = "headphones"
        } else if lowerName.contains("trackpad") {
            category = "Trackpad"
            icon = "rectangle.dashed"
        } else if lowerName.contains("display") || lowerName.contains("monitor") {
            category = "Layar"
            icon = "display"
        }
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            self.deviceMessage = "\(category) \(connected ? LanguageManager.tr("Connected") : LanguageManager.tr("Disconnected"))"
            self.deviceIcon = icon
            self.isDeviceConnected = connected
            self.showDeviceHUD = true
            self.showBatteryHUD = false
            self.showVolumeHUD = false
            self.showTimesUp = false
        }
        scheduleHUDDismiss()
    }
    
    func triggerBatteryHUD(isAC: Bool, isCharging: Bool, level: Int) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            self.isACConnected = isAC
            self.isBatteryCharging = isCharging
            self.batteryLevel = level
            self.showBatteryHUD = true
            self.showVolumeHUD = false
            self.showDeviceHUD = false
            self.showClipboardHUD = false
            self.showTimesUp = false
            self.showAgendaHUD = false
        }
        
        if isAC {
            NSSound(named: "Glass")?.play()
        }
        
        scheduleHUDDismiss(duration: isAC ? 3.5 : 2.5)
    }
    
    private func scheduleHUDDismiss(duration: Double = 3.0) {
        hudDismissTimer?.invalidate()
        hudDismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                self?.showBatteryHUD = false
                self?.showVolumeHUD = false
                self?.showDeviceHUD = false
                self?.showClipboardHUD = false
                self?.showAgendaHUD = false
            }
        }
    }
    
    func startClipboardPolling() {
        lastChangeCount = pasteboard.changeCount
        
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
        
        // Fast polling for instant HUD (0.3s)
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.3,
                                              repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            if event.keyCode == 7 { // 'x'
                lastActionWasCut = true
                lastActionTime = Date()
            } else if event.keyCode == 8 { // 'c'
                lastActionWasCut = false
                lastActionTime = Date()
            }
        }
    }
    
    func startMediaPolling() {
        fetchMedia()
        mediaTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.fetchMedia()
        }
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isPlaying && self.duration > 0 {
                self.elapsed = min(self.elapsed + 0.1, self.duration)
                self.updateLyricIndex()
            }
        }
    }
    
    private func updateLyricIndex() {
        guard !lyrics.isEmpty else { return }
        // Show lyric slightly ahead so it appears when the singer starts
        if let index = lyrics.lastIndex(where: { $0.time <= self.elapsed + 0.2 }) {
            if self.currentLyricIndex != index {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.currentLyricIndex = index
                }
            }
        }
    }
    
    private func fetchMedia() {
        MediaRemoteHelper.shared.fetchNowPlaying { [weak self] title, artist, img, isPlaying, duration, elapsed, bundleId, appName in
            guard let self = self else { return }
            
            self.playerBundleId = bundleId
            self.playerAppName = appName ?? ""
            
            if let title = title {
                if self.currentSong != title {
                    self.currentSong = title
                    self.currentArtist = artist ?? ""
                    
                    // Fetch new lyrics only if enabled (default is off)
                    self.lyrics = []
                    self.currentLyricIndex = -1
                    if UserDefaults.standard.bool(forKey: "enableLyrics") {
                        LyricsManager.shared.fetchLyrics(for: title, artist: artist ?? "") { newLyrics in
                            self.lyrics = newLyrics
                        }
                    }
                }
                
                // Always update artwork, so asynchronous iTunes fetches can overwrite the fallback Chrome icon
                self.artwork = img
                self.isPlaying = isPlaying
                
                // Extract dominant color for glow
                if let artImg = img {
                    DispatchQueue.global(qos: .userInitiated).async {
                        let color = Self.extractDominantColor(from: artImg)
                        DispatchQueue.main.async {
                            self.accentColor = color
                        }
                    }
                } else {
                    self.accentColor = .clear
                }
                
                // Sync elapsed time aggressively for accurate lyrics
                self.duration = duration
                if abs(self.elapsed - elapsed) > 0.5 {
                    self.elapsed = elapsed
                } else {
                    // Small micro-adjustments without jumping
                    self.elapsed = (self.elapsed + elapsed) / 2
                }
                self.updateLyricIndex()
                
                if isPlaying {
                    self.pauseTimer?.invalidate()
                    self.pauseTimer = nil
                    if self.showClock {
                        self.showClock = false
                    }
                } else {
                    if !self.showClock && self.pauseTimer == nil {
                        self.pauseTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
                            self?.showClock = true
                        }
                    }
                }
            } else {
                self.currentSong = "No Media Playing"
                self.currentArtist = ""
                self.artwork = nil
                self.isPlaying = false
                self.duration = 0
                self.elapsed = 0
                if !self.showClock {
                    self.showClock = true
                }
            }
        }
    }
    
struct SmartClipboardResult {
    let message: String
    let icon: String
    let colorSwatch: Color?
    let accentColor: Color
}

class SmartClipboardDetector {
    static func detect(text: String) -> SmartClipboardResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SmartClipboardResult(message: LanguageManager.tr("Text Copied"), icon: "text.quote", colorSwatch: nil, accentColor: .cyan)
        }
        
        // 1. Color Code (HEX, RGB, RGBA)
        if let (color, label) = parseColor(trimmed) {
            let msg = "\(LanguageManager.tr("Color")) \(label) \(LanguageManager.tr("Copied"))"
            return SmartClipboardResult(message: msg, icon: "circle.fill", colorSwatch: color, accentColor: color)
        }
        
        // 2. URL / Link
        if isURL(trimmed) {
            return SmartClipboardResult(
                message: LanguageManager.tr("Link Copied"),
                icon: "link",
                colorSwatch: nil,
                accentColor: .blue
            )
        }
        
        // 3. Email Address
        if isEmail(trimmed) {
            return SmartClipboardResult(
                message: LanguageManager.tr("Email Copied"),
                icon: "envelope.fill",
                colorSwatch: nil,
                accentColor: Color(red: 0.7, green: 0.35, blue: 0.95)
            )
        }
        
        // 4. Terminal Command or Code
        if let (isCommand, _) = detectCodeOrCommand(trimmed) {
            if isCommand {
                return SmartClipboardResult(
                    message: LanguageManager.tr("Terminal Command Copied"),
                    icon: "terminal.fill",
                    colorSwatch: nil,
                    accentColor: Color(red: 0.2, green: 0.9, blue: 0.5)
                )
            } else {
                return SmartClipboardResult(
                    message: LanguageManager.tr("Code Snippet Copied"),
                    icon: "chevron.left.forwardslash.chevron.right",
                    colorSwatch: nil,
                    accentColor: Color(red: 0.3, green: 0.85, blue: 0.95)
                )
            }
        }
        
        // 5. File / Directory Path
        if isFilePath(trimmed) {
            return SmartClipboardResult(
                message: LanguageManager.tr("File Path Copied"),
                icon: "folder.fill",
                colorSwatch: nil,
                accentColor: Color(red: 1.0, green: 0.8, blue: 0.2)
            )
        }
        
        // 6. Currency / Price
        if isCurrency(trimmed) {
            return SmartClipboardResult(
                message: LanguageManager.tr("Currency Copied"),
                icon: "dollarsign.circle.fill",
                colorSwatch: nil,
                accentColor: Color(red: 0.2, green: 0.85, blue: 0.4)
            )
        }
        
        // 7. Phone Number
        if isPhoneNumber(trimmed) {
            return SmartClipboardResult(
                message: LanguageManager.tr("Phone Number Copied"),
                icon: "phone.fill",
                colorSwatch: nil,
                accentColor: Color(red: 0.2, green: 0.85, blue: 0.4)
            )
        }
        
        // 8. Text with Word Count (Fallback)
        let words = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        if words.count > 2 {
            let msg = "\(LanguageManager.tr("Text Copied")) (\(words.count) \(LanguageManager.tr("words")))"
            return SmartClipboardResult(
                message: msg,
                icon: "text.quote",
                colorSwatch: nil,
                accentColor: .cyan
            )
        } else {
            return SmartClipboardResult(
                message: LanguageManager.tr("Text Copied"),
                icon: "text.quote",
                colorSwatch: nil,
                accentColor: .cyan
            )
        }
    }
    
    // MARK: - Helper Parsers
    private static func parseColor(_ text: String) -> (Color, String)? {
        // HEX (#FFF, #FFFF, #RRGGBB, #RRGGBBAA)
        if text.hasPrefix("#") {
            let hex = String(text.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            if hex.count == 3 || hex.count == 4 || hex.count == 6 || hex.count == 8 {
                var int: UInt64 = 0
                if Scanner(string: hex).scanHexInt64(&int) {
                    let r, g, b, a: Double
                    if hex.count == 3 {
                        r = Double((int >> 8) * 17) / 255.0
                        g = Double((int >> 4 & 0xF) * 17) / 255.0
                        b = Double((int & 0xF) * 17) / 255.0
                        a = 1.0
                    } else if hex.count == 6 {
                        r = Double((int >> 16) & 0xFF) / 255.0
                        g = Double((int >> 8) & 0xFF) / 255.0
                        b = Double(int & 0xFF) / 255.0
                        a = 1.0
                    } else if hex.count == 8 {
                        r = Double((int >> 24) & 0xFF) / 255.0
                        g = Double((int >> 16) & 0xFF) / 255.0
                        b = Double((int >> 8) & 0xFF) / 255.0
                        a = Double(int & 0xFF) / 255.0
                    } else {
                        r = 1.0; g = 1.0; b = 1.0; a = 1.0
                    }
                    let color = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
                    return (color, "#\(hex.uppercased())")
                }
            }
        }
        
        // RGB / RGBA: rgb(255, 99, 71) or rgba(255, 99, 71, 0.8)
        let lower = text.lowercased()
        if (lower.hasPrefix("rgb(") || lower.hasPrefix("rgba(")) && lower.hasSuffix(")") {
            let cleaned = lower.replacingOccurrences(of: "rgba(", with: "")
                               .replacingOccurrences(of: "rgb(", with: "")
                               .replacingOccurrences(of: ")", with: "")
            let parts = cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 3,
               let r = Double(parts[0]), let g = Double(parts[1]), let b = Double(parts[2]) {
                let a = parts.count >= 4 ? (Double(parts[3]) ?? 1.0) : 1.0
                let color = Color(.sRGB, red: min(r, 255.0)/255.0, green: min(g, 255.0)/255.0, blue: min(b, 255.0)/255.0, opacity: a)
                return (color, "RGB")
            }
        }
        return nil
    }
    
    private static func isURL(_ text: String) -> Bool {
        guard !text.contains(" ") && !text.contains("\n") else { return false }
        if text.hasPrefix("http://") || text.hasPrefix("https://") || text.hasPrefix("www.") {
            return true
        }
        if let url = URL(string: text), url.scheme != nil, url.host != nil {
            return true
        }
        return false
    }
    
    private static func isEmail(_ text: String) -> Bool {
        guard !text.contains(" ") && !text.contains("\n") && text.contains("@") && text.contains(".") else { return false }
        let pattern = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
        return text.range(of: pattern, options: .regularExpression) != nil
    }
    
    private static func detectCodeOrCommand(_ text: String) -> (isCommand: Bool, dummy: Void)? {
        let cmdPrefixes = [
            "git ", "npm ", "npx ", "yarn ", "pnpm ", "brew ", "sudo ", "curl ", "wget ",
            "docker ", "podman ", "cargo ", "pip ", "python ", "python3 ", "swift ", "go ",
            "cd ", "ls ", "mkdir ", "chmod ", "chown ", "cat ", "grep ", "ssh ", "scp ",
            "defaults ", "killall ", "xcodebuild ", "code ", "open "
        ]
        if cmdPrefixes.contains(where: { text.hasPrefix($0) }) {
            return (true, ())
        }
        
        let codeKeywords = [
            "func ", "function ", "def ", "class ", "struct ", "enum ", "import ",
            "const ", "export ", "public func ", "private func ", "let ", "var "
        ]
        if codeKeywords.contains(where: { text.hasPrefix($0) }) {
            return (false, ())
        }
        return nil
    }
    
    private static func isFilePath(_ text: String) -> Bool {
        guard !text.contains("\n"), text.count > 2 else { return false }
        if text.hasPrefix("//") { return false }
        if text.hasPrefix("/") || text.hasPrefix("~/") {
            let slashCount = text.filter { $0 == "/" }.count
            return slashCount >= 1 && !text.hasPrefix("http")
        }
        return false
    }
    
    private static func isCurrency(_ text: String) -> Bool {
        guard !text.contains("\n"), text.count <= 25 else { return false }
        let lower = text.lowercased()
        if lower.hasPrefix("rp") || lower.hasPrefix("idr") ||
           text.hasPrefix("$") || text.hasPrefix("€") || text.hasPrefix("£") || text.hasPrefix("¥") {
            return text.contains(where: { $0.isNumber })
        }
        if lower.hasSuffix(" idr") || lower.hasSuffix(" usd") || lower.hasSuffix(" eur") {
            return text.contains(where: { $0.isNumber })
        }
        return false
    }
    
    private static func isPhoneNumber(_ text: String) -> Bool {
        guard !text.contains("\n") else { return false }
        let digits = text.filter { $0.isNumber }
        guard digits.count >= 8 && digits.count <= 15 else { return false }
        let allowed = CharacterSet(charactersIn: "+-() 0123456789")
        if text.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
            return text.hasPrefix("+") || text.hasPrefix("08") || text.hasPrefix("02") || text.hasPrefix("(0") || text.hasPrefix("(")
        }
        return false
    }
}

    private func checkClipboard() {
        let currentChangeCount = pasteboard.changeCount
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            
            // Check content types for HUD
            var icon = "doc.on.doc.fill"
            var msg = LanguageManager.tr("Text Copied")
            var isCut = false
            var colorSwatch: Color? = nil
            var accentColor: Color = .blue
            
            if lastActionWasCut && Date().timeIntervalSince(lastActionTime) < 1.5 {
                isCut = true
                msg = LanguageManager.tr("Cut to Clipboard")
                icon = "scissors"
                accentColor = .orange
            } else {
                if let types = pasteboard.types {
                    if types.contains(.fileURL) {
                        icon = "doc.fill"
                        msg = LanguageManager.tr("File Copied")
                        accentColor = .orange
                    } else if types.contains(.tiff) || types.contains(.png) {
                        icon = "photo.fill"
                        msg = LanguageManager.tr("Image Copied")
                        accentColor = .green
                    } else if types.contains(.string), let str = pasteboard.string(forType: .string) {
                        let smart = SmartClipboardDetector.detect(text: str)
                        msg = smart.message
                        icon = smart.icon
                        colorSwatch = smart.colorSwatch
                        accentColor = smart.accentColor
                    }
                }
            }
            
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    self.clipboardMessage = msg
                    self.clipboardIcon = icon
                    self.clipboardIsCut = isCut
                    self.clipboardColorSwatch = colorSwatch
                    self.clipboardAccentColor = accentColor
                    self.showClipboardHUD = true
                    self.showBatteryHUD = false
                    self.showDeviceHUD = false
                    self.showVolumeHUD = false
                    self.showTimesUp = false
                }
                self.scheduleHUDDismiss()
                
                // Keep the history update for text
                if let newString = self.pasteboard.string(forType: .string), !newString.isEmpty {
                    var currentItems = self.clipboardItems
                    currentItems.removeAll { $0 == newString }
                    currentItems.insert(newString, at: 0)
                    if currentItems.count > 25 {
                        currentItems = Array(currentItems.prefix(25))
                    }
                    self.clipboardItems = currentItems
                }
            }
        }
    }
    
    func togglePinClipboard(item: String) {
        if pinnedClipboardItems.contains(item) {
            pinnedClipboardItems.removeAll { $0 == item }
        } else {
            pinnedClipboardItems.insert(item, at: 0)
        }
    }
    
    func isClipboardPinned(item: String) -> Bool {
        return pinnedClipboardItems.contains(item)
    }
    
    var sortedClipboardItems: [String] {
        let pinned = clipboardItems.filter { isClipboardPinned(item: $0) }
        let unpinned = clipboardItems.filter { !isClipboardPinned(item: $0) }
        return pinned + unpinned
    }
    
    func clearUnpinnedClipboard() {
        clipboardItems = clipboardItems.filter { isClipboardPinned(item: $0) }
    }
    
    func startAgendaPolling() {
        // Poll every 10 seconds to check for events starting soon
        agendaTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.checkUpcomingEvents()
        }
    }
    
    func fetchAgenda() {
        self.agendaEvents = CustomAgendaManager.shared.fetchEvents(forDateOffset: self.agendaDateOffset)
    }
    
    private func checkUpcomingEvents() {
        let events = CustomAgendaManager.shared.fetchEvents(forDateOffset: 0) // Always check today for notifications
        let now = Date()
        
        for event in events {
            let timeUntilEvent = event.date.timeIntervalSince(now)
            // Trigger blossom between 5m and 4m 50s before event to avoid multiple triggers
            if timeUntilEvent > 290 && timeUntilEvent <= 300 {
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                        self.agendaHUDMessage = "\(event.title) — 5 menit lagi"
                        self.showAgendaHUD = true
                        self.showBatteryHUD = false
                        self.showDeviceHUD = false
                        self.showVolumeHUD = false
                        self.showTimesUp = false
                        self.showClipboardHUD = false
                    }
                    self.scheduleHUDDismiss()
                }
                break // Only trigger one event
            }
        }
    }
    
    func seek(to time: Double) {
        MediaRemoteHelper.shared.seek(to: time)
        self.elapsed = time
    }
    
    static func extractDominantColor(from image: NSImage) -> Color {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let ciImage = CIImage(bitmapImageRep: bitmap) else { return .clear }
        
        let size = 16 // Sample small area for speed
        let extent = ciImage.extent
        let scaleX = CGFloat(size) / extent.width
        let scaleY = CGFloat(size) / extent.height
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(scaled, from: CGRect(x: 0, y: 0, width: size, height: size)) else { return .clear }
        
        guard let data = cgImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return .clear }
        
        var totalR: CGFloat = 0, totalG: CGFloat = 0, totalB: CGFloat = 0
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let count = size * size
        
        for i in 0..<count {
            let offset = i * bytesPerPixel
            totalR += CGFloat(ptr[offset])
            totalG += CGFloat(ptr[offset + 1])
            totalB += CGFloat(ptr[offset + 2])
        }
        
        let n = CGFloat(count)
        var r = totalR / n / 255.0
        var g = totalG / n / 255.0
        var b = totalB / n / 255.0
        
        // Boost saturation for vivid glow
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let mid = (maxC + minC) / 2
        if maxC - minC > 0.05 {
            r = mid + (r - mid) * 1.8
            g = mid + (g - mid) * 1.8
            b = mid + (b - mid) * 1.8
            r = min(1, max(0, r))
            g = min(1, max(0, g))
            b = min(1, max(0, b))
        }
        
        return Color(red: Double(r), green: Double(g), blue: Double(b))
    }
}

// MARK: - Marquee Text
struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    
    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var animating = false
    
    var body: some View {
        GeometryReader { geo in
            let needsScroll = textWidth > geo.size.width
            
            ZStack(alignment: .leading) {
                if needsScroll {
                    HStack(spacing: 40) {
                        textView
                        textView
                    }
                    .offset(x: offset)
                    .onAppear {
                        containerWidth = geo.size.width
                        startScrolling()
                    }
                } else {
                    textView
                }
            }
            .frame(width: geo.size.width, alignment: .leading)
            .clipped()
        }
        .frame(height: 16)
        .onChange(of: text) { _ in
            startScrolling()
        }
    }
    
    private var textView: some View {
        Text(text)
            .font(font)
            .foregroundColor(color)
            .lineLimit(1)
            .fixedSize()
            .background(GeometryReader { g in
                Color.clear
                    .onAppear { textWidth = g.size.width }
                    .onChange(of: g.size.width) { newWidth in
                        textWidth = newWidth
                        startScrolling()
                    }
            })
    }
    
    private func startScrolling() {
        guard textWidth > containerWidth else { 
            withAnimation(nil) { offset = 0 }
            return 
        }
        
        withAnimation(nil) {
            offset = 0
        }
        
        let scrollDistance = textWidth + 40
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard textWidth > containerWidth else { return }
            withAnimation(.linear(duration: Double(scrollDistance) / 30.0).repeatForever(autoreverses: false)) {
                offset = -scrollDistance
            }
        }
    }
}



// MARK: - Drop Zone View
struct DropZoneCardView: View {
    @ObservedObject var viewModel: NotchViewModel
    
    private var totalFilesSize: Int64 {
        viewModel.stagedFiles.reduce(Int64(0)) { $0 + Self.getFileSize(for: $1) }
    }
    
    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    static func getFileSize(for url: URL) -> Int64 {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            return size
        }
        return 0
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.cyan)
                    Text(LanguageManager.tr("Drop Zone"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    if !viewModel.stagedFiles.isEmpty {
                        Text("\(viewModel.stagedFiles.count) • \(Self.formatFileSize(totalFilesSize))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                if !viewModel.stagedFiles.isEmpty {
                    HStack(spacing: 6) {
                        Button(action: {
                            let picker = NSSharingServicePicker(items: viewModel.stagedFiles)
                            if let window = NSApp.keyWindow ?? NSApp.windows.first, let contentView = window.contentView {
                                picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 10))
                                Text(LanguageManager.tr("Share All"))
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                viewModel.stagedFiles.removeAll()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                Text(LanguageManager.tr("Clear All"))
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.top, 2)
            
            if viewModel.stagedFiles.isEmpty {
                // Drop Area Shelf Empty State
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.cyan.opacity(0.4), Color.blue.opacity(0.2), Color.white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                                )
                        )
                    
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.cyan.opacity(0.25), Color.blue.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 42, height: 42)
                            
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundColor(.cyan)
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(LanguageManager.tr("Drop Files Here"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text(LanguageManager.tr("Quick shelf to drag & drop files anywhere"))
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 72)
                .padding(.top, 2)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.stagedFiles, id: \.self) { url in
                            VStack(spacing: 5) {
                                ZStack(alignment: .topTrailing) {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                        .resizable()
                                        .frame(width: 34, height: 34)
                                        .padding(4)
                                    
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            viewModel.stagedFiles.removeAll { $0 == url }
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .offset(x: 4, y: -4)
                                }
                                
                                Text(url.lastPathComponent)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .frame(width: 62)
                                
                                Text(Self.formatFileSize(Self.getFileSize(for: url)))
                                    .font(.system(size: 8, weight: .regular))
                                    .foregroundColor(.white.opacity(0.45))
                                    .lineLimit(1)
                                
                                HStack(spacing: 6) {
                                    // Quick Look / Open
                                    Button(action: {
                                        NSWorkspace.shared.open(url)
                                    }) {
                                        Image(systemName: "arrow.up.forward.app")
                                            .font(.system(size: 9))
                                            .foregroundColor(.white.opacity(0.7))
                                            .padding(3)
                                            .background(Color.white.opacity(0.08))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help(LanguageManager.tr("Open file"))
                                    
                                    // Share / AirDrop
                                    Button(action: {
                                        let picker = NSSharingServicePicker(items: [url])
                                        if let window = NSApp.keyWindow ?? NSApp.windows.first, let contentView = window.contentView {
                                            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
                                        }
                                    }) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 9))
                                            .foregroundColor(.white.opacity(0.7))
                                            .padding(3)
                                            .background(Color.white.opacity(0.08))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help(LanguageManager.tr("Share or AirDrop"))
                                }
                                .padding(.top, 2)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.07))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                    )
                            )
                            .overlay(
                                DragSourceOverlay(url: url) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                                        viewModel.stagedFiles.removeAll { $0 == url }
                                    }
                                }
                            )
                            .contextMenu {
                                Button(LanguageManager.tr("Open file")) {
                                    NSWorkspace.shared.open(url)
                                }
                                Button(LanguageManager.tr("Share or AirDrop")) {
                                    let picker = NSSharingServicePicker(items: [url])
                                    if let window = NSApp.keyWindow ?? NSApp.windows.first, let contentView = window.contentView {
                                        picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
                                    }
                                }
                                Divider()
                                Button(LanguageManager.tr("Remove")) {
                                    withAnimation {
                                        viewModel.stagedFiles.removeAll { $0 == url }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

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

// MARK: - Detached Pomodoro Island
struct DetachedPomodoroView: View {
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                viewModel.selectedTab = .pomodoro
                viewModel.isExpanded = true
            }
        }) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 3)
                        .frame(width: 18, height: 18)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(viewModel.pomodoroTotal > 0 ? viewModel.pomodoroRemaining / viewModel.pomodoroTotal : 0))
                        .stroke(
                            viewModel.isPomodoroPaused ? Color.yellow : Color.orange,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 18, height: 18)
                        .rotationEffect(.degrees(-90))
                }
                
                Text(timeString(from: viewModel.pomodoroRemaining))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(viewModel.isPomodoroPaused ? .yellow : .orange)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(Color.black)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke((viewModel.isPomodoroPaused ? Color.yellow : Color.orange).opacity(0.4), lineWidth: 1)
            )
            .shadow(color: (viewModel.isPomodoroPaused ? Color.yellow : Color.orange).opacity(0.3), radius: 5, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
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


// MARK: - Calculator View
struct CalculatorView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var showCopiedCheck: Bool = false
    
    let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]
    let buttons = [
        ["7", "8", "9", "÷"],
        ["4", "5", "6", "×"],
        ["1", "2", "3", "-"],
        ["C", "0", "=", "+"]
    ]
    
    var body: some View {
        VStack(spacing: 6) {
            // Expression Bar & Quick Actions
            HStack {
                Text(viewModel.calcExpression)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                
                Spacer()
                
                // Backspace button
                Button(action: handleBackspace) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(5)
                }
                .buttonStyle(PlainButtonStyle())
                .help(LanguageManager.tr("Delete last digit"))
                
                // Copy button
                Button(action: copyResult) {
                    HStack(spacing: 3) {
                        Image(systemName: showCopiedCheck ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9, weight: .bold))
                        if showCopiedCheck {
                            Text(LanguageManager.tr("Copied!"))
                                .font(.system(size: 9, weight: .bold))
                        }
                    }
                    .foregroundColor(showCopiedCheck ? .green : .white.opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(showCopiedCheck ? Color.green.opacity(0.18) : Color.white.opacity(0.08))
                    .cornerRadius(5)
                }
                .buttonStyle(PlainButtonStyle())
                .help(LanguageManager.tr("Copy result"))
            }
            .frame(height: 18)
            .padding(.horizontal, 4)
            
            // Main Number Display
            Button(action: copyResult) {
                Text(viewModel.calcInput)
                    .font(.system(size: 26, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(height: 32)
            }
            .buttonStyle(PlainButtonStyle())
            .help(LanguageManager.tr("Click to copy"))
            
            // Buttons Grid
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(buttons.flatMap { $0 }, id: \.self) { btn in
                    let isActiveOp = viewModel.calcOperator == btn && viewModel.calcIsNewInput
                    Button(action: { handlePress(btn) }) {
                        Text(btn)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isActiveOp ? .white : (isOperator(btn) ? .orange : .white))
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .background(
                                isActiveOp ? Color.orange : (isOperator(btn) ? Color.orange.opacity(0.2) : Color.white.opacity(0.12))
                            )
                            .cornerRadius(8)
                            .shadow(color: isActiveOp ? Color.orange.opacity(0.4) : .clear, radius: 4, x: 0, y: 1)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private func isOperator(_ btn: String) -> Bool {
        ["÷", "×", "-", "+", "="].contains(btn)
    }
    
    private func handleBackspace() {
        guard !viewModel.calcIsNewInput else { return }
        if viewModel.calcInput.count > 1 {
            viewModel.calcInput.removeLast()
        } else {
            viewModel.calcInput = "0"
        }
    }
    
    private func copyResult() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(viewModel.calcInput, forType: .string)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            showCopiedCheck = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopiedCheck = false }
        }
    }
    
    private func handlePress(_ btn: String) {
        if let num = Int(btn) {
            if viewModel.calcIsNewInput || viewModel.calcInput == "0" {
                viewModel.calcInput = "\(num)"
                viewModel.calcIsNewInput = false
            } else {
                viewModel.calcInput += "\(num)"
            }
        } else if btn == "C" {
            viewModel.calcInput = "0"
            viewModel.calcPrevious = nil
            viewModel.calcOperator = nil
            viewModel.calcExpression = ""
            viewModel.calcIsNewInput = false
        } else if btn == "=" {
            if let op = viewModel.calcOperator, let prev = viewModel.calcPrevious, let current = Double(viewModel.calcInput) {
                viewModel.calcExpression = "\(formatDouble(prev)) \(op) \(formatDouble(current)) ="
                calculate()
                viewModel.calcOperator = nil
                viewModel.calcIsNewInput = true
            }
        } else {
            // Operator pressed (+, -, ×, ÷)
            if viewModel.calcOperator != nil && !viewModel.calcIsNewInput {
                calculate()
            } else {
                viewModel.calcPrevious = Double(viewModel.calcInput)
            }
            viewModel.calcOperator = btn
            viewModel.calcExpression = "\(viewModel.calcInput) \(btn)"
            viewModel.calcIsNewInput = true
        }
    }
    
    private func formatDouble(_ val: Double) -> String {
        if val.truncatingRemainder(dividingBy: 1) == 0 && abs(val) < 1e12 {
            return "\(Int(val))"
        } else {
            return String(format: "%g", val)
        }
    }
    
    private func calculate() {
        guard let op = viewModel.calcOperator, let prev = viewModel.calcPrevious, let current = Double(viewModel.calcInput) else { return }
        var result: Double = 0
        switch op {
        case "+": result = prev + current
        case "-": result = prev - current
        case "×": result = prev * current
        case "÷": result = current != 0 ? prev / current : 0
        default: break
        }
        viewModel.calcInput = formatDouble(result)
        viewModel.calcPrevious = result
    }
}

// MARK: - Media Card View
struct MediaCardView: View {
    @ObservedObject var viewModel: NotchViewModel
    @AppStorage("enableLyrics") private var enableLyrics = false
    
    var body: some View {
        VStack(spacing: 8) {
            mediaInfoRow
            
            // Animated Lyrics (only if enabled and available)
            if enableLyrics && !viewModel.lyrics.isEmpty {
                lyricsSection
            }
        }
    }
    
    private var mediaInfoRow: some View {
        HStack(spacing: 12) {
            albumArt
            metadataSection
            Spacer(minLength: 4)
            playbackControls
        }
    }
    
    @ViewBuilder
    private var albumArt: some View {
        Button(action: {
            MediaRemoteHelper.shared.activatePlayerApp()
        }) {
            ZStack(alignment: .bottomTrailing) {
                if let img = viewModel.artwork {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.5))
                        )
                }
                
                // Mini Player App Badge
                if let icon = viewModel.playerAppIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 15, height: 15)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        .offset(x: 3, y: 3)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .help(viewModel.playerAppName.isEmpty ? LanguageManager.tr("Media Player") : "\(LanguageManager.tr("Open in")) \(viewModel.playerAppName)")
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(viewModel.currentSong)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            
            if !viewModel.currentArtist.isEmpty {
                Text(viewModel.currentArtist)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            
            if viewModel.duration > 0 {
                scrubberRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var scrubberRow: some View {
        LiveScrubberView(viewModel: viewModel)
            .padding(.top, 1)
    }
    
    private var playbackControls: some View {
        HStack(spacing: 6) {
            Button(action: {
                MediaRemoteHelper.shared.previousTrack()
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }.buttonStyle(PlainButtonStyle())
            
            Button(action: {
                MediaRemoteHelper.shared.togglePlayPause()
            }) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }.buttonStyle(PlainButtonStyle())
            
            Button(action: {
                MediaRemoteHelper.shared.nextTrack()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }.buttonStyle(PlainButtonStyle())
        }
    }
    
    private var lyricsSection: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    Spacer().frame(height: 35)
                    ForEach(Array(viewModel.lyrics.enumerated()), id: \.element.id) { index, line in
                        lyricLine(line: line, index: index)
                    }
                    Spacer().frame(height: 35)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 90)
            .mask(
                LinearGradient(gradient: Gradient(colors: [
                    .clear,
                    .black.opacity(0.3),
                    .black,
                    .black,
                    .black.opacity(0.3),
                    .clear
                ]), startPoint: .top, endPoint: .bottom)
            )
            .onChange(of: viewModel.currentLyricIndex) { idx in
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo(idx, anchor: .center)
                }
            }
            .onAppear {
                if viewModel.currentLyricIndex >= 0 {
                    proxy.scrollTo(viewModel.currentLyricIndex, anchor: .center)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
    
    private func lyricLine(line: LyricLine, index: Int) -> some View {
        let isCurrent = index == viewModel.currentLyricIndex
        return Text(line.text)
            .font(.system(size: isCurrent ? 16 : 13, weight: isCurrent ? .bold : .medium, design: .rounded))
            .foregroundColor(isCurrent ? .white : .gray.opacity(0.5))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
            .id(index)
            .scaleEffect(isCurrent ? 1.03 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.currentLyricIndex)
    }
    
    private func formatTime(_ time: Double) -> String {
        guard !time.isNaN && !time.isInfinite else { return "0:00" }
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ClipboardStackView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var copiedItemId: String? = nil
    @State private var searchQuery: String = ""
    
    static func parseHexColor(_ text: String) -> Color? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#") else { return nil }
        let hex = String(trimmed.dropFirst())
        guard hex.count == 3 || hex.count == 6 || hex.count == 8 else { return nil }
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }
        let r, g, b, a: Double
        if hex.count == 3 {
            r = Double((int >> 8) * 17) / 255.0
            g = Double((int >> 4 & 0xF) * 17) / 255.0
            b = Double((int & 0xF) * 17) / 255.0
            a = 1.0
        } else if hex.count == 6 {
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
            a = 1.0
        } else {
            r = Double((int >> 24) & 0xFF) / 255.0
            g = Double((int >> 16) & 0xFF) / 255.0
            b = Double((int >> 8) & 0xFF) / 255.0
            a = Double(int & 0xFF) / 255.0
        }
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
    
    static func parseURL(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if (trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")), let url = URL(string: trimmed), url.host != nil {
            return url
        }
        return nil
    }
    
    private var filteredItems: [String] {
        let all = viewModel.sortedClipboardItems
        if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return Array(all.prefix(3))
        } else {
            return Array(all.filter { $0.localizedCaseInsensitiveContains(searchQuery) }.prefix(3))
        }
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue)
                    Text(LanguageManager.tr("Recent Clipboard"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    if !viewModel.clipboardItems.isEmpty {
                        Text("\(viewModel.clipboardItems.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                if !viewModel.clipboardItems.isEmpty {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            viewModel.clearUnpinnedClipboard()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                            Text(LanguageManager.tr("Clear"))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.top, 1)
            
            // Search Bar (shown when there are items)
            if !viewModel.clipboardItems.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                    
                    TextField(LanguageManager.tr("Search clipboard..."), text: $searchQuery)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                    
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
            }
            
            if viewModel.clipboardItems.isEmpty {
                // Empty state card
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.3), Color.indigo.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 42, height: 42)
                            
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(LanguageManager.tr("Clipboard is Empty"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text(LanguageManager.tr("Copied text and snippets will appear here"))
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // Shortcut badge
                        HStack(spacing: 2) {
                            Text("⌘")
                                .font(.system(size: 11, weight: .bold))
                            Text("C")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 72)
                .padding(.top, 2)
            } else if filteredItems.isEmpty {
                // Search has no matching items
                HStack {
                    Spacer()
                    Text(LanguageManager.tr("No matching items"))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.45))
                    Spacer()
                }
                .frame(height: 50)
            } else {
                VStack(spacing: 5) {
                    ForEach(filteredItems, id: \.self) { item in
                        let isPinned = viewModel.isClipboardPinned(item: item)
                        let hexColor = Self.parseHexColor(item)
                        let parsedURL = Self.parseURL(item)
                        
                        HStack(spacing: 8) {
                            // Pin Button
                            Button(action: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                    viewModel.togglePinClipboard(item: item)
                                }
                            }) {
                                Image(systemName: isPinned ? "pin.fill" : "pin")
                                    .font(.system(size: 9))
                                    .foregroundColor(isPinned ? .orange : .white.opacity(0.3))
                                    .padding(4)
                                    .background(isPinned ? Color.orange.opacity(0.18) : Color.white.opacity(0.04))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help(isPinned ? LanguageManager.tr("Unpin") : LanguageManager.tr("Pin to top"))
                            
                            // Smart Icon / Swatch
                            if let color = hexColor {
                                Circle()
                                    .fill(color)
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                            } else if parsedURL != nil {
                                Image(systemName: "link")
                                    .font(.system(size: 10))
                                    .foregroundColor(.cyan)
                            } else {
                                Image(systemName: "text.alignleft")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            
                            Text(item)
                                .lineLimit(1)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Smart URL open button
                            if let url = parsedURL {
                                Button(action: {
                                    NSWorkspace.shared.open(url)
                                }) {
                                    Image(systemName: "arrow.up.forward.square")
                                        .font(.system(size: 11))
                                        .foregroundColor(.cyan)
                                        .padding(4)
                                        .background(Color.cyan.opacity(0.12))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help(LanguageManager.tr("Open in browser"))
                            }
                            
                            if copiedItemId == item {
                                HStack(spacing: 3) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                    Text(LanguageManager.tr("Copied!"))
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Capsule())
                            } else {
                                Button(action: {
                                    let pb = NSPasteboard.general
                                    pb.clearContents()
                                    pb.setString(item, forType: .string)
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                                        copiedItemId = item
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        if copiedItemId == item {
                                            withAnimation { copiedItemId = nil }
                                        }
                                    }
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.55))
                                        .padding(4)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        viewModel.clipboardItems.removeAll { $0 == item }
                                        viewModel.pinnedClipboardItems.removeAll { $0 == item }
                                    }
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white.opacity(0.4))
                                        .padding(4)
                                        .background(Color.white.opacity(0.05))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isPinned ? Color.orange.opacity(0.08) : Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isPinned ? Color.orange.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 0.8)
                                )
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Notch Shape
struct NotchShape: Shape {
    var cornerRadius: CGFloat
    var flareRadius: CGFloat = 12
    
    var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let leftX = flareRadius
        let rightX = rect.maxX - flareRadius
        
        path.move(to: CGPoint(x: 0, y: 0))
        path.addArc(
            center: CGPoint(x: 0, y: flareRadius),
            radius: flareRadius,
            startAngle: .degrees(270),
            endAngle: .degrees(360),
            clockwise: false
        )
        
        path.addLine(to: CGPoint(x: leftX, y: rect.maxY - cornerRadius))
        
        path.addArc(
            center: CGPoint(x: leftX + cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(90),
            clockwise: true
        )
        
        path.addLine(to: CGPoint(x: rightX - cornerRadius, y: rect.maxY))
        
        path.addArc(
            center: CGPoint(x: rightX - cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(90),
            endAngle: .degrees(0),
            clockwise: true
        )
        
        path.addLine(to: CGPoint(x: rightX, y: flareRadius))
        
        path.addArc(
            center: CGPoint(x: rect.maxX, y: flareRadius),
            radius: flareRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Hover Tracking View for Background Apps
struct HoverTrackingView: NSViewRepresentable {
    var onHoverStateChanged: (Bool) -> Void
    
    func makeNSView(context: Context) -> TrackingNSView {
        let view = TrackingNSView()
        view.onHoverStateChanged = onHoverStateChanged
        return view
    }
    
    func updateNSView(_ nsView: TrackingNSView, context: Context) {}
}

class TrackingNSView: NSView {
    var onHoverStateChanged: ((Bool) -> Void)?
    var trackingArea: NSTrackingArea?
    private var isMouseInside = false
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
        
        // Fix for missing mouseExited during resize animations
        if isMouseInside {
            if let window = self.window {
                let mouseLocation = window.mouseLocationOutsideOfEventStream

                let localPoint = self.convert(mouseLocation, from: nil)
                
                let isOutsideBounds = !self.bounds.contains(localPoint)
                let isOutsideHorizontally = localPoint.x < 0 || localPoint.x > self.bounds.maxX
                let isAtTopEdge = localPoint.y >= self.bounds.maxY - 2 && !isOutsideHorizontally
                
                if isOutsideBounds && !isAtTopEdge {
                    isMouseInside = false
                    DispatchQueue.main.async {
                        self.onHoverStateChanged?(false)
                    }
                }
            }
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        if !isMouseInside {
            isMouseInside = true
            onHoverStateChanged?(true)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        // Prevent false exits ONLY when cursor hits the absolute TOP edge of the screen
        if let window = self.window {
            let mouseLocation = window.mouseLocationOutsideOfEventStream
            let localPoint = self.convert(mouseLocation, from: nil)
            
            let isOutsideHorizontally = localPoint.x < 0 || localPoint.x > self.bounds.maxX
            
            // macOS sometimes fires mouseExited when hitting the menu bar area
            if localPoint.y >= self.bounds.maxY - 2 && !isOutsideHorizontally {
                return // False alarm, cursor is at the very top edge, but still within our width
            }
        }
        
        if isMouseInside {
            isMouseInside = false
            onHoverStateChanged?(false)
        }
    }
}

// MARK: - Drop Tracking View
struct DropTrackingView: NSViewRepresentable {
    var onDragEntered: () -> Void
    var onDragExited: () -> Void
    var onDrop: ([URL]) -> Void
    
    func makeNSView(context: Context) -> DropNSView {
        let view = DropNSView()
        view.onDragEntered = onDragEntered
        view.onDragExited = onDragExited
        view.onDrop = onDrop
        return view
    }
    
    func updateNSView(_ nsView: DropNSView, context: Context) {}
}

class DropNSView: NSView {
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?
    var onDrop: (([URL]) -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragEntered?()
        return .copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragExited?()
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            onDrop?(urls)
            return true
        }
        return false
    }
}

// MARK: - Drag Source View
struct DragSourceOverlay: NSViewRepresentable {
    var url: URL
    var onDragSuccess: () -> Void
    
    func makeNSView(context: Context) -> DragSourceNSView {
        let view = DragSourceNSView()
        view.url = url
        view.onDragSuccess = onDragSuccess
        return view
    }
    
    func updateNSView(_ nsView: DragSourceNSView, context: Context) {
        nsView.url = url
        nsView.onDragSuccess = onDragSuccess
    }
}

class DragSourceNSView: NSView, NSDraggingSource {
    var url: URL?
    var onDragSuccess: (() -> Void)?
    
    override func mouseDown(with event: NSEvent) {
        // Needs to be implemented to catch mouseDragged
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let url = url else { return }
        
        let draggingItem = NSDraggingItem(pasteboardWriter: url as NSURL)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 32, height: 32)
        
        let draggingFrame = NSRect(x: (self.bounds.width - 32) / 2, y: (self.bounds.height - 32) / 2, width: 32, height: 32)
        draggingItem.setDraggingFrame(draggingFrame, contents: icon)
        
        self.beginDraggingSession(with: [draggingItem], event: event, source: self)
    }
    
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
    
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if operation != [] {
            DispatchQueue.main.async {
                self.onDragSuccess?()
            }
        }
    }
}

// MARK: - Waveform View
struct WaveformView: View {
    var isPlaying: Bool
    var color: Color = .orange
    @State private var heights: [CGFloat] = [4, 4, 4, 4]
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color == .clear ? Color.orange : color)
                    .frame(width: 3, height: heights[i])
                    .animation(.easeInOut(duration: 0.3), value: color)
            }
        }
        .onChange(of: isPlaying) { playing in
            if playing {
                startAnimating()
            } else {
                stopAnimating()
            }
        }
        .onAppear {
            if isPlaying {
                startAnimating()
            }
        }
    }
    
    private func startAnimating() {
        animating = true
        animateWave()
    }
    
    private func stopAnimating() {
        animating = false
        withAnimation(.easeOut(duration: 0.3)) {
            for i in 0..<4 { heights[i] = 4 }
        }
    }
    
    private func animateWave() {
        guard animating else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            for i in 0..<4 {
                heights[i] = CGFloat.random(in: 3...16)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            animateWave()
        }
    }
}

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
        Text(timeString)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
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
        }
        .padding(.horizontal, 28)
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

// MARK: - Tab Picker Views
struct TabPickerRowView: View {
    let tab: NotchTab
    let isSelected: Bool
    let isPinned: Bool
    let canPin: Bool
    let onSelect: () -> Void
    let onTogglePin: () -> Void
    
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: tab.rawValue)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : (isHovered ? .white : .gray))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.blue.opacity(0.35) : Color.white.opacity(0.06))
                )
            
            Text(tab.displayName)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : (isHovered ? .white : .white.opacity(0.85)))
            
            Spacer()
            
            Button(action: {
                if canPin || isPinned {
                    onTogglePin()
                }
            }) {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isPinned ? Color.blue : (canPin ? (isHovered ? Color.white : Color.gray) : Color.gray.opacity(0.3)))
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!isPinned && !canPin)
            .help(isPinned ? LanguageManager.tr("Unpin from bar") : (canPin ? LanguageManager.tr("Pin to bar") : LanguageManager.tr("Max 6 tabs reached")))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.white.opacity(0.12) : (isHovered ? Color.white.opacity(0.08) : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { h in
            isHovered = h
        }
        .onTapGesture {
            onSelect()
        }
    }
}

struct TabPickerPopoverView: View {
    @ObservedObject var viewModel: NotchViewModel
    let pinnedTabs: [NotchTab]
    let allTabs: [NotchTab]
    let onTogglePin: (NotchTab) -> Void
    let onSelectTab: (NotchTab) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Text(LanguageManager.tr("Notchify Features"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(pinnedTabs.count)/6 " + LanguageManager.tr("Pinned (Max 6)"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(pinnedTabs.count >= 6 ? Color.orange : Color.white.opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                    )
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
            
            Divider()
                .background(Color.white.opacity(0.12))
                .padding(.vertical, 2)
            
            // Tab list
            VStack(spacing: 2) {
                ForEach(allTabs) { tab in
                    let isPinned = pinnedTabs.contains(tab)
                    let isSelected = viewModel.selectedTab == tab
                    let canPin = isPinned || pinnedTabs.count < 6
                    
                    TabPickerRowView(
                        tab: tab,
                        isSelected: isSelected,
                        isPinned: isPinned,
                        canPin: canPin,
                        onSelect: {
                            onSelectTab(tab)
                        },
                        onTogglePin: {
                            onTogglePin(tab)
                        }
                    )
                }
            }
        }
        .padding(10)
        .frame(width: 250)
    }
}

// MARK: - Notch Container View
struct ContentView: View {
    @StateObject private var viewModel = NotchViewModel()
    
    @AppStorage("enableGlow") private var enableGlow = false
    @AppStorage("enableLyrics") private var enableLyrics = false
    @AppStorage("appLanguage") private var appLanguage = "en" 

    @AppStorage("notchOpacity") private var notchOpacity: Double = 1.0
    @AppStorage("expandTrigger") private var expandTrigger: String = "hover"
    @AppStorage("autoHideDelay") private var autoHideDelay: Double = 0.05
    @AppStorage("tabOrderStr") private var tabOrderStr = "media,clipboard,dropzone,pomodoro,calculator,weather,system,agenda,mirror"
    @AppStorage("hiddenTabsStr") private var hiddenTabsStr = ""
    @AppStorage("pinnedTabsStr") private var pinnedTabsStr = "music.note,doc.on.clipboard,tray.and.arrow.down.fill,timer"
    
    @State private var showTabPicker: Bool = false
    @State private var isLeftChevronHovered: Bool = false
    @State private var isRightChevronHovered: Bool = false
    @State private var isMouseInsideNotch: Bool = false
    
    private var visibleTabs: [NotchTab] {
        let order = tabOrderStr.split(separator: ",").compactMap { NotchTab.from(string: String($0)) }
        let hidden = hiddenTabsStr.split(separator: ",").compactMap { NotchTab.from(string: String($0)) }
        
        var tabs = order.filter { !hidden.contains($0) }
        
        // Ensure all tabs exist (in case of updates adding new tabs)
        for tab in NotchTab.allCases {
            if !order.contains(tab) && !hidden.contains(tab) {
                tabs.append(tab)
            }
        }
        
        return tabs
    }
    
    private var pinnedTabs: [NotchTab] {
        let items = pinnedTabsStr.split(separator: ",").compactMap { NotchTab.from(string: String($0)) }
        let available = items.filter { visibleTabs.contains($0) }
        if available.isEmpty {
            return [.media, .clipboard, .dropzone, .pomodoro].filter { visibleTabs.contains($0) }
        }
        return Array(available.prefix(6))
    }
    
    private func togglePin(_ tab: NotchTab) {
        var current = pinnedTabs
        if let idx = current.firstIndex(of: tab) {
            current.remove(at: idx)
        } else {
            guard current.count < 6 else { return }
            current.append(tab)
        }
        pinnedTabsStr = current.map { $0.rawValue }.joined(separator: ",")
    }
    
    private func navigateToNextTab() {
        let tabs = visibleTabs.isEmpty ? NotchTab.allCases : visibleTabs
        guard let idx = tabs.firstIndex(of: viewModel.selectedTab) else {
            if let first = tabs.first { viewModel.selectedTab = first }
            return
        }
        let nextIdx = (idx + 1) % tabs.count
        viewModel.selectedTab = tabs[nextIdx]
    }
    
    private func navigateToPrevTab() {
        let tabs = visibleTabs.isEmpty ? NotchTab.allCases : visibleTabs
        guard let idx = tabs.firstIndex(of: viewModel.selectedTab) else {
            if let last = tabs.last { viewModel.selectedTab = last }
            return
        }
        let prevIdx = (idx - 1 + tabs.count) % tabs.count
        viewModel.selectedTab = tabs[prevIdx]
    }
    
    private let clockWidth: CGFloat = 130
    private let mediaWidth: CGFloat = 220
    private let compactHeight: CGFloat = 34
    private let expandedWidth: CGFloat = 420
    private let expandedHeight: CGFloat = 175
    
    @State private var previousApp: NSRunningApplication?
    @State private var blossomHeight: CGFloat = 0
    @State private var isHiddenByFullscreen: Bool = false
    @State private var isPomodoroInMainIsland: Bool = false
    @State private var pauseGraceTimer: Timer? = nil
    
    private var currentWidth: CGFloat {
        if viewModel.isExpanded { return expandedWidth }
        if viewModel.showBatteryHUD { return 250 }
        if viewModel.showClipboardHUD { return 255 }
        if viewModel.showTimesUp { return 260 }
        if viewModel.showDeviceHUD { return 260 }
        if viewModel.showVolumeHUD { return 160 }
        if viewModel.isHoveringWithFile { return 255 }
        if viewModel.showDropSuccessHUD { return 220 }
        if viewModel.isPomodoroActive && isPomodoroInMainIsland { return mediaWidth }
        return viewModel.showClock ? clockWidth : mediaWidth
    }

    private var currentHeight: CGFloat {
        if viewModel.isExpanded {
            if viewModel.selectedTab == .calculator { return 275 }
            if viewModel.selectedTab == .media {
                if !viewModel.lyrics.isEmpty && enableLyrics { return 285 }
                return viewModel.duration > 0 ? 152 : 142
            }
            if viewModel.selectedTab == .weather { return 165 }
            if viewModel.selectedTab == .system { return 215 }
            if viewModel.selectedTab == .agenda { return viewModel.isPinningExpansion ? 330 : 275 }
            if viewModel.selectedTab == .pomodoro { return 185 }
            if viewModel.selectedTab == .dropzone { return viewModel.stagedFiles.isEmpty ? 180 : 195 }
            if viewModel.selectedTab == .clipboard { return viewModel.clipboardItems.isEmpty ? 180 : 235 }
            if viewModel.selectedTab == .mirror { return 350 }
            if viewModel.selectedTab == .notes { return 270 }
            if viewModel.selectedTab == .network { return 245 }
            return 150
        }
        if viewModel.showBatteryHUD { return 44 }
        if viewModel.showClipboardHUD { return 44 }
        if viewModel.showTimesUp { return 64 }
        if viewModel.showDeviceHUD { return 44 }
        if viewModel.showVolumeHUD { return 44 }
        if viewModel.showAgendaHUD { return 44 }
        if viewModel.isHoveringWithFile { return 56 }
        if viewModel.showDropSuccessHUD { return 46 }
        return compactHeight + blossomHeight
    }
    
    private var isBlossoming: Bool {
        viewModel.showBatteryHUD || viewModel.showClipboardHUD || viewModel.showTimesUp || viewModel.showDeviceHUD || viewModel.showVolumeHUD || viewModel.showAgendaHUD || viewModel.isHoveringWithFile || viewModel.showDropSuccessHUD
    }
    
    private func updatePomodoroPlacement(isPlaying: Bool, isPomodoroActive: Bool, animated: Bool = true) {
        guard isPomodoroActive else {
            pauseGraceTimer?.invalidate()
            pauseGraceTimer = nil
            if animated {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                    isPomodoroInMainIsland = false
                }
            } else {
                isPomodoroInMainIsland = false
            }
            return
        }
        
        if isPlaying {
            // Media is playing: timer must detach to the right side island
            pauseGraceTimer?.invalidate()
            pauseGraceTimer = nil
            if animated {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                    isPomodoroInMainIsland = false
                }
            } else {
                isPomodoroInMainIsland = false
            }
        } else {
            // Media is NOT playing
            if viewModel.currentSong.isEmpty || viewModel.currentSong == "No Media Playing" {
                // No media at all: immediately place timer in main island
                pauseGraceTimer?.invalidate()
                pauseGraceTimer = nil
                if animated {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                        isPomodoroInMainIsland = true
                    }
                } else {
                    isPomodoroInMainIsland = true
                }
            } else {
                // Media was playing but is currently paused: wait 10 seconds before moving into main island
                if !isPomodoroInMainIsland && pauseGraceTimer == nil {
                    pauseGraceTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                            self.isPomodoroInMainIsland = true
                        }
                        self.pauseGraceTimer = nil
                    }
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // The Main Notch Assembly (Always centered at x = 0)
                ZStack(alignment: .top) {
                    NotchShape(cornerRadius: viewModel.isExpanded ? 22 : (isBlossoming ? 18 : 12), flareRadius: 16)
                        .fill(Color.black)
                        .overlay(
                            NotchShape(cornerRadius: viewModel.isExpanded ? 22 : (isBlossoming ? 18 : 12), flareRadius: 16)
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                        )
                        .drawingGroup()
                        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
                        .shadow(color: viewModel.accentColor.opacity(enableGlow && viewModel.isPlaying ? 0.5 : 0), radius: 20, x: 0, y: 8)
                        .shadow(color: viewModel.accentColor.opacity(enableGlow && viewModel.isPlaying ? 0.3 : 0), radius: 40, x: 0, y: 12)
                        .animation(.easeInOut(duration: 1.0), value: viewModel.accentColor)
                
                Group {
                    if viewModel.isExpanded {
                        VStack(spacing: 0) {
                            // Tab Selector
                            HStack(spacing: 12) {
                                // 1. Pinned Tabs
                                ForEach(pinnedTabs, id: \.self) { tab in
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            viewModel.selectedTab = tab
                                        }
                                    }) {
                                        Image(systemName: tab.rawValue)
                                            .font(.system(size: 15, weight: viewModel.selectedTab == tab ? .bold : .medium))
                                            .foregroundColor(viewModel.selectedTab == tab ? .white : .gray)
                                            .frame(width: 24, height: 24)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help(tab.displayName)
                                    .contextMenu {
                                        Button(action: { togglePin(tab) }) {
                                            Label(LanguageManager.tr("Unpin from bar"), systemImage: "pin.slash")
                                        }
                                    }
                                }
                                
                                // 2. Temporary Active Tab (if current tab is not pinned)
                                if !pinnedTabs.contains(viewModel.selectedTab) {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.18))
                                        .frame(width: 1, height: 14)
                                        .padding(.horizontal, 2)
                                        .transition(.opacity)
                                    
                                    Button(action: {
                                        // Already active tab
                                    }) {
                                        Image(systemName: viewModel.selectedTab.rawValue)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 24, height: 24)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help(viewModel.selectedTab.displayName)
                                    .contextMenu {
                                        Button(action: { togglePin(viewModel.selectedTab) }) {
                                            Label(LanguageManager.tr("Pin to bar"), systemImage: "pin")
                                        }
                                    }
                                    .transition(.scale.combined(with: .opacity))
                                }
                                
                                // 3. Feature Picker Button (+)
                                Button(action: {
                                    showTabPicker.toggle()
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(showTabPicker ? .white : Color.white.opacity(0.5))
                                        .frame(width: 22, height: 22)
                                        .background(
                                            Circle()
                                                .fill(showTabPicker ? Color.white.opacity(0.2) : Color.white.opacity(0.06))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help(LanguageManager.tr("All Features & Pinning"))
                                .popover(isPresented: $showTabPicker, arrowEdge: .bottom) {
                                    TabPickerPopoverView(
                                        viewModel: viewModel,
                                        pinnedTabs: pinnedTabs,
                                        allTabs: visibleTabs.isEmpty ? NotchTab.allCases : visibleTabs,
                                        onTogglePin: { tab in
                                            togglePin(tab)
                                        },
                                        onSelectTab: { tab in
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                viewModel.selectedTab = tab
                                            }
                                            showTabPicker = false
                                        }
                                    )
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 30)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                            
                            // Subtle Tab Divider
                            Rectangle()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 0.5)
                                .padding(.horizontal, 24)
                            
                            // Tab Content with Floating Chevrons
                            ZStack(alignment: .top) {
                                ZStack(alignment: .top) {
                                    if viewModel.selectedTab == .media {
                                        MediaCardView(viewModel: viewModel)
                                            .transition(.scale(scale: 0.85, anchor: .top).combined(with: .opacity))
                                    } else if viewModel.selectedTab == .clipboard {
                                        ClipboardStackView(viewModel: viewModel)
                                            .transition(.scale(scale: 0.85, anchor: .top).combined(with: .opacity))
                                    } else if viewModel.selectedTab == .dropzone {
                                        DropZoneCardView(viewModel: viewModel)
                                            .transition(.scale(scale: 0.85, anchor: .top).combined(with: .opacity))
                                    } else if viewModel.selectedTab == .pomodoro {
                                        PomodoroTimerView(viewModel: viewModel)
                                            .transition(.scale(scale: 0.85, anchor: .top).combined(with: .opacity))
                                    } else if viewModel.selectedTab == .calculator {
                                        CalculatorView(viewModel: viewModel)
                                            .transition(.scale(scale: 0.85, anchor: .top).combined(with: .opacity))
                                    } else if viewModel.selectedTab == .weather {
                                        WeatherCardView(viewModel: viewModel)
                                            .transition(.scale(scale: 0.85, anchor: .top).combined(with: .opacity))
                                    } else if viewModel.selectedTab == .system {
                                        SystemMonitorView(viewModel: viewModel)
                                            .transition(.scale(scale: 0.85, anchor: .top).combined(with: .opacity))
                                    } else if viewModel.selectedTab == .agenda {
                                        AgendaCardView(viewModel: viewModel)
                                            .transition(.scale(scale: 0.85, anchor: .top).combined(with: .opacity))
                                    } else if viewModel.selectedTab == .mirror {
                                        MirrorCardView(viewModel: viewModel)
                                            .transition(.scale(scale: 0.85, anchor: .top).combined(with: .opacity))
                                    } else if viewModel.selectedTab == .notes {
                                        NotesCardView(viewModel: viewModel)
                                            .transition(.scale(scale: 0.85, anchor: .top).combined(with: .opacity))
                                    } else if viewModel.selectedTab == .network {
                                        NetworkCardView(viewModel: viewModel)
                                            .transition(.scale(scale: 0.85, anchor: .top).combined(with: .opacity))
                                    }
                                }
                                .padding(.horizontal, 42)
                                .padding(.top, 14)
                                .padding(.bottom, 12)
                                
                                // Floating Chevron Overlays (Cleanly inset inside Notch body, anchored vertically & consistently visible)
                                HStack {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            navigateToPrevTab()
                                        }
                                    }) {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 20, height: 20)
                                            .background(
                                                Circle()
                                                    .fill(isLeftChevronHovered ? Color.white.opacity(0.25) : Color.white.opacity(0.12))
                                                    .overlay(Circle().stroke(Color.white.opacity(isLeftChevronHovered ? 0.4 : 0.2), lineWidth: 0.5))
                                            )
                                            .scaleEffect(isLeftChevronHovered ? 1.08 : 1.0)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help(LanguageManager.tr("Previous Tab"))
                                    .opacity(isLeftChevronHovered ? 1.0 : 0.75)
                                    .onHover { h in
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            isLeftChevronHovered = h
                                        }
                                    }
                                    .padding(.leading, 18)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            navigateToNextTab()
                                        }
                                    }) {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 20, height: 20)
                                            .background(
                                                Circle()
                                                    .fill(isRightChevronHovered ? Color.white.opacity(0.25) : Color.white.opacity(0.12))
                                                    .overlay(Circle().stroke(Color.white.opacity(isRightChevronHovered ? 0.4 : 0.2), lineWidth: 0.5))
                                            )
                                            .scaleEffect(isRightChevronHovered ? 1.08 : 1.0)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help(LanguageManager.tr("Next Tab"))
                                    .opacity(isRightChevronHovered ? 1.0 : 0.75)
                                    .onHover { h in
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            isRightChevronHovered = h
                                        }
                                    }
                                    .padding(.trailing, 18)
                                }
                                .padding(.top, 28)
                            }
                        }
                        .transition(.scale(scale: 0.01, anchor: .top))
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 25)
                                .onEnded { value in
                                    if abs(value.translation.width) > abs(value.translation.height) * 1.5 {
                                        if value.translation.width < -30 {
                                            withAnimation(.easeInOut(duration: 0.25)) {
                                                navigateToNextTab()
                                            }
                                        } else if value.translation.width > 30 {
                                            withAnimation(.easeInOut(duration: 0.25)) {
                                                navigateToPrevTab()
                                            }
                                        }
                                    }
                                }
                        )
                    } else {
                        Group {
                            if viewModel.isHoveringWithFile {
                                DropFileBlossomView()
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            } else if viewModel.showDropSuccessHUD {
                                DropSuccessBlossomView()
                                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                            } else if viewModel.showBatteryHUD {
                                BatteryBlossomView(level: viewModel.batteryLevel, isCharging: viewModel.isBatteryCharging, isAC: viewModel.isACConnected)
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            } else if viewModel.showVolumeHUD {
                                VolumeBlossomView(volume: viewModel.currentVolume)
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            } else if viewModel.showDeviceHUD {
                                DeviceBlossomView(message: viewModel.deviceMessage, iconName: viewModel.deviceIcon, isConnected: viewModel.isDeviceConnected)
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            } else if viewModel.showClipboardHUD {
                                ClipboardBlossomView(message: viewModel.clipboardMessage, iconName: viewModel.clipboardIcon, isCut: viewModel.clipboardIsCut, colorSwatch: viewModel.clipboardColorSwatch, accentColor: viewModel.clipboardAccentColor)
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            } else if viewModel.showTimesUp {
                                TimesUpBlossomView()
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            } else if viewModel.showAgendaHUD {
                                AgendaBlossomView(message: viewModel.agendaHUDMessage)
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            } else if viewModel.isPomodoroActive && isPomodoroInMainIsland {
                                CompactPomodoroView(viewModel: viewModel)
                                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                            } else if viewModel.showClock {
                                CompactClockView()
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            } else {
                                CompactMediaView(viewModel: viewModel)
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            }
                        }
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.05), value: viewModel.isExpanded)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.showClock)
            }
            .background(
                ZStack {
                    HoverTrackingView { isHovering in
                        isMouseInsideNotch = isHovering
                        if isHovering {
                            if expandTrigger == "hover" {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    guard !viewModel.isHoveringWithFile else { return }
                                    guard !viewModel.showDropSuccessHUD else { return }
                                    if viewModel.isPomodoroActive && isPomodoroInMainIsland {
                                        viewModel.selectedTab = .pomodoro
                                    }
                                    withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                                        viewModel.isExpanded = true
                                    }
                                    let frontmost = NSWorkspace.shared.frontmostApplication
                                    if frontmost?.bundleIdentifier != Bundle.main.bundleIdentifier {
                                        previousApp = frontmost
                                    }
                                    NSApp.activate(ignoringOtherApps: true)
                                }
                            }
                        } else {
                            DispatchQueue.main.asyncAfter(deadline: .now() + autoHideDelay) {
                                guard !viewModel.isHoveringWithFile else { return }
                                guard !viewModel.showDropSuccessHUD else { return }
                                guard !viewModel.isPinningExpansion else { return }
                                guard !showTabPicker else { return }
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                                    viewModel.isExpanded = false
                                }
                                previousApp?.activate(options: .activateIgnoringOtherApps)
                            }
                        }
                    }
                    
                    DropTrackingView(
                        onDragEntered: {
                            viewModel.isHoveringWithFile = true
                        },
                        onDragExited: {
                            viewModel.isHoveringWithFile = false
                        },
                        onDrop: { urls in
                            viewModel.isHoveringWithFile = false
                            // Prepend unique urls
                            for url in urls.reversed() {
                                if !viewModel.stagedFiles.contains(url) {
                                    viewModel.stagedFiles.insert(url, at: 0)
                                }
                            }
                            
                            // Audio chime & Green checkmark drop success HUD
                            NSSound(named: "Glass")?.play()
                            withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.65)) {
                                viewModel.showDropSuccessHUD = true
                                blossomHeight = -6
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    blossomHeight = 0
                                }
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
                                    viewModel.showDropSuccessHUD = false
                                    viewModel.selectedTab = .dropzone
                                    viewModel.isExpanded = true
                                }
                            }
                        }
                    )
                }
            )
            .frame(width: currentWidth, height: currentHeight, alignment: .top)
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.6, blendDuration: 0), value: viewModel.isExpanded)
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.55, blendDuration: 0), value: viewModel.showClock)
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.55, blendDuration: 0), value: viewModel.isHoveringWithFile)
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.55, blendDuration: 0), value: viewModel.showDropSuccessHUD)
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.55, blendDuration: 0), value: viewModel.showTimesUp)
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.55, blendDuration: 0), value: viewModel.showVolumeHUD)
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.55, blendDuration: 0), value: viewModel.showBatteryHUD)
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.55, blendDuration: 0), value: viewModel.showDeviceHUD)
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.55, blendDuration: 0), value: viewModel.showClipboardHUD)
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.55, blendDuration: 0), value: viewModel.showAgendaHUD)
            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.65, blendDuration: 0), value: viewModel.selectedTab)
            .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.6, blendDuration: 0), value: viewModel.lyrics.isEmpty)
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.55, blendDuration: 0), value: isPomodoroInMainIsland)
            .offset(y: isHiddenByFullscreen ? -80 : 0)
            .opacity(isHiddenByFullscreen ? 0 : notchOpacity)
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.7, blendDuration: 0), value: isHiddenByFullscreen)
            .onTapGesture {
                if expandTrigger == "click" && !viewModel.isExpanded {
                    if viewModel.isPomodoroActive && isPomodoroInMainIsland {
                        viewModel.selectedTab = .pomodoro
                    }
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                        viewModel.isExpanded = true
                    }
                    let frontmost = NSWorkspace.shared.frontmostApplication
                    if frontmost?.bundleIdentifier != Bundle.main.bundleIdentifier {
                        previousApp = frontmost
                    }
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleNotchify"))) { _ in
                if !viewModel.isExpanded && viewModel.isPomodoroActive && isPomodoroInMainIsland {
                    viewModel.selectedTab = .pomodoro
                }
                withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                    viewModel.isExpanded.toggle()
                }
                if viewModel.isExpanded {
                    let frontmost = NSWorkspace.shared.frontmostApplication
                    if frontmost?.bundleIdentifier != Bundle.main.bundleIdentifier {
                        previousApp = frontmost
                    }
                    NSApp.activate(ignoringOtherApps: true)
                } else {
                    previousApp?.activate(options: .activateIgnoringOtherApps)
                }
            }
            .onChange(of: viewModel.showClock) { _ in
                if !viewModel.isExpanded && !viewModel.isHoveringWithFile && !viewModel.showTimesUp {
                    // Fast upward spring
                    withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.6, blendDuration: 0)) {
                        blossomHeight = 22
                    }
                    // Interrupt with a bouncy downward spring
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.35, blendDuration: 0)) {
                            blossomHeight = 0
                        }
                    }
                }
            }
            .onChange(of: viewModel.isHoveringWithFile) { hovering in
                if hovering {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                        viewModel.isExpanded = false
                    }
                }
            }
            .onChange(of: enableLyrics) { enabled in
                if enabled {
                    if !viewModel.currentSong.isEmpty {
                        LyricsManager.shared.fetchLyrics(for: viewModel.currentSong, artist: viewModel.currentArtist) { newLyrics in
                            viewModel.lyrics = newLyrics
                        }
                    }
                } else {
                    viewModel.lyrics = []
                }
            }
            .onChange(of: viewModel.selectedTab) { newTab in
                if newTab != .mirror {
                    CameraMirrorManager.shared.stopSession()
                }
            }
            .onChange(of: viewModel.isExpanded) { isExpanded in
                if !isExpanded {
                    showTabPicker = false
                    CameraMirrorManager.shared.stopSession()
                }
            }
            .onChange(of: showTabPicker) { isOpen in
                if !isOpen {
                    DispatchQueue.main.asyncAfter(deadline: .now() + max(autoHideDelay, 0.2)) {
                        guard !showTabPicker else { return }
                        guard !isMouseInsideNotch else { return }
                        guard !viewModel.isHoveringWithFile else { return }
                        guard !viewModel.isPinningExpansion else { return }
                        if expandTrigger == "hover" {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                                viewModel.isExpanded = false
                            }
                            previousApp?.activate(options: .activateIgnoringOtherApps)
                        }
                    }
                }
            }
            .onChange(of: viewModel.isPlaying) { playing in
                updatePomodoroPlacement(isPlaying: playing, isPomodoroActive: viewModel.isPomodoroActive)
            }
            .onChange(of: viewModel.isPomodoroActive) { active in
                updatePomodoroPlacement(isPlaying: viewModel.isPlaying, isPomodoroActive: active)
            }
            .onChange(of: viewModel.currentSong) { _ in
                updatePomodoroPlacement(isPlaying: viewModel.isPlaying, isPomodoroActive: viewModel.isPomodoroActive)
            } // End of Main Notch ZStack
            
            // Left Privacy Indicator (Camera & Microphone Island) - Repels outward on blossom & expansion
            if PrivacyMonitor.shared.isCameraActive || PrivacyMonitor.shared.isMicActive {
                PrivacyIndicatorView()
                    .offset(x: -(currentWidth / 2) - 12 - 16, y: 0)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .scale(scale: 0.8)).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .scale(scale: 0.8)).combined(with: .opacity)
                    ))
                    .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.55, blendDuration: 0), value: currentWidth)
                    .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.6), value: PrivacyMonitor.shared.isCameraActive)
                    .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.6), value: PrivacyMonitor.shared.isMicActive)
                    .offset(y: isHiddenByFullscreen ? -80 : 0)
                    .opacity(isHiddenByFullscreen ? 0 : notchOpacity)
            }
            
            // Right Detached Pomodoro Timer Island - Repels outward on blossom & absorbs into main island
            if viewModel.isPomodoroActive && !viewModel.isExpanded && !viewModel.showTimesUp && !isPomodoroInMainIsland {
                DetachedPomodoroView(viewModel: viewModel)
                    .offset(x: (currentWidth / 2) + 12 + 42, y: 0)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .scale(scale: 0.8)).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .scale(scale: 0.5)).combined(with: .opacity)
                    ))
                    .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.55, blendDuration: 0), value: currentWidth)
                    .animation(.spring(response: 0.45, dampingFraction: 0.72), value: isPomodoroInMainIsland)
                    .animation(.spring(response: 0.4, dampingFraction: 0.65), value: viewModel.isPomodoroActive)
                    .offset(y: isHiddenByFullscreen ? -80 : 0)
                    .opacity(isHiddenByFullscreen ? 0 : notchOpacity)
            }
        } // End of outer ZStack
        Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            checkFullscreen()
            updatePomodoroPlacement(isPlaying: viewModel.isPlaying, isPomodoroActive: viewModel.isPomodoroActive, animated: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                checkFullscreen()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                checkFullscreen()
            }
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            checkFullscreen()
        }
    }
    
    private func checkFullscreen() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        
        // When an app is fullscreen, the menu bar is hidden, so visibleFrame == frame
        // Also check if any window covers the entire screen
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        
        var otherAppIsFullscreen = false
        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let windowWidth = bounds["Width"],
                  let windowHeight = bounds["Height"],
                  let layer = window[kCGWindowLayer as String] as? Int else { continue }
            
            // Skip our own app and menu bar / dock windows
            if ownerPID == ProcessInfo.processInfo.processIdentifier { continue }
            if layer != 0 { continue }
            
            // If a window covers the full screen dimensions, it's fullscreen
            if windowWidth >= screenFrame.width && windowHeight >= screenFrame.height {
                otherAppIsFullscreen = true
                break
            }
        }
        
        if otherAppIsFullscreen != isHiddenByFullscreen {
            withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)) {
                isHiddenByFullscreen = otherAppIsFullscreen
            }
        }
    }
}
import Foundation
import AppKit
import Combine
// MARK: - Media Remote Helper
class MediaRemoteHelper {
    static let shared = MediaRemoteHelper()
    
    private var getNowPlayingInfo: MRMediaRemoteGetNowPlayingInfoFunction?
    private var sendCommand: MRMediaRemoteSendCommandFunction?
    private var setElapsedTime: MRMediaRemoteSetElapsedTimeFunction?
    
    private var lastQuery: String = ""
    private var cachedArtwork: NSImage? = nil
    private var spotifyCachedUrl: String = ""
    private var spotifyCachedArtwork: NSImage? = nil
    
    private(set) var activePlayerBundleId: String? = nil
    private(set) var activePlayerName: String? = nil
    
    typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping @convention(block) ([String: Any]) -> Void) -> Void
    typealias MRMediaRemoteSendCommandFunction = @convention(c) (UInt32, Any?) -> Bool
    typealias MRMediaRemoteSetElapsedTimeFunction = @convention(c) (Double) -> Void
    
    init() {
        let bundleURL = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
        if let bundle = CFBundleCreate(kCFAllocatorDefault, bundleURL as CFURL) {
            if let pointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
                getNowPlayingInfo = unsafeBitCast(pointer, to: MRMediaRemoteGetNowPlayingInfoFunction.self)
            }
            if let ptr2 = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) {
                sendCommand = unsafeBitCast(ptr2, to: MRMediaRemoteSendCommandFunction.self)
            }
            if let ptr3 = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSetElapsedTime" as CFString) {
                setElapsedTime = unsafeBitCast(ptr3, to: MRMediaRemoteSetElapsedTimeFunction.self)
            }
        }
    }
    
    // MARK: - App Running & AppleScript Helpers
    private func isAppRunning(_ bundleId: String) -> Bool {
        return NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == bundleId })
    }
    
    @discardableResult
    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: source) {
            let output = scriptObject.executeAndReturnError(&error)
            if error == nil {
                return output.stringValue
            }
        }
        return nil
    }
    
    // MARK: - Playback Controls
    func togglePlayPause() {
        if activePlayerBundleId == "com.spotify.client" && isAppRunning("com.spotify.client") {
            DispatchQueue.global(qos: .userInitiated).async {
                self.runAppleScript("tell application \"Spotify\" to playpause")
            }
        } else if activePlayerBundleId == "com.apple.Music" && isAppRunning("com.apple.Music") {
            DispatchQueue.global(qos: .userInitiated).async {
                self.runAppleScript("tell application \"Music\" to playpause")
            }
        } else {
            _ = sendCommand?(2, nil) // MediaRemote togglePlayPause
        }
    }
    
    func nextTrack() {
        if activePlayerBundleId == "com.spotify.client" && isAppRunning("com.spotify.client") {
            DispatchQueue.global(qos: .userInitiated).async {
                self.runAppleScript("tell application \"Spotify\" to next track")
            }
        } else if activePlayerBundleId == "com.apple.Music" && isAppRunning("com.apple.Music") {
            DispatchQueue.global(qos: .userInitiated).async {
                self.runAppleScript("tell application \"Music\" to next track")
            }
        } else {
            _ = sendCommand?(4, nil) // MediaRemote nextTrack
        }
    }
    
    func previousTrack() {
        if activePlayerBundleId == "com.spotify.client" && isAppRunning("com.spotify.client") {
            DispatchQueue.global(qos: .userInitiated).async {
                self.runAppleScript("tell application \"Spotify\" to previous track")
            }
        } else if activePlayerBundleId == "com.apple.Music" && isAppRunning("com.apple.Music") {
            DispatchQueue.global(qos: .userInitiated).async {
                self.runAppleScript("tell application \"Music\" to previous track")
            }
        } else {
            _ = sendCommand?(5, nil) // MediaRemote previousTrack
        }
    }
    
    func seek(to time: Double) {
        if activePlayerBundleId == "com.spotify.client" && isAppRunning("com.spotify.client") {
            DispatchQueue.global(qos: .userInitiated).async {
                self.runAppleScript("tell application \"Spotify\" to set player position to \(time)")
            }
        } else if activePlayerBundleId == "com.apple.Music" && isAppRunning("com.apple.Music") {
            DispatchQueue.global(qos: .userInitiated).async {
                self.runAppleScript("tell application \"Music\" to set player position to \(time)")
            }
        } else {
            setElapsedTime?(time)
        }
    }
    
    func activatePlayerApp() {
        if let bundleId = activePlayerBundleId {
            if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) {
                app.activate(options: [.activateIgnoringOtherApps])
                return
            } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
                return
            }
        }
        
        // Fallbacks if bundleId was not determined
        if isAppRunning("com.spotify.client") {
            DispatchQueue.global(qos: .userInitiated).async {
                self.runAppleScript("tell application \"Spotify\" to activate")
            }
        } else if isAppRunning("com.apple.Music") {
            DispatchQueue.global(qos: .userInitiated).async {
                self.runAppleScript("tell application \"Music\" to activate")
            }
        }
    }
    
    // MARK: - Query Players
    private func querySpotify(completion: @escaping (_ title: String?, _ artist: String?, _ album: String?, _ isPlaying: Bool, _ duration: Double, _ elapsed: Double, _ artworkUrl: String?) -> Void) {
        guard isAppRunning("com.spotify.client") else {
            completion(nil, nil, nil, false, 0, 0, nil)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let script = """
            tell application "Spotify"
                try
                    set pState to (player state as string)
                    if pState is "playing" or pState is "paused" then
                        set tName to (name of current track)
                        set tArtist to (artist of current track)
                        set tAlbum to (album of current track)
                        set tDur to ((duration of current track) / 1000)
                        set tPos to (player position)
                        set tArt to ""
                        try
                            set tArt to (artwork url of current track)
                        end try
                        return pState & "|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tDur & "|||" & tPos & "|||" & tArt
                    else
                        return "stopped"
                    end if
                on error
                    return "stopped"
                end try
            end tell
            """
            guard let result = self.runAppleScript(script), result != "stopped" else {
                completion(nil, nil, nil, false, 0, 0, nil)
                return
            }
            
            let parts = result.components(separatedBy: "|||")
            if parts.count >= 6 {
                let isPlaying = parts[0] == "playing"
                let title = parts[1]
                let artist = parts[2]
                let album = parts[3]
                let duration = Double(parts[4]) ?? 0.0
                let elapsed = Double(parts[5]) ?? 0.0
                let artworkUrl = parts.count > 6 ? parts[6] : nil
                completion(title, artist, album, isPlaying, duration, elapsed, artworkUrl)
            } else {
                completion(nil, nil, nil, false, 0, 0, nil)
            }
        }
    }
    
    private func queryAppleMusic(completion: @escaping (_ title: String?, _ artist: String?, _ album: String?, _ isPlaying: Bool, _ duration: Double, _ elapsed: Double) -> Void) {
        guard isAppRunning("com.apple.Music") else {
            completion(nil, nil, nil, false, 0, 0)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let script = """
            tell application "Music"
                try
                    set pState to (player state as string)
                    if pState is "playing" or pState is "paused" then
                        set tName to (name of current track)
                        set tArtist to (artist of current track)
                        set tAlbum to (album of current track)
                        set tDur to (duration of current track)
                        set tPos to (player position)
                        return pState & "|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tDur & "|||" & tPos
                    else
                        return "stopped"
                    end if
                on error
                    return "stopped"
                end try
            end tell
            """
            guard let result = self.runAppleScript(script), result != "stopped" else {
                completion(nil, nil, nil, false, 0, 0)
                return
            }
            
            let parts = result.components(separatedBy: "|||")
            if parts.count >= 6 {
                let isPlaying = parts[0] == "playing"
                let title = parts[1]
                let artist = parts[2]
                let album = parts[3]
                let duration = Double(parts[4]) ?? 0.0
                let elapsed = Double(parts[5]) ?? 0.0
                completion(title, artist, album, isPlaying, duration, elapsed)
            } else {
                completion(nil, nil, nil, false, 0, 0)
            }
        }
    }
    
    // MARK: - Native MediaRemote Detector
    private func fetchMediaRemote(completion: @escaping (_ title: String?, _ artist: String?, _ artwork: NSImage?, _ isPlaying: Bool, _ duration: Double, _ elapsed: Double, _ bundleId: String?, _ appName: String?) -> Void) {
        guard let getNowPlayingInfo = getNowPlayingInfo else {
            completion(nil, nil, nil, false, 0, 0, nil, nil)
            return
        }
        
        getNowPlayingInfo(DispatchQueue.global(qos: .userInitiated)) { [weak self] info in
            guard let self = self else { return }
            
            let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
            let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
            let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String
            
            let playbackRate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0.0
            let isPlaying = playbackRate > 0.0
            
            let duration = info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0.0
            let staticElapsed = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0.0
            let timestamp = info["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date ?? Date()
            
            var elapsed = staticElapsed
            if isPlaying {
                let timeSince = Date().timeIntervalSince(timestamp)
                elapsed += timeSince * playbackRate
            }
            
            var artistStr = artist
            if let album = album, !album.isEmpty, !artistStr.isEmpty {
                artistStr += " – \(album)"
            } else if let album = album, !album.isEmpty {
                artistStr = album
            }
            
            var detectedBundleId: String? = nil
            var detectedAppName: String? = nil
            
            if let directBundleId = info["kMRMediaRemoteNowPlayingInfoClientBundleIdentifier"] as? String, !directBundleId.isEmpty {
                detectedBundleId = directBundleId
            } else if let clientData = info["kMRMediaRemoteNowPlayingInfoClientPropertiesData"] as? Data {
                let printable = String(clientData.compactMap { byte -> Character? in
                    return (byte >= 32 && byte <= 126) ? Character(UnicodeScalar(byte)) : nil
                })
                if let regex = try? NSRegularExpression(pattern: "[a-zA-Z0-9-]+\\.[a-zA-Z0-9-]+\\.[a-zA-Z0-9-]+"),
                   let match = regex.firstMatch(in: printable, range: NSRange(printable.startIndex..., in: printable)) {
                    detectedBundleId = String(printable[Range(match.range, in: printable)!])
                }
            }
            
            if let bId = detectedBundleId {
                if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bId) {
                    detectedAppName = FileManager.default.displayName(atPath: appURL.path)
                }
            }
            
            if title.isEmpty && artistStr.isEmpty {
                DispatchQueue.main.async {
                    completion(nil, nil, nil, false, 0, 0, nil, nil)
                }
                return
            }
            
            self.activePlayerBundleId = detectedBundleId
            self.activePlayerName = detectedAppName ?? "Media Player"
            
            if let artworkData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data, artworkData.count > 0 {
                let img = NSImage(data: artworkData)
                self.cachedArtwork = img
                self.lastQuery = ""
                DispatchQueue.main.async {
                    completion(title.isEmpty ? nil : title, artistStr.isEmpty ? nil : artistStr, img, isPlaying, duration, elapsed, detectedBundleId, detectedAppName)
                }
            } else {
                let query = "\(title) \(artist)"
                if query == self.lastQuery && !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    DispatchQueue.main.async {
                        completion(title.isEmpty ? nil : title, artistStr.isEmpty ? nil : artistStr, self.cachedArtwork, isPlaying, duration, elapsed, detectedBundleId, detectedAppName)
                    }
                } else {
                    self.lastQuery = query
                    var fallbackIcon: NSImage? = nil
                    if let bId = detectedBundleId, let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bId) {
                        fallbackIcon = NSWorkspace.shared.icon(forFile: appURL.path)
                    }
                    self.cachedArtwork = fallbackIcon
                    
                    if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                        self.fetchITunesArtwork(title: title, artist: artist) { fetchedImage in
                            if let fetchedImage = fetchedImage {
                                self.cachedArtwork = fetchedImage
                                DispatchQueue.main.async {
                                    completion(title.isEmpty ? nil : title, artistStr.isEmpty ? nil : artistStr, fetchedImage, isPlaying, duration, elapsed, detectedBundleId, detectedAppName)
                                }
                            }
                        }
                    }
                    
                    DispatchQueue.main.async {
                        completion(title.isEmpty ? nil : title, artistStr.isEmpty ? nil : artistStr, self.cachedArtwork, isPlaying, duration, elapsed, detectedBundleId, detectedAppName)
                    }
                }
            }
        }
    }
    
    // MARK: - Master Fetch Now Playing
    func fetchNowPlaying(completion: @escaping (String?, String?, NSImage?, Bool, Double, Double, String?, String?) -> Void) {
        let preference = UserDefaults.standard.string(forKey: "preferredMusicPlayer") ?? "auto"
        
        switch preference {
        case "spotify":
            querySpotify { [weak self] title, artist, album, isPlaying, duration, elapsed, artworkUrl in
                guard let self = self else { return }
                if let title = title, !title.isEmpty {
                    self.activePlayerBundleId = "com.spotify.client"
                    self.activePlayerName = "Spotify"
                    self.handleSpotifyResult(title: title, artist: artist, album: album, isPlaying: isPlaying, duration: duration, elapsed: elapsed, artworkUrl: artworkUrl, completion: completion)
                } else {
                    self.fetchMediaRemote(completion: completion)
                }
            }
            
        case "music":
            queryAppleMusic { [weak self] title, artist, album, isPlaying, duration, elapsed in
                guard let self = self else { return }
                if let title = title, !title.isEmpty {
                    self.activePlayerBundleId = "com.apple.Music"
                    self.activePlayerName = "Music"
                    self.handleAppleMusicResult(title: title, artist: artist, album: album, isPlaying: isPlaying, duration: duration, elapsed: elapsed, completion: completion)
                } else {
                    self.fetchMediaRemote(completion: completion)
                }
            }
            
        case "browser":
            self.fetchMediaRemote(completion: completion)
            
        default: // "auto"
            if isAppRunning("com.spotify.client") {
                querySpotify { [weak self] title, artist, album, isPlaying, duration, elapsed, artworkUrl in
                    guard let self = self else { return }
                    if isPlaying, let title = title, !title.isEmpty {
                        self.activePlayerBundleId = "com.spotify.client"
                        self.activePlayerName = "Spotify"
                        self.handleSpotifyResult(title: title, artist: artist, album: album, isPlaying: isPlaying, duration: duration, elapsed: elapsed, artworkUrl: artworkUrl, completion: completion)
                        return
                    }
                    
                    self.checkAppleMusicOrFallback(spotifyPaused: (title, artist, album, isPlaying, duration, elapsed, artworkUrl), completion: completion)
                }
            } else {
                checkAppleMusicOrFallback(spotifyPaused: nil, completion: completion)
            }
        }
    }
    
    private func checkAppleMusicOrFallback(spotifyPaused: (title: String?, artist: String?, album: String?, isPlaying: Bool, duration: Double, elapsed: Double, artworkUrl: String?)?, completion: @escaping (String?, String?, NSImage?, Bool, Double, Double, String?, String?) -> Void) {
        if isAppRunning("com.apple.Music") {
            queryAppleMusic { [weak self] title, artist, album, isPlaying, duration, elapsed in
                guard let self = self else { return }
                if isPlaying, let title = title, !title.isEmpty {
                    self.activePlayerBundleId = "com.apple.Music"
                    self.activePlayerName = "Music"
                    self.handleAppleMusicResult(title: title, artist: artist, album: album, isPlaying: isPlaying, duration: duration, elapsed: elapsed, completion: completion)
                    return
                }
                
                self.fetchMediaRemote { mrTitle, mrArtist, mrArt, mrPlaying, mrDuration, mrElapsed, mrBundle, mrName in
                    if mrPlaying && mrTitle != nil {
                        completion(mrTitle, mrArtist, mrArt, mrPlaying, mrDuration, mrElapsed, mrBundle, mrName)
                    } else if let sp = spotifyPaused, let spTitle = sp.title, !spTitle.isEmpty {
                        self.activePlayerBundleId = "com.spotify.client"
                        self.activePlayerName = "Spotify"
                        self.handleSpotifyResult(title: spTitle, artist: sp.artist, album: sp.album, isPlaying: sp.isPlaying, duration: sp.duration, elapsed: sp.elapsed, artworkUrl: sp.artworkUrl, completion: completion)
                    } else if let amTitle = title, !amTitle.isEmpty {
                        self.activePlayerBundleId = "com.apple.Music"
                        self.activePlayerName = "Music"
                        self.handleAppleMusicResult(title: amTitle, artist: artist, album: album, isPlaying: isPlaying, duration: duration, elapsed: elapsed, completion: completion)
                    } else {
                        completion(mrTitle, mrArtist, mrArt, mrPlaying, mrDuration, mrElapsed, mrBundle, mrName)
                    }
                }
            }
        } else {
            fetchMediaRemote { [weak self] mrTitle, mrArtist, mrArt, mrPlaying, mrDuration, mrElapsed, mrBundle, mrName in
                guard let self = self else { return }
                if mrPlaying && mrTitle != nil {
                    completion(mrTitle, mrArtist, mrArt, mrPlaying, mrDuration, mrElapsed, mrBundle, mrName)
                } else if let sp = spotifyPaused, let doMatch = sp.title, !doMatch.isEmpty {
                    self.activePlayerBundleId = "com.spotify.client"
                    self.activePlayerName = "Spotify"
                    self.handleSpotifyResult(title: doMatch, artist: sp.artist, album: sp.album, isPlaying: sp.isPlaying, duration: sp.duration, elapsed: sp.elapsed, artworkUrl: sp.artworkUrl, completion: completion)
                } else {
                    completion(mrTitle, mrArtist, mrArt, mrPlaying, mrDuration, mrElapsed, mrBundle, mrName)
                }
            }
        }
    }
    
    private func handleSpotifyResult(title: String, artist: String?, album: String?, isPlaying: Bool, duration: Double, elapsed: Double, artworkUrl: String?, completion: @escaping (String?, String?, NSImage?, Bool, Double, Double, String?, String?) -> Void) {
        var artistStr = artist ?? ""
        if let album = album, !album.isEmpty, !artistStr.isEmpty {
            artistStr += " – \(album)"
        } else if let album = album, !album.isEmpty {
            artistStr = album
        }
        
        let bundleId = "com.spotify.client"
        let appName = "Spotify"
        
        if let artUrlStr = artworkUrl, !artUrlStr.isEmpty, let artUrl = URL(string: artUrlStr) {
            if artUrlStr == self.spotifyCachedUrl && self.spotifyCachedArtwork != nil {
                DispatchQueue.main.async {
                    completion(title, artistStr, self.spotifyCachedArtwork, isPlaying, duration, elapsed, bundleId, appName)
                }
            } else {
                self.spotifyCachedUrl = artUrlStr
                URLSession.shared.dataTask(with: artUrl) { [weak self] data, _, _ in
                    var img: NSImage? = nil
                    if let data = data {
                        img = NSImage(data: data)
                        self?.spotifyCachedArtwork = img
                    }
                    DispatchQueue.main.async {
                        completion(title, artistStr, img ?? self?.spotifyCachedArtwork, isPlaying, duration, elapsed, bundleId, appName)
                    }
                }.resume()
            }
        } else {
            let query = "\(title) \(artist ?? "")"
            if query == self.lastQuery && self.cachedArtwork != nil {
                DispatchQueue.main.async {
                    completion(title, artistStr, self.cachedArtwork, isPlaying, duration, elapsed, bundleId, appName)
                }
            } else {
                self.lastQuery = query
                var fallbackIcon: NSImage? = nil
                if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                    fallbackIcon = NSWorkspace.shared.icon(forFile: appURL.path)
                }
                self.cachedArtwork = fallbackIcon
                
                self.fetchITunesArtwork(title: title, artist: artist ?? "") { fetchedImage in
                    if let fetchedImage = fetchedImage {
                        self.cachedArtwork = fetchedImage
                        DispatchQueue.main.async {
                            completion(title, artistStr, fetchedImage, isPlaying, duration, elapsed, bundleId, appName)
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    completion(title, artistStr, self.cachedArtwork, isPlaying, duration, elapsed, bundleId, appName)
                }
            }
        }
    }
    
    private func handleAppleMusicResult(title: String, artist: String?, album: String?, isPlaying: Bool, duration: Double, elapsed: Double, completion: @escaping (String?, String?, NSImage?, Bool, Double, Double, String?, String?) -> Void) {
        var artistStr = artist ?? ""
        if let album = album, !album.isEmpty, !artistStr.isEmpty {
            artistStr += " – \(album)"
        } else if let album = album, !album.isEmpty {
            artistStr = album
        }
        
        let bundleId = "com.apple.Music"
        let appName = "Music"
        
        if let getNowPlayingInfo = getNowPlayingInfo {
            getNowPlayingInfo(DispatchQueue.global(qos: .userInitiated)) { [weak self] info in
                guard let self = self else { return }
                if let artworkData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data, artworkData.count > 0,
                   let img = NSImage(data: artworkData) {
                    self.cachedArtwork = img
                    DispatchQueue.main.async {
                        completion(title, artistStr, img, isPlaying, duration, elapsed, bundleId, appName)
                    }
                    return
                }
                
                let query = "\(title) \(artist ?? "")"
                if query == self.lastQuery && self.cachedArtwork != nil {
                    DispatchQueue.main.async {
                        completion(title, artistStr, self.cachedArtwork, isPlaying, duration, elapsed, bundleId, appName)
                    }
                } else {
                    self.lastQuery = query
                    var fallbackIcon: NSImage? = nil
                    if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                        fallbackIcon = NSWorkspace.shared.icon(forFile: appURL.path)
                    }
                    self.cachedArtwork = fallbackIcon
                    
                    self.fetchITunesArtwork(title: title, artist: artist ?? "") { fetchedImage in
                        if let fetchedImage = fetchedImage {
                            self.cachedArtwork = fetchedImage
                            DispatchQueue.main.async {
                                completion(title, artistStr, fetchedImage, isPlaying, duration, elapsed, bundleId, appName)
                            }
                        }
                    }
                    
                    DispatchQueue.main.async {
                        completion(title, artistStr, self.cachedArtwork, isPlaying, duration, elapsed, bundleId, appName)
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                completion(title, artistStr, nil, isPlaying, duration, elapsed, bundleId, appName)
            }
        }
    }
    
    private func fetchITunesArtwork(title: String, artist: String, completion: @escaping (NSImage?) -> Void) {
        let term = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://itunes.apple.com/search?term=\(term)&entity=song&limit=1"
        guard let url = URL(string: urlString) else { completion(nil); return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let artworkUrl = first["artworkUrl100"] as? String else {
                completion(nil)
                return
            }
            
            // 1. Instantly yield low-res image for fast UI updates
            if let lowResUrl = URL(string: artworkUrl) {
                URLSession.shared.dataTask(with: lowResUrl) { imgData, _, _ in
                    if let data = imgData, let lowResImage = NSImage(data: data) {
                        completion(lowResImage)
                    }
                    
                    // 2. Fetch high-res image in background
                    let highResUrlString = artworkUrl.replacingOccurrences(of: "100x100bb", with: "600x600bb")
                    if let highResUrl = URL(string: highResUrlString) {
                        URLSession.shared.dataTask(with: highResUrl) { highData, _, _ in
                            if let data = highData, let highResImage = NSImage(data: data) {
                                completion(highResImage)
                            }
                        }.resume()
                    }
                }.resume()
            } else {
                completion(nil)
            }
        }.resume()
    }
}
import Foundation
import IOKit
import IOKit.hid
import IOKit.ps

class BatteryMonitor {
    static let shared = BatteryMonitor()
    
    var onPowerStateChanged: ((_ isAC: Bool, _ isCharging: Bool, _ level: Int) -> Void)?
    
    private(set) var currentIsAC: Bool = true
    private(set) var currentLevel: Int = 100
    private(set) var currentIsCharging: Bool = false
    
    private var lastIsAC: Bool = true
    private var lastLevel: Int = 100
    private var lastIsCharging: Bool = false
    private var isFirstCheck = true
    
    private var runLoopSource: CFRunLoopSource?
    private var pollTimer: Timer?
    
    private init() {}
    
    func start() {
        let info = readPowerInfo()
        self.lastIsAC = info.isAC
        self.lastLevel = info.level
        self.lastIsCharging = info.isCharging
        self.currentIsAC = info.isAC
        self.currentLevel = info.level
        self.currentIsCharging = info.isCharging
        self.isFirstCheck = false
        
        // Setup IOKit Power Source notification
        let context = Unmanaged.passUnretained(self).toOpaque()
        let loopSource = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx = ctx else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(ctx).takeUnretainedValue()
            monitor.evaluatePowerChange()
        }, context)
        
        if let source = loopSource?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            self.runLoopSource = source
        }
        
        // Fallback polling timer (every 2.0s) for robust Hackintosh hardware EC compatibility
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.evaluatePowerChange()
        }
    }
    
    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
        }
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    func evaluatePowerChange() {
        let info = readPowerInfo()
        self.currentIsAC = info.isAC
        self.currentLevel = info.level
        self.currentIsCharging = info.isCharging
        
        guard !isFirstCheck else { return }
        
        let acChanged = (lastIsAC != info.isAC)
        let chargingStarted = (info.isAC && !lastIsCharging && info.isCharging)
        
        if acChanged || chargingStarted {
            self.lastIsAC = info.isAC
            self.lastLevel = info.level
            self.lastIsCharging = info.isCharging
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.onPowerStateChanged?(info.isAC, info.isCharging, info.level)
            }
        } else {
            self.lastLevel = info.level
            self.lastIsCharging = info.isCharging
        }
    }
    
    func readPowerInfo() -> (isAC: Bool, isCharging: Bool, level: Int) {
        var isAC = true
        var level = 100
        var isCharging = false
        var foundBattery = false
        
        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() {
            let type = IOPSGetProvidingPowerSourceType(snapshot)?.takeRetainedValue() as? String
            if type == (kIOPSBatteryPowerValue as String) {
                isAC = false
            } else if type == (kIOPSACPowerValue as String) {
                isAC = true
            }
            
            if let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] {
                for ps in sources {
                    if let desc = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any] {
                        if let state = desc[kIOPSPowerSourceStateKey as String] as? String {
                            if state == (kIOPSACPowerValue as String) {
                                isAC = true
                            } else if state == (kIOPSBatteryPowerValue as String) {
                                isAC = false
                            }
                        }
                        if let curCap = desc[kIOPSCurrentCapacityKey as String] as? Int,
                           let maxCap = desc[kIOPSMaxCapacityKey as String] as? Int,
                           maxCap > 0 {
                            level = min(100, max(0, Int((Double(curCap) / Double(maxCap)) * 100)))
                            foundBattery = true
                        }
                        if let charging = desc[kIOPSIsChargingKey as String] as? Bool {
                            isCharging = charging
                        }
                    }
                }
            }
        }
        
        // If IOKit.ps list did not report battery details, read directly from IOKit AppleSmartBattery registry
        if !foundBattery {
            let smart = readAppleSmartBattery()
            if let ac = smart.isAC { isAC = ac }
            if let lvl = smart.level { level = lvl }
            if let chg = smart.isCharging { isCharging = chg }
        }
        
        return (isAC, isCharging, level)
    }
    
    private func readAppleSmartBattery() -> (isAC: Bool?, isCharging: Bool?, level: Int?) {
        let matching = IOServiceMatching("AppleSmartBattery")
        let service = IOServiceGetMatchingService(0, matching)
        guard service != 0 else { return (nil, nil, nil) }
        defer { IOObjectRelease(service) }
        
        var propDict: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &propDict, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = propDict?.takeRetainedValue() as? [String: Any] else {
            return (nil, nil, nil)
        }
        
        let isAC = props["ExternalConnected"] as? Bool
        let isCharging = props["IsCharging"] as? Bool
        var level: Int? = nil
        if let curCap = props["CurrentCapacity"] as? Int,
           let maxCap = props["MaxCapacity"] as? Int,
           maxCap > 0 {
            level = min(100, Swift.max(0, Int((Double(curCap) / Double(maxCap)) * 100)))
        }
        return (isAC, isCharging, level)
    }
}

class HardwareMonitor {
    static let shared = HardwareMonitor()
    
    var onDeviceConnected: ((String) -> Void)?
    var onDeviceDisconnected: ((String) -> Void)?
    
    private var hidManager: IOHIDManager?
    
    private init() {}
    
    func start() {
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        guard let manager = hidManager else { return }
        
        IOHIDManagerSetDeviceMatching(manager, nil) // Match all HID devices
        
        // Setup Callbacks
        let connectCallback: IOHIDDeviceCallback = { context, result, sender, device in
            let mySelf = Unmanaged<HardwareMonitor>.fromOpaque(context!).takeUnretainedValue()
            if let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String {
                DispatchQueue.main.async {
                    mySelf.onDeviceConnected?(name)
                }
            }
        }
        
        let disconnectCallback: IOHIDDeviceCallback = { context, result, sender, device in
            let mySelf = Unmanaged<HardwareMonitor>.fromOpaque(context!).takeUnretainedValue()
            if let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String {
                DispatchQueue.main.async {
                    mySelf.onDeviceDisconnected?(name)
                }
            }
        }
        
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        IOHIDManagerRegisterDeviceMatchingCallback(manager, connectCallback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, disconnectCallback, context)
        
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }
    
    func stop() {
        guard let manager = hidManager else { return }
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }
}
import Cocoa
import CoreGraphics
import AudioToolbox
import CoreAudio

class VolumeManager {
    static let shared = VolumeManager()
    
    var onVolumeChanged: ((Float) -> Void)?
    private var eventTap: CFMachPort?
    
    private init() {}
    
    func start() {
        // Accessibility permissions check
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessEnabled {
            print("Accessibility not granted")
        }
        
        // systemDefined is 14
        let mask = (1 << UInt64(14))
        
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            if type.rawValue == 14 {
                let nsEvent = NSEvent(cgEvent: event)
                guard let nsEvent = nsEvent, nsEvent.type == .systemDefined else { return Unmanaged.passUnretained(event) }
                let data1 = nsEvent.data1
                let keyCode = (data1 & 0xFFFF0000) >> 16
                let keyFlags = (data1 & 0x0000FFFF)
                let keyState = (((keyFlags & 0xFF00) >> 8)) == 0xA
                
                let manager = Unmanaged<VolumeManager>.fromOpaque(refcon!).takeUnretainedValue()
                
                if keyState {
                    // 0 = SoundUp, 1 = SoundDown, 7 = Mute
                    if keyCode == 0 || keyCode == 1 || keyCode == 7 {
                        manager.handleVolumeKey(Int(keyCode))
                        return nil // Swallow event
                    }
                } else {
                    // Handle key up for swallow as well to prevent beep
                    if keyCode == 0 || keyCode == 1 || keyCode == 7 {
                        return nil
                    }
                }
            }
            return Unmanaged.passUnretained(event)
        }
        
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        if let tap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
    
    private func getSystemVolume() -> Float {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &defaultOutputDeviceID)
        
        var volume: Float32 = 0.0
        var volSize = UInt32(MemoryLayout.size(ofValue: volume))
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        
        if AudioObjectHasProperty(defaultOutputDeviceID, &volAddress) {
            AudioObjectGetPropertyData(defaultOutputDeviceID, &volAddress, 0, nil, &volSize, &volume)
        }
        return volume
    }
    
    private func setSystemVolume(_ volume: Float) {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &defaultOutputDeviceID)
        
        var newVolume = max(0.0, min(1.0, volume))
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        
        if AudioObjectHasProperty(defaultOutputDeviceID, &volAddress) {
            AudioObjectSetPropertyData(defaultOutputDeviceID, &volAddress, 0, nil, UInt32(MemoryLayout.size(ofValue: newVolume)), &newVolume)
        }
    }
    
    private func handleVolumeKey(_ key: Int) {
        var currentVol = getSystemVolume()
        let step: Float = 0.0625 // 1/16th like default macOS
        
        if key == 0 { // UP
            currentVol += step
        } else if key == 1 { // DOWN
            currentVol -= step
        } else if key == 7 { // MUTE
            currentVol = (currentVol > 0.0) ? 0.0 : 0.2
        }
        
        setSystemVolume(currentVol)
        
        DispatchQueue.main.async {
            self.onVolumeChanged?(currentVol)
        }
    }
}
import Foundation

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let time: TimeInterval
    let text: String
}

class LyricsManager {
    static let shared = LyricsManager()
    
    func fetchLyrics(for title: String, artist: String, completion: @escaping ([LyricLine]) -> Void) {
        guard !title.isEmpty else { return }
        
        let urlString = "https://lrclib.net/api/get?artist_name=\(artist)&track_name=\(title)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Notchify/1.0", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else { return }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let synced = json["syncedLyrics"] as? String {
                let parsed = self.parseLRC(synced)
                DispatchQueue.main.async {
                    completion(parsed)
                }
            } else {
                // Try searching if exact match fails
                self.searchLyrics(title: title, artist: artist, completion: completion)
            }
        }.resume()
    }
    
    private func searchLyrics(title: String, artist: String, completion: @escaping ([LyricLine]) -> Void) {
        let urlString = "https://lrclib.net/api/search?q=\(artist) \(title)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Notchify/1.0", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else { return }
            
            if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let firstMatch = jsonArray.first(where: { $0["syncedLyrics"] != nil }),
               let synced = firstMatch["syncedLyrics"] as? String {
                let parsed = self.parseLRC(synced)
                DispatchQueue.main.async {
                    completion(parsed)
                }
            }
        }.resume()
    }
    
    private func parseLRC(_ lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let rawLines = lrc.components(separatedBy: .newlines)
        
        for line in rawLines {
            guard line.hasPrefix("["), let bracketEnd = line.firstIndex(of: "]") else { continue }
            
            let timeString = line[line.index(after: line.startIndex)..<bracketEnd]
            let text = String(line[line.index(after: bracketEnd)...]).trimmingCharacters(in: .whitespaces)
            
            let parts = timeString.split(separator: ":")
            if parts.count == 2, let min = Double(parts[0]) {
                if let secDouble = Double(String(parts[1])) {
                    let totalTime = (min * 60) + secDouble
                    if !text.isEmpty {
                        lines.append(LyricLine(time: totalTime, text: text))
                    }
                }
            }
        }
        return lines
    }
}

// MARK: - Weather Manager
class WeatherManager {
    static let shared = WeatherManager()
    
    func fetchWeather(completion: @escaping (String, String, String, String) -> Void) {
        guard let url = URL(string: "https://wttr.in/?format=j1") else { return }
        var request = URLRequest(url: url)
        request.setValue("Notchify/1.0", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else { return }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            
            if let current = (json["current_condition"] as? [[String: Any]])?.first,
               let area = (json["nearest_area"] as? [[String: Any]])?.first {
                
                let tempC = current["temp_C"] as? String ?? "--"
                let code = current["weatherCode"] as? String ?? "116"
                let city = (area["areaName"] as? [[String: String]])?.first?["value"] ?? ""
                
                let descArr = current["weatherDesc"] as? [[String: String]]
                let desc = descArr?.first?["value"] ?? "Unknown"
                
                let icon = Self.weatherCodeToIcon(code)
                
                DispatchQueue.main.async {
                    completion(tempC, desc, icon, city)
                }
            }
        }.resume()
    }
    
    static func weatherCodeToIcon(_ code: String) -> String {
        switch code {
        case "113": return "sun.max.fill"
        case "116": return "cloud.sun.fill"
        case "119", "122": return "cloud.fill"
        case "143", "248", "260": return "cloud.fog.fill"
        case "176", "263", "266", "293", "296": return "cloud.drizzle.fill"
        case "299", "302", "305", "308", "311", "314", "356", "359": return "cloud.rain.fill"
        case "200", "386", "389", "392", "395": return "cloud.bolt.rain.fill"
        case "227", "230", "320", "323", "326", "329", "332", "335", "338", "350", "368", "371", "374", "377": return "cloud.snow.fill"
        default: return "cloud.fill"
        }
    }
}

// MARK: - System Monitor
class SystemMonitor {
    static func getCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCPUInfo)
        guard result == KERN_SUCCESS, let info = cpuInfo else { return 0 }
        
        var totalUser: Int32 = 0, totalSystem: Int32 = 0, totalIdle: Int32 = 0
        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            totalUser += info[offset + Int(CPU_STATE_USER)]
            totalSystem += info[offset + Int(CPU_STATE_SYSTEM)]
            totalIdle += info[offset + Int(CPU_STATE_IDLE)]
        }
        
        let total = Double(totalUser + totalSystem + totalIdle)
        let used = Double(totalUser + totalSystem)
        
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride))
        
        return total > 0 ? (used / total) * 100 : 0
    }
    
    static func getMemoryUsage() -> (used: Double, total: Double, percent: Double) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return (0, 0, 0) }
        
        let pageSize = Double(vm_kernel_page_size)
        let active = Double(stats.active_count) * pageSize
        let wired = Double(stats.wire_count) * pageSize
        let compressed = Double(stats.compressor_page_count) * pageSize
        
        let used = active + wired + compressed
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        let percent = (used / total) * 100
        
        return (used, total, percent)
    }
    
    static func formatBytes(_ bytes: Double) -> String {
        let gb = bytes / 1_073_741_824
        return String(format: "%.1f GB", gb)
    }
}

// MARK: - Weather Card View
struct WeatherCardView: View {
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            weatherHeader
            weatherDetails
        }
        .onAppear { fetchWeather() }
    }
    
    private var weatherHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: viewModel.weatherIcon)
                .font(.system(size: 36))
                .foregroundColor(.yellow)
                .shadow(color: .yellow.opacity(0.4), radius: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.weatherTemp)°C")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(viewModel.weatherCondition)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
        }
    }
    
    private var weatherDetails: some View {
        HStack {
            Image(systemName: "location.fill")
                .font(.system(size: 10))
                .foregroundColor(.blue)
            Text(viewModel.weatherCity)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
            
            Spacer()
            
            Button(action: { fetchWeather() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private func fetchWeather() {
        WeatherManager.shared.fetchWeather { temp, condition, icon, city in
            viewModel.weatherTemp = temp
            viewModel.weatherCondition = condition
            viewModel.weatherIcon = icon
            viewModel.weatherCity = city
        }
    }
}

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

// MARK: - Agenda Model & Manager
struct CustomEvent: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var date: Date
    var colorName: String
    var isYearly: Bool? = false
    
    var isPast: Bool {
        date < Date()
    }
    var isNow: Bool {
        let now = Date()
        return date <= now && date.addingTimeInterval(3600) > now
    }
    var color: Color {
        switch colorName {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "purple": return .purple
        default: return .blue
        }
    }
}

class CustomAgendaManager {
    static let shared = CustomAgendaManager()
    private let defaultsKey = "notchify_custom_events"
    
    func getAllEvents() -> [CustomEvent] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let events = try? JSONDecoder().decode([CustomEvent].self, from: data) else {
            return []
        }
        return events
    }
    
    func saveEvents(_ events: [CustomEvent]) {
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
    
    func addEvent(_ event: CustomEvent) {
        var events = getAllEvents()
        events.append(event)
        saveEvents(events)
    }
    
    func deleteEvent(id: UUID) {
        var events = getAllEvents()
        events.removeAll { $0.id == id }
        saveEvents(events)
    }
    
    func fetchEvents(forDateOffset offset: Int) -> [CustomEvent] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let targetDate = calendar.date(byAdding: .day, value: offset, to: today),
              let endDate = calendar.date(byAdding: .day, value: 1, to: targetDate) else { return [] }
        
        return getAllEvents().compactMap { event in
            var modifiedEvent = event
            if event.isYearly == true {
                // Change the event's date to match the target date's year
                var components = calendar.dateComponents([.month, .day, .hour, .minute], from: event.date)
                components.year = calendar.component(.year, from: targetDate)
                if let newDate = calendar.date(from: components) {
                    modifiedEvent.date = newDate
                }
            }
            if modifiedEvent.date >= targetDate && modifiedEvent.date < endDate {
                return modifiedEvent
            }
            return nil
        }.sorted { $0.date < $1.date }
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

struct AgendaCardView: View {
    @ObservedObject var viewModel: NotchViewModel
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    @State private var isAdding = false
    @State private var newTitle = ""
    @State private var newTime = Date()
    @State private var newColor = "blue"
    @State private var newIsYearly = false
    @State private var hoveredEventId: UUID? = nil
    
    let colors = ["red", "blue", "green", "yellow", "purple"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isAdding {
                addForm
            } else {
                listView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            viewModel.fetchAgenda()
            resetNewTime()
        }
        .onReceive(timer) { _ in
            if !isAdding { viewModel.fetchAgenda() }
        }
        .onChange(of: viewModel.agendaDateOffset) { _ in
            resetNewTime()
        }
        .onChange(of: isAdding) { newValue in
            viewModel.isPinningExpansion = newValue
        }
    }
    
    private func resetNewTime() {
        let calendar = Calendar.current
        let target = calendar.date(byAdding: .day, value: viewModel.agendaDateOffset, to: Date()) ?? Date()
        newTime = target
    }
    
    private var addForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LanguageManager.tr("Add New Event"))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            
            TextField(LanguageManager.tr("Event title..."), text: $newTitle)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
                .foregroundColor(.white)
                .font(.system(size: 14))
            
            HStack {
                Text(LanguageManager.tr("Time:"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
                DatePicker("", selection: $newTime, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(FieldDatePickerStyle())
            }
            
            HStack(spacing: 12) {
                Text(LanguageManager.tr("Color:"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
                ForEach(colors, id: \.self) { cName in
                    Circle()
                        .fill(colorFor(cName))
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(Color.white, lineWidth: newColor == cName ? 2 : 0))
                        .onTapGesture { newColor = cName }
                }
            }
            .padding(.top, 4)
            
            Toggle(isOn: $newIsYearly) {
                Text(LanguageManager.tr("Yearly (Birthday/Anniversary)"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
            .toggleStyle(CheckboxToggleStyle())
            
            Spacer(minLength: 0)
            
            HStack {
                Button(action: {
                    withAnimation { isAdding = false }
                }) {
                    Text(LanguageManager.tr("Cancel"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button(action: {
                    let ev = CustomEvent(title: newTitle.isEmpty ? "Untitled" : newTitle, date: newTime, colorName: newColor, isYearly: newIsYearly)
                    CustomAgendaManager.shared.addEvent(ev)
                    viewModel.fetchAgenda()
                    newTitle = ""
                    withAnimation { isAdding = false }
                }) {
                    Text(LanguageManager.tr("Save"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 16)
                        .background(Color.white)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(height: 245)
        .onDisappear {
            isAdding = false
            newIsYearly = false
            viewModel.isPinningExpansion = false
        }
    }
    
    private var listView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                header
                Spacer()
                Button(action: {
                    withAnimation { isAdding = true }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if viewModel.agendaEvents.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "calendar.badge.minus")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.5))
                    Text(LanguageManager.tr("No schedule 🎉"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.agendaEvents) { event in
                            eventRow(for: event)
                        }
                    }
                    .padding(.trailing, 4)
                }
                .frame(height: 130)
            }
            
            Spacer(minLength: 0)
            
            // Pagination dots
            HStack(spacing: 8) {
                Spacer()
                ForEach(-1...1, id: \.self) { offset in
                    Circle()
                        .fill(viewModel.agendaDateOffset == offset ? Color.white : Color.white.opacity(0.2))
                        .frame(width: 6, height: 6)
                        .onTapGesture {
                            withAnimation {
                                viewModel.agendaDateOffset = offset
                                viewModel.fetchAgenda()
                            }
                        }
                }
                Spacer()
            }
            .padding(.bottom, 4)
            
            countdownView
        }
    }
    
    private var header: some View {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "EEEE, d MMM"
        
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: viewModel.agendaDateOffset, to: Date()) ?? Date()
        
        var prefix = LanguageManager.tr("Today")
        if viewModel.agendaDateOffset == -1 { prefix = "Kemarin" }
        else if viewModel.agendaDateOffset == 1 { prefix = LanguageManager.tr("Tomorrow") }
        
        return Text("\(prefix) — \(formatter.string(from: targetDate))")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
    }
    
    private func eventRow(for event: CustomEvent) -> some View {
        let isNow = event.isNow
        let isPast = event.isPast
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        return HStack(spacing: 12) {
            Circle()
                .fill(event.color)
                .frame(width: 8, height: 8)
                .opacity(isPast ? 0.3 : 1.0)
            
            Text(formatter.string(from: event.date))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(isPast ? .gray : .white)
                .frame(width: 50, alignment: .leading)
            
            Text(event.title)
                .font(.system(size: 14, weight: isNow ? .bold : .medium))
                .foregroundColor(isPast ? .gray : .white)
                .lineLimit(1)
            
            Spacer()
            
            if hoveredEventId == event.id {
                Button(action: {
                    withAnimation {
                        CustomAgendaManager.shared.deleteEvent(id: event.id)
                        viewModel.fetchAgenda()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isNow ? Color.white.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .onHover { isHovering in
            if isHovering { hoveredEventId = event.id }
            else if hoveredEventId == event.id { hoveredEventId = nil }
        }
    }
    
    private var countdownView: some View {
        Group {
            if let nextEvent = viewModel.agendaEvents.first(where: { !$0.isPast }) {
                countdownText(for: nextEvent)
            } else {
                Text(LanguageManager.tr("No upcoming schedule"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func countdownText(for event: CustomEvent) -> some View {
        let diff = Int(event.date.timeIntervalSince(Date()))
        if diff > 0 {
            let hours = diff / 3600
            let minutes = (diff % 3600) / 60
            let timeStr = hours > 0 ? "\(hours)j \(minutes)m" : "\(minutes)m"
            return Text("\(LanguageManager.tr("Next:")) \(event.title) — \(timeStr) \(LanguageManager.tr("left"))")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.cyan)
                .lineLimit(1)
        } else {
            return Text("\(LanguageManager.tr("Next:")) \(event.title) — \(LanguageManager.tr("In progress"))")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.green)
                .lineLimit(1)
        }
    }
    
    private func colorFor(_ name: String) -> Color {
        switch name {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "purple": return .purple
        default: return .blue
        }
    }
}

// MARK: - Photo Storage Manager
struct PhotoStorageManager {
    static var defaultFolderURL: URL {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Pictures")
        return pictures.appendingPathComponent("Notchify")
    }
    
    static func getPhotosDirectory() -> URL {
        let storageType = UserDefaults.standard.string(forKey: "photoStorageType") ?? "default"
        let customPath = UserDefaults.standard.string(forKey: "customPhotoStoragePath") ?? ""
        
        if storageType == "custom" && !customPath.isEmpty {
            let customURL = URL(fileURLWithPath: customPath)
            if !FileManager.default.fileExists(atPath: customURL.path) {
                try? FileManager.default.createDirectory(at: customURL, withIntermediateDirectories: true)
            }
            return customURL
        }
        
        let def = defaultFolderURL
        if !FileManager.default.fileExists(atPath: def.path) {
            try? FileManager.default.createDirectory(at: def, withIntermediateDirectories: true)
        }
        return def
    }
    
    static func openPhotosFolder() {
        let dir = getPhotosDirectory()
        NSWorkspace.shared.open(dir)
    }
    
    static func revealPhotoInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

// MARK: - Camera & Video Enums
enum CameraCaptureMode: String, CaseIterable, Identifiable {
    case photo = "Photo"
    case video = "Video"
    
    var id: String { rawValue }
    
    var localizedTitle: String {
        switch self {
        case .photo: return LanguageManager.tr("Photo")
        case .video: return LanguageManager.tr("Video")
        }
    }
    
    var iconName: String {
        switch self {
        case .photo: return "camera.fill"
        case .video: return "video.fill"
        }
    }
}

enum VideoDurationPreset: Int, CaseIterable, Identifiable {
    case sec15 = 15
    case sec30 = 30
    case sec60 = 60
    case min3 = 180
    case min5 = 300
    
    var id: Int { rawValue }
    
    var label: String {
        switch self {
        case .sec15: return "15s"
        case .sec30: return "30s"
        case .sec60: return "60s"
        case .min3: return "3m"
        case .min5: return "5m"
        }
    }
    
    var seconds: Int { rawValue }
}

// MARK: - Mirror & Camera Manager
class CameraMirrorManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {
    static let shared = CameraMirrorManager()
    
    @Published var isRunning = false
    @Published var permissionGranted = false
    @Published var isMirrored = true
    @Published var isFrozen = false
    
    // Mode
    @Published var captureMode: CameraCaptureMode = .photo
    
    // Photo capture states
    @Published var isTimerEnabled = false // false = instant, true = 3s
    @Published var isCountingDown = false
    @Published var countdownSeconds = 3
    @Published var isCapturing = false
    @Published var showFlash = false
    @Published var lastCapturedPhotoURL: URL?
    @Published var lastCapturedThumbnail: NSImage?
    @Published var lastCapturedImage: NSImage?
    @Published var savedFeedbackMessage: String?
    
    // Video capture states
    @Published var selectedDurationPreset: VideoDurationPreset = .sec30
    @Published var isRecordingVideo = false
    @Published var recordingElapsedSeconds: Int = 0
    @Published var isMicMuted: Bool = false
    @Published var lastCapturedVideoURL: URL?
    @Published var lastCapturedMediaType: CameraCaptureMode = .photo
    @Published var shouldOpenMediaViewer: Bool = false
    
    let session = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()
    let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "notchify.mirror.sessionQueue")
    private var isConfigured = false
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var countdownTimer: Timer?
    private var recordingTimer: Timer?
    
    override init() {
        super.init()
    }
    
    func checkPermissionAndStart() {
        // Request audio access if needed
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                if granted {
                    self?.sessionQueue.async {
                        guard let self = self, self.isConfigured, self.audioInput == nil else { return }
                        if let audioDevice = AVCaptureDevice.default(for: .audio),
                           let aInput = try? AVCaptureDeviceInput(device: audioDevice) {
                            self.session.beginConfiguration()
                            if self.session.canAddInput(aInput) {
                                self.session.addInput(aInput)
                                self.audioInput = aInput
                            }
                            self.session.commitConfiguration()
                        }
                    }
                }
            }
        }
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { self.permissionGranted = true }
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.permissionGranted = granted
                    if granted {
                        self.startSession()
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async { self.permissionGranted = false }
        @unknown default:
            break
        }
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.session.isRunning else { return }
            if !self.isConfigured {
                self.setupSession()
            }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isRunning = self.session.isRunning
                PrivacyMonitor.shared.isCameraActive = self.session.isRunning
            }
        }
    }
    
    func stopSession() {
        cancelCountdown()
        if isRecordingVideo {
            stopVideoRecording()
        }
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
                PrivacyMonitor.shared.isCameraActive = false
                PrivacyMonitor.shared.isMicActive = false
            }
        }
    }
    
    private func setupSession() {
        session.beginConfiguration()
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        } else if session.canSetSessionPreset(.medium) {
            session.sessionPreset = .medium
        }
        
        // Video Input
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        let device = AVCaptureDevice.default(for: .video) ?? discoverySession.devices.first
        if let camera = device, let input = try? AVCaptureDeviceInput(device: camera) {
            if session.canAddInput(input) {
                session.addInput(input)
                self.videoInput = input
            }
        }
        
        // Audio Input
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let aInput = try? AVCaptureDeviceInput(device: audioDevice) {
            if session.canAddInput(aInput) {
                session.addInput(aInput)
                self.audioInput = aInput
            }
        }
        
        // Photo Output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        // Movie Output (Hard-capped at 5 minutes = 300 seconds)
        movieOutput.maxRecordedDuration = CMTime(seconds: 300, preferredTimescale: 600)
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }
        
        session.commitConfiguration()
        self.isConfigured = true
    }
    
    // MARK: - Capture Sequence
    func triggerCaptureSequence() {
        guard !isCapturing && !isCountingDown else { return }
        if isTimerEnabled {
            startCountdown()
        } else {
            performCapture()
        }
    }
    
    func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        isCountingDown = false
    }
    
    private func startCountdown() {
        countdownSeconds = 3
        isCountingDown = true
        countdownTimer?.invalidate()
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            if self.countdownSeconds > 1 {
                self.countdownSeconds -= 1
                NSSound(named: "Tink")?.play()
            } else {
                timer.invalidate()
                self.countdownTimer = nil
                self.isCountingDown = false
                self.performCapture()
            }
        }
    }
    
    private func performCapture() {
        isCapturing = true
        
        // Visual Screen Flash
        withAnimation(.easeIn(duration: 0.08)) {
            self.showFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeOut(duration: 0.25)) {
                self.showFlash = false
            }
        }
        
        // Shutter Sound
        let playSound = UserDefaults.standard.object(forKey: "playShutterSound") as? Bool ?? true
        if playSound {
            AudioServicesPlaySystemSound(1108)
        }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let photoSettings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        DispatchQueue.main.async {
            self.isCapturing = false
        }
        
        if let error = error {
            print("Notchify camera error: \(error)")
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let originalImage = NSImage(data: data) else {
            return
        }
        
        let finalImage = self.isMirrored ? mirrorImage(originalImage) : originalImage
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateStr = formatter.string(from: Date())
        let filename = "Notchify_\(dateStr).png"
        
        let targetDirectory = PhotoStorageManager.getPhotosDirectory()
        let fileURL = targetDirectory.appendingPathComponent(filename)
        
        if let tiff = finalImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            do {
                try pngData.write(to: fileURL)
                let thumb = makeThumbnail(image: finalImage, targetSize: NSSize(width: 32, height: 32))
                
                DispatchQueue.main.async {
                    self.lastCapturedPhotoURL = fileURL
                    self.lastCapturedThumbnail = thumb
                    self.lastCapturedImage = finalImage
                    self.lastCapturedMediaType = .photo
                    self.savedFeedbackMessage = LanguageManager.tr("Saved!")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        if self.savedFeedbackMessage == LanguageManager.tr("Saved!") {
                            self.savedFeedbackMessage = nil
                        }
                    }
                }
            } catch {
                print("Failed to write photo: \(error)")
            }
        }
    }
    
    // MARK: - Video Recording
    func toggleMicMute() {
        isMicMuted.toggle()
        if let audioConn = movieOutput.connection(with: .audio) {
            audioConn.isEnabled = !isMicMuted
        }
    }
    
    func startVideoRecording() {
        guard !isRecordingVideo else { return }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let dateStr = formatter.string(from: Date())
        let filename = "Notchify_Video_\(dateStr).mp4"
        let targetDirectory = PhotoStorageManager.getPhotosDirectory()
        let fileURL = targetDirectory.appendingPathComponent(filename)
        
        try? FileManager.default.removeItem(at: fileURL)
        
        // Configure mirroring
        if let videoConn = movieOutput.connection(with: .video) {
            if videoConn.isVideoMirroringSupported {
                videoConn.automaticallyAdjustsVideoMirroring = false
                videoConn.isVideoMirrored = self.isMirrored
            }
        }
        
        // Configure audio
        if let audioConn = movieOutput.connection(with: .audio) {
            audioConn.isEnabled = !self.isMicMuted
        }
        
        movieOutput.startRecording(to: fileURL, recordingDelegate: self)
        
        isRecordingVideo = true
        recordingElapsedSeconds = 0
        PrivacyMonitor.shared.isMicActive = !self.isMicMuted
        
        NSSound(named: "Tink")?.play()
        
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            self.recordingElapsedSeconds += 1
            if self.recordingElapsedSeconds >= self.selectedDurationPreset.seconds {
                self.stopVideoRecording()
            }
        }
    }
    
    func stopVideoRecording() {
        guard isRecordingVideo else { return }
        recordingTimer?.invalidate()
        recordingTimer = nil
        movieOutput.stopRecording()
    }
    
    // MARK: - AVCaptureFileOutputRecordingDelegate
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
            self.isRecordingVideo = false
            PrivacyMonitor.shared.isMicActive = false
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
            
            if let error = error {
                let nsError = error as NSError
                let success = (nsError.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool) ?? false
                if !success {
                    print("Video recording failed: \(error)")
                    return
                }
            }
            
            self.lastCapturedVideoURL = outputFileURL
            self.lastCapturedMediaType = .video
            self.generateVideoThumbnail(for: outputFileURL)
            self.savedFeedbackMessage = LanguageManager.tr("Video Saved!")
            self.shouldOpenMediaViewer = true
            
            NSSound(named: "Pop")?.play()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if self.savedFeedbackMessage == LanguageManager.tr("Video Saved!") {
                    self.savedFeedbackMessage = nil
                }
            }
        }
    }
    
    private func generateVideoThumbnail(for url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let time = CMTime(seconds: 0.2, preferredTimescale: 600)
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                let img = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                let thumb = self.makeThumbnail(image: img, targetSize: NSSize(width: 32, height: 32))
                DispatchQueue.main.async {
                    self.lastCapturedThumbnail = thumb
                }
            }
        }
    }
    
    func loadLatestMedia() {
        guard lastCapturedPhotoURL == nil && lastCapturedVideoURL == nil else { return }
        let dir = PhotoStorageManager.getPhotosDirectory()
        let fileManager = FileManager.default
        if let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) {
            let mediaFiles = files.filter {
                let ext = $0.pathExtension.lowercased()
                return ext == "png" || ext == "mp4" || ext == "mov"
            }.sorted { (u1, u2) -> Bool in
                let d1 = (try? u1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                let d2 = (try? u2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                return d1 > d2
            }
            
            if let latest = mediaFiles.first {
                let ext = latest.pathExtension.lowercased()
                if ext == "mp4" || ext == "mov" {
                    self.lastCapturedVideoURL = latest
                    self.lastCapturedMediaType = .video
                    self.generateVideoThumbnail(for: latest)
                } else if ext == "png" {
                    if let img = NSImage(contentsOf: latest) {
                        self.lastCapturedPhotoURL = latest
                        self.lastCapturedMediaType = .photo
                        self.lastCapturedImage = img
                        self.lastCapturedThumbnail = self.makeThumbnail(image: img, targetSize: NSSize(width: 32, height: 32))
                    }
                }
            }
        }
    }
    
    func loadLatestPhoto() {
        loadLatestMedia()
    }
    
    private func mirrorImage(_ image: NSImage) -> NSImage {
        let size = image.size
        let mirrored = NSImage(size: size)
        mirrored.lockFocus()
        let transform = NSAffineTransform()
        transform.translateX(by: size.width, yBy: 0)
        transform.scaleX(by: -1, yBy: 1)
        transform.concat()
        image.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1.0)
        mirrored.unlockFocus()
        return mirrored
    }
    
    private func makeThumbnail(image: NSImage, targetSize: NSSize) -> NSImage {
        let thumb = NSImage(size: targetSize)
        thumb.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize), from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)
        thumb.unlockFocus()
        return thumb
    }
}

class CameraPreviewNSView: NSView {
    var previewLayer: AVCaptureVideoPreviewLayer {
        return (layer as? AVCaptureVideoPreviewLayer) ?? AVCaptureVideoPreviewLayer()
    }
    
    private var currentMirrored: Bool = true
    private var currentFrozen: Bool = false
    
    override func makeBackingLayer() -> CALayer {
        let pLayer = AVCaptureVideoPreviewLayer()
        pLayer.cornerRadius = 16
        pLayer.masksToBounds = true
        return pLayer
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        previewLayer.frame = bounds
        applySettings()
    }
    
    func updateSettings(isMirrored: Bool, isFrozen: Bool) {
        self.currentMirrored = isMirrored
        self.currentFrozen = isFrozen
        applySettings()
    }
    
    private func applySettings() {
        guard let conn = previewLayer.connection else { return }
        if conn.isVideoMirroringSupported {
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = currentMirrored
        }
        conn.isEnabled = !currentFrozen
    }
}

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    var isMirrored: Bool
    var isFrozen: Bool
    
    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.updateSettings(isMirrored: isMirrored, isFrozen: isFrozen)
        return view
    }
    
    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        if nsView.previewLayer.session != session {
            nsView.previewLayer.session = session
        }
        nsView.updateSettings(isMirrored: isMirrored, isFrozen: isFrozen)
    }
}

struct InTabVideoPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?
    @State private var loopObserver: Any?
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .frame(width: 360, height: 195)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black)
                    .frame(width: 360, height: 195)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    )
            }
        }
        .onAppear {
            let p = AVPlayer(url: url)
            self.player = p
            p.play()
            
            self.loopObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: p.currentItem,
                queue: .main
            ) { _ in
                p.seek(to: .zero)
                p.play()
            }
        }
        .onDisappear {
            if let observer = loopObserver {
                NotificationCenter.default.removeObserver(observer)
                loopObserver = nil
            }
            player?.pause()
            player = nil
        }
    }
}

struct MirrorCardView: View {
    @ObservedObject var viewModel: NotchViewModel
    @StateObject private var cameraManager = CameraMirrorManager.shared
    @State private var isViewingMedia = false
    @State private var showCopiedFeedback = false
    @State private var copiedFeedbackText = ""
    @State private var recBlink = false
    
    var body: some View {
        VStack(spacing: 8) {
            if cameraManager.permissionGranted {
                if isViewingMedia {
                    mediaViewerContainer
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                } else {
                    mirrorContainer
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                }
            } else {
                permissionNeededCard
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            cameraManager.checkPermissionAndStart()
            cameraManager.loadLatestMedia()
        }
        .onDisappear {
            cameraManager.stopSession()
            isViewingMedia = false
        }
        .onReceive(cameraManager.$shouldOpenMediaViewer) { shouldOpen in
            if shouldOpen {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    isViewingMedia = true
                }
                cameraManager.shouldOpenMediaViewer = false
            }
        }
    }
    
    private var mirrorContainer: some View {
        VStack(spacing: 8) {
            // Top Mode Switcher Bar
            HStack {
                // Mode Switcher: Photo | Video
                HStack(spacing: 2) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            cameraManager.captureMode = .photo
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text(LanguageManager.tr("Photo"))
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(cameraManager.captureMode == .photo ? .white : .gray)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(cameraManager.captureMode == .photo ? Color.white.opacity(0.2) : Color.clear)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(cameraManager.isRecordingVideo)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            cameraManager.captureMode = .video
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text(LanguageManager.tr("Video"))
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(cameraManager.captureMode == .video ? .white : .gray)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(cameraManager.captureMode == .video ? Color.red.opacity(0.85) : Color.clear)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(cameraManager.isRecordingVideo)
                }
                .padding(2)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                
                Spacer()
                
                // Sub-mode options (Right)
                if cameraManager.captureMode == .video {
                    // Duration Presets: 15s | 30s | 60s | 3m | 5m
                    HStack(spacing: 2) {
                        ForEach(VideoDurationPreset.allCases) { preset in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    cameraManager.selectedDurationPreset = preset
                                }
                            }) {
                                Text(preset.label)
                                    .font(.system(size: 10, weight: cameraManager.selectedDurationPreset == preset ? .bold : .medium))
                                    .foregroundColor(cameraManager.selectedDurationPreset == preset ? .white : .gray)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(cameraManager.selectedDurationPreset == preset ? Color.white.opacity(0.25) : Color.clear)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(cameraManager.isRecordingVideo)
                        }
                    }
                    .padding(2)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                } else {
                    // Photo Timer Toggle: Instant / 3s
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            cameraManager.isTimerEnabled.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.system(size: 10, weight: .semibold))
                            Text(cameraManager.isTimerEnabled ? "3s" : LanguageManager.tr("Off"))
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(cameraManager.isTimerEnabled ? .yellow : .white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(cameraManager.isTimerEnabled ? Color.yellow.opacity(0.2) : Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(LanguageManager.tr("Timer: 3 seconds delay"))
                }
            }
            .frame(width: 360)
            
            // Camera Video Preview Box
            ZStack {
                CameraPreviewView(
                    session: cameraManager.session,
                    isMirrored: cameraManager.isMirrored,
                    isFrozen: cameraManager.isFrozen
                )
                .frame(width: 360, height: 195)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Elegant Border
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    .frame(width: 360, height: 195)
                
                // Screen Flash Animation (Photo)
                if cameraManager.showFlash {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .frame(width: 360, height: 195)
                        .transition(.opacity)
                }
                
                // Countdown Overlay (3.. 2.. 1..)
                if cameraManager.isCountingDown {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.65))
                            .frame(width: 68, height: 68)
                        
                        Text("\(cameraManager.countdownSeconds)")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundColor(.yellow)
                    }
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
                
                // Video Recording HUD (Top-left & Bottom progress bar)
                if cameraManager.isRecordingVideo {
                    VStack {
                        HStack {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .opacity(recBlink ? 1.0 : 0.2)
                                    .animation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: recBlink)
                                    .onAppear { recBlink = true }
                                
                                Text(LanguageManager.tr("REC"))
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundColor(.red)
                                
                                Text("\(formatSeconds(cameraManager.recordingElapsedSeconds)) / \(formatSeconds(cameraManager.selectedDurationPreset.seconds))")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.75))
                            .clipShape(Capsule())
                            .padding(.leading, 10)
                            .padding(.top, 10)
                            
                            Spacer()
                        }
                        
                        Spacer()
                        
                        // Bottom Progress Bar
                        GeometryReader { geo in
                            let progress = min(1.0, max(0.0, Double(cameraManager.recordingElapsedSeconds) / Double(max(1, cameraManager.selectedDurationPreset.seconds))))
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 3)
                                
                                Rectangle()
                                    .fill(Color.red)
                                    .frame(width: geo.size.width * CGFloat(progress), height: 3)
                                    .animation(.linear(duration: 1.0), value: progress)
                            }
                        }
                        .frame(width: 360, height: 3)
                        .clipShape(RoundedRectangle(cornerRadius: 1.5))
                        .padding(.bottom, 6)
                    }
                    .frame(width: 360, height: 195)
                }
                
                // Frozen Overlay Badge
                if cameraManager.isFrozen && !cameraManager.isCountingDown && !cameraManager.isRecordingVideo {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "pause.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(LanguageManager.tr("Preview Paused"))
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.65))
                        .clipShape(Capsule())
                        .padding(.bottom, 8)
                    }
                    .frame(width: 360, height: 195)
                }
                
                // Saved Feedback Toast
                if let msg = cameraManager.savedFeedbackMessage {
                    VStack {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 12, weight: .bold))
                            Text(msg)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Capsule())
                        .padding(.top, 10)
                        Spacer()
                    }
                    .frame(width: 360, height: 195)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(width: 360, height: 195)
            
            // Floating Toolbar Controls
            HStack(spacing: 14) {
                // 1. Left auxiliary button
                if cameraManager.captureMode == .video {
                    // Mic mute/unmute toggle
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            cameraManager.toggleMicMute()
                        }
                    }) {
                        Image(systemName: cameraManager.isMicMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(cameraManager.isMicMuted ? .red : .white)
                            .frame(width: 30, height: 30)
                            .background(cameraManager.isMicMuted ? Color.red.opacity(0.2) : Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(cameraManager.isMicMuted ? LanguageManager.tr("Microphone Muted") : LanguageManager.tr("Microphone Active"))
                } else {
                    // Freeze frame button (Photo mode)
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            cameraManager.isFrozen.toggle()
                        }
                    }) {
                        Image(systemName: cameraManager.isFrozen ? "play.fill" : "pause.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(cameraManager.isFrozen ? .yellow : .white)
                            .frame(width: 30, height: 30)
                            .background(cameraManager.isFrozen ? Color.yellow.opacity(0.2) : Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(LanguageManager.tr("Freeze frame to check details"))
                }
                
                // 2. Flip Mirror / Audience View
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        cameraManager.isMirrored.toggle()
                    }
                }) {
                    Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(cameraManager.isRecordingVideo)
                .help(cameraManager.isMirrored ? LanguageManager.tr("Mirrored (Click for True View)") : LanguageManager.tr("True View (Click for Mirrored)"))
                
                // 3. MAIN ACTION BUTTON (Center)
                if cameraManager.captureMode == .video {
                    if cameraManager.isRecordingVideo {
                        // STOP RECORDING BUTTON
                        Button(action: {
                            cameraManager.stopVideoRecording()
                        }) {
                            ZStack {
                                Circle()
                                    .stroke(Color.red, lineWidth: 2.5)
                                    .frame(width: 36, height: 36)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.red)
                                    .frame(width: 15, height: 15)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(LanguageManager.tr("Stop Recording"))
                    } else {
                        // START RECORDING BUTTON
                        Button(action: {
                            cameraManager.startVideoRecording()
                        }) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white, lineWidth: 2.5)
                                    .frame(width: 36, height: 36)
                                
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 26, height: 26)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(LanguageManager.tr("Record Video"))
                    }
                } else {
                    // PHOTO SHUTTER BUTTON
                    Button(action: {
                        cameraManager.triggerCaptureSequence()
                    }) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 2.5)
                                .frame(width: 36, height: 36)
                            
                            Circle()
                                .fill(cameraManager.isCountingDown ? Color.yellow : Color.white)
                                .frame(width: 26, height: 26)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(cameraManager.isCapturing || cameraManager.isCountingDown)
                    .help(LanguageManager.tr("Take Photo"))
                }
                
                // 4. Freeze button in Video Mode
                if cameraManager.captureMode == .video {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            cameraManager.isFrozen.toggle()
                        }
                    }) {
                        Image(systemName: cameraManager.isFrozen ? "play.fill" : "pause.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(cameraManager.isFrozen ? .yellow : .white)
                            .frame(width: 30, height: 30)
                            .background(cameraManager.isFrozen ? Color.yellow.opacity(0.2) : Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(cameraManager.isRecordingVideo)
                    .help(LanguageManager.tr("Freeze frame to check details"))
                }
                
                // 5. Last Media Thumbnail or Open Folder Button
                if let thumb = cameraManager.lastCapturedThumbnail {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isViewingMedia = true
                        }
                    }) {
                        ZStack(alignment: .bottomTrailing) {
                            Image(nsImage: thumb)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 30, height: 30)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 1.5)
                                )
                            
                            if cameraManager.lastCapturedMediaType == .video {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(2)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 2, y: 2)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(cameraManager.isRecordingVideo)
                    .help(LanguageManager.tr("View latest media"))
                } else {
                    Button(action: {
                        PhotoStorageManager.openPhotosFolder()
                    }) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(cameraManager.isRecordingVideo)
                    .help(LanguageManager.tr("Open Photos Folder"))
                }
            }
            .frame(width: 360)
        }
    }
    
    private var mediaViewerContainer: some View {
        VStack(spacing: 10) {
            // Media Preview Box (Matches 360 x 195 frame)
            ZStack {
                if cameraManager.lastCapturedMediaType == .video, let videoURL = cameraManager.lastCapturedVideoURL {
                    InTabVideoPlayerView(url: videoURL)
                } else if let image = cameraManager.lastCapturedImage ?? (cameraManager.lastCapturedPhotoURL.flatMap { NSImage(contentsOf: $0) }) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 360, height: 195)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 360, height: 195)
                        .overlay(
                            Text(LanguageManager.tr("No Media"))
                                .foregroundColor(.gray)
                                .font(.system(size: 12))
                        )
                }
                
                // Border
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    .frame(width: 360, height: 195)
                
                // Copied Toast Overlay
                if showCopiedFeedback {
                    VStack {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 12, weight: .bold))
                            Text(copiedFeedbackText)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.85))
                        .clipShape(Capsule())
                        .padding(.top, 10)
                        Spacer()
                    }
                    .frame(width: 360, height: 195)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(width: 360, height: 195)
            
            // Media Viewer Toolbar (Back, Copy Image/Video, Open Folder)
            HStack(spacing: 10) {
                // Back to Camera
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isViewingMedia = false
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text(LanguageManager.tr("Camera"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .help(LanguageManager.tr("Back to Camera"))
                
                Spacer()
                
                // Copy Media Button
                Button(action: {
                    copyMediaToClipboard()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10, weight: .semibold))
                        Text(cameraManager.lastCapturedMediaType == .video ? LanguageManager.tr("Copy Video") : LanguageManager.tr("Copy Image"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .help(cameraManager.lastCapturedMediaType == .video ? LanguageManager.tr("Copy video to clipboard") : LanguageManager.tr("Copy photo to clipboard"))
                
                // Open Folder Button
                Button(action: {
                    let targetURL = cameraManager.lastCapturedMediaType == .video ? cameraManager.lastCapturedVideoURL : cameraManager.lastCapturedPhotoURL
                    if let url = targetURL {
                        PhotoStorageManager.revealPhotoInFinder(url: url)
                    } else {
                        PhotoStorageManager.openPhotosFolder()
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "folder")
                            .font(.system(size: 10, weight: .semibold))
                        Text(LanguageManager.tr("Open Folder"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .help(LanguageManager.tr("Open in Finder"))
            }
            .frame(width: 360)
        }
    }
    
    private func copyMediaToClipboard() {
        if cameraManager.lastCapturedMediaType == .video {
            guard let url = cameraManager.lastCapturedVideoURL else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([url as NSURL])
            copiedFeedbackText = LanguageManager.tr("Video Copied to Clipboard")
        } else {
            guard let image = cameraManager.lastCapturedImage ?? (cameraManager.lastCapturedPhotoURL.flatMap { NSImage(contentsOf: $0) }) else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
            copiedFeedbackText = LanguageManager.tr("Image Copied to Clipboard")
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showCopiedFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.2)) {
                showCopiedFeedback = false
            }
        }
    }
    
    private func formatSeconds(_ secs: Int) -> String {
        let m = secs / 60
        let s = secs % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    private var permissionNeededCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 36))
                .foregroundColor(.orange)
            
            Text(LanguageManager.tr("Camera Access Needed"))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            
            Text(LanguageManager.tr("Notchify needs camera access to show your quick webcam mirror preview."))
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Button(action: {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Text(LanguageManager.tr("Open System Settings"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(width: 360, height: 230)
    }
}

struct LiveScrubberView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var localElapsed: Double = 0
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 6) {
            Text(formatTime(localElapsed))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
            
            Slider(value: Binding(
                get: { localElapsed },
                set: { newValue in
                    localElapsed = newValue
                    viewModel.elapsed = newValue
                    viewModel.seek(to: newValue)
                }
            ), in: 0...(viewModel.duration > 0 ? viewModel.duration : 1))
            .controlSize(.mini)
            .tint(.white)
            
            Text(formatTime(viewModel.duration))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
        }
        .onAppear { localElapsed = viewModel.elapsed }
        .onReceive(timer) { _ in
            if viewModel.isPlaying {
                localElapsed = viewModel.elapsed
            }
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        guard time.isFinite && !time.isNaN else { return "0:00" }
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Scratchpad & To-Do Models & Views
struct TodoTask: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var isDone: Bool = false
    var createdAt: Date = Date()
}

enum NotesSubMode: String, CaseIterable {
    case notes = "Notes"
    case todo = "To-Do"
    
    var localizedTitle: String {
        switch self {
        case .notes: return LanguageManager.tr("Notes")
        case .todo: return LanguageManager.tr("To-Do")
        }
    }
}

struct NotesCardView: View {
    @ObservedObject var viewModel: NotchViewModel
    @AppStorage("scratchpadText") private var scratchpadText: String = ""
    @AppStorage("todoTasksJSON") private var todoTasksJSON: String = "[]"
    
    @State private var subMode: NotesSubMode = .notes
    @State private var newTaskTitle: String = ""
    @State private var showCopiedCheck: Bool = false
    @State private var todoTasks: [TodoTask] = []
    
    private var wordCount: Int {
        let trimmed = scratchpadText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        return trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
    
    private var completedCount: Int {
        todoTasks.filter { $0.isDone }.count
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Mode Switcher Header
            HStack {
                HStack(spacing: 4) {
                    ForEach(NotesSubMode.allCases, id: \.self) { mode in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                subMode = mode
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: mode == .notes ? "note.text" : "checklist")
                                    .font(.system(size: 10, weight: .semibold))
                                Text(mode.localizedTitle)
                                    .font(.system(size: 11, weight: subMode == mode ? .bold : .medium))
                                if mode == .todo && !todoTasks.isEmpty {
                                    Text("\(todoTasks.count - completedCount)")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(subMode == mode ? Color.blue : Color.white.opacity(0.15)))
                                }
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
                .padding(3)
                .background(Capsule().fill(Color.white.opacity(0.08)))
                
                Spacer()
                
                if subMode == .notes {
                    // Quick Action Buttons
                    HStack(spacing: 6) {
                        Button(action: copyAllNotes) {
                            HStack(spacing: 3) {
                                Image(systemName: showCopiedCheck ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 9, weight: .bold))
                                Text(showCopiedCheck ? LanguageManager.tr("Copied!") : LanguageManager.tr("Copy All"))
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(showCopiedCheck ? .green : .white.opacity(0.75))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: exportToAppleNotes) {
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.75))
                                .padding(5)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(LanguageManager.tr("Export to Notes"))
                        
                        if !scratchpadText.isEmpty {
                            Button(action: {
                                withAnimation { scratchpadText = "" }
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.red.opacity(0.8))
                                    .padding(5)
                                    .background(Circle().fill(Color.white.opacity(0.08)))
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help(LanguageManager.tr("Clear"))
                        }
                    }
                } else {
                    if completedCount > 0 {
                        Button(action: clearCompletedTasks) {
                            HStack(spacing: 3) {
                                Image(systemName: "trash")
                                    .font(.system(size: 9))
                                Text(LanguageManager.tr("Clear Completed"))
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .frame(width: 336)
            
            // Content Body
            if subMode == .notes {
                notesView
                    .frame(width: 336)
            } else {
                todoView
                    .frame(width: 336)
            }
        }
        .onAppear {
            loadTasks()
        }
    }
    
    private var notesView: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topLeading) {
                if scratchpadText.isEmpty {
                    Text(LanguageManager.tr("Type notes or paste snippets..."))
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.7))
                        .padding(.top, 8)
                        .padding(.leading, 6)
                }
                
                TextEditor(text: $scratchpadText)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white)
                    .lineSpacing(3)
                    .padding(4)
                    .background(Color.clear)
            }
            .frame(height: 155)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
            )
            
            // Footer Counter
            HStack {
                Text("\(scratchpadText.count) " + LanguageManager.tr("Characters") + " • \(wordCount) " + LanguageManager.tr("Words"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal, 4)
        }
    }
    
    private var todoView: some View {
        VStack(spacing: 6) {
            // Add Task Field
            HStack(spacing: 6) {
                Image(systemName: "circle")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                TextField(LanguageManager.tr("Add a task..."), text: $newTaskTitle)
                    .font(.system(size: 12))
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .onSubmit(addTask)
                
                if !newTaskTitle.isEmpty {
                    Button(action: addTask) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 0.5))
            )
            
            // Task List
            if todoTasks.isEmpty {
                VStack(spacing: 4) {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.gray.opacity(0.5))
                    Text(LanguageManager.tr("No tasks yet"))
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(height: 130)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(todoTasks) { task in
                            TodoRowView(task: task, onToggle: {
                                toggleTask(task)
                            }, onDelete: {
                                deleteTask(task)
                            })
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 130)
            }
            
            // Progress Footer
            HStack {
                Text("\(completedCount)/\(todoTasks.count) " + LanguageManager.tr("completed"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal, 4)
        }
    }
    
    private func addTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            todoTasks.insert(TodoTask(title: trimmed), at: 0)
            newTaskTitle = ""
            saveTasks()
        }
    }
    
    private func toggleTask(_ task: TodoTask) {
        guard let idx = todoTasks.firstIndex(where: { $0.id == task.id }) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            todoTasks[idx].isDone.toggle()
            saveTasks()
        }
    }
    
    private func deleteTask(_ task: TodoTask) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            todoTasks.removeAll { $0.id == task.id }
            saveTasks()
        }
    }
    
    private func clearCompletedTasks() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            todoTasks.removeAll { $0.isDone }
            saveTasks()
        }
    }
    
    private func saveTasks() {
        if let data = try? JSONEncoder().encode(todoTasks), let str = String(data: data, encoding: .utf8) {
            todoTasksJSON = str
        }
    }
    
    private func loadTasks() {
        if let data = todoTasksJSON.data(using: .utf8), let list = try? JSONDecoder().decode([TodoTask].self, from: data) {
            todoTasks = list
        }
    }
    
    private func copyAllNotes() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(scratchpadText, forType: .string)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showCopiedCheck = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.2)) {
                showCopiedCheck = false
            }
        }
    }
    
    private func exportToAppleNotes() {
        let escaped = scratchpadText
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "<br>")
        let script = """
        tell application "Notes"
            tell default account
                make new note with properties {body:"\(escaped)"}
            end tell
            activate
        end tell
        """
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
        }
    }
}

struct TodoRowView: View {
    let task: TodoTask
    let onToggle: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(task.isDone ? .green : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(task.title)
                .font(.system(size: 11, weight: task.isDone ? .regular : .medium))
                .strikethrough(task.isDone, color: .gray)
                .foregroundColor(task.isDone ? .gray.opacity(0.7) : .white)
                .lineLimit(2)
            
            Spacer()
            
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.white.opacity(0.06) : Color.white.opacity(0.02))
        )
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = h
            }
        }
    }
}

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

class NetworkSpeedManager: ObservableObject {
    static let shared = NetworkSpeedManager()
    
    @Published var downloadSpeed: Double = 0.0
    @Published var uploadSpeed: Double = 0.0
    @Published var downloadHistory: [CGFloat] = Array(repeating: 0, count: 16)
    @Published var uploadHistory: [CGFloat] = Array(repeating: 0, count: 16)
    
    @Published var wifiSSID: String = "Wi-Fi"
    @Published var signalBars: Int = 3
    @Published var frequencyBand: String = "5 GHz"
    @Published var pingMs: Int = 24
    @Published var localIP: String = "127.0.0.1"
    @Published var publicIP: String = "..."
    @Published var isFetchingPublicIP: Bool = false
    
    var signalIcon: String {
        switch signalBars {
        case 1: return "wifi.exclamationmark"
        case 2: return "wifi"
        case 3: return "wifi"
        default: return "wifi"
        }
    }
    
    var pingColor: Color {
        if pingMs <= 50 { return .green }
        if pingMs <= 120 { return .yellow }
        return .red
    }
    
    private var timer: Timer?
    private var prevInBytes: UInt64 = 0
    private var prevOutBytes: UInt64 = 0
    private var lastSampleTime: Date = Date()
    
    private init() {
        refreshIPs()
        checkWiFi()
        testPing()
    }
    
    func startMonitoring() {
        stopMonitoring()
        sampleBytes()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        refreshIPs()
        checkWiFi()
        testPing()
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func tick() {
        let (inBytes, outBytes) = getNetworkBytes()
        let now = Date()
        let interval = max(now.timeIntervalSince(lastSampleTime), 0.5)
        lastSampleTime = now
        
        if prevInBytes > 0 && inBytes >= prevInBytes {
            let dBytes = inBytes - prevInBytes
            let speed = Double(dBytes) / interval
            DispatchQueue.main.async {
                self.downloadSpeed = speed
                self.downloadHistory.removeFirst()
                self.downloadHistory.append(CGFloat(speed))
            }
        }
        if prevOutBytes > 0 && outBytes >= prevOutBytes {
            let uBytes = outBytes - prevOutBytes
            let speed = Double(uBytes) / interval
            DispatchQueue.main.async {
                self.uploadSpeed = speed
                self.uploadHistory.removeFirst()
                self.uploadHistory.append(CGFloat(speed))
            }
        }
        prevInBytes = inBytes
        prevOutBytes = outBytes
        
        if Int(Date().timeIntervalSince1970) % 5 == 0 {
            checkWiFi()
            testPing()
        }
    }
    
    private func sampleBytes() {
        let (inBytes, outBytes) = getNetworkBytes()
        prevInBytes = inBytes
        prevOutBytes = outBytes
        lastSampleTime = Date()
    }
    
    private func getNetworkBytes() -> (UInt64, UInt64) {
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let first = ifap else { return (0, 0) }
        defer { freeifaddrs(ifap) }
        
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = ptr.pointee
            let name = String(cString: ifa.ifa_name)
            guard !name.hasPrefix("lo"), (name.hasPrefix("en") || name.hasPrefix("bridge") || name.hasPrefix("pdp_ip")) else { continue }
            
            if ifa.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                if let data = ifa.ifa_data {
                    let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                    totalIn += UInt64(networkData.ifi_ibytes)
                    totalOut += UInt64(networkData.ifi_obytes)
                }
            }
        }
        return (totalIn, totalOut)
    }
    
    func checkWiFi() {
        if let client = CWWiFiClient.shared().interface() {
            let ssid = client.ssid() ?? "Wi-Fi Connected"
            let rssi = client.rssiValue()
            let band = client.wlanChannel()?.channelBand == .band2GHz ? "2.4 GHz" : (client.wlanChannel()?.channelBand == .band5GHz ? "5 GHz" : "Wi-Fi")
            
            var bars = 3
            if rssi < -80 { bars = 1 }
            else if rssi < -70 { bars = 2 }
            else if rssi < -55 { bars = 3 }
            else { bars = 4 }
            
            DispatchQueue.main.async {
                self.wifiSSID = ssid
                self.signalBars = bars
                self.frequencyBand = band
            }
        } else {
            DispatchQueue.main.async {
                self.wifiSSID = "Network Active"
                self.signalBars = 4
                self.frequencyBand = "LAN"
            }
        }
    }
    
    func refreshIPs() {
        var localAddress = "127.0.0.1"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)
                    if name.hasPrefix("en") {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                    &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST)
                        localAddress = String(cString: hostname)
                        break
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        DispatchQueue.main.async {
            self.localIP = localAddress
        }
        
        guard !isFetchingPublicIP else { return }
        isFetchingPublicIP = true
        guard let url = URL(string: "https://api.ipify.org") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.isFetchingPublicIP = false
                if let data = data, let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !ip.isEmpty {
                    self?.publicIP = ip
                } else if self?.publicIP == "..." {
                    self?.publicIP = "Unavailable"
                }
            }
        }.resume()
    }
    
    func testPing() {
        guard let url = URL(string: "https://1.1.1.1") else { return }
        let start = Date()
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 2.0
        
        URLSession.shared.dataTask(with: request) { [weak self] _, _, _ in
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            DispatchQueue.main.async {
                self?.pingMs = max(ms, 8)
            }
        }.resume()
    }
    
    static func formatSpeed(_ bytesPerSec: Double) -> (value: String, unit: String) {
        if bytesPerSec >= 1_048_576 {
            return (String(format: "%.1f", bytesPerSec / 1_048_576), "MB/s")
        } else if bytesPerSec >= 1024 {
            return (String(format: "%.0f", bytesPerSec / 1024), "KB/s")
        } else {
            return (String(format: "%.0f", bytesPerSec), "B/s")
        }
    }
}

enum NetworkSubMode: String, CaseIterable {
    case radar = "Radar"
    case speedtest = "Speed Test"
    
    var localizedTitle: String {
        switch self {
        case .radar: return LanguageManager.tr("Radar")
        case .speedtest: return LanguageManager.tr("Speed Test")
        }
    }
}

enum SpeedTestPhase: Equatable {
    case idle
    case pinging
    case downloading
    case uploading
    case completed
    case failed
}

class SpeedTestManager: NSObject, ObservableObject, URLSessionDataDelegate, URLSessionTaskDelegate {
    static let shared = SpeedTestManager()
    
    @Published var phase: SpeedTestPhase = .idle
    @Published var liveSpeedMbps: Double = 0.0
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = ""
    
    @Published var pingResultMs: Int = 0
    @Published var downloadResultMbps: Double = 0.0
    @Published var uploadResultMbps: Double = 0.0
    
    // Historical results saved in UserDefaults
    @Published var lastDownload: Double = UserDefaults.standard.double(forKey: "lastSpeedTestDown")
    @Published var lastUpload: Double = UserDefaults.standard.double(forKey: "lastSpeedTestUp")
    @Published var lastPing: Int = UserDefaults.standard.integer(forKey: "lastSpeedTestPing")
    @Published var lastTimestamp: Double = UserDefaults.standard.double(forKey: "lastSpeedTestTime")
    
    private var activeSession: URLSession?
    private var currentTask: URLSessionTask?
    
    private var phaseStartTime: Date = Date()
    private var bytesTransferred: Int64 = 0
    private var expectedTotalBytes: Int64 = 6_000_000
    private var isCancelled: Bool = false
    
    override init() {
        super.init()
    }
    
    func startTest() {
        guard phase == .idle || phase == .completed || phase == .failed else { return }
        isCancelled = false
        phase = .pinging
        liveSpeedMbps = 0.0
        progress = 0.0
        statusMessage = LanguageManager.tr("Testing Ping...")
        
        runPingMeasurement { [weak self] avgPing in
            guard let self = self, !self.isCancelled else { return }
            self.pingResultMs = avgPing
            self.startDownloadTest()
        }
    }
    
    func cancelTest() {
        isCancelled = true
        currentTask?.cancel()
        currentTask = nil
        activeSession?.invalidateAndCancel()
        activeSession = nil
        phase = .idle
        liveSpeedMbps = 0.0
        progress = 0.0
        statusMessage = ""
    }
    
    private func runPingMeasurement(completion: @escaping (Int) -> Void) {
        var samples: [Int] = []
        let group = DispatchGroup()
        
        for i in 0..<3 {
            group.enter()
            DispatchQueue.global().asyncAfter(deadline: .now() + Double(i) * 0.15) { [weak self] in
                guard let self = self, !self.isCancelled else {
                    group.leave()
                    return
                }
                guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=0") else {
                    group.leave()
                    return
                }
                var req = URLRequest(url: url)
                req.httpMethod = "HEAD"
                req.timeoutInterval = 3.0
                
                let start = Date()
                let task = URLSession.shared.dataTask(with: req) { _, _, _ in
                    let ms = Int(Date().timeIntervalSince(start) * 1000)
                    if ms > 0 { samples.append(ms) }
                    group.leave()
                }
                task.resume()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self, !self.isCancelled else { return }
            let avg = samples.isEmpty ? 22 : (samples.reduce(0, +) / samples.count)
            completion(avg)
        }
    }
    
    private func startDownloadTest() {
        phase = .downloading
        statusMessage = LanguageManager.tr("Testing Download...")
        bytesTransferred = 0
        expectedTotalBytes = 6_000_000 // 6 MB
        phaseStartTime = Date()
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10.0
        activeSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=\(expectedTotalBytes)") else {
            failTest(reason: "Invalid URL")
            return
        }
        
        let task = activeSession?.dataTask(with: url)
        currentTask = task
        task?.resume()
    }
    
    private func startUploadTest() {
        phase = .uploading
        statusMessage = LanguageManager.tr("Testing Upload...")
        bytesTransferred = 0
        expectedTotalBytes = 2_500_000 // 2.5 MB
        phaseStartTime = Date()
        
        let dummyData = Data(count: Int(expectedTotalBytes))
        guard let url = URL(string: "https://speed.cloudflare.com/__up") else {
            failTest(reason: "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10.0
        
        let task = activeSession?.uploadTask(with: request, from: dummyData)
        currentTask = task
        task?.resume()
    }
    
    // MARK: - URLSessionDataDelegate
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard phase == .downloading, !isCancelled else { return }
        bytesTransferred += Int64(data.count)
        let elapsed = max(Date().timeIntervalSince(phaseStartTime), 0.05)
        let mbps = (Double(bytesTransferred) * 8.0) / (elapsed * 1_000_000.0)
        
        DispatchQueue.main.async {
            self.liveSpeedMbps = mbps
            self.progress = min(Double(self.bytesTransferred) / Double(self.expectedTotalBytes), 0.95)
        }
    }
    
    // MARK: - URLSessionTaskDelegate
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard phase == .uploading, !isCancelled else { return }
        bytesTransferred = totalBytesSent
        let elapsed = max(Date().timeIntervalSince(phaseStartTime), 0.05)
        let mbps = (Double(totalBytesSent) * 8.0) / (elapsed * 1_000_000.0)
        
        DispatchQueue.main.async {
            self.liveSpeedMbps = mbps
            self.progress = min(Double(totalBytesSent) / Double(totalBytesExpectedToSend), 0.95)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !isCancelled else { return }
        
        if let error = error {
            if (error as NSError).code == NSURLErrorCancelled { return }
            DispatchQueue.main.async {
                self.failTest(reason: error.localizedDescription)
            }
            return
        }
        
        DispatchQueue.main.async {
            let elapsed = max(Date().timeIntervalSince(self.phaseStartTime), 0.05)
            if self.phase == .downloading {
                let finalMbps = (Double(self.bytesTransferred) * 8.0) / (elapsed * 1_000_000.0)
                self.downloadResultMbps = max(finalMbps, 0.1)
                self.progress = 1.0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    guard !self.isCancelled else { return }
                    self.startUploadTest()
                }
            } else if self.phase == .uploading {
                let finalMbps = (Double(self.bytesTransferred) * 8.0) / (elapsed * 1_000_000.0)
                self.uploadResultMbps = max(finalMbps, 0.1)
                self.progress = 1.0
                self.completeTest()
            }
        }
    }
    
    private func completeTest() {
        phase = .completed
        statusMessage = LanguageManager.tr("Test Completed")
        liveSpeedMbps = 0.0
        
        lastDownload = downloadResultMbps
        lastUpload = uploadResultMbps
        lastPing = pingResultMs
        lastTimestamp = Date().timeIntervalSince1970
        
        UserDefaults.standard.set(lastDownload, forKey: "lastSpeedTestDown")
        UserDefaults.standard.set(lastUpload, forKey: "lastSpeedTestUp")
        UserDefaults.standard.set(lastPing, forKey: "lastSpeedTestPing")
        UserDefaults.standard.set(lastTimestamp, forKey: "lastSpeedTestTime")
    }
    
    private func failTest(reason: String) {
        phase = .failed
        statusMessage = LanguageManager.tr("Test Failed")
        liveSpeedMbps = 0.0
        progress = 0.0
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

struct LanguageManager {
    static let translationsToId: [String: String] = [
        "General": "Umum",
        "Drop Zone": "Zona Lepas",
        "Drag files here to store temporarily.": "Seret file ke sini untuk disimpan sementara.",
        "Focus Timer": "Timer Fokus",
        "Stop": "Berhenti",
        "Recent Clipboard": "Clipboard Terbaru",
        "No recent items": "Tidak ada item terbaru",
        "Event title...": "Judul acara...",
        "Color:": "Warna:",
        "No schedule 🎉": "Tidak ada jadwal 🎉",
        "No upcoming schedule": "Tidak ada jadwal berikutnya",
        "Next:": "Berikutnya:",
        "left": "lagi",
        "In progress": "Sedang berlangsung",
        "Media (Music)": "Media (Musik)",
        "Calculator": "Kalkulator",
        "Weather": "Cuaca",
        "Agenda & Events": "Agenda & Jadwal",
        "Menu & Features": "Menu & Fitur",
        "Appearance": "Personalisasi",
        "Settings...": "Pengaturan...",
        "Quit Notchify": "Keluar Notchify",
        "Language": "Bahasa",
        "How to Open Notch": "Cara Membuka Notch",
        "Hover cursor": "Sentuh kursor (Hover)",
        "Click directly": "Klik langsung (Click)",
        "Auto-Close Speed": "Kecepatan Menutup Otomatis",
        "Fast (0.1s)": "Kilat (0.1 detik)",
        "Standard (0.5s)": "Standar (0.5 detik)",
        "Slow (1.5s)": "Lambat (1.5 detik)",
        "Keyboard Shortcut": "Pintasan Keyboard (Shortcut)",
        "Press Cmd + Shift + N from anywhere to toggle Notchify.": "Tekan Cmd + Shift + N dari mana saja untuk memanggil atau menyembunyikan Notch.",
        "Accessibility Granted": "Izin Aksesibilitas Aktif",
        "Accessibility Required": "Butuh Izin Aksesibilitas",
        "Grant Access": "Beri Izin",
        "Drag & Drop to reorder. Uncheck to hide.": "Geser (Drag & Drop) untuk mengatur urutan. Hilangkan centang untuk menyembunyikan.",
        "Visual Effects": "Efek Visual",
        "Use Glow effect behind Notch": "Gunakan efek cahaya (Glow) di belakang Notch",
        "Disabling this saves CPU/GPU on older Macs.": "Mematikan fitur ini dapat menghemat penggunaan CPU/GPU pada Mac yang lebih tua.",
        "Glass Transparency Level": "Tingkat Transparansi Kaca",
        "TIME'S UP!": "WAKTU HABIS!",
        "DROP FILE HERE": "LEPAS FILE DI SINI",
        "Drop to Absorb": "Lepas untuk Menyerap",
        "Temporary Shelf": "Rak Berkas Sementara",
        "File Stashed!": "File Tersimpan!",
        "Files Stashed!": "File Tersimpan!",
        "Camera in use": "Kamera sedang aktif",
        "Microphone in use": "Mikrofon sedang aktif",
        "Toggle Camera Indicator": "Uji Indikator Kamera",
        "Toggle Mic Indicator": "Uji Indikator Mikrofon",
        "Copied to Clipboard": "Disalin ke Clipboard",
        "Cut to Clipboard": "Terpotong",
        "File Copied": "File Tersalin",
        "Image Copied": "Gambar Tersalin",
        "Text Copied": "Teks Tersalin",
        "Connected": "Terhubung",
        "Disconnected": "Terputus",
        "Feels like": "Terasa seperti",
        "Humidity": "Kelembaban",
        "Wind": "Angin",
        "System Monitor": "Pemantau Sistem",
        "Agenda": "Agenda",
        "Add New Event": "Tambah Acara Baru",
        "Title:": "Judul:",
        "Time:": "Waktu:",
        "Date:": "Tanggal:",
        "Yearly (Birthday/Anniversary)": "Tiap Tahun (Ulang Tahun/Peringatan)",
        "Cancel": "Batal",
        "Save": "Simpan",
        "Today": "Hari ini",
        "Tomorrow": "Besok",
        "Upcoming": "Mendatang",
        "No music playing": "Tidak ada musik dimainkan",
        "Clipboard is Empty": "Papan Klip Kosong",
        "Copied text and snippets will appear here": "Teks dan potongan yang disalin akan muncul di sini",
        "Clear All": "Bersihkan Semua",
        "Clear": "Bersihkan",
        "Copied!": "Tersalin!",
        "Drop Files Here": "Lepas File di Sini",
        "Quick shelf to drag & drop files anywhere": "Penyimpanan cepat untuk seret & lepas file ke mana saja",
        "Focus Session": "Sesi Fokus",
        "Start Focus": "Mulai Fokus",
        "Start Break": "Mulai Jeda",
        "Start Rest": "Mulai Santai",
        "Start Timer": "Mulai Timer",
        "Custom": "Kustom",
        "Custom Timer": "Timer Kustom",
        "Decrease (Right click for -5m)": "Kurang (Klik kanan untuk -5 mnt)",
        "Increase (Right click for +5m)": "Tambah (Klik kanan untuk +5 mnt)",
        "Pause": "Jeda",
        "Resume": "Lanjut",
        "min": "mnt",
        "Focus": "Fokus",
        "Break": "Istirahat",
        "Rest": "Santai",
        "Remove": "Hapus",
        "Media & Lyrics": "Media & Lirik",
        "Search & display music lyrics": "Cari & tampilkan lirik musik",
        "Fetch synchronized lyrics online when playing music.": "Ambil lirik tersinkronisasi online saat memutar musik.",
        "Preferred Music Source": "Sumber Musik Utama",
        "Preferred player to display and control when multiple music sources are active.": "Pilihan pemutar untuk ditampilkan dan dikontrol saat beberapa sumber musik aktif.",
        "Auto (Detect Any Active App)": "Otomatis (Deteksi Aplikasi Aktif)",
        "Spotify Desktop": "Spotify Desktop",
        "Apple Music": "Apple Music",
        "Browser Web (YouTube Music)": "Browser Web (YouTube Music)",
        "Open in": "Buka di",
        "Media Player": "Pemutar Media",
        "Search clipboard...": "Cari clipboard...",
        "No matching items": "Tidak ada item yang cocok",
        "Pin to top": "Sematkan ke atas",
        "Unpin": "Lepas sematan",
        "Open in browser": "Buka di browser",
        "Share or AirDrop": "Bagikan atau AirDrop",
        "Share All": "Bagikan Semua",
        "Share": "Bagikan",
        "Open file": "Buka file",
        "Delete last digit": "Hapus angka terakhir",
        "Copy result": "Salin hasil",
        "Click to copy": "Klik untuk menyalin",
        "Focus Timer: Click to open": "Timer Fokus: Klik untuk membuka",
        "Charging": "Mengisi Daya",
        "Fully Charged": "Daya Penuh",
        "On Battery": "Daya Baterai",
        "Battery": "Baterai",
        "Battery Level": "Tingkat Baterai",
        "Test Charging Animation": "Uji Animasi Pengisian Daya",
        "Mirror": "Cermin",
        "Ring Light": "Lampu Ring",
        "Cool": "Sejuk",
        "Neutral": "Netral",
        "Warm": "Hangat",
        "Mirrored": "Tampilan Cermin",
        "Audience View": "Tampilan Nyata",
        "Freeze": "Bekukan",
        "Preview Paused": "Pratinjau Dijeda",
        "Virtual Ring Light: Illuminate face": "Lampu Ring Virtual: Terangi wajah",
        "Toggle between real mirror and what others see": "Ganti antara cermin dan tampilan orang lain",
        "Freeze frame to check details": "Bekukan gambar untuk memeriksa detail",
        "Camera Access Needed": "Izin Kamera Diperlukan",
        "Notchify needs camera access to show your quick webcam mirror preview.": "Notchify memerlukan izin kamera untuk menampilkan pratinjau cermin webcam cepat.",
        "Open System Settings": "Buka Pengaturan Sistem",
        "Camera": "Kamera",
        "Camera & Photos": "Kamera & Foto",
        "Photo Storage Location": "Lokasi Simpan Foto",
        "Default Folder": "Folder Bawaan",
        "Custom Folder": "Folder Kustom",
        "Choose Folder...": "Pilih Folder...",
        "No folder selected": "Belum ada folder dipilih",
        "Open Folder in Finder": "Buka Folder di Finder",
        "Shutter Feedback": "Umpan Balik Jepretan",
        "Play Shutter Sound": "Bunyikan Suara Rana",
        "Select": "Pilih",
        "Off": "Mati",
        "Take Photo": "Ambil Foto",
        "Saved!": "Tersimpan!",
        "Show latest photo in Finder": "Tampilkan foto terakhir di Finder",
        "Open Photos Folder": "Buka Folder Foto",
        "Timer: 3 seconds delay": "Timer: jeda 3 detik",
        "Mirrored (Click for True View)": "Cermin (Klik untuk Tampilan Nyata)",
        "True View (Click for Mirrored)": "Tampilan Nyata (Klik untuk Cermin)",
        "View latest photo": "Lihat foto terakhir",
        "Back to Camera": "Kembali ke Kamera",
        "Copy Image": "Salin Gambar",
        "Open Folder": "Buka Folder",
        "Image Copied to Clipboard": "Gambar Disalin ke Clipboard",
        "No Photo": "Tidak Ada Foto",
        "Photo": "Foto",
        "Video": "Video",
        "Stop Recording": "Berhenti Merekam",
        "Record Video": "Rekam Video",
        "Copy Video": "Salin Video",
        "Video Copied to Clipboard": "File Video Disalin ke Clipboard",
        "Copy video to clipboard": "Salin file video ke clipboard",
        "Microphone Muted": "Mikrofon Dimatikan",
        "Microphone Active": "Mikrofon Aktif",
        "Duration Template": "Template Durasi",
        "Video Saved!": "Video Tersimpan!",
        "View latest media": "Lihat media terakhir",
        "No Media": "Tidak Ada Media",
        "REC": "REC",
        "Smart Dynamic Island & Notch for macOS": "Dynamic Island & Notch Pintar untuk macOS",
        "Welcome to Notchify": "Selamat Datang di Notchify",
        "Transform your MacBook Notch into a powerful Dynamic Island": "Ubah Notch MacBook Anda menjadi Dynamic Island yang cerdas & bertenaga",
        "Continue": "Lanjutkan",
        "Back": "Kembali",
        "Essential Permissions": "Izin Sistem Penting",
        "Notchify needs a few permissions to provide seamless controls. You can grant them now or later in Settings.": "Notchify membutuhkan beberapa izin agar semua fitur berjalan mulus. Anda bisa mengizinkannya sekarang atau nanti di Pengaturan.",
        "Accessibility Access": "Akses Aksesibilitas",
        "Required for global shortcut (Cmd+Shift+N) and Notch interaction": "Diperlukan untuk pintasan keyboard (Cmd+Shift+N) dan interaksi Notch",
        "Camera & Microphone": "Kamera & Mikrofon",
        "For quick webcam mirror, photo snapshots, and video clips": "Untuk cermin webcam kilat, snapshot foto, dan rekaman klip video",
        "Music Automation": "Otomatisasi Musik",
        "To display current song and control Spotify & Apple Music": "Untuk menampilkan lagu yang sedang diputar dan mengontrol Spotify & Apple Music",
        "Granted": "Diizinkan",
        "Grant": "Izinkan",
        "Configure": "Atur",
        "Personalize Controls": "Personalisasi Kontrol",
        "Choose how you'd like to interact with Notchify.": "Pilih bagaimana Anda ingin berinteraksi dengan Notchify.",
        "Hover to Expand": "Arahkan Kursor (Hover)",
        "Move your cursor near the Notch to smoothly expand": "Gerakkan kursor mendekati Notch untuk membuka",
        "Click to Expand": "Klik Langsung (Click)",
        "Only expands when you click or tap on the Notch": "Hanya terbuka saat Anda mengeklik Notch",
        "Global Shortcut": "Pintasan Global",
        "Press anytime to toggle Notchify from anywhere": "Tekan kapan saja untuk membuka/menutup Notchify dari mana saja",
        "You're All Set!": "Semua Sudah Siap!",
        "Notchify is now ready to assist your daily workflow.": "Notchify kini siap menemani produktivitas harian Anda.",
        "Launch automatically at startup (Launch at Login)": "Buka otomatis saat Mac menyala (Launch at Login)",
        "Start Using Notchify": "Mulai Gunakan Notchify",
        "Show Onboarding Tour": "Tampilkan Panduan Onboarding",
        "Onboarding Tour...": "Panduan Onboarding...",
        "Onboarding Tour": "Panduan Onboarding",
        "Revisit the setup guide and feature overview.": "Buka kembali panduan pengaturan awal dan ringkasan fitur.",
        "Media & Real-time Lyrics": "Pemutar Media & Lirik Real-time",
        "Webcam Mirror & Quick Video": "Webcam Cermin & Video Cepat",
        "Drop Zone File Shelf": "Shelf File & Drop Zone",
        "Smart Clipboard History": "Riwayat Clipboard Cerdas",
        "Control Spotify, Apple Music & Web Player with lyrics": "Kontrol Spotify, Apple Music & Web Player lengkap dengan lirik",
        "Check face, take instant photos & video clips before meetings": "Cek wajah, foto asli & video kilat 5 detik sebelum rapat",
        "Pin important snippets & search clipboard history": "Sematkan teks penting & cari riwayat salinan teks",
        "Clipboard Manager": "Manajer Clipboard",
        "Pomodoro Timer": "Timer Pomodoro",
        "Notchify Features": "Fitur Notchify",
        "Pinned Tabs": "Tab Disematkan",
        "Pinned (Max 6)": "Disematkan (Maks 6)",
        "Pin to bar": "Sematkan ke bilah",
        "Unpin from bar": "Lepas dari bilah",
        "Max 6 tabs reached": "Batas 6 tab tercapai",
        "All Features & Pinning": "Semua Fitur & Penyematan",
        "Previous Tab": "Tab Sebelumnya",
        "Next Tab": "Tab Berikutnya",
        "Scratchpad & Tasks": "Catatan & Tugas",
        "Network Radar": "Pemantau Jaringan",
        "Notes": "Catatan",
        "To-Do": "To-Do",
        "Type notes or paste snippets...": "Ketik catatan atau tempel teks di sini...",
        "Characters": "Karakter",
        "Words": "Kata",
        "Copy All": "Salin Semua",
        "Notes Copied": "Catatan Disalin",
        "Export to Notes": "Ekspor ke Notes",
        "Add a task...": "Tambah tugas baru...",
        "No tasks yet": "Belum ada tugas",
        "completed": "selesai",
        "Clear Completed": "Hapus Selesai",
        "Download": "Unduh",
        "Upload": "Unggah",
        "Local IP": "IP Lokal",
        "Public IP": "IP Publik",
        "Latency": "Latensi",
        "Re-testing network...": "Menguji ulang jaringan...",
        "IP Copied": "IP Disalin",
        "Radar": "Radar",
        "Speed Test": "Uji Kecepatan",
        "Start Speed Test": "Mulai Uji Kecepatan",
        "Testing Ping...": "Mengukur Ping...",
        "Testing Download...": "Menguji Unduh...",
        "Testing Upload...": "Menguji Unggah...",
        "Test Completed": "Uji Selesai",
        "Test Failed": "Gagal Menguji",
        "Test Again": "Uji Ulang",
        "Last Tested": "Tes Terakhir",
        "Ready to Test": "Siap Menguji",
        "Check your current download and upload speeds.": "Uji kecepatan unduh dan unggah jaringan Anda.",
        "Please check your internet connection": "Periksa koneksi internet Anda",
        "Color": "Warna",
        "Copied": "Disalin",
        "Color Copied": "Warna Disalin",
        "Link Copied": "Tautan Disalin",
        "Email Copied": "Email Disalin",
        "Terminal Command Copied": "Perintah Terminal Disalin",
        "Code Snippet Copied": "Kode Disalin",
        "File Path Copied": "Path Direktori Disalin",
        "Phone Number Copied": "Nomor Telepon Disalin",
        "Currency Copied": "Nominal Uang Disalin",
        "words": "kata"
    ]
    
    static func tr(_ key: String) -> String {
        let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        if lang == "id" {
            return translationsToId[key] ?? key
        }
        return key
    }
}
struct PrivacyIndicatorView: View {
    @ObservedObject var privacy = PrivacyMonitor.shared
    @State private var isBlinking = false
    
    var body: some View {
        Button(action: {
            withAnimation {
                privacy.toggleCamera()
            }
        }) {
            ZStack {
                // Background Island
                Capsule()
                    .fill(Color.black)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 2)
                
                // Dot
                Circle()
                    .fill(privacy.isCameraActive ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                    .opacity(isBlinking ? 0.3 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(), value: isBlinking)
                    .onAppear {
                        isBlinking = true
                    }
            }
            .frame(height: 34, alignment: .top) // Align with compact height
            .padding(.top, 0)
        }
        .buttonStyle(PlainButtonStyle())
        .help(privacy.isCameraActive ? LanguageManager.tr("Camera in use") : LanguageManager.tr("Microphone in use"))
        .contextMenu {
            Button(LanguageManager.tr("Toggle Camera Indicator")) {
                withAnimation { privacy.toggleCamera() }
            }
            Button(LanguageManager.tr("Toggle Mic Indicator")) {
                withAnimation { privacy.toggleMic() }
            }
        }
    }
}

class PrivacyMonitor: ObservableObject {
    @Published var isCameraActive: Bool = false
    @Published var isMicActive: Bool = false
    
    static let shared = PrivacyMonitor()
    func toggleCamera() { isCameraActive.toggle() }
    func toggleMic() {   isMicActive.toggle() }
}
