import SwiftUI

struct EnrollmentView: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var cameraManager: CameraManager
    @State private var inputName: String = NSFullUserName()
    @State private var isEnrolling: Bool = false
    @State private var statusMessage: String = ""
    @State private var isSuccess: Bool = false
    
    init(appState: AppState) {
        self.appState = appState
        self._cameraManager = ObservedObject(wrappedValue: appState.cameraManager)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 6) {
                Text("Enroll Face ID Profile")
                    .font(.title2.bold())
                Text("GlanceID analyzes your facial features and generates a local biometric embedding.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
            
            // Circular Camera Viewfinder
            ZStack {
                Circle()
                    .stroke(
                        isSuccess ? Color.green : (isEnrolling ? Color.accentColor : Color.secondary.opacity(0.3)),
                        lineWidth: 4
                    )
                    .frame(width: 220, height: 220)
                
                if cameraManager.isRunning {
                    CameraPreviewView(
                        session: cameraManager.previewSession,
                        mirrored: appState.isCameraMirrored
                    )
                    .clipShape(Circle())
                    .frame(width: 212, height: 212)
                } else {
                    Circle()
                        .fill(Color.black.opacity(0.75))
                        .frame(width: 212, height: 212)
                        .overlay(
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 70))
                                .foregroundColor(.secondary)
                        )
                }
                
                // Success overlay
                if isSuccess {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 212, height: 212)
                        .overlay(
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 72))
                                .foregroundColor(.green)
                        )
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            // Name Input Field
            VStack(alignment: .leading, spacing: 6) {
                Text("Profile Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Enter Name (e.g. Kobe)", text: $inputName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)
            }
            
            // Guidance / Status
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundColor(isSuccess ? .green : .secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Action Buttons
            HStack(spacing: 16) {
                Button(action: {
                    startEnrollment()
                }) {
                    HStack {
                        if isEnrolling {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.trailing, 4)
                        }
                        Text(isEnrolling ? "Scanning Face..." : "Start Enrollment")
                    }
                    .frame(minWidth: 160)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isEnrolling || inputName.isEmpty)
                
                if appState.isEnrolled {
                    Button("Reset Profile") {
                        appState.resetBiometrics()
                        isSuccess = false
                        statusMessage = "Biometric profile cleared."
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            cameraManager.start()
            if inputName.isEmpty {
                inputName = "Mac User"
            }
        }
        .onDisappear {
            cameraManager.stop()
        }
    }
    
    private func startEnrollment() {
        isEnrolling = true
        isSuccess = false
        statusMessage = "Look directly at the Mac camera..."
        
        appState.enrollUser(name: inputName) { success, message in
            DispatchQueue.main.async {
                self.isEnrolling = false
                self.isSuccess = success
                self.statusMessage = message
                
                if success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        appState.selectedTab = .simulator
                    }
                }
            }
        }
    }
}
