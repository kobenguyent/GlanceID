import Foundation
import AppKit

// MARK: - GitHub Release Models

struct GitHubAsset: Codable, Equatable, Identifiable {
    var id: String { name }
    let name: String
    let browserDownloadUrl: String
    let size: Int
    let contentType: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
        case contentType = "content_type"
    }
}

struct GitHubRelease: Codable, Equatable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlUrl: String
    let publishedAt: String?
    let prerelease: Bool?
    let draft: Bool?
    let assets: [GitHubAsset]?
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case prerelease
        case draft
        case assets
    }
    
    /// Returns the preferred downloadable installer asset (.dmg preferred over .zip)
    var preferredInstallerAsset: GitHubAsset? {
        guard let assets = assets, !assets.isEmpty else { return nil }
        if let dmg = assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") }) {
            return dmg
        }
        if let zip = assets.first(where: { $0.name.lowercased().hasSuffix(".zip") }) {
            return zip
        }
        return assets.first
    }
    
    var cleanVersionString: String {
        SemanticVersion.normalizeTag(tagName)
    }
}

// MARK: - Semantic Versioning

struct SemanticVersion: Comparable, Equatable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int
    let prerelease: String?
    
    var description: String {
        if let prerelease = prerelease, !prerelease.isEmpty {
            return "\(major).\(minor).\(patch)-\(prerelease)"
        }
        return "\(major).\(minor).\(patch)"
    }
    
    init?(string: String) {
        let normalized = Self.normalizeTag(string)
        guard !normalized.isEmpty else { return nil }
        
        // Strip build metadata (+...)
        let withoutBuild = normalized.components(separatedBy: "+").first ?? normalized
        
        // Split pre-release (-alpha, -beta.1, etc.)
        let dashParts = withoutBuild.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let corePart = String(dashParts[0])
        let prereleasePart: String? = dashParts.count > 1 && !dashParts[1].isEmpty ? String(dashParts[1]) : nil
        
        let numberStrings = corePart.split(separator: ".")
        guard !numberStrings.isEmpty, numberStrings.count <= 4 else { return nil }
        
        var numbers: [Int] = []
        for part in numberStrings {
            guard let value = Int(part) else { return nil }
            numbers.append(value)
        }
        
        self.major = numbers[0]
        self.minor = numbers.count > 1 ? numbers[1] : 0
        self.patch = numbers.count > 2 ? numbers[2] : 0
        self.prerelease = prereleasePart
    }
    
    static func normalizeTag(_ raw: String) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("v") {
            trimmed.removeFirst()
        }
        return trimmed
    }
    
    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        
        // A version without a prerelease tag is higher than one with a prerelease tag (e.g., 1.0.0 > 1.0.0-beta.1)
        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil):
            return false
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        case (.some(let lPre), .some(let rPre)):
            return lPre.localizedStandardCompare(rPre) == .orderedAscending
        }
    }
}

// MARK: - Update Status State

enum UpdateStatus: Equatable {
    case idle
    case checking
    case upToDate(currentVersion: String, latestVersion: String)
    case updateAvailable(release: GitHubRelease, currentVersion: String, latestVersion: String)
    case noReleasesPublished(currentVersion: String)
    case error(message: String)
    
    var isUpdateAvailable: Bool {
        if case .updateAvailable = self { return true }
        return false
    }
}

// MARK: - UpdateManager Service

