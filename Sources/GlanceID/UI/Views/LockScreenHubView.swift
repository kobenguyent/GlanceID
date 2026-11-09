import SwiftUI

struct LockScreenHubView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var lockManager = ScreenLockManager.shared
    @State private var pamStatusMessage: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 16) {
                    Image(systemName: "laptopcomputer.and.arrow.down")
                        .font(.system(size: 42))
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MacBook Face ID Lock & Unlock")
                            .font(.title2.bold())
                        Text("Secure your entire MacBook workspace with glance-and-unlock facial biometrics.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)
                
                Divider()
                
                // Primary Action Card: Lock Screen
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Full-Screen MacBook Lock")
                                    .font(.headline)
                                Text("Engages the authentic macOS lock screen with Face ID camera sensor glance.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            Button(action: {
                                lockManager.lockMacBook()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "lock.fill")
                                    Text("Lock MacBook Now")
                                }
                                .font(.headline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(!appState.isEnrolled)
                        }
                        
                        if !appState.isEnrolled {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Please enroll your face first to enable Face ID MacBook unlock.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        } else {
                            Text("💡 Tip: Look at the webcam when locked; GlanceID will authenticate in 0.5s and slide the screen away.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                }
                
                // Real macOS PAM Integration (Face ID for sudo & System Auth)
                GroupBox(label: Label("Terminal sudo Face ID Integration", systemImage: "terminal.fill")) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Just like Touch ID (`pam_tid.so`), you can enable Face ID for `sudo` in macOS Terminal using the included GlanceID PAM module.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quick Terminal Setup:")
                                .font(.subheadline.bold())
                            
                            Text("Run the setup script from the GlanceID folder:")
                                .font(.caption)
                            
                            Text("cd /Users/kobet/Desktop/projects/GlanceID && ./scripts/setup_sudo_faceid.sh")
                                .font(.system(.caption, design: .monospaced))
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(8)
                                .textSelection(.enabled)
                        }
                        
                        Text("Once enabled, running `sudo` triggers a 0.5s Face ID glance instead of prompting for your password.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                }
                
                // Real System Wake Monitor
                GroupBox(label: Label("Background Wake Monitor", systemImage: "eye.fill")) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Screen Wake Listener:")
                                .font(.subheadline)
                            Spacer()
                            Text("Active (com.apple.screenIsLocked)")
                                .font(.system(.caption, design: .monospaced).bold())
                                .foregroundColor(.green)
                        }
                        
                        Text("GlanceID automatically listens to macOS display wake and screen lock events to prepare instant biometric verification.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                }
            }
            .padding(24)
        }
    }
}
