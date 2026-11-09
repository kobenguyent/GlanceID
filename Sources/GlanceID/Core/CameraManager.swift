import Foundation
import AVFoundation
import CoreImage

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
    
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.glanceid.sessionqueue", qos: .userInitiated)
    private let videoOutput = AVCaptureVideoDataOutput()
    
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
            case .notDetermined:
                self.authStatus = .notDetermined
            case .denied:
                self.authStatus = .denied
            case .restricted:
                self.authStatus = .restricted
            @unknown default:
                self.authStatus = .denied
            }
        }
    }
    
    func requestAccess(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.updateAuthStatus()
                completion(granted)
            }
        }
    }
    
    func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.captureSession.isRunning {
                return
            }
            
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .high
            
            // Remove existing inputs/outputs
            for input in self.captureSession.inputs {
                self.captureSession.removeInput(input)
            }
            for output in self.captureSession.outputs {
                self.captureSession.removeOutput(output)
            }
            
            // Discover suitable camera (FaceTime HD camera / built-in / continuity)
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
            
            guard let device = discovery.devices.first ?? AVCaptureDevice.default(for: .video) else {
                DispatchQueue.main.async {
                    self.errorMessage = "No camera found on this Mac."
                }
                self.captureSession.commitConfiguration()
                return
            }
            
            DispatchQueue.main.async {
                self.cameraName = device.localizedName
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                }
                
                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                self.videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                ]
                self.videoOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
                
                if self.captureSession.canAddOutput(self.videoOutput) {
                    self.captureSession.addOutput(self.videoOutput)
                }
                
                self.captureSession.commitConfiguration()
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Camera input error: \(error.localizedDescription)"
                }
                self.captureSession.commitConfiguration()
            }
        }
    }
    
    func start() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.setupSession()
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
