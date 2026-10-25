import SwiftUI
import AppKit
import ServiceManagement
import AVFoundation

@main
struct NotchifyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NotchPanel?
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "enableGlow": false,
            "enableLyrics": true,
            "appLanguage": "en"
        ])
        
        setupMenuBar()
        setupGlobalShortcut()
        
        let notchPanel = NotchPanel()
        self.panel = notchPanel
        
        let containerView = ContentView()
        let hostingView = NSHostingView(rootView: containerView)
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.wantsLayer = true
        
        notchPanel.contentView = hostingView
        
        if let screen = NSScreen.main {
            let panelWidth: CGFloat = 600
            let panelHeight: CGFloat = 380
            let screenRect = screen.frame
            let x = (screenRect.width - panelWidth) / 2
            let y = screenRect.height - panelHeight
            
            notchPanel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        }
        
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if !hasCompletedOnboarding {
            OnboardingWindowController.shared.show { [weak self] in
                self?.panel?.makeKeyAndOrderFront(nil)
            }
        } else {
            notchPanel.makeKeyAndOrderFront(nil)
        }
    }
    
    func setupGlobalShortcut() {
        // Cmd + Shift + N
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.panel != nil else { return }
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 45 {
                // Post a custom notification so ContentView can toggle
                NotificationCenter.default.post(name: NSNotification.Name("ToggleNotchify"), object: nil)
            }
        }
        
        // Also support local monitor when app is active
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 45 {
                NotificationCenter.default.post(name: NSNotification.Name("ToggleNotchify"), object: nil)
                return nil // Consume event
            }
            return event
        }
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "macwindow.badge.plus", accessibilityDescription: "Notchify")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: LanguageManager.tr("Onboarding Tour..."), action: #selector(openOnboarding), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: LanguageManager.tr("Settings..."), action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: LanguageManager.tr("Quit Notchify"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func openOnboarding() {
        OnboardingWindowController.shared.show(force: true)
    }
    
    @objc func openSettings() {
        SettingsWindowController.shared.show()
    }
}

class NotchPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        
        self.acceptsMouseMovedEvents = true
    }
    
    override var canBecomeKey: Bool {
        return true
    }
}

