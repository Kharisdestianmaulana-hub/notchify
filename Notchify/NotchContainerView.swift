import SwiftUI

struct NotchContainerView: View {
    @StateObject private var viewModel = NotchViewModel()
    
    // Geometry
    private let compactWidth: CGFloat = 180
    private let compactHeight: CGFloat = 32
    
    private let expandedWidth: CGFloat = 400
    private let expandedHeight: CGFloat = 160
    
    // We get topOffset to know if we should float or attach to the top edge
    private let topOffset: CGFloat = ScreenNotchDetector.topOffset
    
    var body: some View {
        VStack(spacing: 0) {
            // Gap for non-notch displays
            Spacer().frame(height: topOffset)
            
            // Main Pill/Notch Shape
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: viewModel.isExpanded ? 22 : 15, style: .continuous)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: viewModel.isExpanded ? 22 : 15, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                
                // Content
                VStack(spacing: 0) {
                    if viewModel.isExpanded {
                        MediaCardView(viewModel: viewModel)
                        
                        Divider().background(Color.white.opacity(0.1))
                            .padding(.horizontal, 20)
                        
                        ClipboardStackView(viewModel: viewModel)
                    } else {
                        // Compact state content (optional icon or just black bar)
                    }
                }
                .opacity(viewModel.isExpanded ? 1 : 0)
                // Add a slight delay to the content appearing for a smoother effect
                .animation(.easeInOut(duration: 0.2).delay(viewModel.isExpanded ? 0.1 : 0), value: viewModel.isExpanded)
                
            }
            .frame(
                width: viewModel.isExpanded ? expandedWidth : compactWidth,
                height: viewModel.isExpanded ? expandedHeight : compactHeight
            )
            // Use drawingGroup if performance issues arise, but standard animation is usually fine
            
            // We use onHover on the Shape itself to expand it
            .onHover { isHovering in
                withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                    viewModel.isExpanded = isHovering
                }
            }
            
            // Remaining space in the 300px fixed window frame
            Spacer()
        }
        // Force the whole view to take up the full NSWindow size so we never resize the NSWindow
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
