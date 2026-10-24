import SwiftUI

// MARK: - Notch Shape
struct NotchShape: Shape {
    var cornerRadius: CGFloat
    var flareRadius: CGFloat = 12
    
    var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let leftX = flareRadius
        let rightX = rect.maxX - flareRadius
        
        path.move(to: CGPoint(x: 0, y: 0))
        path.addArc(
            center: CGPoint(x: 0, y: flareRadius),
            radius: flareRadius,
            startAngle: .degrees(270),
            endAngle: .degrees(360),
            clockwise: false
        )
        
        path.addLine(to: CGPoint(x: leftX, y: rect.maxY - cornerRadius))
        
        path.addArc(
            center: CGPoint(x: leftX + cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(90),
            clockwise: true
        )
        
        path.addLine(to: CGPoint(x: rightX - cornerRadius, y: rect.maxY))
        
        path.addArc(
            center: CGPoint(x: rightX - cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(90),
            endAngle: .degrees(0),
            clockwise: true
        )
        
        path.addLine(to: CGPoint(x: rightX, y: flareRadius))
        
        path.addArc(
            center: CGPoint(x: rect.maxX, y: flareRadius),
            radius: flareRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        
        path.closeSubpath()
        return path
    }
}

