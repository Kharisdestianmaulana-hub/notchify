import SwiftUI
import AppKit

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

