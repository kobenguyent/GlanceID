import SwiftUI

struct FaceMeshOverlay: View {
    let landmarkData: FaceLandmarkData?
    var mirrored: Bool = true
    
    var body: some View {
        GeometryReader { geo in
            if let landmarks = landmarkData {
                let size = geo.size
                let box = landmarks.boundingBox
                let rect = convertVisionRect(box, viewSize: size, mirrored: mirrored)
                
                ZStack {
                    // Face Bounding Box with rounded corners
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor.opacity(0.85), lineWidth: 2)
                        .frame(width: max(0, rect.width), height: max(0, rect.height))
                        .position(x: rect.midX, y: rect.midY)
                    
                    // Quality / Attention Indicator Badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(landmarks.quality > 0.4 ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(String(format: "Attention: %.0f%%", landmarks.quality * 100))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(6)
                    .position(x: rect.midX, y: max(16, rect.minY - 14))
                    
                    // Draw Landmark Contours
                    Path { path in
                        drawRegion(landmarks.leftEye, in: box, path: &path, viewSize: size, close: true)
                        drawRegion(landmarks.rightEye, in: box, path: &path, viewSize: size, close: true)
                        drawRegion(landmarks.nose, in: box, path: &path, viewSize: size, close: false)
                        drawRegion(landmarks.lips, in: box, path: &path, viewSize: size, close: true)
                        drawRegion(landmarks.contour, in: box, path: &path, viewSize: size, close: false)
                    }
                    .stroke(Color.cyan.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    
                    // Draw eye pupil / center dots
                    if let leftEyeCenter = computeCenter(landmarks.leftEye, in: box, viewSize: size) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .position(leftEyeCenter)
                    }
                    if let rightEyeCenter = computeCenter(landmarks.rightEye, in: box, viewSize: size) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .position(rightEyeCenter)
                    }
                }
            }
        }
    }
    
    private func convertVisionRect(_ visionRect: CGRect, viewSize: CGSize, mirrored: Bool) -> CGRect {
        let w = visionRect.width * viewSize.width
        let h = visionRect.height * viewSize.height
        let y = (1.0 - visionRect.origin.y - visionRect.height) * viewSize.height
        let x = mirrored ? ((1.0 - visionRect.origin.x - visionRect.width) * viewSize.width) : (visionRect.origin.x * viewSize.width)
        return CGRect(x: x, y: y, width: w, height: h)
    }
    
    private func convertPoint(_ pt: CGPoint, in box: CGRect, viewSize: CGSize) -> CGPoint {
        let absX = box.origin.x + (pt.x * box.size.width)
        let absY = box.origin.y + (pt.y * box.size.height)
        let screenX = mirrored ? (1.0 - absX) * viewSize.width : absX * viewSize.width
        let screenY = (1.0 - absY) * viewSize.height
        return CGPoint(x: screenX, y: screenY)
    }
    
    private func drawRegion(_ points: [CGPoint], in box: CGRect, path: inout Path, viewSize: CGSize, close: Bool) {
        guard let first = points.first else { return }
        path.move(to: convertPoint(first, in: box, viewSize: viewSize))
        for pt in points.dropFirst() {
            path.addLine(to: convertPoint(pt, in: box, viewSize: viewSize))
        }
        if close {
            path.closeSubpath()
        }
    }
    
    private func computeCenter(_ points: [CGPoint], in box: CGRect, viewSize: CGSize) -> CGPoint? {
        guard !points.isEmpty else { return nil }
        let avgX = points.reduce(0.0) { $0 + $1.x } / CGFloat(points.count)
        let avgY = points.reduce(0.0) { $0 + $1.y } / CGFloat(points.count)
        return convertPoint(CGPoint(x: avgX, y: avgY), in: box, viewSize: viewSize)
    }
}
