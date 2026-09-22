import SwiftUI
import AppKit

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
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .media: return LanguageManager.tr("Media (Music)")
        case .clipboard: return "Clipboard Manager"
        case .dropzone: return "Dropzone"
        case .pomodoro: return "Pomodoro Timer"
        case .calculator: return LanguageManager.tr("Calculator")
        case .weather: return LanguageManager.tr("Weather")
        case .system: return LanguageManager.tr("System Monitor")
        case .agenda: return LanguageManager.tr("Agenda & Events")
        }
    }
}

// MARK: - Notch ViewModel
class NotchViewModel: ObservableObject {
    @Published var isExpanded: Bool = false
    @Published var isPinningExpansion: Bool = false
    @Published var clipboardItems: [String] = []
    
    // Media States
    @Published var currentSong: String = "No Media Playing"
    @Published var currentArtist: String = ""
    @Published var artwork: NSImage? = nil
    @Published var isPlaying: Bool = false
    @Published var showClock: Bool = true
    
    @Published var duration: Double = 0.0
    var elapsed: Double = 0.0
    
    // DropZone States
    @Published var stagedFiles: [URL] = []
    @Published var isHoveringWithFile: Bool = false
    
    // Pomodoro States
    @Published var isPomodoroActive: Bool = false
    @Published var pomodoroRemaining: TimeInterval = 0
    @Published var pomodoroTotal: TimeInterval = 0
    @Published var showTimesUp: Bool = false
    private var pomodoroTimer: Timer?
    
    // Calculator State
    @Published var calcInput: String = "0"
    @Published var calcPrevious: Double? = nil
    @Published var calcOperator: String? = nil
    
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
        showTimesUp = false
        
