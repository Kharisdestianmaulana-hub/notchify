import Foundation


class LyricsManager {
    static let shared = LyricsManager()
    
    // MARK: - Text Cleaning Helpers
    static func cleanArtist(from rawArtist: String) -> String {
        var clean = rawArtist
        // If artist contains " – " (e.g., "Artist – Album") or " - ", take the first part
        if let dashRange = clean.range(of: " – ") {
            clean = String(clean[..<dashRange.lowerBound])
        } else if let dashRange = clean.range(of: " - ") {
            clean = String(clean[..<dashRange.lowerBound])
        }
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func cleanTitle(from rawTitle: String) -> String {
        var clean = rawTitle
        
        // If title contains "Artist - Song Title" (common in browser/YouTube metadata), take the song part
        if let dashRange = clean.range(of: " - ") {
            clean = String(clean[dashRange.upperBound...])
        }
        
        // Patterns to remove (case-insensitive)
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
            "\\s*\\(Remastered[^)]*\\)",
            "\\s*\\[Remastered[^\\]]*\\]",
            "\\s*\\(Live[^)]*\\)",
            "\\s*\\[Live[^\\]]*\\]",
            "\\s*\\(feat\\.[^)]*\\)",
            "\\s*\\[feat\\.[^\\]]*\\]",
            "\\s*\\(ft\\.[^)]*\\)",
            "\\s*\\[ft\\.[^\\]]*\\]",
            "\\s*\\(with[^)]*\\)",
            "\\s*\\[with[^\\]]*\\]"
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
    
    // MARK: - Fetch Lyrics
    func fetchLyrics(
        for rawTitle: String,
        artist rawArtist: String,
        duration: Double = 0,
        completion: @escaping ([LyricLine]) -> Void
    ) {
        let cleanTitle = Self.cleanTitle(from: rawTitle)
        let cleanArtist = Self.cleanArtist(from: rawArtist)
        
        guard !cleanTitle.isEmpty else {
            completion([])
            return
        }
        
        // 1. Try exact match using URLComponents
        var components = URLComponents(string: "https://lrclib.net/api/get")
        components?.queryItems = [
            URLQueryItem(name: "artist_name", value: cleanArtist),
            URLQueryItem(name: "track_name", value: cleanTitle)
        ]
        
        guard let url = components?.url else {
            searchLyrics(cleanTitle: cleanTitle, cleanArtist: cleanArtist, duration: duration, completion: completion)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Notchify/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let synced = json["syncedLyrics"] as? String, !synced.isEmpty {
                let parsed = self.parseLRC(synced)
                if !parsed.isEmpty {
                    DispatchQueue.main.async {
                        completion(parsed)
                    }
                    return
                }
            }
            
            // If exact match failed or had no synced lyrics, fallback to smart search
            self.searchLyrics(cleanTitle: cleanTitle, cleanArtist: cleanArtist, duration: duration, completion: completion)
        }.resume()
    }
    
    private func searchLyrics(
        cleanTitle: String,
        cleanArtist: String,
        duration: Double,
        completion: @escaping ([LyricLine]) -> Void
    ) {
        var components = URLComponents(string: "https://lrclib.net/api/search")
        let searchQuery = cleanArtist.isEmpty ? cleanTitle : "\(cleanArtist) \(cleanTitle)"
        components?.queryItems = [
            URLQueryItem(name: "q", value: searchQuery)
        ]
        
        guard let url = components?.url else {
            DispatchQueue.main.async { completion([]) }
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Notchify/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            guard let data = data, error == nil,
                  let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            // Filter candidates that actually contain syncedLyrics
            let syncedCandidates = jsonArray.filter { item in
                if let synced = item["syncedLyrics"] as? String, !synced.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return true
                }
                return false
            }
            
            guard !syncedCandidates.isEmpty else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            // Smart candidate selection:
            // 1. Prefer candidates whose duration is within ±5 seconds of the playing track
            // 2. Prefer candidates whose trackName closely matches cleanTitle
            let bestMatch = syncedCandidates.min { a, b in
                let durA = (a["duration"] as? NSNumber)?.doubleValue ?? (a["duration"] as? Double ?? 0)
                let durB = (b["duration"] as? NSNumber)?.doubleValue ?? (b["duration"] as? Double ?? 0)
                
                if duration > 0 {
                    let diffA = abs(durA - duration)
                    let diffB = abs(durB - duration)
                    // If difference is substantial, pick the closer duration
                    if abs(diffA - diffB) > 3.0 {
                        return diffA < diffB
                    }
                }
                
                // Secondary check: name matching
                let nameA = (a["trackName"] as? String ?? (a["name"] as? String ?? "")).lowercased()
                let nameB = (b["trackName"] as? String ?? (b["name"] as? String ?? "")).lowercased()
                let target = cleanTitle.lowercased()
                
                let exactA = nameA == target
                let exactB = nameB == target
                if exactA != exactB {
                    return exactA && !exactB
                }
                
                return false
            } ?? syncedCandidates[0]
            
            if let synced = bestMatch["syncedLyrics"] as? String {
                let parsed = self.parseLRC(synced)
                DispatchQueue.main.async {
                    completion(parsed)
                }
            } else {
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }.resume()
    }
    
    // MARK: - Robust LRC Parser
    func parseLRC(_ lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let rawLines = lrc.components(separatedBy: .newlines)
        
        // Regex to extract all timestamps like [00:15.50] or [01:23,45] or [01:02:15.50]
        let timeTagRegex = try? NSRegularExpression(pattern: "\\[(\\d{1,2}:\\d{2}(?:[:.]\\d{2,3})?)\\]")
        
        for rawLine in rawLines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("[") else { continue }
            
            // Skip metadata lines like [offset:...], [ar:...], [ti:...], etc.
            let lower = line.lowercased()
            if lower.hasPrefix("[offset:") || lower.hasPrefix("[ar:") || lower.hasPrefix("[ti:") ||
               lower.hasPrefix("[al:") || lower.hasPrefix("[by:") || lower.hasPrefix("[re:") ||
               lower.hasPrefix("[ve:") || lower.hasPrefix("[length:") {
                continue
            }
            
            guard let regex = timeTagRegex else { continue }
            let nsLine = line as NSString
            let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: nsLine.length))
            guard !matches.isEmpty else { continue }
            
            // Extract the lyric text after the last bracket
            if let lastMatch = matches.last {
                let textStartIndex = lastMatch.range.location + lastMatch.range.length
                guard textStartIndex <= nsLine.length else { continue }
                let text = nsLine.substring(from: textStartIndex).trimmingCharacters(in: .whitespaces)
                
                // Skip empty text or credit lines
                guard !text.isEmpty else { continue }
                let textLower = text.lowercased()
                if textLower.hasPrefix("synced by") || textLower.hasPrefix("sync by") ||
                   textLower.hasPrefix("lyrics by") || textLower.hasPrefix("encoded by") ||
                   textLower.hasPrefix("created by") || textLower.hasPrefix("source:") {
                    continue
                }
                
                // A single line may have multiple timestamps (e.g. [00:15.50][01:25.50]Chorus)
                for match in matches {
                    let timeStr = nsLine.substring(with: match.range(at: 1))
                    if let seconds = parseTimeSeconds(timeStr) {
                        lines.append(LyricLine(time: seconds, text: text))
                    }
                }
            }
        }
        
        // CRITICAL: Sort lines strictly by timestamp so monotonic search always works
        lines.sort { $0.time < $1.time }
        return lines
    }
    
    private func parseTimeSeconds(_ timeString: String) -> Double? {
        // Handles mm:ss.xx, mm:ss,xx, or hh:mm:ss.xx
        let normalized = timeString.replacingOccurrences(of: ",", with: ".")
        let parts = normalized.split(separator: ":")
        
        if parts.count == 2 {
            if let minutes = Double(parts[0]), let seconds = Double(parts[1]) {
                return (minutes * 60.0) + seconds
            }
        } else if parts.count == 3 {
            if let hours = Double(parts[0]), let minutes = Double(parts[1]), let seconds = Double(parts[2]) {
                return (hours * 3600.0) + (minutes * 60.0) + seconds
            }
        }
        return nil
    }
}
