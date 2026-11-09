import SwiftUI
import AVFoundation
import AppKit

final class CameraPreviewNSView: NSView {
    var previewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    init(session: AVCaptureSession, mirrored: Bool = false) {
        super.init(frame: .zero)
        self.wantsLayer = true
        self.previewLayer.session = session
        self.previewLayer.videoGravity = .resizeAspectFill
        setMirrored(mirrored)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func makeBackingLayer() -> CALayer {
        let layer = AVCaptureVideoPreviewLayer()
        layer.videoGravity = .resizeAspectFill
        return layer
    }
    
    func setMirrored(_ mirrored: Bool) {
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
    }
    
    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }
}

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    var mirrored: Bool = false
    
    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView(session: session, mirrored: mirrored)
        return view
    }
    
    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        if nsView.previewLayer.session !== session {
            nsView.previewLayer.session = session
        }
        nsView.setMirrored(mirrored)
    }
}