        pomodoroTimer?.invalidate()
        pomodoroTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.pomodoroRemaining > 0 {
                self.pomodoroRemaining -= 1
            } else {
                self.stopPomodoro()
                self.showTimesUp = true
                
                // Trigger times up notification
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    self.showTimesUp = false
                }
            }
        }
    }
    
    func stopPomodoro() {
        isPomodoroActive = false
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
    }
    
    func triggerVolumeHUD(volume: Float) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            self.currentVolume = volume
            self.showVolumeHUD = true
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
            self.showVolumeHUD = false
            self.showTimesUp = false
        }
        scheduleHUDDismiss()
    }
    
    private func scheduleHUDDismiss() {
        hudDismissTimer?.invalidate()
        hudDismissTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
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
        MediaRemoteHelper.shared.fetchNowPlaying { [weak self] title, artist, img, isPlaying, duration, elapsed in
            guard let self = self else { return }
            
            if let title = title {
                if self.currentSong != title {
                    self.currentSong = title
                    self.currentArtist = artist ?? ""
                    
                    // Fetch new lyrics
                    self.lyrics = []
                    self.currentLyricIndex = -1
                    LyricsManager.shared.fetchLyrics(for: title, artist: artist ?? "") { newLyrics in
                        self.lyrics = newLyrics
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
    
    private func checkClipboard() {
        let currentChangeCount = pasteboard.changeCount
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            
            // Check content types for HUD
            var icon = "doc.on.doc.fill"
            var msg = "Tersalin"
            var isCut = false
            
            if lastActionWasCut && Date().timeIntervalSince(lastActionTime) < 1.5 {
                isCut = true
                msg = LanguageManager.tr("Cut to Clipboard")
                icon = "scissors"
            } else {
                if let types = pasteboard.types {
                    if types.contains(.fileURL) {
                        icon = "doc.fill"
                        msg = LanguageManager.tr("File Copied")
                    } else if types.contains(.tiff) || types.contains(.png) {
                        icon = "photo.fill"
                        msg = LanguageManager.tr("Image Copied")
                    } else if types.contains(.string) {
                        icon = "text.quote"
                        msg = LanguageManager.tr("Text Copied")
                    }
                }
            }
            
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    self.clipboardMessage = msg
                    self.clipboardIcon = icon
                    self.clipboardIsCut = isCut
                    self.showClipboardHUD = true
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
                    if currentItems.count > 3 {
                        currentItems = Array(currentItems.prefix(3))
                    }
                    self.clipboardItems = currentItems
                }
            }
        }
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LanguageManager.tr("Drop Zone"))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            
            if viewModel.stagedFiles.isEmpty {
                Text(LanguageManager.tr("Drag files here to store temporarily."))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.stagedFiles, id: \.self) { url in
                            VStack {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                Text(url.lastPathComponent)
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .frame(width: 50)
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                DragSourceOverlay(url: url) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                                        viewModel.stagedFiles.removeAll { $0 == url }
                                    }
                                }
                            )
                            .contextMenu {
                                Button("Remove") {
                                    withAnimation {
                                        viewModel.stagedFiles.removeAll { $0 == url }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

// MARK: - Pomodoro View
struct PomodoroTimerView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var customMinutes: String = ""
    
    var body: some View {
        VStack(spacing: 12) {
            Text(LanguageManager.tr("Focus Timer"))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                Button(action: {
                    viewModel.startPomodoro(minutes: 25)
                }) {
                    VStack {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 20))
                        Text("25m")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.white)
                    .frame(width: 60, height: 50)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                }.buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    viewModel.startPomodoro(minutes: 5)
                }) {
                    VStack {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 20))
                        Text("5m")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.white)
                    .frame(width: 60, height: 50)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                }.buttonStyle(PlainButtonStyle())
                
                HStack(spacing: 8) {
                    TextField("m", text: $customMinutes)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(width: 30)
                    
                    Button(action: {
                        if let min = Double(customMinutes) {
                            viewModel.startPomodoro(minutes: min)
                        }
                    }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(width: 70, height: 50)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                
                if viewModel.isPomodoroActive {
                    Button(action: {
                        viewModel.stopPomodoro()
                    }) {
                        VStack {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 20))
                            Text(LanguageManager.tr("Stop"))
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.red)
                        .frame(width: 60, height: 50)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                    }.buttonStyle(PlainButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

// MARK: - Detached Pomodoro Island
struct DetachedPomodoroView: View {
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 3)
                    .frame(width: 18, height: 18)
                
                Circle()
                    .trim(from: 0, to: CGFloat(viewModel.pomodoroTotal > 0 ? viewModel.pomodoroRemaining / viewModel.pomodoroTotal : 0))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 18, height: 18)
                    .rotationEffect(.degrees(-90))
            }
            
            Text(timeString(from: viewModel.pomodoroRemaining))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(Color.black)
        .clipShape(Capsule())
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
    
    let columns = [
        GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())
    ]
    let buttons = [
        ["7", "8", "9", "÷"],
        ["4", "5", "6", "×"],
        ["1", "2", "3", "-"],
        ["C", "0", "=", "+"]
    ]
    
    var body: some View {
        VStack(spacing: 4) {
            Text(viewModel.calcInput)
                .font(.system(size: 24, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 24)
                .padding(.top, 12)
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(buttons.flatMap { $0 }, id: \.self) { btn in
                    Button(action: { handlePress(btn) }) {
                        Text(btn)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 28)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }
    
    private func handlePress(_ btn: String) {
        if let num = Int(btn) {
            if viewModel.calcInput == "0" {
                viewModel.calcInput = "\(num)"
            } else {
                viewModel.calcInput += "\(num)"
            }
        } else if btn == "C" {
            viewModel.calcInput = "0"
            viewModel.calcPrevious = nil
            viewModel.calcOperator = nil
        } else if btn == "=" {
            calculate()
            viewModel.calcOperator = nil
        } else {
            calculate()
            viewModel.calcOperator = btn
            viewModel.calcPrevious = Double(viewModel.calcInput)
            viewModel.calcInput = "0"
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
        viewModel.calcInput = String(format: "%g", result)
        viewModel.calcPrevious = result
    }
}

// MARK: - Media Card View
struct MediaCardView: View {
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            mediaInfoRow
            
            // Animated Lyrics
            if !viewModel.lyrics.isEmpty {
                lyricsSection
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    private var mediaInfoRow: some View {
        HStack(spacing: 16) {
            albumArt
            metadataSection
            Spacer()
            playbackControls
        }
    }
    
    @ViewBuilder
    private var albumArt: some View {
        if let img = viewModel.artwork {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.5))
                )
        }
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.currentSong)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
            
            if !viewModel.currentArtist.isEmpty {
                Text(viewModel.currentArtist)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            if viewModel.duration > 0 {
                scrubberRow
            }
        }
    }
    
    private var scrubberRow: some View {
        LiveScrubberView(viewModel: viewModel)
            .padding(.top, 2)
    }
    
    private var playbackControls: some View {
        HStack(spacing: 12) {
            Button(action: {
                MediaRemoteHelper.shared.previousTrack()
            }) {
                Image(systemName: "backward.fill").foregroundColor(.gray)
            }.buttonStyle(PlainButtonStyle())
            
            Button(action: {
                MediaRemoteHelper.shared.togglePlayPause()
            }) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 18))
            }.buttonStyle(PlainButtonStyle())
            
            Button(action: {
                MediaRemoteHelper.shared.nextTrack()
            }) {
                Image(systemName: "forward.fill").foregroundColor(.gray)
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
    var body: some View {
        VStack(spacing: 8) {
            Text(LanguageManager.tr("Recent Clipboard"))
                .font(.caption).foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 8)
            if viewModel.clipboardItems.isEmpty {
                Text(LanguageManager.tr("No recent items")).foregroundColor(.gray).font(.footnote).padding(.bottom, 12)
            } else {
                ForEach(viewModel.clipboardItems, id: \.self) { item in
                    Button(action: {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(item, forType: .string)
                    }) {
                        Text(item).lineLimit(1).font(.system(size: 13)).foregroundColor(.white)
                            .padding(.vertical, 6).padding(.horizontal, 12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.1)).cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle()).padding(.horizontal, 20)
                }
                .padding(.bottom, 12)
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
    @State private var heights: [CGFloat] = [4, 4, 4, 4]
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.orange)
                    .frame(width: 3, height: heights[i])
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
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundColor(isCut ? .orange : .blue)
                
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
            
            WaveformView(isPlaying: viewModel.isPlaying)
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

// MARK: - Blossom Animations
struct DropFileBlossomView: View {
    @State private var scale: CGFloat = 0.4
    @State private var arrowOffset: CGFloat = -8
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 22))
                .offset(y: arrowOffset)
            Text(LanguageManager.tr("DROP FILE HERE"))
                .font(.system(size: 14, weight: .black))
        }
        .frame(height: 56)
        .foregroundColor(.cyan)
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.4, blendDuration: 0)) {
                scale = 1.0
            }
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                arrowOffset = 2
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

