import SwiftUI

/// A reusable SwiftUI Shape that renders four Apple-style rounded corner scanning brackets
/// (top-left, top-right, bottom-right, bottom-left) with configurable corner radius and arm length.
public struct ReticleBracketShape: Shape {
    public var cornerRadius: CGFloat
    public var bracketLength: CGFloat

    public init(cornerRadius: CGFloat = 16, bracketLength: CGFloat = 32) {
        self.cornerRadius = cornerRadius
        self.bracketLength = bracketLength
    }

    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(cornerRadius, bracketLength) }
        set {
            cornerRadius = newValue.first
            bracketLength = newValue.second
        }
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        guard w > 0, h > 0 else { return path }

        let minX = rect.minX
        let minY = rect.minY
        let maxX = rect.maxX
        let maxY = rect.maxY

        let maxDimension = min(w, h) / 2
        let radius = max(0, min(cornerRadius, maxDimension))
        let armLength = max(radius, min(bracketLength, maxDimension))

        guard armLength > 0 else { return path }

        // Top-Left corner
        path.move(to: CGPoint(x: minX, y: minY + armLength))
        if radius > 0 {
            path.addLine(to: CGPoint(x: minX, y: minY + radius))
            path.addArc(
                center: CGPoint(x: minX + radius, y: minY + radius),
                radius: radius,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
        } else {
            path.addLine(to: CGPoint(x: minX, y: minY))
        }
        path.addLine(to: CGPoint(x: minX + armLength, y: minY))

        // Top-Right corner
        path.move(to: CGPoint(x: maxX - armLength, y: minY))
        if radius > 0 {
            path.addLine(to: CGPoint(x: maxX - radius, y: minY))
            path.addArc(
                center: CGPoint(x: maxX - radius, y: minY + radius),
                radius: radius,
                startAngle: .degrees(270),
                endAngle: .degrees(0),
                clockwise: false
            )
        } else {
            path.addLine(to: CGPoint(x: maxX, y: minY))
        }
        path.addLine(to: CGPoint(x: maxX, y: minY + armLength))

        // Bottom-Right corner
        path.move(to: CGPoint(x: maxX, y: maxY - armLength))
        if radius > 0 {
            path.addLine(to: CGPoint(x: maxX, y: maxY - radius))
            path.addArc(
                center: CGPoint(x: maxX - radius, y: maxY - radius),
                radius: radius,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
        } else {
            path.addLine(to: CGPoint(x: maxX, y: maxY))
        }
        path.addLine(to: CGPoint(x: maxX - armLength, y: maxY))

        // Bottom-Left corner
        path.move(to: CGPoint(x: minX + armLength, y: maxY))
        if radius > 0 {
            path.addLine(to: CGPoint(x: minX + radius, y: maxY))
            path.addArc(
                center: CGPoint(x: minX + radius, y: maxY - radius),
                radius: radius,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
        } else {
            path.addLine(to: CGPoint(x: minX, y: maxY))
        }
        path.addLine(to: CGPoint(x: minX, y: maxY - armLength))

        return path
    }
}
