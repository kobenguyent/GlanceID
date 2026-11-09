import Foundation
import AudioToolbox
import AVFoundation

final class SoundManager {
    static let shared = SoundManager()
    
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    
    private init() {}
    
    /// Plays the iconic Face ID recognition chime
    func playFaceIDSuccess() {
        // macOS System Sound 1057 (Tink) or 1054
        AudioServicesPlaySystemSound(1054)
        
        // Also synthesize the dual-frequency Apple Pay / Face ID chime:
        // C6 (1046.5 Hz) short blip followed by E6 (1318.5 Hz)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.synthesizeFaceIDChime()
        }
    }
    
    /// Plays the Face ID rejection / retry buzz
    func playFaceIDFailure() {
        // macOS System Sound for alert / error
        AudioServicesPlaySystemSound(1053) // Funk / Basso
    }
    
    /// Synthesizes a crisp, soft two-tone chime matching iOS Face ID audio feedback
    private func synthesizeFaceIDChime() {
        let sampleRate: Double = 44100.0
        let duration: Double = 0.09
        let count = Int(sampleRate * duration)
        
        func generateTone(frequency: Double, volume: Float) -> [Float] {
            var samples = [Float](repeating: 0, count: count)
            for i in 0..<count {
                let progress = Double(i) / Double(count)
                // Smooth Hann window envelope to prevent clicks
                let envelope = 0.5 * (1.0 - cos(2.0 * .pi * progress))
                let sample = sin(2.0 * .pi * frequency * Double(i) / sampleRate) * envelope
                samples[i] = Float(sample) * volume
            }
            return samples
        }
        
        let tone1 = generateTone(frequency: 1174.66, volume: 0.18) // D6
        let tone2 = generateTone(frequency: 1567.98, volume: 0.22) // G6
        let fullBuffer = tone1 + tone2
        
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(fullBuffer.count)) else {
            return
        }
        
        pcmBuffer.frameLength = AVAudioFrameCount(fullBuffer.count)
        let channelData = pcmBuffer.floatChannelData![0]
        for (i, val) in fullBuffer.enumerated() {
            channelData[i] = val
        }
        
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        
        do {
            try engine.start()
            player.play()
            player.scheduleBuffer(pcmBuffer) {
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
                    engine.stop()
                }
            }
        } catch {
            // AudioServices fallback was already triggered
        }
    }
}
