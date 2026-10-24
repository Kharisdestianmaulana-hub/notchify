import Foundation


class LyricsManager {
    static let shared = LyricsManager()
    
    func fetchLyrics(for title: String, artist: String, completion: @escaping ([LyricLine]) -> Void) {
        guard !title.isEmpty else { return }
        
        let urlString = "https://lrclib.net/api/get?artist_name=\(artist)&track_name=\(title)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Notchify/1.0", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else { return }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let synced = json["syncedLyrics"] as? String {
                let parsed = self.parseLRC(synced)
                DispatchQueue.main.async {
                    completion(parsed)
                }
            } else {
                // Try searching if exact match fails
                self.searchLyrics(title: title, artist: artist, completion: completion)
            }
        }.resume()
    }
    
    private func searchLyrics(title: String, artist: String, completion: @escaping ([LyricLine]) -> Void) {
        let urlString = "https://lrclib.net/api/search?q=\(artist) \(title)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Notchify/1.0", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else { return }
            
            if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let firstMatch = jsonArray.first(where: { $0["syncedLyrics"] != nil }),
               let synced = firstMatch["syncedLyrics"] as? String {
                let parsed = self.parseLRC(synced)
                DispatchQueue.main.async {
                    completion(parsed)
                }
            }
        }.resume()
    }
    
    private func parseLRC(_ lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let rawLines = lrc.components(separatedBy: .newlines)
        
        for line in rawLines {
            guard line.hasPrefix("["), let bracketEnd = line.firstIndex(of: "]") else { continue }
            
            let timeString = line[line.index(after: line.startIndex)..<bracketEnd]
            let text = String(line[line.index(after: bracketEnd)...]).trimmingCharacters(in: .whitespaces)
            
            let parts = timeString.split(separator: ":")
            if parts.count == 2, let min = Double(parts[0]) {
                if let secDouble = Double(String(parts[1])) {
                    let totalTime = (min * 60) + secDouble
                    if !text.isEmpty {
                        lines.append(LyricLine(time: totalTime, text: text))
                    }
                }
            }
        }
        return lines
    }
}
