import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var updateManager = UpdateManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Software Update Section (GitHub Releases)
                GroupBox(label: Label("Software Update", systemImage: "arrow.triangle.2.circlepath.circle.fill")) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Text("GlanceID v\(updateManager.currentVersion)")
                                        .font(.subheadline.bold())
                                    Text("(\(updateManager.repoOwner)/\(updateManager.repoName))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let lastChecked = updateManager.lastCheckedDate {
                                    Text("Last checked: \(lastChecked.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Checks GitHub Releases for new versions and prebuilt .dmg/.zip installers.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if updateManager.status == .checking {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, 6)
                            }
                            
                            Button(updateManager.status == .checking ? "Checking..." : "Check for Updates") {
                                updateManager.checkForUpdates()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(updateManager.status == .checking)
                        }
                        
                        // Dynamic Update Status Banner
                        updateStatusBanner
                        
                        Divider()
                        
                        Toggle(isOn: $updateManager.autoCheckOnLaunch) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Automatically check for updates on launch")
                                    .font(.subheadline)
                                Text("Queries the GitHub Releases API in the background when GlanceID starts.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(8)
                }
                
                // Biometrics Settings
                GroupBox(label: Label("Biometrics Configuration", systemImage: "slider.horizontal.3")) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Feature Print Distance Threshold")
                                    .font(.subheadline.bold())
                                Text("Lower values are stricter (fewer false positives). Higher values are more lenient.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(String(format: "%.2f", appState.threshold))
                                .font(.system(.body, design: .monospaced).bold())
                                .foregroundColor(.accentColor)
                        }
                        
                        Slider(value: $appState.threshold, in: 0.28...0.52, step: 0.01) {
                            Text("Threshold")
                        } minimumValueLabel: {
                            Text("0.28 (Strict)")
                                .font(.caption2)
                        } maximumValueLabel: {
                            Text("0.52 (Lenient)")
                                .font(.caption2)
                        }
                    }
                    .padding(8)
                }
                
                // Anti-Spoofing & Liveness Protection
                GroupBox(label: Label("Anti-Spoofing & Liveness Protection", systemImage: "shield.lefthalf.filled")) {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle(isOn: $appState.requireLiveness) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Require Natural Blink Challenge")
                                    .font(.subheadline.bold())
                                Text("Prevents 2D printed photo and static screen spoofing by requiring physiological eye blink verification.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Standard 2D Webcam Protection Techniques:")
                                .font(.caption.bold())
                                .foregroundColor(.primary)
                            
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "eye.fill")
                                    .foregroundColor(.accentColor)
                                    .frame(width: 16)
                                Text("Eye Aspect Ratio (EAR) Blink Detection: Calculates eyelid contour dynamics to confirm live human eye motion.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "waveform.path.ecg")
                                    .foregroundColor(.accentColor)
                                    .frame(width: 16)
                                Text("Zero-Variance Filter: Rejects static printed photos and rigid screens with near-zero involuntary tremor.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "iphone.gen3")
                                    .foregroundColor(.accentColor)
                                    .frame(width: 16)
                                Text("Apple Continuity Camera: Mount an iPhone with TrueDepth to gain genuine hardware 3D IR point-cloud security.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(8)
                }
                
                // Hardware & Device
                GroupBox(label: Label("Hardware & Camera", systemImage: "camera.fill")) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Active Camera Device:")
                                .font(.subheadline)
                            Spacer()
                            Text(appState.cameraManager.cameraName)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Vision Engine:")
                                .font(.subheadline)
                            Spacer()
                            Text("Apple Vision (VNFeaturePrintRevision2)")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                }
                
                // Local Installation Without Apple Developer Account
                GroupBox(label: Label("Testing Without Apple Developer Account", systemImage: "laptopcomputer")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Unlike iOS, macOS does not mandate an active $99/year Apple Developer Membership for local machine testing.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("1. Ad-hoc Signing (Built-in Script)")
                                .font(.subheadline.bold())
                            Text("The project includes a ready-to-use `./scripts/install.sh` script that bundles the app, attaches `NSCameraUsageDescription`, signs ad-hoc (`codesign -s -`), and copies to `/Applications`.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("2. Free Apple ID (Personal Team)")
                                .font(.subheadline.bold())
                            Text("In Xcode Settings -> Accounts, you can add any standard Apple ID for a free 'Personal Team' signing identity.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("3. Camera Permissions (TCC)")
                                .font(.subheadline.bold())
                            Text("If macOS prompts 'GlanceID would like to access the camera', select 'Allow'. You can review it in System Settings -> Privacy & Security -> Camera.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                }
                
                // Profile Reset
                GroupBox(label: Label("Profile Management", systemImage: "trash")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Clear Enrolled Biometrics")
                                .font(.subheadline.bold())
                            Text("Permanently removes the local facial feature print.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Delete Profile", role: .destructive) {
                            appState.resetBiometrics()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!appState.isEnrolled)
                    }
                    .padding(8)
                }
            }
            .padding(24)
        }
    }
    
    @ViewBuilder
    private var updateStatusBanner: some View {
        switch updateManager.status {
        case .idle, .checking:
            EmptyView()
            
        case .upToDate(let currentVersion, _):
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                Text("GlanceID is up to date (v\(currentVersion)).")
                    .font(.caption.bold())
                    .foregroundColor(.primary)
                Spacer()
                Button("GitHub Releases") {
                    updateManager.openRepositoryReleasesPage()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.1)))
            
        case .noReleasesPublished(let currentVersion):
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                Text("Running latest version (v\(currentVersion)) — no newer GitHub releases published yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("View Releases") {
                    updateManager.openRepositoryReleasesPage()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.08)))
            
        case .updateAvailable(let release, let currentVersion, let latestVersion):
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.green)
                    Text("New Version Available: v\(latestVersion)")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text("(installed: v\(currentVersion))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                if let body = release.body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(body.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(4)
                }
                
                HStack(spacing: 12) {
                    Button {
                        updateManager.downloadPreferredAsset(for: release)
                    } label: {
                        if let asset = release.preferredInstallerAsset {
                            Label("Download \(asset.name)", systemImage: "arrow.down.circle.fill")
                        } else {
                            Label("Download Update", systemImage: "arrow.down.circle.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    
                    Button("View Release Notes on GitHub") {
                        updateManager.openReleasePage(release)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.12)))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.green.opacity(0.35), lineWidth: 1)
            )
            
        case .error(let message):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Open GitHub Releases") {
                    updateManager.openRepositoryReleasesPage()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.1)))
        }
    }
}
