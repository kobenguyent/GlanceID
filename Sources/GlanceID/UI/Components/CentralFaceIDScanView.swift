import SwiftUI

/// Visual state for the Central Face ID scanning reticle
enum CentralScanVisualState: String, CaseIterable, Equatable {
    case searching
    case tracking
    case liveness
    case success
    case failure
}

/// A central, high-fidelity Apple-native biometric scanning HUD component that displays
/// the Apple Vision Pro holographic reticle during face scanning.
struct CentralFaceIDScanView: View {
    @ObservedObject var appState: AppState
    var size: CGFloat
    var overrideState: CentralScanVisualState?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Animations
    @State private var laserBeamOffset: CGFloat = 0.0
    @State private var breathingScale: CGFloat = 1.0
    @State private var reticleScale: CGFloat = 1.0
    @State private var checkmarkPop: Bool = false
    @State private var shockwaveScale: CGFloat = 0.85
    @State private var shockwaveOpacity: Double = 0.0
    @State private var shakeOffset: CGFloat = 0.0
    @State private var livenessPulseScale: CGFloat = 1.0
    @State private var livenessPulseOpacity: Double = 0.8

    init(appState: AppState, size: CGFloat = 150, overrideState: CentralScanVisualState? = nil) {
        self.appState = appState
        self.size = size
        self.overrideState = overrideState
    }

    /// Resolves the current visual state from AppState telemetry
    var visualState: CentralScanVisualState {
        if let override = overrideState {
            return override
        }
        return CentralFaceIDScanView.resolveState(
            glyphState: appState.glyphState,
            isFaceTracked: appState.isFaceTracked,
            requireLiveness: appState.requireLiveness,
            engineState: appState.engine.state,
            livenessConfirmed: appState.engine.livenessDetector.isLivenessConfirmed
        )
    }

    static func resolveState(
        glyphState: GlyphState,
        isFaceTracked: Bool,
        requireLiveness: Bool,
        engineState: RecognitionState? = nil,
        livenessConfirmed: Bool = false
    ) -> CentralScanVisualState {
        switch glyphState {
        case .success:
            return .success
        case .failure:
            return .failure
        case .scanning:
            if isFaceTracked {
                if requireLiveness && !livenessConfirmed {
                    return .liveness
                }
                return .tracking
            } else {
                return .searching
            }
        case .idle:
            return .searching
        }
    }

    static func caption(for state: CentralScanVisualState) -> String {
        switch state {
        case .searching:
            return "Looking for face..."
        case .tracking:
            return "Face Captured • Verifying..."
        case .liveness:
            return "Blink naturally to unlock"
        case .success:
            return "GlanceID Authenticated"
        case .failure:
            return "Position Face in Camera"
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                // 1. Success Shockwave Ripple (expands outside reticle)
                if visualState == .success {
                    Circle()
                        .stroke(Color.green.opacity(shockwaveOpacity), lineWidth: 2.5)
                        .frame(width: size * shockwaveScale, height: size * shockwaveScale)
                        .blur(radius: 1.5)
                }

                // 2. Ambient Breathing Aura Glow
                ambientAuraGlow

                // 3. Frosted backdrop squircle/circle with thin border
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
                    .scaleEffect(reticleScale)

                // 4. Sweeping vertical laser beam in searching state
                if visualState == .searching {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.cyan.opacity(0.15),
                            Color.cyan.opacity(0.7),
                            Color.cyan.opacity(0.15),
                            Color.clear
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: size, height: 26)
                    .offset(y: laserBeamOffset)
                    .clipShape(Circle())
                    .scaleEffect(reticleScale)
                }

                // 5. Biometric Quality Ring Arc (in tracking and liveness)
                if (visualState == .tracking || visualState == .liveness) && appState.scanQuality > 0.01 {
                    Circle()
                        .trim(from: 0, to: CGFloat(min(max(appState.scanQuality, 0.05), 1.0)))
                        .stroke(
                            qualityRingColor,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: size * 0.94, height: size * 0.94)
                        .animation(.easeInOut(duration: 0.2), value: appState.scanQuality)
                }

                // 6. Eye Gaze Focus Dots (in tracking and liveness)
                if visualState == .tracking || visualState == .liveness {
                    eyeGazeDotsView
                }

                // 7. Corner Brackets (ReticleBracketShape)
                cornerBracketsView

                // 8. Success Checkmark Pop
                if visualState == .success {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                        .scaleEffect(checkmarkPop ? 1.0 : 0.2)
                        .opacity(checkmarkPop ? 1.0 : 0.0)
                        .shadow(color: Color.green.opacity(0.6), radius: 8)
                }

                // 9. Failure State Icon
                if visualState == .failure {
                    Image(systemName: "faceid")
                        .font(.system(size: size * 0.36, weight: .medium, design: .rounded))
                        .foregroundColor(.red.opacity(0.9))
                        .shadow(color: Color.red.opacity(0.5), radius: 8)
                }
            }
            .frame(width: size, height: size)
            .offset(x: shakeOffset)

