import SwiftUI
import Foundation

// MARK: - Agenda Model & Manager
struct CustomEvent: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var date: Date
    var colorName: String
    var isYearly: Bool? = false
    var meetingURL: String? = nil
    
    init(id: UUID = UUID(), title: String, date: Date, colorName: String, isYearly: Bool? = false, meetingURL: String? = nil) {
        self.id = id
        self.title = title
        self.date = date
        self.colorName = colorName
        self.isYearly = isYearly
        self.meetingURL = meetingURL
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, date, colorName, isYearly, meetingURL
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.date = try container.decode(Date.self, forKey: .date)
        self.colorName = try container.decode(String.self, forKey: .colorName)
        self.isYearly = try container.decodeIfPresent(Bool.self, forKey: .isYearly) ?? false
        self.meetingURL = try container.decodeIfPresent(String.self, forKey: .meetingURL)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(date, forKey: .date)
        try container.encode(colorName, forKey: .colorName)
        try container.encode(isYearly, forKey: .isYearly)
        try container.encode(meetingURL, forKey: .meetingURL)
    }
    
    var isPast: Bool {
        date < Date()
    }
    var isNow: Bool {
        let now = Date()
        return date <= now && date.addingTimeInterval(3600) > now
    }
    var color: Color {
        switch colorName {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "purple": return .purple
        default: return .blue
        }
    }
    
    var meetingLink: URL? {
        if let explicit = meetingURL?.trimmingCharacters(in: .whitespacesAndNewlines), !explicit.isEmpty {
            if let url = URL(string: explicit), url.scheme != nil {
                return url
            } else if let url = URL(string: "https://" + explicit) {
                return url
            }
        }
        return CustomEvent.extractMeetingURL(from: title)
    }
    
    var hasMeetingLink: Bool {
        meetingLink != nil
    }
    
    static func extractMeetingURL(from text: String) -> URL? {
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length))
            for match in matches {
                if let url = match.url {
                    let host = url.host?.lowercased() ?? ""
                    let full = url.absoluteString.lowercased()
                    if host.contains("meet.google.com") ||
                       host.contains("zoom.us") ||
                       host.contains("teams.microsoft.com") ||
                       host.contains("teams.live.com") ||
                       host.contains("webex.com") ||
                       full.contains("meet.google") ||
                       full.contains("zoom.us") ||
                       full.contains("teams.microsoft") {
                        return url
                    }
                }
            }
            if let firstURL = matches.first?.url {
                return firstURL
            }
        }
        
        let regexPatterns = [
            #"(?:https?:\/\/)?meet\.google\.com\/[a-zA-Z0-9\-]+"#,
            #"(?:https?:\/\/)?[a-zA-Z0-9\.\-]*zoom\.us\/[a-zA-Z0-9\/\?\=\&\.\-\_]+"#,
            #"(?:https?:\/\/)?teams\.microsoft\.com\/[a-zA-Z0-9\/\?\=\&\.\-\_\%]+"#,
            #"(?:https?:\/\/)?[a-zA-Z0-9\.\-]*webex\.com\/[a-zA-Z0-9\/\?\=\&\.\-\_]+"#
        ]
        
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        for pattern in regexPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: fullRange) {
                var matchedStr = nsText.substring(with: match.range)
                if !matchedStr.lowercased().hasPrefix("http://") && !matchedStr.lowercased().hasPrefix("https://") {
                    matchedStr = "https://" + matchedStr
                }
                if let url = URL(string: matchedStr) {
                    return url
                }
            }
        }
        
        return nil
    }
}

class CustomAgendaManager {
    static let shared = CustomAgendaManager()
    private let defaultsKey = "notchify_custom_events"
    
    func getAllEvents() -> [CustomEvent] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let events = try? JSONDecoder().decode([CustomEvent].self, from: data) else {
            return []
        }
        return events
    }
    
    func saveEvents(_ events: [CustomEvent]) {
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
    
    func addEvent(_ event: CustomEvent) {
        var events = getAllEvents()
        events.append(event)
        saveEvents(events)
    }
    
    func deleteEvent(id: UUID) {
        var events = getAllEvents()
        events.removeAll { $0.id == id }
        saveEvents(events)
    }
    
    func fetchEvents(forDateOffset offset: Int) -> [CustomEvent] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let targetDate = calendar.date(byAdding: .day, value: offset, to: today),
              let endDate = calendar.date(byAdding: .day, value: 1, to: targetDate) else { return [] }
        
        return getAllEvents().compactMap { event in
            var modifiedEvent = event
            if event.isYearly == true {
                // Change the event's date to match the target date's year
                var components = calendar.dateComponents([.month, .day, .hour, .minute], from: event.date)
                components.year = calendar.component(.year, from: targetDate)
                if let newDate = calendar.date(from: components) {
                    modifiedEvent.date = newDate
                }
            }
            if modifiedEvent.date >= targetDate && modifiedEvent.date < endDate {
                return modifiedEvent
            }
            return nil
        }.sorted { $0.date < $1.date }
    }
}
