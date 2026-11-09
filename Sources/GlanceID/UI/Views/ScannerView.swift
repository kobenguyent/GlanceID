import SwiftUI

struct ScannerView: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var cameraManager: CameraManager
    @ObservedObject private var engine: FaceRecognitionEngine
    @State private var showLandmarkMesh: Bool = true
    
    init(appState: AppState) {
        self.appState = appState
        self._cameraManager = ObservedObject(wrappedValue: appState.cameraManager)
        self._engine = ObservedObject(wrappedValue: appState.engine)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Neural Vision Telemetry")
                        .font(.title2.bold())
                    Text("Live landmark detection & biometric feature print analysis")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Toggle("Face Mesh", isOn: $showLandmarkMesh)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                
                Button(action: {
                    if cameraManager.isRunning {
                        cameraManager.stop()
                    } else {
                        cameraManager.start()
                    }
                }) {
                    Label(
                        cameraManager.isRunning ? "Stop Camera" : "Start Camera",
                        systemImage: cameraManager.isRunning ? "video.slash.fill" : "video.fill"
                    )
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            // Viewport & Telemetry
            HStack(spacing: 16) {
                // Video Preview Box
                ZStack {
                    if cameraManager.isRunning {
                        CameraPreviewView(
                            session: cameraManager.previewSession,
                            mirrored: appState.isCameraMirrored
                        )
                        .clipped()
                        .cornerRadius(16)
                        
                        if showLandmarkMesh {
                            FaceMeshOverlay(
                                landmarkData: engine.landmarkData,
                                mirrored: appState.isCameraMirrored
                            )
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.8))
                            .overlay(
                                cameraStatusOverlay
                            )
                    }
                }
                .frame(minWidth: 420, minHeight: 320)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                
                // Telemetry Metrics Sidebar
                VStack(alignment: .leading, spacing: 14) {
                    Text("Biometric Telemetry")
                        .font(.headline)
                    
                    Divider()
                    
                    // Face Detection Status
                    MetricRow(
                        label: "Detection",
                        value: engine.landmarkData != nil ? "Tracked" : (cameraManager.isRunning ? "Searching..." : "No Face"),
                        color: engine.landmarkData != nil ? .green : .secondary
                    )
                    
                    // Capture Quality
                    MetricRow(
                        label: "Attention / Quality",
                        value: String(format: "%.0f%%", (engine.landmarkData?.quality ?? 0) * 100),
                        color: (engine.landmarkData?.quality ?? 0) > 0.4 ? .green : .orange
                    )
                    
                    // Roll & Yaw Angles
                    if let roll = engine.landmarkData?.roll {
                        MetricRow(
                            label: "Head Roll",
                            value: String(format: "%.1f°", roll * 180 / .pi),
                            color: .cyan
                        )
                    }
                    if let yaw = engine.landmarkData?.yaw {
                        MetricRow(
                            label: "Head Yaw",
                            value: String(format: "%.1f°", yaw * 180 / .pi),
                            color: .cyan
                        )
                    }
                    
                    // Distance to Enrolled Face
                    if let dist = engine.lastDistance {
                        MetricRow(
                            label: "Feature Distance",
                            value: String(format: "%.3f", dist),
                            color: dist <= appState.threshold ? .green : .red
                        )
                        
                        MetricRow(
                            label: "Threshold",
                            value: String(format: "%.2f", appState.threshold),
                            color: .secondary
                        )
                        
                        MetricRow(
                            label: "Match Verdict",
                            value: dist <= appState.threshold ? "MATCH" : "DIFF",
                            color: dist <= appState.threshold ? .green : .red
                        )
                    } else if appState.isEnrolled {
                        MetricRow(
                            label: "Distance Check",
                            value: engine.landmarkData != nil ? "Calculating..." : "Awaiting Face",
                            color: .secondary
                        )
                    } else {
                        MetricRow(
                            label: "Distance Check",
                            value: "No Face Enrolled",
                            color: .secondary
                        )
                    }
                    
                    Spacer()
                    
                    // Mirroring Toggle
                    Toggle("Mirror Webcam View", isOn: $appState.isCameraMirrored)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                .padding()
                .frame(width: 240)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(16)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .onAppear {
            cameraManager.start()
        }
        .onDisappear {
            cameraManager.stop()
        }
    }
    
    @ViewBuilder
    private var cameraStatusOverlay: some View {
        switch cameraManager.authStatus {
        case .denied:
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                Text("Camera Permission Denied")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("Enable GlanceID in macOS System Settings > Privacy & Security > Camera to use the scanner.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Button("Open System Settings") {
                    appState.openCameraPrivacySettings()
                }
                .buttonStyle(.borderedProminent)
            }
        case .restricted:
            VStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("Camera Restricted")
                    .font(.headline)
                Text("Camera access is restricted by system policy.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .notDetermined:
            VStack(spacing: 12) {
                Image(systemName: "camera.badge.ellipsis")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                Text("Camera Access Required")
                    .font(.headline)
                Text("Grant camera access to start live face scanning.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Grant Permission") {
                    cameraManager.requestAccess { granted in
                        if granted {
                            cameraManager.start()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        case .authorized:
            VStack(spacing: 12) {
                if let error = cameraManager.errorMessage {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                    Text("Camera Error")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    Button("Retry") {
                        cameraManager.start()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Image(systemName: "video.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Camera Stopped")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Button("Activate Camera") {
                        cameraManager.start()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .monospaced).bold())
                .foregroundColor(color)
        }
    }
}
