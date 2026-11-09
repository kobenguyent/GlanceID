import SwiftUI

struct FullscreenLockScreenView: View {
    @ObservedObject var appState: AppState
    var onUnlockRequested: () -> Void
    var onPasswordUnlocked: () -> Void
    
    @State private var currentTime = Date()
    @State private var passwordInput: String = ""
    @State private var showPasswordError: Bool = false
    @State private var timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Dynamic blurred wallpaper background
            WallpaperBackgroundView()
            
            VStack(spacing: 0) {
                // Top Face ID Status Pill
                HStack(spacing: 10) {
                    FaceIDGlyphView(state: appState.glyphState, size: 28)
                    Text(statusMessage)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .padding(.top, 40)
                
                Spacer()
                
                // Clock & Date (Native macOS Style)
                VStack(spacing: 8) {
                    Text(currentTime.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 96, weight: .thin, design: .default))
                        .foregroundColor(.white)
                    
                    Text(currentTime.formatted(.dateTime.weekday(.wide).month().day()))
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
                
                Spacer()
                
                // User Profile & Face ID Trigger
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 88, height: 88)
                            .overlay(
                                Circle()
                                    .stroke(appState.glyphState == .success ? Color.green : Color.white.opacity(0.3), lineWidth: 3)
                            )
                        
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Text(appState.isEnrolled ? appState.enrolledName : NSFullUserName())
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    // Fallback Password input or Face ID button
                    HStack(spacing: 8) {
                        SecureField("Enter Password", text: $passwordInput)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.35))
                            .cornerRadius(18)
                            .foregroundColor(.white)
                            .frame(width: 180)
                            .onSubmit {
                                handlePasswordSubmit()
                            }
                        
                        Button(action: {
                            handlePasswordSubmit()
                        }) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(showPasswordError ? Color.red : Color.white.opacity(0.25), lineWidth: 1)
                    )
                    
                    // Face ID retry button
                    Button(action: {
                        onUnlockRequested()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "faceid")
                            Text("Glance to Unlock")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.bottom, 60)
            }
        }
        .onReceive(timer) { input in
            currentTime = input
        }
        .onAppear {
            onUnlockRequested()
        }
    }
    
    private var statusMessage: String {
        switch appState.glyphState {
        case .idle:
            return "Glance at camera to unlock"
        case .scanning:
            return "Recognizing face..."
        case .success:
            return "Unlocked"
        case .failure:
            return "Try Again"
        }
    }
    
    private func handlePasswordSubmit() {
        // Allow fallback password unlock (or empty press for quick testing)
        if !passwordInput.isEmpty || !appState.isEnrolled {
            onPasswordUnlocked()
        } else {
            showPasswordError = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showPasswordError = false
            }
        }
    }
}

struct WallpaperBackgroundView: View {
    var body: some View {
        ZStack {
            // Elegant macOS Sonoma / Sequoia mesh gradient styling
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.14, blue: 0.22),
                    Color(red: 0.08, green: 0.10, blue: 0.16),
                    Color(red: 0.04, green: 0.05, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Soft atmospheric lighting orbs
            Circle()
                .fill(Color.blue.opacity(0.18))
                .blur(radius: 120)
                .offset(x: -200, y: -200)
            
            Circle()
                .fill(Color.purple.opacity(0.15))
                .blur(radius: 140)
                .offset(x: 250, y: 150)
        }
    }
}
