import SwiftUI
import AppKit
import Combine

struct FullscreenLockScreenView: View {
    @ObservedObject var appState: AppState
    var screen: NSScreen? = nil
    var isPrimary: Bool = true
    var onUnlockRequested: () -> Void
    var onPasswordUnlocked: () -> Void
    
    @State private var currentTime = Date()
    @State private var passwordInput: String = ""
    @State private var showPasswordError: Bool = false
    @State private var isSlidingUp: Bool = false
    @State private var slideOffset: CGFloat = 0.0
    @State private var contentOpacity: Double = 1.0
    @State private var wallpaperBlur: CGFloat = 8.0
    @FocusState private var isPasswordFieldFocused: Bool
    @State private var timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Authentic macOS Desktop Wallpaper Background with dynamic unblur
                WallpaperBackgroundView(screen: screen, blurRadius: wallpaperBlur)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !isSlidingUp {
                            onUnlockRequested()
                        }
                    }
                
                // Floating Lock Screen Foreground Interface (Slides Up on Face ID Unlock)
                VStack(spacing: 0) {
                    // Top Bar: Native macOS status indicators & Apple Lock Morph Pill
                    HStack {
                        Spacer()
                            .frame(width: 140)
                        
                        Spacer()
                        
                        // Center: Interactive Apple Face ID Morph Pill on primary; subtle status on secondary
                        if isPrimary {
                            Button(action: {
                                if !isSlidingUp {
                                    onUnlockRequested()
                                }
                            }) {
                                HStack(spacing: 9) {
                                    AppleLockGlyphView(state: appState.glyphState, size: 22)
                                    
                                    Text(statusMessage)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.95))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(20)
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            appState.glyphState == .scanning ? Color.accentColor.opacity(0.85) : (appState.glyphState == .success ? Color.green.opacity(0.8) : Color.white.opacity(0.25)),
                                            lineWidth: 1.5
                                        )
                                )
                                .shadow(color: appState.glyphState == .success ? Color.green.opacity(0.4) : Color.black.opacity(0.2), radius: 10)
                            }
                            .buttonStyle(.plain)
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: appState.glyphState == .success ? "lock.open.fill" : "lock.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(appState.glyphState == .success ? .green : .white.opacity(0.7))
                                Text(appState.glyphState == .success ? "Unlocked" : "GlanceID Locked")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                        }
                        
                        Spacer()
                        
                        // Right: Native macOS status icons
                        HStack(spacing: 14) {
                            Text("ABC")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                            
                            Image(systemName: "wifi")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.85))
                            
                            HStack(spacing: 4) {
                                Text("100%")
                                    .font(.system(size: 11, weight: .medium))
                                Image(systemName: "battery.100")
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(.white.opacity(0.85))
                        }
                        .frame(width: 140, alignment: .trailing)
                        .padding(.trailing, 28)
                    }
                    .padding(.top, 24)
                    
                    Spacer()
                    
                    // Clock & Date (Native macOS Style)
                    VStack(spacing: 6) {
                        Text(currentTime.formatted(.dateTime.hour().minute()))
                            .font(.system(size: 108, weight: .thin, design: .default))
                            .foregroundColor(.white)
                        
                        Text(currentTime.formatted(.dateTime.weekday(.wide).month().day()))
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4)
                    
                    Spacer()
                    
                    if isPrimary {
                        // User Profile & Face ID Trigger
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 84, height: 84)
                                    .overlay(
                                        Circle()
                                            .stroke(appState.glyphState == .success ? Color.green : Color.white.opacity(0.35), lineWidth: 3)
                                    )
                                
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                            
                            Text(appState.isEnrolled ? appState.enrolledName : NSFullUserName())
                                .font(.title3.bold())
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
                            
                            // Fallback Password input
                            HStack(spacing: 8) {
                                SecureField("Enter Password", text: $passwordInput)
                                    .focused($isPasswordFieldFocused)
                                    .textFieldStyle(.plain)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(Color.black.opacity(0.35))
                                    .cornerRadius(18)
                                    .foregroundColor(.white)
                                    .frame(width: 175)
                                    .onSubmit {
                                        handlePasswordSubmit()
                                    }
                                
                                Button(action: {
                                    handlePasswordSubmit()
                                }) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.white.opacity(0.85))
                                }
                                .buttonStyle(.plain)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                ScreenLockManager.shared.focusPrimaryLockWindow()
                                isPasswordFieldFocused = true
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(showPasswordError ? Color.red : (isPasswordFieldFocused ? Color.white.opacity(0.55) : Color.white.opacity(0.25)), lineWidth: 1)
                            )
                            
                            // Face ID Trigger Button
                            Button(action: {
                                if !isSlidingUp {
                                    onUnlockRequested()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "faceid")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text(appState.glyphState == .scanning ? "Scanning Face..." : "Glance to Unlock")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .foregroundColor(.white.opacity(0.95))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(
                                    appState.glyphState == .scanning ? Color.accentColor.opacity(0.8) : Color.white.opacity(0.18)
                                )
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                        }
                        .padding(.bottom, 50)
                    } else {
                        // Secondary screen subtle click-to-unlock hint
                        VStack(spacing: 8) {
                            Button(action: {
                                if !isSlidingUp {
                                    onUnlockRequested()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "faceid")
                                        .font(.system(size: 14))
                                    Text("Click to Glance & Unlock")
                                        .font(.subheadline.weight(.medium))
                                }
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.bottom, 60)
                    }
                }
                .offset(y: slideOffset)
                .opacity(contentOpacity)
                
                // Central Apple Vision Pro Face ID Scanning Reticle HUD
                if isPrimary && (appState.glyphState == .scanning || appState.glyphState == .success || appState.glyphState == .failure) {
                    CentralFaceIDScanView(appState: appState, size: 160)
                        .allowsHitTesting(false)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                        .offset(y: slideOffset)
                        .opacity(contentOpacity)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: appState.glyphState)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .onAppear {
                if isPrimary {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        ScreenLockManager.shared.focusPrimaryLockWindow()
                        isPasswordFieldFocused = true
                    }
                }
            }
            .onChange(of: appState.glyphState) { newState in
                if newState == .success && !isSlidingUp {
                    performSlideUpUnlock(screenHeight: geo.size.height)
                } else if isPrimary && (newState == .failure || newState == .idle) {
                    ScreenLockManager.shared.focusPrimaryLockWindow()
                    isPasswordFieldFocused = true
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onReceive(timer) { input in
            currentTime = input
        }
    }
    
    private var statusMessage: String {
        switch appState.glyphState {
        case .idle:
            return "GlanceID Locked • Click to Glance"
        case .scanning:
            if appState.requireLiveness && appState.engine.state == .analyzing {
                return "Face Matched • Blink to Unlock"
            }
            return "Verifying Face..."
        case .success:
            return "Unlocked"
        case .failure:
            return "Face not recognized. Click to retry"
        }
    }
    
    private func performSlideUpUnlock(screenHeight: CGFloat) {
        isSlidingUp = true
        
        // Brief pause (0.35s) so the user enjoys the open padlock spring bounce & chime
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            // Swift spring curve matching iOS lock screen slide-up
            withAnimation(.spring(response: 0.52, dampingFraction: 0.85)) {
                slideOffset = -screenHeight * 1.1
                wallpaperBlur = 0.0
                contentOpacity = 0.0
            }
            
            // Dismiss window once slide-up clears the screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                onPasswordUnlocked()
            }
        }
    }
    
    private func handlePasswordSubmit() {
        if !passwordInput.isEmpty || !appState.isEnrolled {
            ScreenLockManager.shared.cancelActiveGlanceScan()
            appState.soundManager.playFaceIDSuccess()
            withAnimation {
                appState.glyphState = .success
            }
        } else {
            showPasswordError = true
            appState.soundManager.playFaceIDFailure()
            isPasswordFieldFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showPasswordError = false
            }
        }
    }
}

/// Renders the real macOS desktop wallpaper dynamically with Apple's lock screen depth blur
struct WallpaperBackgroundView: View {
    @ObservedObject var wallpaperProvider = WallpaperProvider.shared
    var screen: NSScreen? = nil
    var blurRadius: CGFloat = 8.0
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                let wallpaper = wallpaperProvider.wallpaper(for: screen)
                if let wallpaper = wallpaper {
                    Image(nsImage: wallpaper)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: blurRadius)
                        .scaleEffect(1.04) // Scales slightly to prevent edge bleed from blur
                } else {
                    // Sleek gradient fallback
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.14, blue: 0.22),
                            Color(red: 0.08, green: 0.10, blue: 0.16),
                            Color(red: 0.04, green: 0.05, blue: 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        }
    }
}
