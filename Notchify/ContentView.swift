import SwiftUI
import AppKit

// MARK: - Notch Container View
struct ContentView: View {
    @StateObject private var viewModel = NotchViewModel()
    @ObservedObject private var privacy = PrivacyMonitor.shared
    @ObservedObject private var cameraManager = CameraMirrorManager.shared
    
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
    
    private let clockWidth: CGFloat = 175
    private let mediaWidth: CGFloat = 265
    private let compactHeight: CGFloat = 34
    private let expandedWidth: CGFloat = 420
    private let expandedHeight: CGFloat = 175
    
    @State private var previousApp: NSRunningApplication?
    @State private var blossomHeight: CGFloat = 0
    @State private var isHiddenByFullscreen: Bool = false
    @State private var isPomodoroInMainIsland: Bool = false
    @State private var pauseGraceTimer: Timer? = nil
    
    private var currentWidth: CGFloat {
        if viewModel.isExpanded {
            if viewModel.selectedTab == .media && viewModel.showMediaLyrics {
                return 560
            }
            return expandedWidth
        }
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
            if viewModel.selectedTab == .calculator { return 285 }
            if viewModel.selectedTab == .media {
                return viewModel.showMediaLyrics ? 195 : 172
            }
            if viewModel.selectedTab == .weather { return 175 }
            if viewModel.selectedTab == .system { return 225 }
            if viewModel.selectedTab == .agenda { return viewModel.isPinningExpansion ? 370 : 285 }
            if viewModel.selectedTab == .pomodoro { return 195 }
            if viewModel.selectedTab == .dropzone { return viewModel.stagedFiles.isEmpty ? 190 : 205 }
            if viewModel.selectedTab == .clipboard { return viewModel.clipboardItems.isEmpty ? 190 : 245 }
            if viewModel.selectedTab == .mirror { return 360 }
            if viewModel.selectedTab == .notes { return 280 }
            if viewModel.selectedTab == .network { return 255 }
            return 160
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
                        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
                        .notchGlowShadow(enableGlow: enableGlow, isPlaying: viewModel.isPlaying, accentColor: viewModel.accentColor)
                        .animation(.easeInOut(duration: 0.8), value: viewModel.accentColor)
                
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
                                
                                NotchMascotCompanionView(viewModel: viewModel, size: 28)
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
                                .compositingGroup()
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
                            
                            // Persistent Global Tab Pagination Dots across all tabs
                            tabPaginationDotsView
                                .padding(.bottom, 8)
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
                                CompactClockView(viewModel: viewModel)
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
                            viewModel.notifyUserActivity()
                            if expandTrigger == "hover" {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    guard !viewModel.isHoveringWithFile else { return }
                                    guard !viewModel.showDropSuccessHUD else { return }
                                    if viewModel.isPomodoroActive && isPomodoroInMainIsland {
                                        viewModel.selectedTab = .pomodoro
                                    }
                                    withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.76, blendDuration: 0.08)) {
                                        viewModel.isExpanded = true
                                    }
                                    capturePreviousApp()
                                    NSApp.activate(ignoringOtherApps: true)
                                }
                            }
                        } else {
                            DispatchQueue.main.asyncAfter(deadline: .now() + autoHideDelay) {
                                guard !viewModel.isHoveringWithFile else { return }
                                guard !viewModel.showDropSuccessHUD else { return }
                                guard !viewModel.isPinningExpansion else { return }
                                guard !showTabPicker else { return }
                                withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.76, blendDuration: 0.08)) {
                                    viewModel.isExpanded = false
                                }
                                restorePreviousAppFocus()
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
            .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.72, blendDuration: 0), value: viewModel.showMediaLyrics)
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
                    withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.76, blendDuration: 0.08)) {
                        viewModel.isExpanded = true
                    }
                    capturePreviousApp()
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleNotchify"))) { _ in
                if !viewModel.isExpanded && viewModel.isPomodoroActive && isPomodoroInMainIsland {
                    viewModel.selectedTab = .pomodoro
                }
                withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.76, blendDuration: 0.08)) {
                    viewModel.isExpanded.toggle()
                }
                if viewModel.isExpanded {
                    capturePreviousApp()
                    NSApp.activate(ignoringOtherApps: true)
                } else {
                    restorePreviousAppFocus()
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
                    withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.76, blendDuration: 0.08)) {
                        viewModel.isExpanded = false
                    }
                }
            }
            .onChange(of: enableLyrics) { enabled in
                if enabled {
                    if !viewModel.currentSong.isEmpty {
                        viewModel.fetchLyricsNow()
                    }
                } else {
                    viewModel.lyrics = []
                }
            }
            .onChange(of: viewModel.selectedTab) { newTab in
                if newTab != .mirror && !cameraManager.isRecordingVideo {
                    CameraMirrorManager.shared.stopSession()
                }
            }
            .onChange(of: viewModel.isExpanded) { isExpanded in
                if !isExpanded {
                    showTabPicker = false
                    if !cameraManager.isRecordingVideo {
                        CameraMirrorManager.shared.stopSession()
                    }
                    restorePreviousAppFocus()
                }
            }
            .onChange(of: cameraManager.isRecordingVideo) { isRecording in
                if !isRecording && (!viewModel.isExpanded || viewModel.selectedTab != .mirror) {
                    cameraManager.stopSession()
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
                            withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.76, blendDuration: 0.08)) {
                                viewModel.isExpanded = false
                            }
                            restorePreviousAppFocus()
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
            
            // Left Detached Video Recording Island (Active when collapsed & recording video)
            if cameraManager.isRecordingVideo && !viewModel.isExpanded {
                let sideIslandGap: CGFloat = 28
                let sideIslandY: CGFloat = 3.5
                VideoRecordingIslandView(viewModel: viewModel, cameraManager: cameraManager)
                    .frame(width: 250, alignment: .trailing)
                    .offset(x: -(currentWidth / 2) - sideIslandGap - 125, y: isHiddenByFullscreen ? -80 : sideIslandY)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .scale(scale: 0.8)).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .scale(scale: 0.8)).combined(with: .opacity)
                    ))
                    .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.55, blendDuration: 0), value: currentWidth)
                    .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.6), value: cameraManager.isRecordingVideo)
                    .opacity(isHiddenByFullscreen ? 0 : notchOpacity)
            }
            
            // Left Privacy Indicator (Camera & Microphone Island) - Repels outward on blossom & expansion
            // Only displayed when video recording island is NOT active to avoid duplicate/overlapping indicators
            if (privacy.isCameraActive || privacy.isMicActive) && !(cameraManager.isRecordingVideo && !viewModel.isExpanded) {
                let sideIslandGap: CGFloat = 28
                let sideIslandY: CGFloat = 3.5
                PrivacyIndicatorView()
                    .frame(width: 250, alignment: .trailing)
                    .offset(x: -(currentWidth / 2) - sideIslandGap - 125, y: isHiddenByFullscreen ? -80 : sideIslandY)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .scale(scale: 0.8)).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .scale(scale: 0.8)).combined(with: .opacity)
                    ))
                    .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.55, blendDuration: 0), value: currentWidth)
                    .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.6), value: privacy.isCameraActive)
                    .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.6), value: privacy.isMicActive)
                    .opacity(isHiddenByFullscreen ? 0 : notchOpacity)
            }
            
            // Right Detached Pomodoro Timer Island - Repels outward on blossom & absorbs into main island
            if viewModel.isPomodoroActive && !viewModel.isExpanded && !viewModel.showTimesUp && !isPomodoroInMainIsland {
                let sideIslandGap: CGFloat = 28
                let sideIslandY: CGFloat = 3.5
                DetachedPomodoroView(viewModel: viewModel)
                    .frame(width: 250, alignment: .leading)
                    .offset(x: (currentWidth / 2) + sideIslandGap + 125, y: isHiddenByFullscreen ? -80 : sideIslandY)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .scale(scale: 0.8)).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .scale(scale: 0.5)).combined(with: .opacity)
                    ))
                    .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.55, blendDuration: 0), value: currentWidth)
                    .animation(.spring(response: 0.45, dampingFraction: 0.72), value: isPomodoroInMainIsland)
                    .animation(.spring(response: 0.4, dampingFraction: 0.65), value: viewModel.isPomodoroActive)
                    .opacity(isHiddenByFullscreen ? 0 : notchOpacity)
            }
            
            // Smart Meeting Auto-Joiner Side Island (Blossoms 2 minutes before meeting)
            if let meeting = viewModel.upcomingMeetingEvent, !viewModel.isExpanded {
                let sideIslandGap: CGFloat = 28
                let sideIslandY: CGFloat = 3.5
                let isPomodoroOnRight = viewModel.isPomodoroActive && !viewModel.showTimesUp && !isPomodoroInMainIsland
                let isLeftOccupied = (privacy.isCameraActive || privacy.isMicActive) || cameraManager.isRecordingVideo
                let leftExtraOffset: CGFloat = cameraManager.isRecordingVideo ? 85 : ((privacy.isCameraActive || privacy.isMicActive) ? 60 : 0)
                let meetingIslandWidth: CGFloat = 300
                
                MeetingAlertIslandView(viewModel: viewModel, event: meeting)
                    .frame(width: meetingIslandWidth, alignment: isPomodoroOnRight ? .trailing : .leading)
                    .offset(
                        x: isPomodoroOnRight
                            ? (-(currentWidth / 2) - sideIslandGap - leftExtraOffset - (meetingIslandWidth / 2))
                            : ((currentWidth / 2) + sideIslandGap + (meetingIslandWidth / 2)),
                        y: isHiddenByFullscreen ? -80 : sideIslandY
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: isPomodoroOnRight ? .trailing : .leading).combined(with: .scale(scale: 0.8)).combined(with: .opacity),
                        removal: .move(edge: isPomodoroOnRight ? .trailing : .leading).combined(with: .scale(scale: 0.6)).combined(with: .opacity)
                    ))
                    .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.55, blendDuration: 0), value: currentWidth)
                    .animation(.spring(response: 0.45, dampingFraction: 0.72), value: viewModel.upcomingMeetingEvent)
                    .animation(.spring(response: 0.45, dampingFraction: 0.72), value: isPomodoroOnRight)
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
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)) { _ in
            checkFullscreen()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                checkFullscreen()
            }
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)) { _ in
            checkFullscreen()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                checkFullscreen()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                checkFullscreen()
            }
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didDeactivateApplicationNotification)) { _ in
            checkFullscreen()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didHideApplicationNotification)) { _ in
            checkFullscreen()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didUnhideApplicationNotification)) { _ in
            checkFullscreen()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            checkFullscreen()
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            checkFullscreen()
        }
    }
    
    private func checkFullscreen() {
        DispatchQueue.global(qos: .userInteractive).async {
            guard let screen = NSScreen.main else { return }
            let screenFrame = screen.frame
            
            // 1. Identify the frontmost active application
            guard let frontmostApp = NSWorkspace.shared.frontmostApplication else { return }
            
            // If Notchify itself is frontmost (e.g. user clicked notch), do not change state
            if frontmostApp.bundleIdentifier == Bundle.main.bundleIdentifier {
                return
            }
            
            // If user switched to Finder, they are on the desktop workspace
            if frontmostApp.bundleIdentifier == "com.apple.finder" {
                DispatchQueue.main.async {
                    if self.isHiddenByFullscreen {
                        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.75, blendDuration: 0.08)) {
                            self.isHiddenByFullscreen = false
                        }
                    }
                }
                return
            }
            
            let frontPID = frontmostApp.processIdentifier
            let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
            
            let topInset = max(screen.safeAreaInsets.top, 0)
            let maxTopInset = max(topInset, 44.0)
            
            var frontAppHasVisibleLayer0 = false
            var frontAppHasFullscreen = false
            var topmostLayer0Fullscreen = false
            
            for window in windowList {
                guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
                      let layer = window[kCGWindowLayer as String] as? Int,
                      let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                      let windowWidth = bounds["Width"],
                      let windowHeight = bounds["Height"] else { continue }
                
                // Skip Notchify's own windows
                if ownerPID == ProcessInfo.processInfo.processIdentifier { continue }
                // Only evaluate standard application windows (layer 0)
                guard layer == 0 else { continue }
                
                // Ignore tiny utility, cursor, tooltip or hidden zero-alpha windows
                guard windowWidth > 200 && windowHeight > 200 else { continue }
                if let alpha = window[kCGWindowAlpha as String] as? Double, alpha < 0.1 { continue }
                
                let windowX = bounds["X"] ?? 0
                let windowY = bounds["Y"] ?? 0
                let windowBottom = windowY + windowHeight
                
                // Check if this window covers the screen:
                // - Horizontally: windowWidth >= screenFrame.width - 16 and windowX <= 16
                // - Vertically: window reaches or exceeds screen height (or height minus notch safe area), and bottom touches screen bottom
                let coversWidth = (windowWidth >= screenFrame.width - 16) && (windowX <= 16)
                let coversHeight = (windowHeight >= screenFrame.height - 16 || windowHeight >= screenFrame.height - maxTopInset - 16) && (windowBottom >= screenFrame.height - 16)
                
                let isFullscreen = coversWidth && coversHeight
                
                if ownerPID == frontPID {
                    frontAppHasVisibleLayer0 = true
                    if isFullscreen {
                        frontAppHasFullscreen = true
                        break // Found frontmost app's fullscreen window!
                    }
                } else if !topmostLayer0Fullscreen && isFullscreen {
                    topmostLayer0Fullscreen = true
                }
            }
            
            // If the frontmost active app has standard visible windows, its state dictates whether fullscreen is active
            let otherAppIsFullscreen: Bool
            if frontAppHasVisibleLayer0 {
                otherAppIsFullscreen = frontAppHasFullscreen
            } else {
                otherAppIsFullscreen = topmostLayer0Fullscreen
            }
            
            DispatchQueue.main.async {
                if otherAppIsFullscreen != self.isHiddenByFullscreen {
                    withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.75, blendDuration: 0.08)) {
                        self.isHiddenByFullscreen = otherAppIsFullscreen
                    }
                }
            }
        }
    }
    
    private var isSettingsOrOnboardingOpen: Bool {
        NSApp.windows.contains { window in
            window.isVisible &&
            window.level == .normal &&
            !(window is NotchPanel) &&
            !NSStringFromClass(type(of: window)).contains("StatusBar")
        }
    }
    
    private func capturePreviousApp() {
        guard !isSettingsOrOnboardingOpen else { return }
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = frontmost
        }
    }
    
    private func restorePreviousAppFocus() {
        guard !isSettingsOrOnboardingOpen else { return }
        
        let mouseLoc = NSEvent.mouseLocation
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? (NSScreen.main?.frame.height ?? 1080)
        let quartzMouse = CGPoint(x: mouseLoc.x, y: primaryScreenHeight - mouseLoc.y)
        
        var activatedTargetApp = false
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        
        for window in windowList {
            guard let pidNumber = window[kCGWindowOwnerPID as String] as? NSNumber else { continue }
            let ownerPID = pidNumber.int32Value
            guard ownerPID != ProcessInfo.processInfo.processIdentifier else { continue }
            
            let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? -1
            guard layer == 0 else { continue }
            
            let alpha = (window[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1.0
            guard alpha > 0.1 else { continue }
            
            if let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
               let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) {
                if rect.width > 40 && rect.height > 40 && rect.contains(quartzMouse) {
                    if let app = NSRunningApplication(processIdentifier: ownerPID),
                       app.activationPolicy == .regular {
                        app.activate(options: .activateIgnoringOtherApps)
                        activatedTargetApp = true
                        break
                    }
                }
            }
        }
        
        if !activatedTargetApp {
            if let previous = previousApp, !previous.isTerminated {
                previous.activate(options: .activateIgnoringOtherApps)
            } else {
                NSApp.deactivate()
            }
        } else {
            NSApp.deactivate()
        }
    }
    
    // MARK: - Global Tab Pagination Dots (Persistent across all tabs)
    private var tabPaginationDotsView: some View {
        HStack(spacing: 5) {
            ForEach(visibleTabs, id: \.self) { tab in
                let isCurrent = tab == viewModel.selectedTab
                Button(action: {
                    withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.72)) {
                        viewModel.selectedTab = tab
                    }
                }) {
                    if isCurrent {
                        Capsule()
                            .fill(Color.white.opacity(0.95))
                            .frame(width: 14, height: 3.5)
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 3.5, height: 3.5)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help(tab.displayName)
            }
        }
    }
}
