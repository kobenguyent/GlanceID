import Foundation
import Vision
import CoreImage
import CoreVideo

struct FaceLandmarkData {
    let boundingBox: CGRect
    let roll: Double?
    let yaw: Double?
    let quality: Float
    let leftEye: [CGPoint]
    let rightEye: [CGPoint]
    let nose: [CGPoint]
    let lips: [CGPoint]
    let contour: [CGPoint]
}

enum RecognitionState: Equatable {
    case idle
    case searching
    case tracking(quality: Float)
    case analyzing
    case authenticated(userName: String, distance: Float)
    case unrecognized(distance: Float)
    case noFaceDetected
}

final class FaceRecognitionEngine: ObservableObject, CameraFrameDelegate {
    @Published var state: RecognitionState = .idle
    @Published var landmarkData: FaceLandmarkData? = nil
    @Published var lastDistance: Float? = nil
    @Published var isAuthenticating: Bool = false
    @Published var isEnrolling: Bool = false
    
    private var isProcessingFrame = false
    private let processingQueue = DispatchQueue(label: "com.glanceid.visionqueue", qos: .userInitiated)
    
    // Last extracted feature print
    private var currentFeaturePrint: VNFeaturePrintObservation?
    
    // Enrollment state
    private var enrollmentCompletion: ((Result<VNFeaturePrintObservation, Error>) -> Void)?
    
    // Authentication state
    private var authCompletion: ((Bool, Float, String?) -> Void)?
    private var targetThreshold: Float = 0.42
    
    func reset() {
        state = .idle
        landmarkData = nil
        lastDistance = nil
        isAuthenticating = false
        isEnrolling = false
        currentFeaturePrint = nil
    }
    
    func startAuthentication(threshold: Float = 0.42, completion: @escaping (Bool, Float, String?) -> Void) {
        self.targetThreshold = threshold
        self.authCompletion = completion
        self.isAuthenticating = true
        self.state = .searching
    }
    
    func startEnrollment(completion: @escaping (Result<VNFeaturePrintObservation, Error>) -> Void) {
        self.enrollmentCompletion = completion
        self.isEnrolling = true
        self.state = .searching
    }
    
    // MARK: - CameraFrameDelegate
    func cameraDidOutput(pixelBuffer: CVPixelBuffer) {
        // Drop frame if already processing previous frame to prevent backlog
        guard !isProcessingFrame else { return }
        isProcessingFrame = true
        
        processingQueue.async { [weak self] in
            defer { self?.isProcessingFrame = false }
            self?.processFrame(pixelBuffer: pixelBuffer)
        }
    }
    
    private func processFrame(pixelBuffer: CVPixelBuffer) {
        let landmarksRequest = VNDetectFaceLandmarksRequest()
        let qualityRequest = VNDetectFaceCaptureQualityRequest()
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        
        do {
            try handler.perform([landmarksRequest, qualityRequest])
        } catch {
            DispatchQueue.main.async {
                self.landmarkData = nil
                self.state = .noFaceDetected
            }
            return
        }
        
        guard let faceObservations = landmarksRequest.results,
              let primaryFace = faceObservations.first else {
            DispatchQueue.main.async {
                self.landmarkData = nil
                if self.isAuthenticating || self.isEnrolling {
                    self.state = .searching
                }
            }
            return
        }
        
        // Quality observation
        var captureQuality: Float = 0.5
        if let qualityResults = qualityRequest.results,
           let matchingQuality = qualityResults.first(where: { $0.uuid == primaryFace.uuid }) {
            captureQuality = matchingQuality.faceCaptureQuality ?? 0.5
        }
        
        // Extract landmarks
        let landmarkInfo = extractLandmarks(from: primaryFace, quality: captureQuality)
        
        // Extract Face Feature Print for biometric comparison
        let featurePrint = extractFeaturePrint(from: pixelBuffer, faceBounds: primaryFace.boundingBox)
        
        DispatchQueue.main.async {
            self.landmarkData = landmarkInfo
            self.currentFeaturePrint = featurePrint
            
            if self.isEnrolling {
                self.handleEnrollmentStep(featurePrint: featurePrint, quality: captureQuality)
            } else if self.isAuthenticating {
                self.handleAuthenticationStep(featurePrint: featurePrint, quality: captureQuality)
            } else {
                self.state = .tracking(quality: captureQuality)
            }
        }
    }
    
    private func extractLandmarks(from face: VNFaceObservation, quality: Float) -> FaceLandmarkData {
        func points(from region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
            guard let region = region else { return [] }
            return region.normalizedPoints
        }
        
        let roll = face.roll?.doubleValue
        let yaw = face.yaw?.doubleValue
        
        return FaceLandmarkData(
            boundingBox: face.boundingBox,
            roll: roll,
            yaw: yaw,
            quality: quality,
            leftEye: points(from: face.landmarks?.leftEye),
            rightEye: points(from: face.landmarks?.rightEye),
            nose: points(from: face.landmarks?.nose),
            lips: points(from: face.landmarks?.outerLips),
            contour: points(from: face.landmarks?.faceContour)
        )
    }
    
    private func extractFeaturePrint(from pixelBuffer: CVPixelBuffer, faceBounds: CGRect) -> VNFeaturePrintObservation? {
        let featurePrintRequest = VNGenerateImageFeaturePrintRequest()
        featurePrintRequest.regionOfInterest = faceBounds
        featurePrintRequest.imageCropAndScaleOption = .scaleFill
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([featurePrintRequest])
            return featurePrintRequest.results?.first as? VNFeaturePrintObservation
        } catch {
            return nil
        }
    }
    
    private func handleEnrollmentStep(featurePrint: VNFeaturePrintObservation?, quality: Float) {
        guard let featurePrint = featurePrint else { return }
        
        // Complete enrollment immediately once face feature vector is extracted
        self.isEnrolling = false
        self.state = .authenticated(userName: "Enrolled", distance: 0.0)
        self.enrollmentCompletion?(.success(featurePrint))
        self.enrollmentCompletion = nil
    }
    
    private func handleAuthenticationStep(featurePrint: VNFeaturePrintObservation?, quality: Float) {
        guard let currentPrint = featurePrint else {
            self.state = .searching
            return
        }
        
        guard let stored = BiometricStorage.shared.loadProfile() else {
            self.isAuthenticating = false
            self.state = .unrecognized(distance: 1.0)
            self.authCompletion?(false, 1.0, nil)
            self.authCompletion = nil
            return
        }
        
        var distance: Float = 1.0
        do {
            try stored.observation.computeDistance(&distance, to: currentPrint)
            self.lastDistance = distance
            
            let threshold = min(stored.profile.threshold, self.targetThreshold)
            if distance <= threshold {
                self.isAuthenticating = false
                self.state = .authenticated(userName: stored.profile.userName, distance: distance)
                self.authCompletion?(true, distance, stored.profile.userName)
                self.authCompletion = nil
            } else {
                self.state = .tracking(quality: quality)
            }
        } catch {
            self.isAuthenticating = false
            self.state = .unrecognized(distance: 1.0)
            self.authCompletion?(false, 1.0, nil)
            self.authCompletion = nil
        }
    }
}
