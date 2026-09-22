import SwiftUI
import AppKit

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
            let panelHeight: CGFloat = 300
            let screenRect = screen.frame
            let x = (screenRect.width - panelWidth) / 2
            let y = screenRect.height - panelHeight
            
            notchPanel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        }
        
        notchPanel.makeKeyAndOrderFront(nil)
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
        menu.addItem(NSMenuItem(title: LanguageManager.tr("Settings..."), action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: LanguageManager.tr("Quit Notchify"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func openSettings() {
        if #available(macOS 13.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
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
import SwiftUI
import AppKit

struct SettingsView: View {
    private enum Tabs: Hashable {
        case general, tabs, appearance
    }
    
    @AppStorage("appLanguage") private var appLanguage = "en"
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label(LanguageManager.tr("General"), systemImage: "gearshape")
                }
                .tag(Tabs.general)
            
            TabsSettingsView()
                .tabItem {
                    Label(LanguageManager.tr("Menu & Features"), systemImage: "square.grid.2x2")
                }
                .tag(Tabs.tabs)
                
            AppearanceSettingsView()
                .tabItem {
                    Label(LanguageManager.tr("Appearance"), systemImage: "paintpalette")
                }
                .tag(Tabs.appearance)
        }
        .padding(20)
        .frame(width: 450, height: 420)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("expandTrigger") private var expandTrigger = "hover"
    @AppStorage("autoHideDelay") private var autoHideDelay = 0.5
    @AppStorage("appLanguage") private var appLanguage = "en"
    @State private var isTrusted = AXIsProcessTrusted()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LanguageManager.tr("Language"))
                            .font(.headline)
                        Picker("", selection: $appLanguage) {
                            Text("English").tag("en")
                            Text("Bahasa Indonesia").tag("id")
                        }
                        .labelsHidden()
                        .frame(width: 200)
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
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LanguageManager.tr("Auto-Close Speed"))
                            .font(.headline)
                        Picker("", selection: $autoHideDelay) {
                            Text(LanguageManager.tr("Fast (0.1s)")).tag(0.1)
                            Text(LanguageManager.tr("Standard (0.5s)")).tag(0.5)
                            Text(LanguageManager.tr("Slow (1.5s)")).tag(1.5)
                        }
                        .labelsHidden()
                        .frame(width: 200)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
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
                    .padding(.top, 4)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            isTrusted = AXIsProcessTrusted()
        }
    }
}

struct TabsSettingsView: View {
    @AppStorage("tabOrderStr") private var tabOrderStr = "media,clipboard,dropzone,pomodoro,calculator,weather,system,agenda"
    @AppStorage("hiddenTabsStr") private var hiddenTabsStr = ""
    @AppStorage("appLanguage") private var appLanguage = "en" 

    
    @State private var tabs: [NotchTab] = []
    @State private var hiddenSet: Set<String> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LanguageManager.tr("Drag & Drop to reorder. Uncheck to hide."))
                .font(.subheadline)
                .foregroundColor(.gray)
            
            List {
                ForEach(tabs) { tab in
                    HStack {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.gray)
                            .imageScale(.large)
                            .padding(.trailing, 8)
                            
                        Toggle(isOn: Binding(
                            get: { !hiddenSet.contains(tab.rawValue) },
                            set: { isVisible in
                                if isVisible {
                                    hiddenSet.remove(tab.rawValue)
                                } else {
                                    hiddenSet.insert(tab.rawValue)
                                }
                                saveState()
                            }
                        )) {
                            Label(tab.displayName, systemImage: tab.rawValue)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onMove(perform: move)
            }
            .listStyle(PlainListStyle())
            .border(Color.gray.opacity(0.2), width: 1)
        }
        .onAppear(perform: loadState)
    }
    
    private func loadState() {
        let order = tabOrderStr.split(separator: ",").map(String.init)
        let hidden = hiddenTabsStr.split(separator: ",").map(String.init)
        
        hiddenSet = Set(hidden)
        
        var loadedTabs = order.compactMap { NotchTab(rawValue: $0) }
        
        for tab in NotchTab.allCases {
            if !loadedTabs.contains(tab) {
                loadedTabs.append(tab)
            }
        }
        tabs = loadedTabs
    }
    
    private func saveState() {
        tabOrderStr = tabs.map { $0.rawValue }.joined(separator: ",")
        hiddenTabsStr = Array(hiddenSet).joined(separator: ",")
    }
    
    private func move(from source: IndexSet, to destination: Int) {
        tabs.move(fromOffsets: source, toOffset: destination)
        saveState()
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("enableGlow") private var enableGlow = true
    @AppStorage("notchOpacity") private var notchOpacity: Double = 1.0
    @AppStorage("appLanguage") private var appLanguage = "en" 

    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text(LanguageManager.tr("Visual Effects"))
                        .font(.headline)
                    
                    Toggle(isOn: $enableGlow) {
                        VStack(alignment: .leading, spacing: 4) {
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
                    Text(LanguageManager.tr("Glass Transparency Level"))
                        .font(.headline)
                        
                    HStack(spacing: 12) {
                        Image(systemName: "circle.dotted")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                        
                        Slider(value: $notchOpacity, in: 0.5...1.0)
                        
                        Image(systemName: "circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
                    .padding(.top, 4)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
        }
        .padding()
    }
}
