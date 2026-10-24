import SwiftUI
import AppKit
import Combine

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
    
    // Mascot Companion Living States
    @Published var mascotNewTrackCelebration: Bool = false
    @Published var isDeepIdle: Bool = false
    @Published var mascotWakeUpTrigger: Bool = false
    @Published var cursorNormalizedOffset: CGSize = .zero
    var lastUserActivityDate: Date = Date()
    
    func notifyUserActivity() {
        if isDeepIdle {
            isDeepIdle = false
            mascotWakeUpTrigger = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.mascotWakeUpTrigger = false
            }
        }
        lastUserActivityDate = Date()
    }
    
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
    @Published var showMediaLyrics: Bool = false
    @Published var isFetchingLyrics: Bool = false
    
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
    @Published var upcomingMeetingEvent: CustomEvent? = nil
    @Published var dismissedMeetingIds: Set<UUID> = []
    
    func dismissMeetingAlert(id: UUID) {
        dismissedMeetingIds.insert(id)
        if upcomingMeetingEvent?.id == id {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                upcomingMeetingEvent = nil
            }
        }
    }
    
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
        
        // Smart fallback interval (1.5s) while instant checks are triggered via Cmd+C / Cmd+X
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 1.5,
                                              repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            if event.keyCode == 7 { // 'x'
                lastActionWasCut = true
                lastActionTime = Date()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                    self?.checkClipboard()
                }
            } else if event.keyCode == 8 { // 'c'
                lastActionWasCut = false
                lastActionTime = Date()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                    self?.checkClipboard()
                }
            }
        }
    }
    
    func startMediaPolling() {
        fetchMedia()
        mediaTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.fetchMedia()
        }
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isPlaying && self.duration > 0 {
                self.elapsed = min(self.elapsed + 0.5, self.duration)
                if UserDefaults.standard.bool(forKey: "enableLyrics") && !self.lyrics.isEmpty {
                    self.updateLyricIndex()
                }
            }
        }
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if Date().timeIntervalSince(self.lastUserActivityDate) > 45.0 && !self.isPlaying && !self.isPomodoroActive && !self.isExpanded {
                if !self.isDeepIdle {
                    self.isDeepIdle = true
                }
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
                    let oldSong = self.currentSong
                    self.currentSong = title
                    self.currentArtist = artist ?? ""
                    
                    if !oldSong.isEmpty && oldSong != "No Media Playing" {
                        self.mascotNewTrackCelebration = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                            self.mascotNewTrackCelebration = false
                        }
                    }
                    
                    // Fetch new lyrics only if enabled or user opened lyrics
                    self.lyrics = []
                    self.currentLyricIndex = -1
                    if UserDefaults.standard.bool(forKey: "enableLyrics") || self.showMediaLyrics {
                        self.isFetchingLyrics = true
                        LyricsManager.shared.fetchLyrics(for: title, artist: artist ?? "") { [weak self] newLyrics in
                            self?.isFetchingLyrics = false
                            self?.lyrics = newLyrics
                        }
                    }
                }
                
                // Only update artwork and re-extract glow color if artwork instance changed
                if self.artwork !== img {
                    self.artwork = img
                    
                    if let artImg = img {
                        DispatchQueue.global(qos: .userInitiated).async {
                            let color = Self.extractDominantColor(from: artImg)
                            DispatchQueue.main.async {
                                if self.accentColor != color {
                                    self.accentColor = color
                                }
                            }
                        }
                    } else {
                        self.accentColor = .clear
                    }
                }
                self.isPlaying = isPlaying
                
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
                if self.artwork != nil {
                    self.artwork = nil
                    self.accentColor = .clear
                }
                self.isPlaying = false
                self.duration = 0
                self.elapsed = 0
                if !self.showClock {
                    self.showClock = true
                }
            }
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
    
    private var agendaTickCount = 0
    func startAgendaPolling() {
        // Poll every 1 second for real-time meeting countdown and every 10 seconds for general agenda notifications
        agendaTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.checkUpcomingMeeting()
            self.agendaTickCount += 1
            if self.agendaTickCount % 10 == 0 {
                self.checkUpcomingEvents()
            }
        }
    }
    
    func fetchAgenda() {
        self.agendaEvents = CustomAgendaManager.shared.fetchEvents(forDateOffset: self.agendaDateOffset)
    }
    
    func checkUpcomingMeeting() {
        let events = CustomAgendaManager.shared.fetchEvents(forDateOffset: 0)
        let now = Date()
        
        let meeting = events.first { event in
            guard event.hasMeetingLink, !self.dismissedMeetingIds.contains(event.id) else { return false }
            let diff = event.date.timeIntervalSince(now)
            // Active from 2 minutes before (120s) up to 10 minutes past start (-600s)
            return diff <= 120 && diff >= -600
        }
        
        DispatchQueue.main.async {
            if let meeting = meeting {
                if self.upcomingMeetingEvent?.id != meeting.id {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                        self.upcomingMeetingEvent = meeting
                    }
                } else {
                    self.upcomingMeetingEvent = meeting
                }
            } else {
                if self.upcomingMeetingEvent != nil {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        self.upcomingMeetingEvent = nil
                    }
                }
            }
        }
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
    
    func toggleMediaLyrics() {
        withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.76)) {
            showMediaLyrics.toggle()
        }
        if showMediaLyrics && lyrics.isEmpty && !currentSong.isEmpty {
            fetchLyricsNow()
        }
    }
    
    func fetchLyricsNow() {
        guard !currentSong.isEmpty else { return }
        isFetchingLyrics = true
        LyricsManager.shared.fetchLyrics(for: currentSong, artist: currentArtist) { [weak self] newLyrics in
            self?.isFetchingLyrics = false
            self?.lyrics = newLyrics
        }
    }
    
    static func extractDominantColor(from image: NSImage) -> Color {
        var cgImage: CGImage? = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        if cgImage == nil, let tiffData = image.tiffRepresentation, let source = CGImageSourceCreateWithData(tiffData as CFData, nil) {
            cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
        guard let sourceImage = cgImage else { return .clear }
        
        let size = 16
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData = [UInt8](repeating: 0, count: size * size * 4)
        guard let context = CGContext(
            data: &pixelData,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return .clear }
        
        context.interpolationQuality = .low
        context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: size, height: size))
        
        var totalR: CGFloat = 0, totalG: CGFloat = 0, totalB: CGFloat = 0
        let count = size * size
        
        for i in 0..<count {
            let offset = i * 4
            totalR += CGFloat(pixelData[offset])
            totalG += CGFloat(pixelData[offset + 1])
            totalB += CGFloat(pixelData[offset + 2])
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
