import Foundation
import AppKit
import Combine

class MediaRemoteHelper {
    static let shared = MediaRemoteHelper()
    
    private var getNowPlayingInfo: MRMediaRemoteGetNowPlayingInfoFunction?
    
    typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping @convention(block) ([String: Any]) -> Void) -> Void
    
    init() {
        let bundleURL = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
        if let bundle = CFBundleCreate(kCFAllocatorDefault, bundleURL as CFURL),
           let pointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
            getNowPlayingInfo = unsafeBitCast(pointer, to: MRMediaRemoteGetNowPlayingInfoFunction.self)
        }
    }
    
    func fetchNowPlaying(completion: @escaping (String?, String?, NSImage?) -> Void) {
        guard let getNowPlayingInfo = getNowPlayingInfo else {
            completion(nil, nil, nil)
            return
        }
        
        getNowPlayingInfo(DispatchQueue.global(qos: .userInitiated)) { info in
            let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String
            let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String
            let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String
            
            var artwork: NSImage? = nil
            if let artworkData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                artwork = NSImage(data: artworkData)
            }
            
            // Combine artist and album if available
            var artistStr = artist ?? ""
            if let album = album, !album.isEmpty, !artistStr.isEmpty {
                artistStr += " – \(album)"
            } else if let album = album, !album.isEmpty {
                artistStr = album
            }
            
            DispatchQueue.main.async {
                completion(title, artistStr.isEmpty ? nil : artistStr, artwork)
            }
        }
    }
}
