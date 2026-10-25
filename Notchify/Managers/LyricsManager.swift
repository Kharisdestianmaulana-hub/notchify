import Foundation

class LyricsManager {
    static let shared = LyricsManager()
    
    // In-memory cache to avoid repeated network requests for the same track
    private var lyricsCache: [String: [LyricLine]] = [:]
    private let cacheLock = NSLock()
    
    // MARK: - Text Cleaning Helpers
    static func cleanArtist(from rawArtist: String) -> String {
        var clean = rawArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove album if formatted as "Artist – Album" or "Artist - Album"
        for sep in [" – ", " — ", " - "] {
            if let range = clean.range(of: sep) {
                let candidate = String(clean[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !candidate.isEmpty {
                    clean = candidate
                    break
                }
            }
        }
        
        // Clean YouTube topic channels (e.g. "Coldplay - Topic" -> "Coldplay")
        if clean.lowercased().hasSuffix(" - topic") {
            clean = String(clean.dropLast(8)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func cleanTitle(from rawTitle: String, artist: String = "") -> String {
        var clean = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove video, audio, and visualizer metadata tags common in web and video titles
        let patterns = [
            "\\s*\\(Official\\s+(Music\\s+)?Video\\)",
            "\\s*\\[Official\\s+(Music\\s+)?Video\\]",
            "\\s*\\(Official\\s+Audio\\)",
            "\\s*\\[Official\\s+Audio\\]",
            "\\s*\\(Lyric\\s+Video\\)",
            "\\s*\\[Lyric\\s+Video\\]",
            "\\s*\\(Visualizer\\)",
            "\\s*\\[Visualizer\\]",
            "\\s*\\(Lyrics?\\)",
            "\\s*\\[Lyrics?\\]",
            "\\s*\\(Audio\\)",
            "\\s*\\[Audio\\]",
            "\\s*\\(MV\\)",
            "\\s*\\[MV\\]",
            "\\s*\\(Official\\)",
            "\\s*\\[Official\\]"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                clean = regex.stringByReplacingMatches(
                    in: clean,
                    options: [],
                    range: NSRange(clean.startIndex..., in: clean),
                    withTemplate: ""
                )
            }
        }
        
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If artist is known and title starts with "Artist - Track", remove "Artist - "
        if !artist.isEmpty {
            let lowerClean = clean.lowercased()
            let lowerArtist = artist.lowercased()
            for sep in [" - ", " – ", " — ", ": "] {
                let prefix = lowerArtist + sep
                if lowerClean.hasPrefix(prefix) {
                    clean = String(clean.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
        }
        
        return clean
    }
    
    static func extractArtistAndTitle(rawArtist: String, rawTitle: String) -> (artist: String, title: String) {
        var artist = cleanArtist(from: rawArtist)
        var title = cleanTitle(from: rawTitle, artist: artist)
        
        let genericArtists = ["youtube", "google chrome", "safari", "brave", "music", "media player", "apple music", "spotify"]
        let isGeneric = artist.isEmpty || genericArtists.contains(artist.lowercased())
        
        // If artist is missing or generic, try extracting from "Artist - Track" in title
        if isGeneric {
            for sep in [" - ", " – ", " — "] {
                if let range = title.range(of: sep) {
                    let candidateArtist = String(title[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let candidateTitle = String(title[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !candidateArtist.isEmpty && !candidateTitle.isEmpty {
                        artist = candidateArtist
                        title = cleanTitle(from: candidateTitle, artist: candidateArtist)
                        break
                    }
                }
            }
        }
        
        return (artist, title)
    }
    
    static func strippedTitle(from title: String) -> String {
        var clean = title
        
        // Secondary stripping used as fallback: remove (feat. ...), (with ...), - Remastered..., etc.
        let secondaryPatterns = [
            "\\s*\\(feat\\.[^)]*\\)",
            "\\s*\\[feat\\.[^\\]]*\\]",
            "\\s*\\(ft\\.[^)]*\\)",
            "\\s*\\[ft\\.[^\\]]*\\]",
            "\\s*\\(with[^)]*\\)",
            "\\s*\\[with[^\\]]*\\]",
            "\\s*-\\s*(Remastered|Live|Radio Edit|Acoustic|Bonus Track).*",
            "\\s*\\((Remastered|Live|Radio Edit|Acoustic|Bonus Track)[^)]*\\)",
            "\\s*\\[(Remastered|Live|Radio Edit|Acoustic|Bonus Track)[^\\]]*\\]"
        ]
        
        for pattern in secondaryPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                clean = regex.stringByReplacingMatches(
                    in: clean,
                    options: [],
                    range: NSRange(clean.startIndex..., in: clean),
                    withTemplate: ""
                )
            }
        }
        
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Fetch Lyrics
    func fetchLyrics(
        for rawTitle: String,
        artist rawArtist: String,
        duration: Double = 0,
        completion: @escaping ([LyricLine]) -> Void
    ) {
        let (artist, title) = Self.extractArtistAndTitle(rawArtist: rawArtist, rawTitle: rawTitle)
        
        guard !title.isEmpty else {
            completion([])
            return
        }
        
        // 0. Cache check
        let cacheKey = "\(artist.lowercased()) - \(title.lowercased())"
        cacheLock.lock()
        if let cached = lyricsCache[cacheKey], !cached.isEmpty {
            cacheLock.unlock()
            DispatchQueue.main.async { completion(cached) }
            return
        }
        cacheLock.unlock()
        
        let finishSuccess: ([LyricLine]) -> Void = { [weak self] lines in
            if !lines.isEmpty {
                self?.cacheLock.lock()
                self?.lyricsCache[cacheKey] = lines
                self?.cacheLock.unlock()
            }
            DispatchQueue.main.async { completion(lines) }
        }
        
        // Tier 1: Search by track_name & artist_name (ultra-fast ~0.3s)
        self.searchByField(trackName: title, artistName: artist, duration: duration) { [weak self] tier1Lyrics in
            guard let self = self else { return }
            if !tier1Lyrics.isEmpty {
                finishSuccess(tier1Lyrics)
                return
            }
            
            // Tier 2: Stripped title search by field (if stripped title is different)
            let stripped = Self.strippedTitle(from: title)
            if stripped != title && !stripped.isEmpty {
                self.searchByField(trackName: stripped, artistName: artist, duration: duration) { [weak self] tier2Lyrics in
                    guard let self = self else { return }
                    if !tier2Lyrics.isEmpty {
                        finishSuccess(tier2Lyrics)
                        return
                    }
                    
                    // Tier 3: Search with query "artist title"
                    let query = artist.isEmpty ? stripped : "\(artist) \(stripped)"
                    self.searchByQuery(query: query, duration: duration) { tier3Lyrics in
                        finishSuccess(tier3Lyrics)
                    }
                }
            } else {
                // Tier 3: Search with query "artist title"
                let query = artist.isEmpty ? title : "\(artist) \(title)"
                self.searchByQuery(query: query, duration: duration) { tier3Lyrics in
                    finishSuccess(tier3Lyrics)
                }
            }
        }
    }
    
    // MARK: - Search by Field (Fast API Search)
    private func searchByField(
        trackName: String,
        artistName: String,
        duration: Double,
        completion: @escaping ([LyricLine]) -> Void
    ) {
        guard !trackName.isEmpty else {
            completion([])
            return
        }
        
        var components = URLComponents(string: "https://lrclib.net/api/search")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "track_name", value: trackName)
        ]
        if !artistName.isEmpty {
            queryItems.append(URLQueryItem(name: "artist_name", value: artistName))
        }
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            completion([])
            return
        }
        
        executeSearchRequest(url: url, duration: duration, completion: completion)
    }
    
    // MARK: - Search by Query (Fallback Search)
    private func searchByQuery(
        query: String,
        duration: Double,
        completion: @escaping ([LyricLine]) -> Void
    ) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion([])
            return
        }
        
        var components = URLComponents(string: "https://lrclib.net/api/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: trimmed)
        ]
        
        guard let url = components?.url else {
            completion([])
            return
        }
        
        executeSearchRequest(url: url, duration: duration, completion: completion)
    }
    
    // MARK: - HTTP Request Executor
    private func executeSearchRequest(
        url: URL,
        duration: Double,
        completion: @escaping ([LyricLine]) -> Void
    ) {
        var request = URLRequest(url: url)
        request.setValue("Notchify/1.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 4.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, error == nil,
                  let data = data,
                  let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  !jsonArray.isEmpty else {
                completion([])
                return
            }
            
            // 1. Synced lyrics candidates
            let syncedCandidates = jsonArray.filter { item in
                if let synced = item["syncedLyrics"] as? String, !synced.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return true
                }
                return false
            }
            
            if !syncedCandidates.isEmpty {
                let bestMatch: [String: Any]
                if duration > 0 {
                    bestMatch = syncedCandidates.min(by: { a, b in
                        let durA = (a["duration"] as? Double) ?? ((a["duration"] as? NSNumber)?.doubleValue ?? 0)
                        let durB = (b["duration"] as? Double) ?? ((b["duration"] as? NSNumber)?.doubleValue ?? 0)
                        return abs(durA - duration) < abs(durB - duration)
                    }) ?? syncedCandidates[0]
                } else {
                    bestMatch = syncedCandidates[0]
                }
                
                if let synced = bestMatch["syncedLyrics"] as? String {
                    let parsed = self.parseLRC(synced)
                    if !parsed.isEmpty {
                        completion(parsed)
                        return
                    }
                }
            }
            
            // 2. Fallback to plainLyrics if no synced lyrics available
            let plainCandidates = jsonArray.filter { item in
                if let plain = item["plainLyrics"] as? String, !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return true
                }
                return false
            }
            
            if let firstPlain = plainCandidates.first, let plainText = firstPlain["plainLyrics"] as? String {
                let parsed = self.parsePlainLyrics(plainText, duration: duration)
                if !parsed.isEmpty {
                    completion(parsed)
                    return
                }
            }
            
            completion([])
        }.resume()
    }
    
    // MARK: - Robust Bracket-Based LRC Parser
    func parseLRC(_ lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let rawLines = lrc.components(separatedBy: .newlines)
        
        for rawLine in rawLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("[") else { continue }
            
            var remaining = trimmed
            var timestamps: [Double] = []
            
            // Extract all [timestamp] tags from the line (e.g. [00:15.50][01:25.50]Chorus)
            while remaining.hasPrefix("["), let closeBracket = remaining.firstIndex(of: "]") {
                let tagContent = String(remaining[remaining.index(after: remaining.startIndex)..<closeBracket]).trimmingCharacters(in: .whitespaces)
                remaining = String(remaining[remaining.index(after: closeBracket)...]).trimmingCharacters(in: .whitespaces)
                
                let normalized = tagContent.replacingOccurrences(of: ",", with: ".")
                let parts = normalized.split(separator: ":")
                
                var seconds: Double? = nil
                if parts.count == 2 {
                    if let m = Double(parts[0]), let s = Double(parts[1]) {
                        seconds = (m * 60.0) + s
                    }
                } else if parts.count == 3 {
                    if let h = Double(parts[0]), let m = Double(parts[1]), let s = Double(parts[2]) {
                        seconds = (h * 3600.0) + (m * 60.0) + s
                    }
                }
                
                if let sec = seconds {
                    timestamps.append(sec)
                }
            }
            
            let text = remaining.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            
            // Filter out non-lyric credit lines
            let lower = text.lowercased()
            if lower.hasPrefix("synced by") || lower.hasPrefix("sync by") ||
               lower.hasPrefix("lyrics by") || lower.hasPrefix("encoded by") ||
               lower.hasPrefix("created by") || lower.hasPrefix("source:") {
                continue
            }
            
            for t in timestamps {
                lines.append(LyricLine(time: t, text: text))
            }
        }
        
        // CRITICAL: Sort lines strictly by timestamp so monotonic search always works and lyrics don't jump
        lines.sort { $0.time < $1.time }
        return lines
    }
    
    // MARK: - Plain Lyrics Parser (Fallback)
    func parsePlainLyrics(_ plain: String, duration: Double) -> [LyricLine] {
        let rawLines = plain.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard !rawLines.isEmpty else { return [] }
        
        let step = duration > 0 ? (duration / Double(rawLines.count)) : 0.0
        return rawLines.enumerated().map { index, text in
            LyricLine(time: Double(index) * step, text: text)
        }
    }
}
