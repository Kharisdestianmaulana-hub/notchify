import Foundation

class LyricsManager {
    static let shared = LyricsManager()
    
    // In-memory cache to avoid repeated network requests for the same track
    private var lyricsCache: [String: [LyricLine]] = [:]
    private let cacheLock = NSLock()
    
    // MARK: - Text Cleaning Helpers
    static func cleanArtist(from rawArtist: String) -> String {
        var clean = rawArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        // Clean YouTube topic channels (e.g. "Coldplay - Topic" -> "Coldplay")
        if clean.lowercased().hasSuffix(" - topic") {
            clean = String(clean.dropLast(8)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return clean
    }
    
    static func cleanTitle(from rawTitle: String) -> String {
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
        
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func strippedTitle(from title: String) -> String {
        var clean = cleanTitle(from: title)
        
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
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = rawArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        
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
        
        let cleanedTitle = Self.cleanTitle(from: title)
        let cleanedArtist = Self.cleanArtist(from: artist)
        
        // Tier 1: Exact match with cleaned title & artist
        tryExactMatch(trackName: cleanedTitle, artistName: cleanedArtist, duration: duration) { [weak self] tier1Lyrics in
            guard let self = self else { return }
            if !tier1Lyrics.isEmpty {
                finishSuccess(tier1Lyrics)
                return
            }
            
            // Tier 2: Stripped title (remove feat, remaster, live) if different
            let stripped = Self.strippedTitle(from: cleanedTitle)
            if stripped != cleanedTitle && !stripped.isEmpty {
                self.tryExactMatch(trackName: stripped, artistName: cleanedArtist, duration: duration) { tier2Lyrics in
                    if !tier2Lyrics.isEmpty {
                        finishSuccess(tier2Lyrics)
                        return
                    }
                    
                    // Tier 3: Search endpoint with stripped query
                    self.searchLyrics(queryTitle: stripped, artist: cleanedArtist, duration: duration, completion: finishSuccess)
                }
            } else {
                // Tier 3: Search endpoint with cleaned query
                self.searchLyrics(queryTitle: cleanedTitle, artist: cleanedArtist, duration: duration, completion: finishSuccess)
            }
        }
    }
    
    // MARK: - Tier 1 & 2: Exact Match
    private func tryExactMatch(
        trackName: String,
        artistName: String,
        duration: Double,
        completion: @escaping ([LyricLine]) -> Void
    ) {
        guard !trackName.isEmpty, !artistName.isEmpty else {
            completion([])
            return
        }
        
        var components = URLComponents(string: "https://lrclib.net/api/get")
        components?.queryItems = [
            URLQueryItem(name: "artist_name", value: artistName),
            URLQueryItem(name: "track_name", value: trackName)
        ]
        
        guard let url = components?.url else {
            completion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Notchify/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 7.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, error == nil,
                  let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion([])
                return
            }
            
            if let synced = json["syncedLyrics"] as? String, !synced.isEmpty {
                let parsed = self.parseLRC(synced)
                if !parsed.isEmpty {
                    completion(parsed)
                    return
                }
            }
            
            if let plain = json["plainLyrics"] as? String, !plain.isEmpty {
                let parsed = self.parsePlainLyrics(plain, duration: duration)
                if !parsed.isEmpty {
                    completion(parsed)
                    return
                }
            }
            
            completion([])
        }.resume()
    }
    
    // MARK: - Tier 3: Search Fallback
    private func searchLyrics(
        queryTitle: String,
        artist: String,
        duration: Double,
        completion: @escaping ([LyricLine]) -> Void
    ) {
        var components = URLComponents(string: "https://lrclib.net/api/search")
        let searchQuery = artist.isEmpty ? queryTitle : "\(artist) \(queryTitle)"
        components?.queryItems = [
            URLQueryItem(name: "q", value: searchQuery)
        ]
        
        guard let url = components?.url else {
            completion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Notchify/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 7.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, error == nil,
                  let data = data,
                  let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  !jsonArray.isEmpty else {
                completion([])
                return
            }
            
            // 1. First priority: Candidates with syncedLyrics
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
            
            // 2. Second priority: Fallback to plainLyrics if no synced lyrics are available
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