            // Caption
            Text(CentralFaceIDScanView.caption(for: visualState))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.92))
                .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 1.5)
                .animation(.easeInOut(duration: 0.2), value: visualState)
        }
        .onAppear {
            startAnimations(for: visualState)
        }
        .onChange(of: visualState) { newState in
            startAnimations(for: newState)
        }
        .onChange(of: reduceMotion) { _ in
            startAnimations(for: visualState)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var ambientAuraGlow: some View {
        switch visualState {
        case .searching:
            Circle()
                .fill(Color.cyan.opacity(0.25))
                .frame(width: size * 1.15, height: size * 1.15)
                .blur(radius: 12)
                .scaleEffect(breathingScale)
        case .tracking, .liveness:
            Circle()
                .fill(Color.cyan.opacity(0.3))
                .frame(width: size * 1.12, height: size * 1.12)
                .blur(radius: 10)
        case .success:
            Circle()
                .fill(Color.green.opacity(0.35))
                .frame(width: size * 1.18, height: size * 1.18)
                .blur(radius: 14)
        case .failure:
            Circle()
                .fill(Color.red.opacity(0.3))
                .frame(width: size * 1.15, height: size * 1.15)
                .blur(radius: 12)
        }
    }

    private var cornerBracketsView: some View {
        let config = bracketConfiguration
        return ReticleBracketShape(
            cornerRadius: config.cornerRadius,
            bracketLength: config.bracketLength
        )
        .stroke(
            config.color,
            style: StrokeStyle(lineWidth: config.lineWidth, lineCap: .round, lineJoin: .round)
        )
        .frame(width: config.frameSize, height: config.frameSize)
        .scaleEffect(reticleScale)
        .shadow(color: config.shadowColor, radius: config.shadowRadius)
        .animation(reduceMotion ? .none : .spring(response: 0.32, dampingFraction: 0.68), value: visualState)
        .animation(reduceMotion ? .none : .spring(response: 0.32, dampingFraction: 0.68), value: appState.isFaceTracked)
    }

    private var eyeGazeDotsView: some View {
        let leftPoint = calculateEyePosition(
            points: appState.currentLandmarks?.leftEye ?? [],
            defaultRelativePoint: CGPoint(x: 0.36, y: 0.42)
        )
        let rightPoint = calculateEyePosition(
            points: appState.currentLandmarks?.rightEye ?? [],
            defaultRelativePoint: CGPoint(x: 0.64, y: 0.42)
        )

        return ZStack {
            eyeDot(at: leftPoint)
            eyeDot(at: rightPoint)
        }
    }

    private func eyeDot(at point: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(Color.cyan.opacity(0.35))
                .frame(width: 14, height: 14)
                .blur(radius: 2)

            Circle()
                .fill(Color.cyan)
                .frame(width: 8, height: 8)
                .shadow(color: Color.cyan, radius: 4)

            if visualState == .liveness {
                Circle()
                    .stroke(Color.cyan.opacity(livenessPulseOpacity), lineWidth: 1.5)
                    .frame(width: 18 * livenessPulseScale, height: 18 * livenessPulseScale)
            }
        }
        .position(point)
        .animation(reduceMotion ? .none : .spring(response: 0.25, dampingFraction: 0.75), value: point)
    }

    // MARK: - Helpers

    private var qualityRingColor: Color {
        appState.scanQuality > 0.5 ? Color.green : Color.cyan
    }

    private func calculateEyePosition(points: [CGPoint], defaultRelativePoint: CGPoint) -> CGPoint {
        guard !points.isEmpty else {
            return CGPoint(x: defaultRelativePoint.x * size, y: defaultRelativePoint.y * size)
        }
        let avgX = points.reduce(0.0) { $0 + $1.x } / CGFloat(points.count)
        let avgY = points.reduce(0.0) { $0 + $1.y } / CGFloat(points.count)

        // Invert Y for SwiftUI top-down coordinate system
        let normY = 1.0 - avgY
        let normX = appState.isCameraMirrored ? (1.0 - avgX) : avgX

        // Inset into reticle frame so gaze dots smoothly track inside the viewfinder
        let mappedX = size * (0.15 + (normX * 0.70))
        let mappedY = size * (0.15 + (normY * 0.70))
        return CGPoint(x: mappedX, y: mappedY)
    }

    private struct BracketConfig {
        let cornerRadius: CGFloat
        let bracketLength: CGFloat
        let frameSize: CGFloat
        let lineWidth: CGFloat
        let color: Color
        let shadowColor: Color
        let shadowRadius: CGFloat
    }

    private var bracketConfiguration: BracketConfig {
        switch visualState {
        case .searching:
            return BracketConfig(
                cornerRadius: size * 0.22,
                bracketLength: size * 0.22,
                frameSize: size * 0.94,
                lineWidth: 3.0,
                color: Color.cyan.opacity(0.7),
                shadowColor: Color.cyan.opacity(0.35),
                shadowRadius: 6
            )
        case .tracking:
            return BracketConfig(
                cornerRadius: size * 0.16,
                bracketLength: size * 0.28,
                frameSize: size * 0.88,
                lineWidth: 3.5,
                color: Color.cyan,
                shadowColor: Color.cyan.opacity(0.6),
                shadowRadius: 8
            )
        case .liveness:
            return BracketConfig(
                cornerRadius: size * 0.16,
                bracketLength: size * 0.28,
                frameSize: size * 0.88,
                lineWidth: 3.5,
                color: Color.cyan,
                shadowColor: Color.cyan.opacity(0.6),
                shadowRadius: 8
            )
        case .success:
            return BracketConfig(
                cornerRadius: size * 0.20,
                bracketLength: size * 0.26,
                frameSize: size * 0.90,
                lineWidth: 3.5,
                color: Color.green,
                shadowColor: Color.green.opacity(0.65),
                shadowRadius: 10
            )
        case .failure:
            return BracketConfig(
                cornerRadius: size * 0.20,
                bracketLength: size * 0.22,
                frameSize: size * 0.92,
                lineWidth: 3.0,
                color: Color.red.opacity(0.9),
                shadowColor: Color.red.opacity(0.45),
                shadowRadius: 8
            )
        }
    }

    private func startAnimations(for state: CentralScanVisualState) {
        if reduceMotion {
            laserBeamOffset = 0
            breathingScale = 1.0
            shockwaveScale = 1.0
            shockwaveOpacity = 0.0
            checkmarkPop = (state == .success)
            shakeOffset = 0
            reticleScale = 1.0
            return
        }

        switch state {
        case .searching:
            checkmarkPop = false
            shockwaveOpacity = 0.0
            shockwaveScale = 0.85
            shakeOffset = 0
            reticleScale = 1.0

            withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                breathingScale = 1.05
            }

            laserBeamOffset = -size * 0.45
            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: true)) {
                laserBeamOffset = size * 0.45
            }

        case .tracking:
            breathingScale = 1.0
            checkmarkPop = false
            shockwaveOpacity = 0.0
            shakeOffset = 0

            withAnimation(.spring(response: 0.32, dampingFraction: 0.68)) {
                reticleScale = 1.0
            }

        case .liveness:
            breathingScale = 1.0
            checkmarkPop = false
            shockwaveOpacity = 0.0
            shakeOffset = 0

            livenessPulseScale = 1.0
            livenessPulseOpacity = 0.85
            withAnimation(Animation.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                livenessPulseScale = 1.5
                livenessPulseOpacity = 0.15
            }

        case .success:
            breathingScale = 1.0
            shakeOffset = 0

            reticleScale = 0.90
            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                reticleScale = 1.0
                checkmarkPop = true
            }

            shockwaveScale = 0.85
            shockwaveOpacity = 0.8
            withAnimation(.easeOut(duration: 0.7)) {
                shockwaveScale = 1.6
                shockwaveOpacity = 0.0
            }

        case .failure:
            breathingScale = 1.0
            checkmarkPop = false
            shockwaveOpacity = 0.0
            reticleScale = 1.0

            shakeOffset = 0
            withAnimation(Animation.easeInOut(duration: 0.07).repeatCount(5, autoreverses: true)) {
                shakeOffset = 8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                shakeOffset = 0
            }
        }
    }
}
