import SwiftUI

struct AuthenticationView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        ZStack {
            VStack(spacing: 28) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "faceid")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                    
                    Text("GlanceID")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    
                    Text("Simulate iOS Face ID biometric authentication on macOS")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 24)
                
                // Enrollment Status Card
                HStack(spacing: 16) {
                    Circle()
                        .fill(appState.isEnrolled ? Color.green : Color.orange)
                        .frame(width: 14, height: 14)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(appState.isEnrolled ? "Biometrics Active: \(appState.enrolledName)" : "No Face Enrolled")
                            .font(.headline)
                        
                        Text(appState.isEnrolled ? "Enrolled: \(appState.enrolledDate?.formatted(date: .abbreviated, time: .shortened) ?? "Recently")" : "Enroll your face to test authenticating.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if !appState.isEnrolled {
                        Button("Enroll Now") {
                            appState.selectedTab = .enrollment
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 32)
                
                // Camera Permission Warning / Action if needed
                if appState.cameraManager.authStatus == .denied {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Camera Permission Required")
                                .font(.headline)
                            Text("GlanceID needs camera access. Please enable it in macOS System Settings.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Open Settings") {
                            appState.openCameraPrivacySettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 32)
                } else if appState.cameraManager.authStatus == .notDetermined {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.badge.ellipsis")
                            .foregroundColor(.accentColor)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Camera Access Not Yet Granted")
                                .font(.headline)
                            Text("Click below to trigger the macOS camera permission prompt.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Allow Camera") {
                            appState.cameraManager.requestAccess()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding()
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 32)
                }
                
                // Big Face ID Trigger Button
                VStack(spacing: 16) {
                    Button(action: {
                        appState.triggerAuthentication()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "faceid")
                                .font(.system(size: 22, weight: .semibold))
                            Text("Glance to Authenticate")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(minWidth: 260)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Text("Press to activate camera & verify face with Vision")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                
                // Test Simulators & Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Simulation Actions")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            appState.triggerAuthentication {
                                appState.selectedTab = .vault
                            }
                        }) {
                            Label("Unlock Protected Vault", systemImage: "lock.open.fill")
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: {
                            appState.soundManager.playFaceIDSuccess()
                        }) {
                            Label("Play Chime", systemImage: "speaker.wave.2")
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: {
                            appState.soundManager.playFaceIDFailure()
                        }) {
                            Label("Play Rejection", systemImage: "speaker.slash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            
            // Floating Face ID HUD Modal Overlay (iOS Style)
            if appState.isHUDActive {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        appState.cancelAuthentication()
                    }
                
                VStack(spacing: 20) {
                    FaceIDGlyphView(state: appState.glyphState, size: 90)
                        .padding(.top, 8)
                    
                    VStack(spacing: 6) {
                        Text(appState.hudTitle)
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                        
                        Text(appState.hudSubtitle)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button("Cancel") {
                        appState.cancelAuthentication()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                }
                .padding(28)
                .frame(width: 280, height: 260)
                .background(.ultraThinMaterial)
                .cornerRadius(24)
                .shadow(color: .black.opacity(0.25), radius: 30, x: 0, y: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .transition(.scale(scale: 0.88).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: appState.isHUDActive)
    }
}
