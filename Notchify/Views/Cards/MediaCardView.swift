import SwiftUI
import AppKit

struct MediaCardView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var localElapsed: Double = 0
    @State private var isDraggingScrubber: Bool = false
    
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Group {
            if viewModel.showMediaLyrics {
                // Image 3: Side-by-Side Lyrics View
                expandedLyricsLayout
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                        removal: .opacity.combined(with: .scale(scale: 0.96))
                    ))
            } else {
                // Image 2: Standard Single-Card Player View
                standardPlayerLayout
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                        removal: .opacity.combined(with: .scale(scale: 0.96))
                    ))
            }
        }
        .onAppear {
            localElapsed = viewModel.elapsed
        }
        .onReceive(timer) { _ in
            if viewModel.isPlaying && !isDraggingScrubber {
                localElapsed = viewModel.elapsed
            }
        }
    }
    
    // MARK: - Image 2: Standard Player Layout (Lyrics Closed)
    private var standardPlayerLayout: some View {
        VStack(spacing: 12) {
            // Row 1: Artwork + Title/Artist + Chevron Expand Button
            HStack(spacing: 14) {
                albumArtView(size: 56)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.currentSong.isEmpty ? LanguageManager.tr("No music playing") : viewModel.currentSong)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(viewModel.currentArtist.isEmpty ? LanguageManager.tr("Media Player") : viewModel.currentArtist)
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Circular Chevron Button (expands to side-by-side lyrics)
                Button(action: {
                    viewModel.toggleMediaLyrics()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .help(LanguageManager.tr("Show Lyrics"))
            }
            
            // Row 2: Scrubber (03:13 ──[====]── -01:03)
            scrubberRow
            
            // Row 3: Lyrics Button + Centered Controls + Spacer
            HStack {
                // Lyrics Toggle Button (Image 2 style)
                Button(action: {
                    viewModel.toggleMediaLyrics()
                }) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .help(LanguageManager.tr("Search & display music lyrics"))
                
                Spacer()
                
                playbackButtonsRow
                
                Spacer()
                
                // Balancer so controls remain centered
                Color.clear.frame(width: 28, height: 28)
            }
        }
    }
    
    // MARK: - Image 3: Expanded Side-by-Side Lyrics Layout
    private var expandedLyricsLayout: some View {
        HStack(spacing: 16) {
            // LEFT COLUMN: Compact Media Controls (~235 pt)
            VStack(spacing: 11) {
                // Top Row: Album Art + Song & Artist
                HStack(spacing: 12) {
                    albumArtView(size: 46)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.currentSong.isEmpty ? LanguageManager.tr("No music playing") : viewModel.currentSong)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(viewModel.currentArtist.isEmpty ? LanguageManager.tr("Media Player") : viewModel.currentArtist)
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Scrubber Row
                scrubberRow
                
                // Bottom Controls Row with Active Lyrics Button
                HStack {
                    // Active Lyrics Button (quote.bubble.fill highlighted)
                    Button(action: {
                        viewModel.toggleMediaLyrics()
                    }) {
                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.24))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(LanguageManager.tr("Close Lyrics"))
                    
                    Spacer()
                    
                    playbackButtonsRow
                    
                    Spacer()
                    
                    Color.clear.frame(width: 28, height: 28)
                }
            }
            .frame(width: 236)
            
            // MIDDLE: Thin Vertical Divider Line
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 0.5)
                .padding(.vertical, 2)
            
            // RIGHT COLUMN: Synchronized Scrolling Lyrics (~260 pt)
            lyricsScrollView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Scrubber Row (03:13 ──[====]── -01:03)
    private var scrubberRow: some View {
        HStack(spacing: 8) {
            // Elapsed Time
            Text(formatTime(localElapsed))
                .font(.system(size: 11, weight: .semibold, design: .monospaced).monospacedDigit())
                .foregroundColor(.white)
            
            // Interactive Capsule Progress Slider
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let maxDur = max(1, viewModel.duration)
                let pct = max(0, min(1, localElapsed / maxDur))
                let fillWidth = max(0, min(totalWidth, totalWidth * CGFloat(pct)))
                
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.20))
                        .frame(height: 4.5)
                    
                    // Active progress fill
                    Capsule()
                        .fill(Color.white)
                        .frame(width: fillWidth, height: 4.5)
                }
                .frame(height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            isDraggingScrubber = true
                            let dragPct = max(0, min(1, val.location.x / totalWidth))
                            localElapsed = dragPct * maxDur
                        }
                        .onEnded { val in
                            let dragPct = max(0, min(1, val.location.x / totalWidth))
                            let targetTime = dragPct * maxDur
                            localElapsed = targetTime
                            viewModel.seek(to: targetTime)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isDraggingScrubber = false
                            }
                        }
                )
            }
            .frame(height: 14)
            
            // Negative Remaining Time
            Text(remainingTimeString)
                .font(.system(size: 11, weight: .semibold, design: .monospaced).monospacedDigit())
                .foregroundColor(.white.opacity(0.85))
        }
    }
    
    private var remainingTimeString: String {
        if viewModel.duration > 0 {
            let remain = max(0, viewModel.duration - localElapsed)
            return "-" + formatTime(remain)
        }
        return "-0:00"
    }
    
    // MARK: - Playback Buttons Row (<< || >>)
    private var playbackButtonsRow: some View {
        HStack(spacing: 18) {
            Button(action: {
                MediaRemoteHelper.shared.previousTrack()
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                MediaRemoteHelper.shared.togglePlayPause()
            }) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                MediaRemoteHelper.shared.nextTrack()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Album Artwork View
    @ViewBuilder
    private func albumArtView(size: CGFloat) -> some View {
        Button(action: {
            MediaRemoteHelper.shared.activatePlayerApp()
        }) {
            ZStack(alignment: .bottomTrailing) {
                if let img = viewModel.artwork {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                        .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: size, height: size)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: size * 0.38))
                                .foregroundColor(.white.opacity(0.5))
                        )
                }
                
                // Mini Player App Badge
                if let icon = viewModel.playerAppIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: size * 0.32, height: size * 0.32)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        .offset(x: 2, y: 2)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .help(viewModel.playerAppName.isEmpty ? LanguageManager.tr("Media Player") : "\(LanguageManager.tr("Open in")) \(viewModel.playerAppName)")
    }
    
    // MARK: - Lyrics Scroll View
    private var lyricsScrollView: some View {
        Group {
            if viewModel.isFetchingLyrics {
                VStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(LanguageManager.tr("Fetching synchronized lyrics online when playing music."))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.lyrics.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.35))
                    Text(LanguageManager.tr("No lyrics available"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Button(action: {
                        viewModel.fetchLyricsNow()
                    }) {
                        Text(LanguageManager.tr("Search"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 9) {
                            // Generous top spacer so even the first line can be centered
                            Color.clear.frame(height: 70)
                            
                            ForEach(Array(viewModel.lyrics.enumerated()), id: \.element.id) { index, line in
                                let isCurrent = index == viewModel.currentLyricIndex
                                Button(action: {
                                    viewModel.seek(to: line.time)
                                }) {
                                    Text(line.text)
                                        .font(.system(size: isCurrent ? 15.5 : 13, weight: isCurrent ? .bold : .medium, design: .rounded))
                                        .foregroundColor(isCurrent ? .white : .white.opacity(0.35))
                                        .shadow(color: isCurrent ? Color.white.opacity(0.45) : .clear, radius: 5)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: viewModel.currentLyricIndex)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .id(index)
                            }
                            
                            // Generous bottom spacer so even the last line can be centered
                            Color.clear.frame(height: 70)
                        }
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .black, location: 0.16),
                                .init(color: .black, location: 0.84),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .onChange(of: viewModel.currentLyricIndex) { idx in
                        if idx >= 0 {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                proxy.scrollTo(idx, anchor: .center)
                            }
                        }
                    }
                    .onChange(of: viewModel.lyrics.count) { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if viewModel.currentLyricIndex >= 0 {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    proxy.scrollTo(viewModel.currentLyricIndex, anchor: .center)
                                }
                            }
                        }
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if viewModel.currentLyricIndex >= 0 {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    proxy.scrollTo(viewModel.currentLyricIndex, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        guard !time.isNaN && !time.isInfinite else { return "0:00" }
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