// MARK: - Notch Container View
struct ContentView: View {
    @StateObject private var viewModel = NotchViewModel()
    
    @AppStorage("enableGlow") private var enableGlow = true
    @AppStorage("appLanguage") private var appLanguage = "en" 

    @AppStorage("notchOpacity") private var notchOpacity: Double = 1.0
    @AppStorage("expandTrigger") private var expandTrigger: String = "hover"
    @AppStorage("autoHideDelay") private var autoHideDelay: Double = 0.05
    @AppStorage("tabOrderStr") private var tabOrderStr = "media,clipboard,dropzone,pomodoro,calculator,weather,system,agenda"
    @AppStorage("hiddenTabsStr") private var hiddenTabsStr = ""
    
    private var visibleTabs: [NotchTab] {
        let order = tabOrderStr.split(separator: ",").compactMap { NotchTab(rawValue: String($0)) }
        let hidden = hiddenTabsStr.split(separator: ",").compactMap { NotchTab(rawValue: String($0)) }
        
        var tabs = order.filter { !hidden.contains($0) }
        
        // Ensure all tabs exist (in case of updates adding new tabs)
        for tab in NotchTab.allCases {
            if !order.contains(tab) && !hidden.contains(tab) {
                tabs.append(tab)
            }
        }
        
        return tabs
    }
    
    private let clockWidth: CGFloat = 130
    private let mediaWidth: CGFloat = 220
    private let compactHeight: CGFloat = 34
    private let expandedWidth: CGFloat = 400
    private let expandedHeight: CGFloat = 160
    
    @State private var previousApp: NSRunningApplication?
    @State private var blossomHeight: CGFloat = 0
    @State private var isHiddenByFullscreen: Bool = false
    
    private var currentWidth: CGFloat {
        if viewModel.isExpanded { return expandedWidth }
        if viewModel.showClipboardHUD { return 220 }
        if viewModel.showTimesUp { return 260 }
        if viewModel.showDeviceHUD { return 260 }
        if viewModel.showVolumeHUD { return 160 }
        if viewModel.isHoveringWithFile { return 240 }
        return viewModel.showClock ? clockWidth : mediaWidth
    }

    private var currentHeight: CGFloat {
        if viewModel.isExpanded {
            if viewModel.selectedTab == .calculator { return 230 }
            if viewModel.selectedTab == .media && !viewModel.lyrics.isEmpty { return 280 }
            if viewModel.selectedTab == .weather { return 180 }
            if viewModel.selectedTab == .system { return 180 }
            if viewModel.selectedTab == .agenda { return 330 }
            return expandedHeight
        }
        if viewModel.showClipboardHUD { return 44 }
        if viewModel.showTimesUp { return 64 }
        if viewModel.showDeviceHUD { return 44 }
        if viewModel.showVolumeHUD { return 44 }
        if viewModel.showAgendaHUD { return 44 }
        if viewModel.isHoveringWithFile { return 56 }
        return compactHeight + blossomHeight
    }
    
