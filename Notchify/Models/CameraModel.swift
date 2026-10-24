import Foundation
import AVFoundation
import AppKit

// MARK: - Photo Storage Manager
struct PhotoStorageManager {
    static var defaultFolderURL: URL {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Pictures")
        return pictures.appendingPathComponent("Notchify")
    }
    
    static func getPhotosDirectory() -> URL {
        let storageType = UserDefaults.standard.string(forKey: "photoStorageType") ?? "default"
        let customPath = UserDefaults.standard.string(forKey: "customPhotoStoragePath") ?? ""
        
        if storageType == "custom" && !customPath.isEmpty {
            let customURL = URL(fileURLWithPath: customPath)
            if !FileManager.default.fileExists(atPath: customURL.path) {
                try? FileManager.default.createDirectory(at: customURL, withIntermediateDirectories: true)
            }
            return customURL
        }
        
        let def = defaultFolderURL
        if !FileManager.default.fileExists(atPath: def.path) {
            try? FileManager.default.createDirectory(at: def, withIntermediateDirectories: true)
        }
        return def
    }
    
    static func openPhotosFolder() {
        let dir = getPhotosDirectory()
        NSWorkspace.shared.open(dir)
    }
    
    static func revealPhotoInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

// MARK: - Camera & Video Enums
enum CameraCaptureMode: String, CaseIterable, Identifiable {
    case photo = "Photo"
    case video = "Video"
    
    var id: String { rawValue }
    
    var localizedTitle: String {
        switch self {
        case .photo: return LanguageManager.tr("Photo")
        case .video: return LanguageManager.tr("Video")
        }
    }
    
    var iconName: String {
        switch self {
        case .photo: return "camera.fill"
        case .video: return "video.fill"
        }
    }
}

enum VideoDurationPreset: Int, CaseIterable, Identifiable {
    case sec15 = 15
    case sec30 = 30
    case sec60 = 60
    case min3 = 180
    case min5 = 300
    
    var id: Int { rawValue }
    
    var label: String {
        switch self {
        case .sec15: return "15s"
        case .sec30: return "30s"
        case .sec60: return "60s"
        case .min3: return "3m"
        case .min5: return "5m"
        }
    }
    
    var seconds: Int { rawValue }
}

