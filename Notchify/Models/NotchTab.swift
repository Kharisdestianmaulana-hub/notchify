import SwiftUI

enum NotchTab: String, CaseIterable, Identifiable, Codable {
    case media = "music.note"
    case clipboard = "doc.on.clipboard"
    case dropzone = "tray.and.arrow.down.fill"
    case pomodoro = "timer"
    case calculator = "plus.forwardslash.minus"
    case weather = "cloud.sun.fill"
    case system = "gauge"
    case agenda = "calendar"
    case mirror = "camera.fill"
    case notes = "note.text"
    case network = "network"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .media: return LanguageManager.tr("Media (Music)")
        case .clipboard: return LanguageManager.tr("Clipboard Manager")
        case .dropzone: return LanguageManager.tr("Dropzone")
        case .pomodoro: return LanguageManager.tr("Pomodoro Timer")
        case .calculator: return LanguageManager.tr("Calculator")
        case .weather: return LanguageManager.tr("Weather")
        case .system: return LanguageManager.tr("System Monitor")
        case .agenda: return LanguageManager.tr("Agenda & Events")
        case .mirror: return LanguageManager.tr("Mirror")
        case .notes: return LanguageManager.tr("Scratchpad & Tasks")
        case .network: return LanguageManager.tr("Network Radar")
        }
    }
    
    static func from(string: String) -> NotchTab? {
        if let match = NotchTab(rawValue: string) { return match }
        switch string.lowercased() {
        case "media", "music": return .media
        case "clipboard": return .clipboard
        case "dropzone": return .dropzone
        case "pomodoro", "timer": return .pomodoro
        case "calculator": return .calculator
        case "weather": return .weather
        case "system": return .system
        case "agenda": return .agenda
        case "mirror", "camera": return .mirror
        case "notes", "note", "todo", "tasks": return .notes
        case "network", "wifi", "speed": return .network
        default: return nil
        }
    }
}

