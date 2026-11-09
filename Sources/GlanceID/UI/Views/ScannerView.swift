import SwiftUI

struct ScannerView: View {
    @ObservedObject var appState: AppState
    @State private var showLandmarkMesh: Bool = true
    
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
                    if appState.cameraManager.isRunning {
                        appState.cameraManager.stop()
                    } else {
                        appState.cameraManager.start()
                    }
                }) {
                    Label(
                        appState.cameraManager.isRunning ? "Stop Camera" : "Start Camera",
                        systemImage: appState.cameraManager.isRunning ? "video.slash.fill" : "video.fill"
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
                    if appState.cameraManager.isRunning {
                        CameraPreviewView(session: appState.cameraManager.previewSession)
                            .clipped()
                            .cornerRadius(16)
                        
                        if showLandmarkMesh {
                            FaceMeshOverlay(
                                landmarkData: appState.engine.landmarkData,
                                mirrored: appState.isCameraMirrored
                            )
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.8))
                            .overlay(
                                VStack(spacing: 12) {
                                    Image(systemName: "video.slash")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary)
                                    Text("Camera Stopped")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Button("Activate Camera") {
                                        appState.cameraManager.start()
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
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
                        value: appState.engine.landmarkData != nil ? "Tracked" : "No Face",
                        color: appState.engine.landmarkData != nil ? .green : .secondary
                    )
                    
                    // Capture Quality
                    MetricRow(
                        label: "Attention / Quality",
                        value: String(format: "%.0f%%", (appState.engine.landmarkData?.quality ?? 0) * 100),
                        color: (appState.engine.landmarkData?.quality ?? 0) > 0.4 ? .green : .orange
                    )
                    
                    // Roll & Yaw Angles
                    if let roll = appState.engine.landmarkData?.roll {
                        MetricRow(
                            label: "Head Roll",
                            value: String(format: "%.1f°", roll * 180 / .pi),
                            color: .cyan
                        )
                    }
                    if let yaw = appState.engine.landmarkData?.yaw {
                        MetricRow(
                            label: "Head Yaw",
                            value: String(format: "%.1f°", yaw * 180 / .pi),
                            color: .cyan
                        )
                    }
                    
                    // Distance to Enrolled Face
                    if let dist = appState.engine.lastDistance {
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
                    } else {
                        MetricRow(
                            label: "Distance Check",
                            value: "Idle",
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
            appState.cameraManager.start()
        }
        .onDisappear {
            appState.cameraManager.stop()
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
