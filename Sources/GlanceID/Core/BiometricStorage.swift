import Foundation
import Vision

struct BiometricProfile: Codable {
    let userName: String
    let enrolledAt: Date
    let featurePrintData: Data
    var threshold: Float
}

final class BiometricStorage {
    static let shared = BiometricStorage()
    
    private let fileManager = FileManager.default
    private let profileFileName = "glance_profile.json"
    
    private var storageDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let glanceDir = appSupport.appendingPathComponent("GlanceID", isDirectory: true)
        if !fileManager.fileExists(atPath: glanceDir.path) {
            try? fileManager.createDirectory(at: glanceDir, withIntermediateDirectories: true)
        }
        return glanceDir
    }
    
    private var profileURL: URL {
        storageDirectory.appendingPathComponent(profileFileName)
    }
    
    private init() {}
    
    var isEnrolled: Bool {
        return fileManager.fileExists(atPath: profileURL.path)
    }
    
    func saveProfile(userName: String, observation: VNFeaturePrintObservation, threshold: Float = 0.40) throws {
        let printData = try NSKeyedArchiver.archivedData(withRootObject: observation, requiringSecureCoding: true)
        let profile = BiometricProfile(
            userName: userName,
            enrolledAt: Date(),
            featurePrintData: printData,
            threshold: threshold
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(profile)
        try jsonData.write(to: profileURL, options: .atomic)
    }
    
    func loadProfile() -> (profile: BiometricProfile, observation: VNFeaturePrintObservation)? {
        guard let jsonData = try? Data(contentsOf: profileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let profile = try? decoder.decode(BiometricProfile.self, from: jsonData) else { return nil }
        
        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: profile.featurePrintData)
            unarchiver.requiresSecureCoding = true
            guard let observation = unarchiver.decodeObject(of: VNFeaturePrintObservation.self, forKey: NSKeyedArchiveRootObjectKey) else {
                return nil
            }
            return (profile, observation)
        } catch {
            return nil
        }
    }
    
    func deleteProfile() {
        try? fileManager.removeItem(at: profileURL)
    }
}
