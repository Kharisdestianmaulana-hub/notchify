import Foundation
import AppKit
import Combine

class MediaRemoteHelper {
    static let shared = MediaRemoteHelper()
    
    func fetchNowPlaying(completion: @escaping (String?, String?, NSImage?, Bool, Double, Double, String?, String?) -> Void) {
        completion("Song Title", "Artist", nil, true, 200, 50, nil, nil)
    }
    
    func seek(to time: Double) {}
    func previousTrack() {}
    func nextTrack() {}
    func togglePlayPause() {}
    func activatePlayerApp() {}
}