// MARK: - Settings Window Controller
class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = LanguageManager.tr("Notchify Settings")
        window.isMovableByWindowBackground = true
        window.level = .normal
        window.hidesOnDeactivate = true
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.contentView = NSHostingView(rootView: SettingsView())
        
        super.init(window: window)
        window.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show() {
        window?.title = LanguageManager.tr("Notchify Settings")
        window?.contentView = NSHostingView(rootView: SettingsView())
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SettingsView: View {
    enum SettingsTab: String, CaseIterable, Identifiable {
        case general
        case tabs
        case appearance
        case camera
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .general: return LanguageManager.tr("General")
            case .tabs: return LanguageManager.tr("Menu & Features")
            case .appearance: return LanguageManager.tr("Appearance")
            case .camera: return LanguageManager.tr("Camera")
            }
        }
        
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .tabs: return "square.grid.2x2"
            case .appearance: return "paintpalette"
            case .camera: return "camera"
            }
        }
    }
    
    @State private var selectedTab: SettingsTab = .general
    @AppStorage("appLanguage") private var appLanguage = "en"
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Custom Tab Bar
            HStack(spacing: 8) {
                ForEach(SettingsTab.allCases) { tab in
                    let isSelected = selectedTab == tab
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                            selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                            Text(tab.title)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                        }
                        .foregroundColor(isSelected ? .white : .secondary)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 14)
                        .background(
                            ZStack {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.accentColor.opacity(0.85))
                                        .shadow(color: Color.accentColor.opacity(0.3), radius: 4, x: 0, y: 1)
                                } else {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.white.opacity(0.05))
                                }
                            }
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Tab Content
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .tabs:
                    TabsSettingsView()
                case .appearance:
                    AppearanceSettingsView()
                case .camera:
                    CameraSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 560, height: 620)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct GeneralSettingsView: View {
    @AppStorage("expandTrigger") private var expandTrigger = "hover"
    @AppStorage("autoHideDelay") private var autoHideDelay = 0.5
    @AppStorage("appLanguage") private var appLanguage = "en"
    @State private var isTrusted = AXIsProcessTrusted()
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                // App Branding Header
                HStack(spacing: 12) {
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Notchify")
                                .font(.system(size: 16, weight: .bold))
                            Text("v2.0")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(4)
                        }
                        Text(LanguageManager.tr("Smart Dynamic Island & Notch for macOS"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.bottom, 2)
                
                // GroupBox 1: Behavior & Language
                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LanguageManager.tr("Language"))
                                    .font(.headline)
                                Text(appLanguage == "id" ? "Pilih bahasa antarmuka aplikasi" : "Select app interface language")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Picker("", selection: $appLanguage) {
                                Text("English").tag("en")
                                Text("Bahasa Indonesia").tag("id")
                            }
                            .labelsHidden()
                            .frame(width: 170)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LanguageManager.tr("How to Open Notch"))
                                .font(.headline)
                            Picker("", selection: $expandTrigger) {
                                Text(LanguageManager.tr("Hover cursor")).tag("hover")
                                Text(LanguageManager.tr("Click directly")).tag("click")
                            }
                            .pickerStyle(RadioGroupPickerStyle())
                            .labelsHidden()
                        }
                        
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LanguageManager.tr("Auto-Close Speed"))
                                    .font(.headline)
                                Text(appLanguage == "id" ? "Jeda waktu sebelum Notch menutup otomatis" : "Delay before Notch automatically closes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Picker("", selection: $autoHideDelay) {
                                Text(LanguageManager.tr("Fast (0.1s)")).tag(0.1)
                                Text(LanguageManager.tr("Standard (0.5s)")).tag(0.5)
                                Text(LanguageManager.tr("Slow (1.5s)")).tag(1.5)
                            }
                            .labelsHidden()
                            .frame(width: 170)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // GroupBox 2: Keyboard Shortcut & Accessibility
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(LanguageManager.tr("Keyboard Shortcut"))
                            .font(.headline)
                        Text(LanguageManager.tr("Press Cmd + Shift + N from anywhere to toggle Notchify."))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        HStack {
                            Image(systemName: isTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                                .foregroundColor(isTrusted ? .green : .orange)
                                .font(.system(size: 16))
                                
                            Text(isTrusted ? LanguageManager.tr("Accessibility Granted") : LanguageManager.tr("Accessibility Required"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(isTrusted ? .green : .orange)
                            
                            Spacer()
                            
                            if !isTrusted {
                                Button(LanguageManager.tr("Grant Access")) {
                                    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                                    AXIsProcessTrustedWithOptions(options as CFDictionary)
                                }
                            }
                        }
                        .padding(10)
                        .background(isTrusted ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // GroupBox 3: Onboarding Tour
                GroupBox {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(LanguageManager.tr("Onboarding Tour"))
                                .font(.headline)
                            Text(LanguageManager.tr("Revisit the setup guide and feature overview."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            OnboardingWindowController.shared.show(force: true)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                Text(LanguageManager.tr("Revisit Onboarding Tour"))
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .onAppear {
            isTrusted = AXIsProcessTrusted()
        }
    }
}

struct TabsSettingsView: View {
    @AppStorage("tabOrderStr") private var tabOrderStr = "media,clipboard,dropzone,pomodoro,calculator,weather,system,agenda,mirror,notes,network"
    @AppStorage("hiddenTabsStr") private var hiddenTabsStr = ""
    @AppStorage("appLanguage") private var appLanguage = "en" 

    @State private var tabs: [NotchTab] = []
    @State private var hiddenSet: Set<String> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LanguageManager.tr("Drag & Drop to reorder. Uncheck to hide."))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 14)
            
            List {
                ForEach(tabs) { tab in
                    HStack(spacing: 10) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.gray.opacity(0.6))
                            .font(.system(size: 13))
                            
                        Image(systemName: tab.rawValue)
                            .font(.system(size: 13))
                            .foregroundColor(.accentColor)
                            .frame(width: 22, height: 22)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        
                        Text(tab.displayName)
                            .font(.system(size: 13, weight: .medium))
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { !hiddenSet.contains(tab.id) },
                            set: { isVisible in
                                if isVisible {
                                    hiddenSet.remove(tab.id)
                                } else {
                                    hiddenSet.insert(tab.id)
                                }
                                saveState()
                            }
                        ))
                        .labelsHidden()
                        .toggleStyle(CheckboxToggleStyle())
                    }
                    .padding(.vertical, 4)
                }
                .onMove(perform: move)
            }
            .listStyle(PlainListStyle())
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .onAppear(perform: loadState)
    }
    
    private func loadState() {
        let order = tabOrderStr.split(separator: ",").map(String.init)
        let hidden = hiddenTabsStr.split(separator: ",").map(String.init)
        
        hiddenSet = Set(hidden.compactMap { NotchTab.from(string: $0)?.id })
        
        var loadedTabs = order.compactMap { NotchTab.from(string: $0) }
        
        for tab in NotchTab.allCases {
            if !loadedTabs.contains(tab) {
                loadedTabs.append(tab)
            }
        }
        tabs = loadedTabs
    }
    
    private func saveState() {
        tabOrderStr = tabs.map { $0.id }.joined(separator: ",")
        hiddenTabsStr = Array(hiddenSet).joined(separator: ",")
    }
    
    private func move(from source: IndexSet, to destination: Int) {
        tabs.move(fromOffsets: source, toOffset: destination)
        saveState()
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("enableGlow") private var enableGlow = false
    @AppStorage("enableLyrics") private var enableLyrics = true
    @AppStorage("preferredMusicPlayer") private var preferredMusicPlayer = "auto"
    @AppStorage("notchOpacity") private var notchOpacity: Double = 1.0
    @AppStorage("appLanguage") private var appLanguage = "en" 

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(LanguageManager.tr("Visual Effects"))
                            .font(.headline)
                        
                        Toggle(isOn: $enableGlow) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(LanguageManager.tr("Use Glow effect behind Notch"))
                                    .font(.system(size: 13, weight: .medium))
                                Text(LanguageManager.tr("Disabling this saves CPU/GPU on older Macs."))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(LanguageManager.tr("Media & Lyrics"))
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LanguageManager.tr("Preferred Music Source"))
                                .font(.system(size: 13, weight: .medium))
                            
                            Picker("", selection: $preferredMusicPlayer) {
                                Text(LanguageManager.tr("Auto (Detect Any Active App)")).tag("auto")
                                Text("Spotify").tag("spotify")
                                Text("Apple Music").tag("music")
                                Text(LanguageManager.tr("Browser Web (YouTube Music)")).tag("browser")
                            }
                            .pickerStyle(MenuPickerStyle())
                            
                            Text(LanguageManager.tr("Preferred player to display and control when multiple music sources are active."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Divider()
                        
                        Toggle(isOn: $enableLyrics) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(LanguageManager.tr("Search & display music lyrics"))
                                    .font(.system(size: 13, weight: .medium))
                                Text(LanguageManager.tr("Fetch synchronized lyrics online when playing music."))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(LanguageManager.tr("Glass Transparency Level"))
                                .font(.headline)
                            Spacer()
                            Text("\(Int(notchOpacity * 100))%")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                            
                        HStack(spacing: 12) {
                            Image(systemName: "circle.dotted")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                            
                            Slider(value: $notchOpacity, in: 0.5...1.0)
                            
                            Image(systemName: "circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                        }
                        .padding(.top, 2)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
    }
}

struct CameraSettingsView: View {
    @AppStorage("photoStorageType") private var photoStorageType = "default"
    @AppStorage("customPhotoStoragePath") private var customPhotoStoragePath = ""
    @AppStorage("playShutterSound") private var playShutterSound = true
    @AppStorage("appLanguage") private var appLanguage = "en"
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(LanguageManager.tr("Photo Storage Location"))
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            // Default Folder
                            Button(action: {
                                photoStorageType = "default"
                            }) {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: photoStorageType == "default" ? "largecircle.fill.circle" : "circle")
                                        .foregroundColor(photoStorageType == "default" ? .blue : .gray)
                                        .font(.system(size: 14))
                                        .padding(.top, 2)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(LanguageManager.tr("Default Folder"))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.primary)
                                        Text("~/Pictures/Notchify")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Divider().padding(.vertical, 2)
                            
                            // Custom Folder
                            VStack(alignment: .leading, spacing: 8) {
                                Button(action: {
                                    photoStorageType = "custom"
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: photoStorageType == "custom" ? "largecircle.fill.circle" : "circle")
                                            .foregroundColor(photoStorageType == "custom" ? .blue : .gray)
                                            .font(.system(size: 14))
                                        
                                        Text(LanguageManager.tr("Custom Folder"))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.primary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                HStack(spacing: 8) {
                                    Text(customPhotoStoragePath.isEmpty ? LanguageManager.tr("No folder selected") : customPhotoStoragePath)
                                        .font(.system(size: 11))
                                        .foregroundColor(customPhotoStoragePath.isEmpty ? .secondary : .primary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.gray.opacity(0.12))
                                        .cornerRadius(6)
                                    
                                    Button(LanguageManager.tr("Choose Folder...")) {
                                        chooseCustomFolder()
                                    }
                                }
                                .padding(.leading, 22)
                            }
                        }
                        
                        Divider().padding(.vertical, 2)
                        
                        HStack {
                            Button(action: {
                                PhotoStorageManager.openPhotosFolder()
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "folder")
                                    Text(LanguageManager.tr("Open Folder in Finder"))
                                }
                            }
                            Spacer()
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(LanguageManager.tr("Shutter Feedback"))
                            .font(.headline)
                        
                        Toggle(LanguageManager.tr("Play Shutter Sound"), isOn: $playShutterSound)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
    }
    
    private func chooseCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = LanguageManager.tr("Select")
        
        if panel.runModal() == .OK, let url = panel.url {
            customPhotoStoragePath = url.path
            photoStorageType = "custom"
        }
    }
}