final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    
    @Published var status: UpdateStatus = .idle
    @Published var lastCheckedDate: Date? = nil
    @Published var autoCheckOnLaunch: Bool {
        didSet {
            UserDefaults.standard.set(autoCheckOnLaunch, forKey: Self.autoCheckKey)
        }
    }
    
    let repoOwner: String
    let repoName: String
    private let session: URLSession
    
    private static let autoCheckKey = "com.kobet.glanceid.autoCheckForUpdates"
    private static let lastCheckedKey = "com.kobet.glanceid.lastUpdateCheckDate"
    
    var currentVersion: String {
        if let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           !bundleVersion.isEmpty {
            return bundleVersion
        }
        return "1.0.0"
    }
    
    init(
        repoOwner: String = "kobenguyent",
        repoName: String = "GlanceID",
        session: URLSession = .shared
    ) {
        self.repoOwner = repoOwner
        self.repoName = repoName
        self.session = session
        
        if UserDefaults.standard.object(forKey: Self.autoCheckKey) == nil {
            self.autoCheckOnLaunch = true
        } else {
            self.autoCheckOnLaunch = UserDefaults.standard.bool(forKey: Self.autoCheckKey)
        }
        
        if let savedTimestamp = UserDefaults.standard.object(forKey: Self.lastCheckedKey) as? Date {
            self.lastCheckedDate = savedTimestamp
        }
    }
    
    /// Evaluates a fetched GitHubRelease against a local version string
    static func evaluateRelease(_ release: GitHubRelease, currentVersion: String) -> UpdateStatus {
        let latestClean = release.cleanVersionString
        let currentClean = SemanticVersion.normalizeTag(currentVersion)
        
        if let remoteSemVer = SemanticVersion(string: latestClean),
           let localSemVer = SemanticVersion(string: currentClean) {
            if remoteSemVer > localSemVer {
                return .updateAvailable(
                    release: release,
                    currentVersion: currentClean,
                    latestVersion: remoteSemVer.description
                )
            } else {
                return .upToDate(
                    currentVersion: currentClean,
                    latestVersion: remoteSemVer.description
                )
            }
        }
        
        // Fallback string comparison if non-semver tag is used
        if latestClean != currentClean && !latestClean.isEmpty {
            return .updateAvailable(
                release: release,
                currentVersion: currentClean,
                latestVersion: latestClean
            )
        }
        
        return .upToDate(currentVersion: currentClean, latestVersion: currentClean)
    }
    
    /// Queries GitHub Releases API for the newest version
    func checkForUpdates() {
        guard status != .checking else { return }
        
        DispatchQueue.main.async {
            self.status = .checking
        }
        
        let latestURLString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let latestURL = URL(string: latestURLString) else {
            DispatchQueue.main.async {
                self.status = .error(message: "Invalid GitHub Releases URL.")
            }
            return
        }
        
        var request = URLRequest(url: latestURL)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("GlanceID-macOS/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12
        
        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.status = .error(message: "Network error: \(error.localizedDescription)")
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self.status = .error(message: "Invalid response from GitHub.")
                }
                return
            }
            
            // If 404 on /releases/latest, the repo may have pre-releases only or no releases published yet
            if httpResponse.statusCode == 404 {
                self.checkAllReleasesFallback()
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode), let data = data else {
                DispatchQueue.main.async {
                    self.status = .error(message: "GitHub API returned status \(httpResponse.statusCode).")
                }
                return
            }
            
            do {
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                let newStatus = Self.evaluateRelease(release, currentVersion: self.currentVersion)
                let now = Date()
                DispatchQueue.main.async {
                    self.lastCheckedDate = now
                    UserDefaults.standard.set(now, forKey: Self.lastCheckedKey)
                    self.status = newStatus
                }
            } catch {
                DispatchQueue.main.async {
                    self.status = .error(message: "Failed to parse release metadata.")
                }
            }
        }.resume()
    }
    
    /// Fallback check against `/releases` list if `/releases/latest` returned 404
    private func checkAllReleasesFallback() {
        let listURLString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases"
        guard let listURL = URL(string: listURLString) else {
            DispatchQueue.main.async {
                self.status = .noReleasesPublished(currentVersion: self.currentVersion)
            }
            return
        }
        
        var request = URLRequest(url: listURL)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("GlanceID-macOS/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12
        
        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            guard error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data = data,
                  let releases = try? JSONDecoder().decode([GitHubRelease].self, from: data) else {
                DispatchQueue.main.async {
                    self.status = .noReleasesPublished(currentVersion: self.currentVersion)
                }
                return
            }
            
            let now = Date()
            // Pick first non-draft release
            if let latestRelease = releases.first(where: { $0.draft != true }) {
                let evaluated = Self.evaluateRelease(latestRelease, currentVersion: self.currentVersion)
                DispatchQueue.main.async {
                    self.lastCheckedDate = now
                    UserDefaults.standard.set(now, forKey: Self.lastCheckedKey)
                    self.status = evaluated
                }
            } else {
                DispatchQueue.main.async {
                    self.lastCheckedDate = now
                    UserDefaults.standard.set(now, forKey: Self.lastCheckedKey)
                    self.status = .noReleasesPublished(currentVersion: self.currentVersion)
                }
            }
        }.resume()
    }
    
    // MARK: - Browser & Download Actions
    
    func openReleasePage(_ release: GitHubRelease) {
        if let url = URL(string: release.htmlUrl) {
            NSWorkspace.shared.open(url)
        }
    }
    
    func downloadPreferredAsset(for release: GitHubRelease) {
        if let asset = release.preferredInstallerAsset,
           let url = URL(string: asset.browserDownloadUrl) {
            NSWorkspace.shared.open(url)
        } else {
            openReleasePage(release)
        }
    }
    
    func openRepositoryReleasesPage() {
        if let url = URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases") {
            NSWorkspace.shared.open(url)
        }
    }
}
