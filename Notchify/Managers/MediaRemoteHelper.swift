import Foundation
import AppKit
import Combine
import ImageIO
import CoreGraphics

// MARK: - Media Remote Helper
class MediaRemoteHelper {
    static let shared = MediaRemoteHelper()
    
    private var getNowPlayingInfo: MRMediaRemoteGetNowPlayingInfoFunction?
    private var sendCommand: MRMediaRemoteSendCommandFunction?
    private var setElapsedTime: MRMediaRemoteSetElapsedTimeFunction?
    
    private var lastQuery: String = ""
    private var cachedArtwork: NSImage? = nil
    private var spotifyCachedUrl: String = ""
    private var spotifyCachedArtwork: NSImage? = nil
    
    private(set) var activePlayerBundleId: String? = nil
    private(set) var activePlayerName: String? = nil
    
    typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping @convention(block) ([String: Any]) -> Void) -> Void
    typealias MRMediaRemoteSendCommandFunction = @convention(c) (UInt32, Any?) -> Bool
    typealias MRMediaRemoteSetElapsedTimeFunction = @convention(c) (Double) -> Void
    
    init() {
        let bundleURL = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
        if let bundle = CFBundleCreate(kCFAllocatorDefault, bundleURL as CFURL) {
            if let pointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
                getNowPlayingInfo = unsafeBitCast(pointer, to: MRMediaRemoteGetNowPlayingInfoFunction.self)
            }
            if let ptr2 = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) {
                sendCommand = unsafeBitCast(ptr2, to: MRMediaRemoteSendCommandFunction.self)
            }
            if let ptr3 = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSetElapsedTime" as CFString) {
                setElapsedTime = unsafeBitCast(ptr3, to: MRMediaRemoteSetElapsedTimeFunction.self)
            }
        }
    }
    
    // MARK: - Memory-Efficient Downsampling
    static func downsample(data: Data, maxDimension: CGFloat = 128) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return nil
        }
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: downsampledImage, size: NSSize(width: downsampledImage.width, height: downsampledImage.height))
    }
    
    // MARK: - App Running & AppleScript Helpers
    private func isAppRunning(_ bundleId: String) -> Bool {
        return NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == bundleId })
    }
    
    @discardableResult
    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: source) {
            let output = scriptObject.executeAndReturnError(&error)
            if error == nil {
                return output.stringValue
            }
        }
        return nil
    }
    
    // MARK: - Playback Controls
    func togglePlayPause() {
        if activePlayerBundleId == "com.spotify.client" && isAppRunning("com.spotify.client") {
            DispatchQueue.global(qos: .userInitiated).async {
                self.runAppleScript("tell application \"Spotify\" to playpause")
            }
        } else if activePlayerBundleId == "com.apple.Music" && isAppRunning("com.apple.Music") {
            DispatchQueue.global(qos: .userInitiated).async {
                self.runAppleScript("tell application \"Music\" to playpause")
            }
        } else {
            _ = sendCommand?(2, nil) // MediaRemote togglePlayPause
        }
    }
    
    func nextTrack() {
        if activePlayerBundleId == "com.spotify.client" && isAppRunning("com.spotify.client") {
            DispatchQueue.global(qos: .userInitiated).async {
                self.runAppleScript("tell application \"Spotify\" to next track")
            }
        } else if activePlayerBundleId == "com.apple.Music" && isAppRunning("com.apple.Music") {
            DispatchQueue.global(qos: .userInitiated).async {
                self.runAppleScript("tell application \"Music\" to next track")
            }
        } else {
            _ = sendCommand?(4, nil) // MediaRemote nextTrack
        }
    }
    
    func previousTrack() {
        if activePlayerBundleId == "com.spotify.client" && isAppRunning("com.spotify.client") {
            DispatchQueue.global(qos: .userInitiated).async {
                self.runAppleScript("tell application \"Spotify\" to previous track")
            }
        } else if activePlayerBundleId == "com.apple.Music" && isAppRunning("com.apple.Music") {
            DispatchQueue.global(qos: .userInitiated).async {
                self.runAppleScript("tell application \"Music\" to previous track")
            }
        } else {
            _ = sendCommand?(5, nil) // MediaRemote previousTrack
        }
    }
    
    func seek(to time: Double) {
        if activePlayerBundleId == "com.spotify.client" && isAppRunning("com.spotify.client") {
            DispatchQueue.global(qos: .userInitiated).async {
                self.runAppleScript("tell application \"Spotify\" to set player position to \(time)")
            }
        } else if activePlayerBundleId == "com.apple.Music" && isAppRunning("com.apple.Music") {
            DispatchQueue.global(qos: .userInitiated).async {
                self.runAppleScript("tell application \"Music\" to set player position to \(time)")
            }
        } else {
            setElapsedTime?(time)
        }
    }
    
    func activatePlayerApp() {
        if let bundleId = activePlayerBundleId {
            if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) {
                app.activate(options: [.activateIgnoringOtherApps])
                return
            } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
                return
            }
        }
        
        // Fallbacks if bundleId was not determined
        if isAppRunning("com.spotify.client") {
            DispatchQueue.global(qos: .userInitiated).async {
                self.runAppleScript("tell application \"Spotify\" to activate")
            }
        } else if isAppRunning("com.apple.Music") {
            DispatchQueue.global(qos: .userInitiated).async {
                self.runAppleScript("tell application \"Music\" to activate")
            }
        }
    }
    
    // MARK: - Query Players
    private func querySpotify(completion: @escaping (_ title: String?, _ artist: String?, _ album: String?, _ isPlaying: Bool, _ duration: Double, _ elapsed: Double, _ artworkUrl: String?) -> Void) {
        guard isAppRunning("com.spotify.client") else {
            completion(nil, nil, nil, false, 0, 0, nil)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let script = """
            tell application "Spotify"
                try
                    set pState to (player state as string)
                    if pState is "playing" or pState is "paused" then
                        set tName to (name of current track)
                        set tArtist to (artist of current track)
                        set tAlbum to (album of current track)
                        set tDur to ((duration of current track) / 1000)
                        set tPos to (player position)
                        set tArt to ""
                        try
                            set tArt to (artwork url of current track)
                        end try
                        return pState & "|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tDur & "|||" & tPos & "|||" & tArt
                    else
                        return "stopped"
                    end if
                on error
                    return "stopped"
                end try
            end tell
            """
            guard let result = self.runAppleScript(script), result != "stopped" else {
                completion(nil, nil, nil, false, 0, 0, nil)
                return
            }
            
            let parts = result.components(separatedBy: "|||")
            if parts.count >= 6 {
                let isPlaying = parts[0] == "playing"
                let title = parts[1]
                let artist = parts[2]
                let album = parts[3]
                let duration = Double(parts[4]) ?? 0.0
                let elapsed = Double(parts[5]) ?? 0.0
                let artworkUrl = parts.count > 6 ? parts[6] : nil
                completion(title, artist, album, isPlaying, duration, elapsed, artworkUrl)
            } else {
                completion(nil, nil, nil, false, 0, 0, nil)
            }
        }
    }
    
    private func queryAppleMusic(completion: @escaping (_ title: String?, _ artist: String?, _ album: String?, _ isPlaying: Bool, _ duration: Double, _ elapsed: Double) -> Void) {
        guard isAppRunning("com.apple.Music") else {
            completion(nil, nil, nil, false, 0, 0)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let script = """
            tell application "Music"
                try
                    set pState to (player state as string)
                    if pState is "playing" or pState is "paused" then
                        set tName to (name of current track)
                        set tArtist to (artist of current track)
                        set tAlbum to (album of current track)
                        set tDur to (duration of current track)
                        set tPos to (player position)
                        return pState & "|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tDur & "|||" & tPos
                    else
                        return "stopped"
                    end if
                on error
                    return "stopped"
                end try
            end tell
            """
            guard let result = self.runAppleScript(script), result != "stopped" else {
                completion(nil, nil, nil, false, 0, 0)
                return
            }
            
            let parts = result.components(separatedBy: "|||")
            if parts.count >= 6 {
                let isPlaying = parts[0] == "playing"
                let title = parts[1]
                let artist = parts[2]
                let album = parts[3]
                let duration = Double(parts[4]) ?? 0.0
                let elapsed = Double(parts[5]) ?? 0.0
                completion(title, artist, album, isPlaying, duration, elapsed)
            } else {
                completion(nil, nil, nil, false, 0, 0)
            }
        }
    }
    
    // MARK: - Native MediaRemote Detector
    private func fetchMediaRemote(completion: @escaping (_ title: String?, _ artist: String?, _ artwork: NSImage?, _ isPlaying: Bool, _ duration: Double, _ elapsed: Double, _ bundleId: String?, _ appName: String?) -> Void) {
        guard let getNowPlayingInfo = getNowPlayingInfo else {
            completion(nil, nil, nil, false, 0, 0, nil, nil)
            return
        }
        
        getNowPlayingInfo(DispatchQueue.global(qos: .userInitiated)) { [weak self] info in
            guard let self = self else { return }
            
            let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? ""
            let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
            let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String
            
            let playbackRate = info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0.0
            let isPlaying = playbackRate > 0.0
            
            let duration = (info["kMRMediaRemoteNowPlayingInfoDuration"] as? NSNumber)?.doubleValue
                ?? (info["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0.0)
            let staticElapsed = (info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? NSNumber)?.doubleValue
                ?? (info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0.0)
            
            var elapsed = staticElapsed
            if isPlaying {
                var timestamp: Date? = nil
                if let d = info["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date {
                    timestamp = d
                } else if let nsd = info["kMRMediaRemoteNowPlayingInfoTimestamp"] as? NSDate {
                    timestamp = nsd as Date
                }
                
                if let ts = timestamp {
                    let timeSince = Date().timeIntervalSince(ts)
                    if timeSince >= 0 {
                        elapsed += timeSince * (playbackRate > 0 ? playbackRate : 1.0)
                    }
                }
            }
            if duration > 0 {
                elapsed = max(0, min(elapsed, duration))
            } else {
                elapsed = max(0, elapsed)
            }
            
            var artistStr = artist
            if let album = album, !album.isEmpty, !artistStr.isEmpty {
                artistStr += " – \(album)"
            } else if let album = album, !album.isEmpty {
                artistStr = album
            }
            
            var detectedBundleId: String? = nil
            var detectedAppName: String? = nil
            
            if let directBundleId = info["kMRMediaRemoteNowPlayingInfoClientBundleIdentifier"] as? String, !directBundleId.isEmpty {
                detectedBundleId = directBundleId
            } else if let clientData = info["kMRMediaRemoteNowPlayingInfoClientPropertiesData"] as? Data {
                let printable = String(clientData.compactMap { byte -> Character? in
                    return (byte >= 32 && byte <= 126) ? Character(UnicodeScalar(byte)) : nil
                })
                if let regex = try? NSRegularExpression(pattern: "[a-zA-Z0-9-]+\\.[a-zA-Z0-9-]+\\.[a-zA-Z0-9-]+"),
                   let match = regex.firstMatch(in: printable, range: NSRange(printable.startIndex..., in: printable)) {
                    detectedBundleId = String(printable[Range(match.range, in: printable)!])
                }
            }
            
            if let bId = detectedBundleId {
                if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bId) {
                    detectedAppName = FileManager.default.displayName(atPath: appURL.path)
                }
            }
            
            if title.isEmpty && artistStr.isEmpty {
                DispatchQueue.main.async {
                    completion(nil, nil, nil, false, 0, 0, nil, nil)
                }
                return
            }
            
            self.activePlayerBundleId = detectedBundleId
            self.activePlayerName = detectedAppName ?? "Media Player"
            
            if let artworkData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data, artworkData.count > 0 {
                let img = Self.downsample(data: artworkData, maxDimension: 128) ?? NSImage(data: artworkData)
                self.cachedArtwork = img
                self.lastQuery = ""
                DispatchQueue.main.async {
                    completion(title.isEmpty ? nil : title, artistStr.isEmpty ? nil : artistStr, img, isPlaying, duration, elapsed, detectedBundleId, detectedAppName)
                }
            } else {
                let query = "\(title) \(artist)"
                if query == self.lastQuery && !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    DispatchQueue.main.async {
                        completion(title.isEmpty ? nil : title, artistStr.isEmpty ? nil : artistStr, self.cachedArtwork, isPlaying, duration, elapsed, detectedBundleId, detectedAppName)
                    }
                } else {
                    self.lastQuery = query
                    var fallbackIcon: NSImage? = nil
                    if let bId = detectedBundleId, let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bId) {
                        fallbackIcon = NSWorkspace.shared.icon(forFile: appURL.path)
                    }
                    self.cachedArtwork = fallbackIcon
                    
                    if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                        self.fetchITunesArtwork(title: title, artist: artist) { fetchedImage in
                            if let fetchedImage = fetchedImage {
                                self.cachedArtwork = fetchedImage
                                DispatchQueue.main.async {
                                    completion(title.isEmpty ? nil : title, artistStr.isEmpty ? nil : artistStr, fetchedImage, isPlaying, duration, elapsed, detectedBundleId, detectedAppName)
                                }
                            }
                        }
                    }
                    
                    DispatchQueue.main.async {
                        completion(title.isEmpty ? nil : title, artistStr.isEmpty ? nil : artistStr, self.cachedArtwork, isPlaying, duration, elapsed, detectedBundleId, detectedAppName)
                    }
                }
            }
        }
    }
    
    // MARK: - Master Fetch Now Playing
    func fetchNowPlaying(completion: @escaping (String?, String?, NSImage?, Bool, Double, Double, String?, String?) -> Void) {
        let preference = UserDefaults.standard.string(forKey: "preferredMusicPlayer") ?? "auto"
        
        switch preference {
        case "spotify":
            querySpotify { [weak self] title, artist, album, isPlaying, duration, elapsed, artworkUrl in
                guard let self = self else { return }
                if let title = title, !title.isEmpty {
                    self.activePlayerBundleId = "com.spotify.client"
                    self.activePlayerName = "Spotify"
                    self.handleSpotifyResult(title: title, artist: artist, album: album, isPlaying: isPlaying, duration: duration, elapsed: elapsed, artworkUrl: artworkUrl, completion: completion)
                } else {
                    self.fetchMediaRemote(completion: completion)
                }
            }
            
        case "music":
            queryAppleMusic { [weak self] title, artist, album, isPlaying, duration, elapsed in
                guard let self = self else { return }
                if let title = title, !title.isEmpty {
                    self.activePlayerBundleId = "com.apple.Music"
                    self.activePlayerName = "Music"
                    self.handleAppleMusicResult(title: title, artist: artist, album: album, isPlaying: isPlaying, duration: duration, elapsed: elapsed, completion: completion)
                } else {
                    self.fetchMediaRemote(completion: completion)
                }
            }
            
        case "browser":
            self.fetchMediaRemote(completion: completion)
            
        default: // "auto"
            if isAppRunning("com.spotify.client") {
                querySpotify { [weak self] title, artist, album, isPlaying, duration, elapsed, artworkUrl in
                    guard let self = self else { return }
                    if isPlaying, let title = title, !title.isEmpty {
                        self.activePlayerBundleId = "com.spotify.client"
                        self.activePlayerName = "Spotify"
                        self.handleSpotifyResult(title: title, artist: artist, album: album, isPlaying: isPlaying, duration: duration, elapsed: elapsed, artworkUrl: artworkUrl, completion: completion)
                        return
                    }
                    
                    self.checkAppleMusicOrFallback(spotifyPaused: (title, artist, album, isPlaying, duration, elapsed, artworkUrl), completion: completion)
                }
            } else {
                checkAppleMusicOrFallback(spotifyPaused: nil, completion: completion)
            }
        }
    }
    
    private func checkAppleMusicOrFallback(spotifyPaused: (title: String?, artist: String?, album: String?, isPlaying: Bool, duration: Double, elapsed: Double, artworkUrl: String?)?, completion: @escaping (String?, String?, NSImage?, Bool, Double, Double, String?, String?) -> Void) {
        if isAppRunning("com.apple.Music") {
            queryAppleMusic { [weak self] title, artist, album, isPlaying, duration, elapsed in
                guard let self = self else { return }
                if isPlaying, let title = title, !title.isEmpty {
                    self.activePlayerBundleId = "com.apple.Music"
                    self.activePlayerName = "Music"
                    self.handleAppleMusicResult(title: title, artist: artist, album: album, isPlaying: isPlaying, duration: duration, elapsed: elapsed, completion: completion)
                    return
                }
                
                self.fetchMediaRemote { mrTitle, mrArtist, mrArt, mrPlaying, mrDuration, mrElapsed, mrBundle, mrName in
                    if mrPlaying && mrTitle != nil {
                        completion(mrTitle, mrArtist, mrArt, mrPlaying, mrDuration, mrElapsed, mrBundle, mrName)
                    } else if let sp = spotifyPaused, let spTitle = sp.title, !spTitle.isEmpty {
                        self.activePlayerBundleId = "com.spotify.client"
                        self.activePlayerName = "Spotify"
                        self.handleSpotifyResult(title: spTitle, artist: sp.artist, album: sp.album, isPlaying: sp.isPlaying, duration: sp.duration, elapsed: sp.elapsed, artworkUrl: sp.artworkUrl, completion: completion)
                    } else if let amTitle = title, !amTitle.isEmpty {
                        self.activePlayerBundleId = "com.apple.Music"
                        self.activePlayerName = "Music"
                        self.handleAppleMusicResult(title: amTitle, artist: artist, album: album, isPlaying: isPlaying, duration: duration, elapsed: elapsed, completion: completion)
                    } else {
                        completion(mrTitle, mrArtist, mrArt, mrPlaying, mrDuration, mrElapsed, mrBundle, mrName)
                    }
                }
            }
        } else {
            fetchMediaRemote { [weak self] mrTitle, mrArtist, mrArt, mrPlaying, mrDuration, mrElapsed, mrBundle, mrName in
                guard let self = self else { return }
                if mrPlaying && mrTitle != nil {
                    completion(mrTitle, mrArtist, mrArt, mrPlaying, mrDuration, mrElapsed, mrBundle, mrName)
                } else if let sp = spotifyPaused, let doMatch = sp.title, !doMatch.isEmpty {
                    self.activePlayerBundleId = "com.spotify.client"
                    self.activePlayerName = "Spotify"
                    self.handleSpotifyResult(title: doMatch, artist: sp.artist, album: sp.album, isPlaying: sp.isPlaying, duration: sp.duration, elapsed: sp.elapsed, artworkUrl: sp.artworkUrl, completion: completion)
                } else {
                    completion(mrTitle, mrArtist, mrArt, mrPlaying, mrDuration, mrElapsed, mrBundle, mrName)
                }
            }
        }
    }
    
    private func handleSpotifyResult(title: String, artist: String?, album: String?, isPlaying: Bool, duration: Double, elapsed: Double, artworkUrl: String?, completion: @escaping (String?, String?, NSImage?, Bool, Double, Double, String?, String?) -> Void) {
        var artistStr = artist ?? ""
        if let album = album, !album.isEmpty, !artistStr.isEmpty {
            artistStr += " – \(album)"
        } else if let album = album, !album.isEmpty {
            artistStr = album
        }
        
        let bundleId = "com.spotify.client"
        let appName = "Spotify"
        
        if let artUrlStr = artworkUrl, !artUrlStr.isEmpty, let artUrl = URL(string: artUrlStr) {
            if artUrlStr == self.spotifyCachedUrl && self.spotifyCachedArtwork != nil {
                DispatchQueue.main.async {
                    completion(title, artistStr, self.spotifyCachedArtwork, isPlaying, duration, elapsed, bundleId, appName)
                }
            } else {
                self.spotifyCachedUrl = artUrlStr
                URLSession.shared.dataTask(with: artUrl) { [weak self] data, _, _ in
                    var img: NSImage? = nil
                    if let data = data {
                        img = Self.downsample(data: data, maxDimension: 128) ?? NSImage(data: data)
                        self?.spotifyCachedArtwork = img
                    }
                    DispatchQueue.main.async {
                        completion(title, artistStr, img ?? self?.spotifyCachedArtwork, isPlaying, duration, elapsed, bundleId, appName)
                    }
                }.resume()
            }
        } else {
            let query = "\(title) \(artist ?? "")"
            if query == self.lastQuery && self.cachedArtwork != nil {
                DispatchQueue.main.async {
                    completion(title, artistStr, self.cachedArtwork, isPlaying, duration, elapsed, bundleId, appName)
                }
            } else {
                self.lastQuery = query
                var fallbackIcon: NSImage? = nil
                if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                    fallbackIcon = NSWorkspace.shared.icon(forFile: appURL.path)
                }
                self.cachedArtwork = fallbackIcon
                
                self.fetchITunesArtwork(title: title, artist: artist ?? "") { fetchedImage in
                    if let fetchedImage = fetchedImage {
                        self.cachedArtwork = fetchedImage
                        DispatchQueue.main.async {
                            completion(title, artistStr, fetchedImage, isPlaying, duration, elapsed, bundleId, appName)
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    completion(title, artistStr, self.cachedArtwork, isPlaying, duration, elapsed, bundleId, appName)
                }
            }
        }
    }
    
    private func handleAppleMusicResult(title: String, artist: String?, album: String?, isPlaying: Bool, duration: Double, elapsed: Double, completion: @escaping (String?, String?, NSImage?, Bool, Double, Double, String?, String?) -> Void) {
        var artistStr = artist ?? ""
        if let album = album, !album.isEmpty, !artistStr.isEmpty {
            artistStr += " – \(album)"
        } else if let album = album, !album.isEmpty {
            artistStr = album
        }
        
        let bundleId = "com.apple.Music"
        let appName = "Music"
        
        if let getNowPlayingInfo = getNowPlayingInfo {
            getNowPlayingInfo(DispatchQueue.global(qos: .userInitiated)) { [weak self] info in
                guard let self = self else { return }
                if let artworkData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data, artworkData.count > 0,
                   let img = Self.downsample(data: artworkData, maxDimension: 128) ?? NSImage(data: artworkData) {
                    self.cachedArtwork = img
                    DispatchQueue.main.async {
                        completion(title, artistStr, img, isPlaying, duration, elapsed, bundleId, appName)
                    }
                    return
                }
                
                let query = "\(title) \(artist ?? "")"
                if query == self.lastQuery && self.cachedArtwork != nil {
                    DispatchQueue.main.async {
                        completion(title, artistStr, self.cachedArtwork, isPlaying, duration, elapsed, bundleId, appName)
                    }
                } else {
                    self.lastQuery = query
                    var fallbackIcon: NSImage? = nil
                    if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                        fallbackIcon = NSWorkspace.shared.icon(forFile: appURL.path)
                    }
                    self.cachedArtwork = fallbackIcon
                    
                    self.fetchITunesArtwork(title: title, artist: artist ?? "") { fetchedImage in
                        if let fetchedImage = fetchedImage {
                            self.cachedArtwork = fetchedImage
                            DispatchQueue.main.async {
                                completion(title, artistStr, fetchedImage, isPlaying, duration, elapsed, bundleId, appName)
                            }
                        }
                    }
                    
                    DispatchQueue.main.async {
                        completion(title, artistStr, self.cachedArtwork, isPlaying, duration, elapsed, bundleId, appName)
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                completion(title, artistStr, nil, isPlaying, duration, elapsed, bundleId, appName)
            }
        }
    }
    
    private func fetchITunesArtwork(title: String, artist: String, completion: @escaping (NSImage?) -> Void) {
        let term = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://itunes.apple.com/search?term=\(term)&entity=song&limit=1"
        guard let url = URL(string: urlString) else { completion(nil); return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let artworkUrl = first["artworkUrl100"] as? String else {
                completion(nil)
                return
            }
            
            // Single optimal 200x200 image fetch (plenty for Retina 48x48)
            let optimalUrlString = artworkUrl.replacingOccurrences(of: "100x100bb", with: "200x200bb")
            if let targetUrl = URL(string: optimalUrlString) {
                URLSession.shared.dataTask(with: targetUrl) { imgData, _, _ in
                    if let data = imgData, let optimalImage = Self.downsample(data: data, maxDimension: 128) ?? NSImage(data: data) {
                        completion(optimalImage)
                    } else {
                        completion(nil)
                    }
                }.resume()
            } else {
                completion(nil)
            }
        }.resume()
    }
}