    private var isBlossoming: Bool {
        viewModel.showClipboardHUD || viewModel.showTimesUp || viewModel.showDeviceHUD || viewModel.showVolumeHUD || viewModel.showAgendaHUD || viewModel.isHoveringWithFile
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // The Main Notch
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
                            HStack(spacing: 16) {
                                ForEach(visibleTabs, id: \.self) { tab in
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
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                            
                            // Tab Content
                            ZStack(alignment: .top) {
                                if viewModel.selectedTab == .media {
                                    MediaCardView(viewModel: viewModel)
                                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                                } else if viewModel.selectedTab == .clipboard {
                                    ClipboardStackView(viewModel: viewModel)
                                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                                } else if viewModel.selectedTab == .dropzone {
                                    DropZoneCardView(viewModel: viewModel)
                                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                                } else if viewModel.selectedTab == .pomodoro {
                                    PomodoroTimerView(viewModel: viewModel)
                                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                                } else if viewModel.selectedTab == .calculator {
                                    CalculatorView(viewModel: viewModel)
                                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                                } else if viewModel.selectedTab == .weather {
                                    WeatherCardView(viewModel: viewModel)
                                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                                } else if viewModel.selectedTab == .system {
                                    SystemMonitorView(viewModel: viewModel)
                                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                                } else if viewModel.selectedTab == .agenda {
                                    AgendaCardView(viewModel: viewModel)
                                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .transition(.scale(scale: 0.01, anchor: .top))
                    } else {
                        Group {
                            if viewModel.isHoveringWithFile {
                                DropFileBlossomView()
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            } else if viewModel.showVolumeHUD {
                                VolumeBlossomView(volume: viewModel.currentVolume)
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            } else if viewModel.showDeviceHUD {
                                DeviceBlossomView(message: viewModel.deviceMessage, iconName: viewModel.deviceIcon, isConnected: viewModel.isDeviceConnected)
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            } else if viewModel.showClipboardHUD {
                                ClipboardBlossomView(message: viewModel.clipboardMessage, iconName: viewModel.clipboardIcon, isCut: viewModel.clipboardIsCut)
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            } else if viewModel.showTimesUp {
                                TimesUpBlossomView()
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            } else if viewModel.showAgendaHUD {
                                AgendaBlossomView(message: viewModel.agendaHUDMessage)
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
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
                        if isHovering {
                            if expandTrigger == "hover" {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    guard !viewModel.isHoveringWithFile else { return }
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
                                guard !viewModel.isPinningExpansion else { return }
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
                            
                            // Swallow animation
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                blossomHeight = -8
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
                                    blossomHeight = 0
                                    viewModel.selectedTab = .dropzone
                                    viewModel.isExpanded = true
                                }
                            }
                        }
                    )
                }
            )
            .frame(width: currentWidth, height: currentHeight)
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.6, blendDuration: 0), value: viewModel.isExpanded)
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.55, blendDuration: 0), value: viewModel.showClock)
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.55, blendDuration: 0), value: viewModel.isHoveringWithFile)
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.55, blendDuration: 0), value: viewModel.showTimesUp)
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.55, blendDuration: 0), value: viewModel.showVolumeHUD)
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.55, blendDuration: 0), value: viewModel.showDeviceHUD)
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.55, blendDuration: 0), value: viewModel.showClipboardHUD)
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.55, blendDuration: 0), value: viewModel.showAgendaHUD)
            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.65, blendDuration: 0), value: viewModel.selectedTab)
            .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.6, blendDuration: 0), value: viewModel.lyrics.isEmpty)
            .offset(y: isHiddenByFullscreen ? -80 : 0)
            .opacity(isHiddenByFullscreen ? 0 : notchOpacity)
            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.7, blendDuration: 0), value: isHiddenByFullscreen)
            .onTapGesture {
                if expandTrigger == "click" && !viewModel.isExpanded {
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
            } // End of inner ZStack
            
            // Detached Pomodoro Timer Island
            if viewModel.isPomodoroActive && !viewModel.isExpanded && !viewModel.showTimesUp {
                DetachedPomodoroView(viewModel: viewModel)
                    .offset(x: ((viewModel.showClock ? clockWidth : mediaWidth) / 2) + 12 + 42, y: 0)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .scale(scale: 0.8)).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .scale(scale: 0.8)).combined(with: .opacity)
                    ))
                    .animation(.spring(response: 0.4, dampingFraction: 0.65), value: viewModel.showClock)
                    .animation(.spring(response: 0.4, dampingFraction: 0.65), value: viewModel.isPomodoroActive)
            }
        } // End of outer ZStack
        Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            checkFullscreen()
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
    
    func togglePlayPause() {
        _ = sendCommand?(2, nil) // togglePlayPause
    }
    
    func nextTrack() {
        _ = sendCommand?(4, nil) // nextTrack
    }
    
    func previousTrack() {
        _ = sendCommand?(5, nil) // previousTrack
    }
    
    func seek(to time: Double) {
        setElapsedTime?(time)
    }
    
    func fetchNowPlaying(completion: @escaping (String?, String?, NSImage?, Bool, Double, Double) -> Void) {
        guard let getNowPlayingInfo = getNowPlayingInfo else {
            completion(nil, nil, nil, false, 0, 0)
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
            
            if let artworkData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data, artworkData.count > 0 {
                let img = NSImage(data: artworkData)
                self.cachedArtwork = img
                self.lastQuery = "" // Reset to prevent unnecessary iTunes fetch
                DispatchQueue.main.async {
                    completion(title.isEmpty ? nil : title, artistStr.isEmpty ? nil : artistStr, img, isPlaying, duration, elapsed)
                }
            } else {
                // Artwork is missing, use iTunes Search API as fallback
                let query = "\(title) \(artist)"
                
                if query == self.lastQuery && !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    // We already fetched or are fetching this track
                    DispatchQueue.main.async {
                        completion(title.isEmpty ? nil : title, artistStr.isEmpty ? nil : artistStr, self.cachedArtwork, isPlaying, duration, elapsed)
                    }
                } else {
                    self.lastQuery = query
                    
                    // Fallback to app icon initially while we fetch
                    var fallbackIcon: NSImage? = nil
                    if let clientData = info["kMRMediaRemoteNowPlayingInfoClientPropertiesData"] as? Data {
                        let printable = String(clientData.compactMap { byte -> Character? in
                            return (byte >= 32 && byte <= 126) ? Character(UnicodeScalar(byte)) : nil
                        })
                        if let regex = try? NSRegularExpression(pattern: "[a-zA-Z0-9-]+\\.[a-zA-Z0-9-]+\\.[a-zA-Z0-9-]+"),
                           let match = regex.firstMatch(in: printable, range: NSRange(printable.startIndex..., in: printable)) {
                            let bundleId = String(printable[Range(match.range, in: printable)!])
                            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                                fallbackIcon = NSWorkspace.shared.icon(forFile: appURL.path)
                            }
                        }
                    }
                    
                    self.cachedArtwork = fallbackIcon
                    
                    if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                        self.fetchITunesArtwork(title: title, artist: artist) { fetchedImage in
                            if let fetchedImage = fetchedImage {
                                self.cachedArtwork = fetchedImage
                                DispatchQueue.main.async {
                                    completion(title.isEmpty ? nil : title, artistStr.isEmpty ? nil : artistStr, fetchedImage, isPlaying, duration, elapsed)
                                }
                            }
                        }
                    }
                    
                    DispatchQueue.main.async {
                        completion(title.isEmpty ? nil : title, artistStr.isEmpty ? nil : artistStr, self.cachedArtwork, isPlaying, duration, elapsed)
                    }
                }
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
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
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
        VStack(spacing: 14) {
            cpuRow
            memRow
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
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
    
    private var cpuColor: Color {
        viewModel.cpuUsage > 80 ? .red : (viewModel.cpuUsage > 50 ? .orange : .green)
    }
    
    private var memColor: Color {
        viewModel.memUsage > 80 ? .red : (viewModel.memUsage > 60 ? .orange : .purple)
    }
    
    private func refreshStats() {
        viewModel.cpuUsage = SystemMonitor.getCPUUsage()
        let mem = SystemMonitor.getMemoryUsage()
        viewModel.memUsage = mem.percent
        viewModel.memUsed = SystemMonitor.formatBytes(mem.used)
        viewModel.memTotal = SystemMonitor.formatBytes(mem.total)
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
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
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
        .frame(height: 260)
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
        "No music playing": "Tidak ada musik dimainkan"
    ]
    
    static func tr(_ key: String) -> String {
        let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        if lang == "id" {
            return translationsToId[key] ?? key
        }
        return key
    }
}
