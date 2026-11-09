import Foundation
import AVFoundation
import AppKit

enum CameraAuthorizationStatus {
    case authorized
    case notDetermined
    case denied
    case restricted
}

protocol CameraFrameDelegate: AnyObject {
    func cameraDidOutput(pixelBuffer: CVPixelBuffer)
}

final class CameraManager: NSObject, ObservableObject {
    @Published var isRunning: Bool = false
    @Published var authStatus: CameraAuthorizationStatus = .notDetermined
    @Published var cameraName: String = "Detecting..."
    @Published var errorMessage: String? = nil
    
    let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.glanceid.sessionqueue", qos: .userInitiated)
    private let videoOutput = AVCaptureVideoDataOutput()
    private var isConfigured = false
    
    weak var frameDelegate: CameraFrameDelegate?
    
    var previewSession: AVCaptureSession {
        return captureSession
    }
    
    override init() {
        super.init()
        updateAuthStatus()
    }
    
    func updateAuthStatus() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async {
            switch status {
            case .authorized:
                self.authStatus = .authorized
                self.errorMessage = nil
            case .notDetermined:
                self.authStatus = .notDetermined
            case .denied:
                self.authStatus = .denied
                self.errorMessage = "Camera permission denied. Enable GlanceID in System Settings > Privacy & Security > Camera."
            case .restricted:
                self.authStatus = .restricted
                self.errorMessage = "Camera access restricted by system policy."
            @unknown default:
                self.authStatus = .denied
            }
        }
    }
    
    /// Explicitly requests camera access from macOS TCC, triggering the system dialog
    func requestAccess(completion: ((Bool) -> Void)? = nil) {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if currentStatus == .authorized {
            DispatchQueue.main.async {
                self.authStatus = .authorized
                self.errorMessage = nil
                completion?(true)
            }
            return
        }
        
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.updateAuthStatus()
                if granted {
                    self.errorMessage = nil
                } else {
                    self.errorMessage = "Camera access denied. Please allow camera access in System Settings."
                }
                completion?(granted)
            }
        }
    }
    
    /// Synchronously configures inputs and outputs on the sessionQueue
    private func configureSession() {
        guard !isConfigured else { return }
        
        captureSession.beginConfiguration()
        if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        }
        
        // Remove existing inputs/outputs
        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }
        for output in captureSession.outputs {
            captureSession.removeOutput(output)
        }
        
        // Search for built-in camera first, then external/continuity
        var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(macOS 14.0, *) {
            deviceTypes.append(.external)
        } else {
            deviceTypes.append(.externalUnknown)
        }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )
        
        let targetDevice = discovery.devices.first(where: { $0.deviceType == .builtInWideAngleCamera })
            ?? discovery.devices.first
            ?? AVCaptureDevice.default(for: .video)
        
        guard let device = targetDevice else {
            DispatchQueue.main.async {
                self.errorMessage = "No camera found on this Mac."
            }
            captureSession.commitConfiguration()
            return
        }
        
        DispatchQueue.main.async {
            self.cameraName = device.localizedName
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }
            
            captureSession.commitConfiguration()
            isConfigured = true
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Camera input error: \(error.localizedDescription)"
            }
            captureSession.commitConfiguration()
        }
    }
    
    func start() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized {
            startSessionRunning()
        } else if status == .notDetermined {
            requestAccess { [weak self] granted in
                if granted {
                    self?.startSessionRunning()
                }
            }
        } else {
            updateAuthStatus()
        }
    }
    
    private func startSessionRunning() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.isConfigured {
                self.configureSession()
            }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                DispatchQueue.main.async {
                    self.isRunning = self.captureSession.isRunning
                }
            }
        }
    }
    
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                DispatchQueue.main.async {
                    self.isRunning = false
                }
            }
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        frameDelegate?.cameraDidOutput(pixelBuffer: pixelBuffer)
    }
}
