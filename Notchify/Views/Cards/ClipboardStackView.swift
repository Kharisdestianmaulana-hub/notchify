import SwiftUI
import AppKit

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

