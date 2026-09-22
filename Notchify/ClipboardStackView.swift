import SwiftUI
import AppKit

struct ClipboardStackView: View {
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Recent Clipboard")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
            
            if viewModel.clipboardItems.isEmpty {
                Text("No recent items")
                    .foregroundColor(.gray)
                    .font(.footnote)
                    .padding(.bottom, 12)
            } else {
                ForEach(viewModel.clipboardItems, id: \.self) { item in
                    Button(action: {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(item, forType: .string)
                    }) {
                        Text(item)
                            .lineLimit(1)
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 12)
            }
        }
    }
}
