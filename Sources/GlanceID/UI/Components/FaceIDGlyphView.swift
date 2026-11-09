import SwiftUI

enum GlyphState {
    case idle
    case scanning
    case success
    case failure
}

struct FaceIDGlyphView: View {
    var state: GlyphState
    var size: CGFloat = 84
    
    @State private var scanProgress: CGFloat = 0.0
    @State private var pulseScale: CGFloat = 1.0
    @State private var shakeOffset: CGFloat = 0.0
    
    var body: some View {
        ZStack {
            // Rounded Face ID outer corner brackets
            FaceIDBracketShape()
                .stroke(
                    bracketColor,
                    style: StrokeStyle(lineWidth: size * 0.065, lineCap: .round, lineJoin: .round)
                )
                .frame(width: size, height: size)
                .scaleEffect(pulseScale)
            
            // Inner Face Features or Checkmark
            if state == .success {
                // Morph to animated checkmark
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundColor(.green)
                    .transition(.scale.combined(with: .opacity))
            } else {
                // Stylized Face (Eyes, Nose, Mouth)
                ZStack {
                    // Scanning light sweep across the face
                    if state == .scanning {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, Color.blue.opacity(0.35), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: size * 0.8, height: size * 0.25)
                            .offset(y: (scanProgress - 0.5) * (size * 0.8))
                            .mask(FaceFeaturesShape())
                    }
                    
                    FaceFeaturesShape()
                        .stroke(
                            featureColor,
                            style: StrokeStyle(lineWidth: size * 0.055, lineCap: .round, lineJoin: .round)
                        )
                }
                .frame(width: size * 0.62, height: size * 0.62)
            }
        }
        .offset(x: shakeOffset)
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: state)
        .onChange(of: state) { newState in
            handleStateTransition(newState)
        }
        .onAppear {
            if state == .scanning {
                startScanningAnimation()
            }
        }
    }
    
    private var bracketColor: Color {
        switch state {
        case .idle:
            return Color.primary.opacity(0.85)
        case .scanning:
            return Color.accentColor
        case .success:
            return Color.green
        case .failure:
            return Color.red
        }
    }
    
    private var featureColor: Color {
        switch state {
        case .idle:
            return Color.primary.opacity(0.85)
        case .scanning:
            return Color.accentColor
        case .success:
            return Color.green
        case .failure:
            return Color.red.opacity(0.85)
        }
    }
    
    private func handleStateTransition(_ newState: GlyphState) {
        switch newState {
        case .scanning:
            startScanningAnimation()
        case .success:
            stopAnimations()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                pulseScale = 1.08
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.15)) {
                pulseScale = 1.0
            }
        case .failure:
            stopAnimations()
            triggerShake()
        case .idle:
            stopAnimations()
        }
    }
    
    private func startScanningAnimation() {
        withAnimation(Animation.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            pulseScale = 1.04
        }
        withAnimation(Animation.linear(duration: 1.4).repeatForever(autoreverses: true)) {
            scanProgress = 1.0
        }
    }
    
    private func stopAnimations() {
        pulseScale = 1.0
        scanProgress = 0.0
    }
    
    private func triggerShake() {
        let offsets: [CGFloat] = [-8, 8, -6, 6, -3, 3, 0]
        for (index, offset) in offsets.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.04) {
                self.shakeOffset = offset
            }
        }
    }
}

/// The 4 iconic corner brackets of the Face ID glyph
struct FaceIDBracketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let cornerLen = w * 0.28
        let radius = w * 0.22
        
        // Top-Left corner
        path.move(to: CGPoint(x: 0, y: cornerLen))
        path.addLine(to: CGPoint(x: 0, y: radius))
        path.addArc(
            center: CGPoint(x: radius, y: radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: cornerLen, y: 0))
        
        // Top-Right corner
        path.move(to: CGPoint(x: w - cornerLen, y: 0))
        path.addLine(to: CGPoint(x: w - radius, y: 0))
        path.addArc(
            center: CGPoint(x: w - radius, y: radius),
            radius: radius,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: w, y: cornerLen))
        
        // Bottom-Right corner
        path.move(to: CGPoint(x: w, y: h - cornerLen))
        path.addLine(to: CGPoint(x: w, y: h - radius))
        path.addArc(
            center: CGPoint(x: w - radius, y: h - radius),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: w - cornerLen, y: h))
        
        // Bottom-Left corner
        path.move(to: CGPoint(x: cornerLen, y: h))
        path.addLine(to: CGPoint(x: radius, y: h))
        path.addArc(
            center: CGPoint(x: radius, y: h - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: 0, y: h - cornerLen))
        
        return path
    }
}

/// The stylized inner face features (left eye, right eye, nose, smile)
struct FaceFeaturesShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Left Eye (vertical capsule line)
        path.move(to: CGPoint(x: w * 0.28, y: h * 0.28))
        path.addLine(to: CGPoint(x: w * 0.28, y: h * 0.40))
        
        // Right Eye (vertical capsule line)
        path.move(to: CGPoint(x: w * 0.72, y: h * 0.28))
        path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.40))
        
        // Nose (angled line + horizontal foot)
        path.move(to: CGPoint(x: w * 0.50, y: h * 0.36))
        path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.58))
        path.addLine(to: CGPoint(x: w * 0.46, y: h * 0.58))
        
        // Mouth (gentle smile curve)
        path.move(to: CGPoint(x: w * 0.28, y: h * 0.72))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.72, y: h * 0.72),
            control: CGPoint(x: w * 0.50, y: h * 0.86)
        )
        
        return path
    }
}
