import Foundation
import AppKit
import SwiftUI

final class WallpaperProvider: ObservableObject {
    static let shared = WallpaperProvider()
    
    @Published var wallpaperImage: NSImage?
    
    private init() {
        reloadWallpaper()
    }
    
    func reloadWallpaper() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let screen = NSScreen.main else { return }
            
            var loadedImage: NSImage?
            
            // 1. Query macOS for current desktop wallpaper URL
            if let url = NSWorkspace.shared.desktopImageURL(for: screen),
               let img = NSImage(contentsOf: url) {
                loadedImage = img
            }
            
            // 2. Fallback to macOS default system desktop
            if loadedImage == nil {
                let defaultPaths = [
                    "/System/Library/CoreServices/DefaultDesktop.heic",
                    "/System/Library/Desktop Pictures/Sequoia.heic",
                    "/System/Library/Desktop Pictures/Sonoma.heic",
                    "/System/Library/Desktop Pictures/Ventura.heic"
                ]
                for path in defaultPaths {
                    if let img = NSImage(contentsOfFile: path) {
                        loadedImage = img
                        break
                    }
                }
            }
            
            DispatchQueue.main.async {
                self?.wallpaperImage = loadedImage
            }
        }
    }
}
