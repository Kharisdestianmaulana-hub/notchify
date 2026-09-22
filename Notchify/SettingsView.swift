import SwiftUI
import AppKit

struct SettingsView: View {
    private enum Tabs: Hashable {
        case general, tabs, appearance
    }
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("Umum", systemImage: "gearshape")
                }
                .tag(Tabs.general)
            
            TabsSettingsView()
                .tabItem {
                    Label("Menu & Fitur", systemImage: "square.grid.2x2")
                }
                .tag(Tabs.tabs)
                
            AppearanceSettingsView()
                .tabItem {
                    Label("Personalisasi", systemImage: "paintpalette")
                }
                .tag(Tabs.appearance)
        }
        .padding(20)
        .frame(width: 450, height: 420)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("enableGlow") private var enableGlow = true
    @AppStorage("expandTrigger") private var expandTrigger = "hover"
    @AppStorage("autoHideDelay") private var autoHideDelay = 0.5
    
    @State private var isTrusted = AXIsProcessTrusted()
    
    var body: some View {
        Form {
            Section(header: Text("Perilaku Notch").font(.headline)) {
                Picker("Cara membuka Notch:", selection: $expandTrigger) {
                    Text("Sentuh kursor (Hover)").tag("hover")
                    Text("Klik langsung (Click)").tag("click")
                }
                .pickerStyle(RadioGroupPickerStyle())
                
                Picker("Kecepatan menutup otomatis:", selection: $autoHideDelay) {
                    Text("Kilat (0.1 detik)").tag(0.1)
                    Text("Standar (0.5 detik)").tag(0.5)
                    Text("Lambat (1.5 detik)").tag(1.5)
                }
                .padding(.top, 8)
            }
            
            Divider().padding(.vertical, 8)
            
            Section(header: Text("Pintasan Keyboard (Shortcut)").font(.headline)) {
                Text("Buka/Tutup Notchify dari mana saja menggunakan Cmd + Shift + N")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack {
                    Circle()
                        .fill(isTrusted ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(isTrusted ? "Izin Aksesibilitas Aktif" : "Butuh Izin Aksesibilitas")
                        .font(.system(size: 12))
                    
                    if !isTrusted {
                        Button("Beri Izin") {
                            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                            AXIsProcessTrustedWithOptions(options as CFDictionary)
                        }
                        .controlSize(.small)
                    }
                }
                .padding(.top, 4)
                .onAppear {
                    isTrusted = AXIsProcessTrusted()
                }
            }
        }
    }
}

struct TabsSettingsView: View {
    @AppStorage("tabOrderStr") private var tabOrderStr = "media,clipboard,dropzone,pomodoro,calculator,weather,system,agenda"
    @AppStorage("hiddenTabsStr") private var hiddenTabsStr = ""
    
    @State private var tabs: [NotchTab] = []
    @State private var hiddenSet: Set<String> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Geser (Drag & Drop) untuk mengatur urutan. Hilangkan centang untuk menyembunyikan.")
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
    
    var body: some View {
        Form {
            Section(header: Text("Efek Visual").font(.headline)) {
                Toggle("Gunakan efek cahaya (Glow) di belakang Notch", isOn: $enableGlow)
                Text("Mematikan fitur ini dapat menghemat penggunaan CPU/GPU pada Mac yang lebih tua.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Divider().padding(.vertical, 8)
            
            Section(header: Text("Tingkat Transparansi Kaca").font(.headline)) {
                HStack {
                    Text("Tembus Pandang")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Slider(value: $notchOpacity, in: 0.5...1.0)
                    Text("Solid")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}
