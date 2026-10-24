import SwiftUI
import AppKit

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