// MARK: - Onboarding Window Controller & View
class OnboardingWindowController: NSWindowController {
    static let shared = OnboardingWindowController()
    private var onCompleteCallback: (() -> Void)?
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 530),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Welcome to Notchify"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.isReleasedWhenClosed = false
        
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show(force: Bool = false, onComplete: (() -> Void)? = nil) {
        if let onComplete = onComplete {
            self.onCompleteCallback = onComplete
        }
        let contentView = OnboardingView(onComplete: { [weak self] in
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            self?.close()
            self?.onCompleteCallback?()
            self?.onCompleteCallback = nil
        })
        window?.contentView = NSHostingView(rootView: contentView)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct OnboardingView: View {
    var onComplete: () -> Void
    
    @State private var currentStep = 0
    @AppStorage("expandTrigger") private var expandTrigger = "hover"
    @AppStorage("appLanguage") private var appLanguage = "en"
    @State private var launchAtLogin = false
    
    // Permission states
    @State private var isAccessibilityTrusted = AXIsProcessTrusted()
    @State private var isCameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    @State private var isMicAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    @State private var isMusicTested = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Slide Content
            ZStack {
                switch currentStep {
                case 0:
                    welcomeSlide
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96)),
                            removal: .opacity.combined(with: .scale(scale: 1.04))
                        ))
                case 1:
                    permissionsSlide
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                case 2:
                    controlsSlide
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                case 3:
                    readySlide
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96)),
                            removal: .opacity.combined(with: .scale(scale: 1.04))
                        ))
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Stepper & Nav Footer
            HStack {
                if currentStep > 0 {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            currentStep -= 1
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .bold))
                            Text(LanguageManager.tr("Back"))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Spacer().frame(width: 80)
                }
                
                Spacer()
                
                // Stepper Dots
                HStack(spacing: 8) {
                    ForEach(0..<4) { idx in
                        Circle()
                            .fill(currentStep == idx ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: currentStep == idx ? 9 : 7, height: currentStep == idx ? 9 : 7)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                    }
                }
                
                Spacer()
                
                if currentStep < 3 {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            currentStep += 1
                        }
                    }) {
                        HStack(spacing: 5) {
                            Text(LanguageManager.tr("Continue"))
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(Color.blue)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Spacer().frame(width: 80)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 22)
            .padding(.top, 10)
        }
        .frame(width: 620, height: 530)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            refreshPermissions()
            checkLaunchAtLoginStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissions()
        }
    }
    
    // MARK: - Slide 0: Welcome
    private var welcomeSlide: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 10)
            
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 3)
            
            VStack(spacing: 4) {
                Text(LanguageManager.tr("Welcome to Notchify"))
                    .font(.system(size: 24, weight: .bold))
                
                Text(LanguageManager.tr("Transform your MacBook Notch into a powerful Dynamic Island"))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // 2x2 Feature Grid
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                featureCard(
                    icon: "music.note",
                    iconColor: .orange,
                    title: LanguageManager.tr("Media & Real-time Lyrics"),
                    subtitle: LanguageManager.tr("Control Spotify, Apple Music & Web Player with lyrics")
                )
                
                featureCard(
                    icon: "camera.fill",
                    iconColor: .blue,
                    title: LanguageManager.tr("Webcam Mirror & Quick Video"),
                    subtitle: LanguageManager.tr("Check face, take instant photos & video clips before meetings")
                )
                
                featureCard(
                    icon: "tray.and.arrow.down.fill",
                    iconColor: .green,
                    title: LanguageManager.tr("Drop Zone File Shelf"),
                    subtitle: LanguageManager.tr("Stash temporary files and share via AirDrop or Mail")
                )
                
                featureCard(
                    icon: "doc.on.clipboard",
                    iconColor: .purple,
                    title: LanguageManager.tr("Smart Clipboard History"),
                    subtitle: LanguageManager.tr("Pin important snippets & search clipboard history")
                )
            }
            .padding(.horizontal, 36)
            
            Spacer()
        }
    }
    
    private func featureCard(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }
    
    // MARK: - Slide 1: Permissions
    private var permissionsSlide: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 10)
            
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 60, height: 60)
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 4) {
                Text(LanguageManager.tr("Essential Permissions"))
                    .font(.system(size: 22, weight: .bold))
                
                Text(LanguageManager.tr("Notchify needs a few permissions to provide seamless controls. You can grant them now or later in Settings."))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            VStack(spacing: 10) {
                // Accessibility
                permissionRow(
                    icon: "hand.raised.fill",
                    iconColor: .blue,
                    title: LanguageManager.tr("Accessibility Access"),
                    description: LanguageManager.tr("Required for global shortcut (Cmd+Shift+N) and Notch interaction"),
                    isGranted: isAccessibilityTrusted,
                    grantAction: { requestAccessibility() }
                )
                
                // Camera & Mic
                permissionRow(
                    icon: "camera.fill",
                    iconColor: .orange,
                    title: LanguageManager.tr("Camera & Microphone"),
                    description: LanguageManager.tr("For quick webcam mirror, photo snapshots, and video clips"),
                    isGranted: isCameraAuthorized && isMicAuthorized,
                    grantAction: { requestCameraAndMic() }
                )
                
                // Music Automation
                permissionRow(
                    icon: "music.note",
                    iconColor: .purple,
                    title: LanguageManager.tr("Music Automation"),
                    description: LanguageManager.tr("To display current song and control Spotify & Apple Music"),
                    isGranted: isMusicTested,
                    grantAction: { requestMusicAutomation() }
                )
            }
            .padding(.horizontal, 36)
            
            Spacer()
        }
    }
    
    private func permissionRow(icon: String, iconColor: Color, title: String, description: String, isGranted: Bool, grantAction: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                Text(description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if isGranted {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(LanguageManager.tr("Granted"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.green.opacity(0.1))
                .clipShape(Capsule())
            } else {
                Button(action: grantAction) {
                    Text(LanguageManager.tr("Grant"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    // MARK: - Slide 2: Controls & Language
    private var controlsSlide: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 10)
            
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 60, height: 60)
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 4) {
                Text(LanguageManager.tr("Personalize Controls"))
                    .font(.system(size: 22, weight: .bold))
                
                Text(LanguageManager.tr("Choose how you'd like to interact with Notchify."))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 14) {
                // Section 1: How to Open Notch
                VStack(alignment: .leading, spacing: 8) {
                    Text(LanguageManager.tr("How to Open Notch"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        // Card A: Hover
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                expandTrigger = "hover"
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "cursorarrow.motionlines")
                                    .font(.system(size: 18))
                                    .foregroundColor(expandTrigger == "hover" ? .blue : .gray)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(LanguageManager.tr("Hover to Expand"))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(expandTrigger == "hover" ? .primary : .secondary)
                                    Text(LanguageManager.tr("Move your cursor near the Notch to smoothly expand"))
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if expandTrigger == "hover" {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(12)
                            .background(expandTrigger == "hover" ? Color.blue.opacity(0.12) : Color.gray.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(expandTrigger == "hover" ? Color.blue : Color.clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Card B: Click
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                expandTrigger = "click"
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(expandTrigger == "click" ? .blue : .gray)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(LanguageManager.tr("Click to Expand"))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(expandTrigger == "click" ? .primary : .secondary)
                                    Text(LanguageManager.tr("Only expands when you click or tap on the Notch"))
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if expandTrigger == "click" {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(12)
                            .background(expandTrigger == "click" ? Color.blue.opacity(0.12) : Color.gray.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(expandTrigger == "click" ? Color.blue : Color.clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // Section 2: Global Shortcut & Language
                HStack(spacing: 14) {
                    // Shortcut Tip
                    HStack(spacing: 10) {
                        HStack(spacing: 4) {
                            keycapView("⌘")
                            keycapView("⇧")
                            keycapView("N")
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LanguageManager.tr("Global Shortcut"))
                                .font(.system(size: 11, weight: .bold))
                            Text(LanguageManager.tr("Press anytime to toggle Notchify from anywhere"))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(Color.gray.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    
                    // Language Selector
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                        Text(LanguageManager.tr("Language"))
                            .font(.system(size: 11, weight: .bold))
                        Spacer()
                        Picker("", selection: $appLanguage) {
                            Text("English").tag("en")
                            Text("Bahasa Indonesia").tag("id")
                        }
                        .labelsHidden()
                        .frame(width: 130)
                    }
                    .padding(10)
                    .background(Color.gray.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(.horizontal, 36)
            
            Spacer()
        }
    }
    
    private func keycapView(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(.primary)
            .frame(minWidth: 20, minHeight: 20)
            .padding(.horizontal, 3)
            .background(Color.gray.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
    }
    
    // MARK: - Slide 3: All Set!
    private var readySlide: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 15)
            
            // Stylized Glowing Dynamic Island Mockup
            ZStack {
                // Subtle Glow Behind Notch
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.5), Color.purple.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 200, height: 42)
                    .blur(radius: 12)
                
                // Notch Body
                Capsule()
                    .fill(Color.black)
                    .frame(width: 200, height: 40)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                
                // Mini indicators inside
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.yellow)
                    
                    Text("Notchify")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 16)
                .frame(width: 200, height: 40)
            }
            .padding(.bottom, 6)
            
            VStack(spacing: 4) {
                Text(LanguageManager.tr("You're All Set!"))
                    .font(.system(size: 26, weight: .bold))
                
                Text(LanguageManager.tr("Notchify is now ready to assist your daily workflow."))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Launch at Login Toggle
            VStack(spacing: 12) {
                Toggle(isOn: $launchAtLogin) {
                    HStack(spacing: 8) {
                        Image(systemName: "power")
                            .foregroundColor(.blue)
                        Text(LanguageManager.tr("Launch automatically at startup (Launch at Login)"))
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .toggleStyle(.checkbox)
                .onChange(of: launchAtLogin) { enabled in
                    updateLaunchAtLogin(enabled: enabled)
                }
                
                // Big Call-To-Action Button
                Button(action: onComplete) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .bold))
                        Text(LanguageManager.tr("Start Using Notchify"))
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 260, height: 44)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color.blue.opacity(0.35), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 6)
            }
            .padding(.horizontal, 36)
            
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    private func refreshPermissions() {
        isAccessibilityTrusted = AXIsProcessTrusted()
        isCameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        isMicAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }
    
    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            refreshPermissions()
        }
    }
    
    private func requestCameraAndMic() {
        if !isCameraAuthorized {
            AVCaptureDevice.requestAccess(for: .video) { _ in
                DispatchQueue.main.async { refreshPermissions() }
            }
        }
        if !isMicAuthorized {
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                DispatchQueue.main.async { refreshPermissions() }
            }
        }
    }
    
    private func requestMusicAutomation() {
        let script = "tell application \"Music\" to get player state"
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
            DispatchQueue.main.async {
                isMusicTested = true
                refreshPermissions()
            }
        }
    }
    
    private func checkLaunchAtLoginStatus() {
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
    
    private func updateLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                print("Launch at login error: \(error)")
            }
        }
    }
}
