import SwiftUI
import AppKit

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
            // Authentic macOS Desktop Wallpaper Background with Depth Blur
            WallpaperBackgroundView()
                .contentShape(Rectangle())
                .onTapGesture {
                    if appState.glyphState == .idle {
                        onUnlockRequested()
                    }
                }
            
            VStack(spacing: 0) {
                // Top Bar: Status indicators & Face ID Pill
                HStack {
                    // Left spacer
                    Spacer()
                        .frame(width: 140)
                    
                    Spacer()
                    
                    // Center: Face ID Status Pill
                    Button(action: {
                        onUnlockRequested()
                    }) {
                        HStack(spacing: 10) {
                            FaceIDGlyphView(state: appState.glyphState, size: 28)
                            Text(statusMessage)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.94))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .overlay(
                            Capsule()
                                .stroke(
                                    appState.glyphState == .scanning ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.25),
                                    lineWidth: 1.5
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    // Right: Native macOS status icons (Battery, Wi-Fi, ABC)
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(showPasswordError ? Color.red : Color.white.opacity(0.25), lineWidth: 1)
                    )
                    
                    // Face ID Trigger Button
                    Button(action: {
                        onUnlockRequested()
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
            }
        }
        .onReceive(timer) { input in
            currentTime = input
        }
    }
    
    private var statusMessage: String {
        switch appState.glyphState {
        case .idle:
            return "GlanceID Locked • Click to Glance"
        case .scanning:
            return "Verifying Face..."
        case .success:
            return "Unlocked"
        case .failure:
            return "Face not recognized. Click to retry"
        }
    }
    
    private func handlePasswordSubmit() {
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

/// Renders the real macOS desktop wallpaper dynamically with Apple's lock screen depth blur
struct WallpaperBackgroundView: View {
    @ObservedObject var wallpaperProvider = WallpaperProvider.shared
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let wallpaper = wallpaperProvider.wallpaperImage {
                    Image(nsImage: wallpaper)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: 8)
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
                
                // Authentic Apple lock screen darkening vignette gradient
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.35),
                        Color.black.opacity(0.08),
                        Color.black.opacity(0.45)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        }
        .onAppear {
            wallpaperProvider.reloadWallpaper()
        }
    }
}
