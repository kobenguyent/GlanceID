import SwiftUI

struct AppleLockGlyphView: View {
    var state: GlyphState
    var size: CGFloat = 32
    
    @State private var lockBouncing: Bool = false
    @State private var shackleOpen: Bool = false
    @State private var checkmarkScale: CGFloat = 0.5
    @State private var checkmarkOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            if state == .idle {
                // Closed Apple Lock Icon with gentle resting glow
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.72, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                    .transition(.scale.combined(with: .opacity))
            } else if state == .scanning {
                // Morph to animated Face ID scanning brackets
                FaceIDGlyphView(state: .scanning, size: size)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            } else if state == .success {
                // Spring-loaded Open Padlock & Green Checkmark Morph
                ZStack {
                    // Pulsing green aura ring
                    Circle()
                        .stroke(Color.green.opacity(0.4), lineWidth: 2)
                        .frame(width: size * 1.3, height: size * 1.3)
                        .scaleEffect(lockBouncing ? 1.25 : 0.8)
                        .opacity(lockBouncing ? 0.0 : 0.8)
                    
                    // Unlocked bouncing shackle
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: size * 0.75, weight: .bold))
                        .foregroundColor(.green)
                        .offset(y: lockBouncing ? -3 : 0)
                        .scaleEffect(lockBouncing ? 1.15 : 1.0)
                }
                .transition(.scale(scale: 1.2).combined(with: .opacity))
            } else if state == .failure {
                // Locked with alert shake
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.72, weight: .semibold))
                    .foregroundColor(.red.opacity(0.95))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: state)
        .onChange(of: state) { newState in
            if newState == .success {
                triggerUnlockSpring()
            }
        }
    }
    
    private func triggerUnlockSpring() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.45)) {
            lockBouncing = true
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.2)) {
            lockBouncing = false
        }
    }
}
