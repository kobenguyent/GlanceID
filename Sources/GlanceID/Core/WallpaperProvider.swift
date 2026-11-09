import Foundation
import AppKit
import SwiftUI

final class WallpaperProvider: ObservableObject {
    static let shared = WallpaperProvider()
    
    @Published var wallpaperImage: NSImage?
    private var screenWallpapers: [String: NSImage] = [:]
    
    private init() {
        reloadWallpaper()
    }
    
    func reloadWallpaper() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let screens = NSScreen.screens
            var wallpapersMap: [String: NSImage] = [:]
            
            for screen in screens {
                let key = self?.screenKey(for: screen) ?? "main"
                if let url = NSWorkspace.shared.desktopImageURL(for: screen),
                   let img = NSImage(contentsOf: url) {
                    wallpapersMap[key] = img
                }
            }
            
            // Primary image fallback
            let fallback = self?.loadFallbackDesktop()
            let primaryKey = screens.first.flatMap { self?.screenKey(for: $0) } ?? "main"
            let primaryImg = wallpapersMap[primaryKey] ?? fallback
            
            DispatchQueue.main.async {
                self?.screenWallpapers = wallpapersMap
                self?.wallpaperImage = primaryImg
            }
        }
    }
    
    func wallpaper(for screen: NSScreen?) -> NSImage? {
        guard let targetScreen = screen else {
            return wallpaperImage
        }
        let key = screenKey(for: targetScreen)
        return screenWallpapers[key] ?? wallpaperImage
    }
    
    private func screenKey(for screen: NSScreen) -> String {
        if let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? Int {
            return "\(id)"
        }
        return "\(Int(screen.frame.origin.x))_\(Int(screen.frame.origin.y))"
    }
    
    private func loadFallbackDesktop() -> NSImage? {
        let defaultPaths = [
            "/System/Library/CoreServices/DefaultDesktop.heic",
            "/System/Library/Desktop Pictures/Sequoia.heic",
            "/System/Library/Desktop Pictures/Sonoma.heic",
            "/System/Library/Desktop Pictures/Ventura.heic"
        ]
        for path in defaultPaths {
            if let img = NSImage(contentsOfFile: path) {
                return img
            }
        }
        return nil
    }
}
