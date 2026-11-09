import SwiftUI

struct VaultView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack {
            if appState.isVaultUnlocked {
                unlockedContent
            } else {
                lockedPlaceholder
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var lockedPlaceholder: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 6) {
                Text("Developer Vault Locked")
                    .font(.title2.bold())
                Text("Authenticate with GlanceID Face ID simulation to reveal secrets.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                appState.triggerAuthentication()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "faceid")
                    Text("Unlock with Face ID")
                }
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 10)
        }
    }
    
    private var unlockedContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.open.fill")
                            .foregroundColor(.green)
                        Text("Vault Unlocked")
                            .font(.title2.bold())
                    }
                    Text("Authenticated via GlanceID • \(appState.lastUnlockTime?.formatted(date: .omitted, time: .standard) ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Lock Vault") {
                    withAnimation {
                        appState.isVaultUnlocked = false
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(.bottom, 8)
            
            // Mock Secret Cards
            VStack(spacing: 12) {
                SecretCard(
                    title: "Developer Identity",
                    icon: "person.text.rectangle",
                    value: "ID: \(appState.enrolledName) (Authenticated via Facial Vector)"
                )
                
                SecretCard(
                    title: "Mock Production API Key",
                    icon: "key.fill",
                    value: "mock_vault_key_948194829410948291048201948291048"
                )
                
                SecretCard(
                    title: "Mock Encrypted Note",
                    icon: "note.text",
                    value: "macOS simulated Face ID using AVFoundation + Apple Vision Framework."
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
}

struct SecretCard: View {
    let title: String
    let icon: String
    let value: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
