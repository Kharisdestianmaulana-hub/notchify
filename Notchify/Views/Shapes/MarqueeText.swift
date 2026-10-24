import SwiftUI

// MARK: - Marquee Text
struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    
    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var animating = false
    
    var body: some View {
        GeometryReader { geo in
            let needsScroll = textWidth > geo.size.width
            
            ZStack(alignment: .leading) {
                if needsScroll {
                    HStack(spacing: 40) {
                        textView
                        textView
                    }
                    .offset(x: offset)
                    .onAppear {
                        containerWidth = geo.size.width
                        startScrolling()
                    }
                } else {
                    textView
                }
            }
            .frame(width: geo.size.width, alignment: .leading)
            .clipped()
        }
        .frame(height: 16)
        .onChange(of: text) { _ in
            startScrolling()
        }
    }
    
    private var textView: some View {
        Text(text)
            .font(font)
            .foregroundColor(color)
            .lineLimit(1)
            .fixedSize()
            .background(GeometryReader { g in
                Color.clear
                    .onAppear { textWidth = g.size.width }
                    .onChange(of: g.size.width) { newWidth in
                        textWidth = newWidth
                        startScrolling()
                    }
            })
    }
    
    private func startScrolling() {
        guard textWidth > containerWidth else { 
            withAnimation(nil) { offset = 0 }
            return 
        }
        
        withAnimation(nil) {
            offset = 0
        }
        
        let scrollDistance = textWidth + 40
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard textWidth > containerWidth else { return }
            withAnimation(.linear(duration: Double(scrollDistance) / 30.0).repeatForever(autoreverses: false)) {
                offset = -scrollDistance
            }
        }
    }
}



