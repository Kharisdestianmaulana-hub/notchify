import Foundation

// MARK: - Scratchpad & To-Do Models & Views
struct TodoTask: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var isDone: Bool = false
    var createdAt: Date = Date()
}

enum NotesSubMode: String, CaseIterable {
    case notes = "Notes"
    case todo = "To-Do"
    
    var localizedTitle: String {
        switch self {
        case .notes: return LanguageManager.tr("Notes")
        case .todo: return LanguageManager.tr("To-Do")
        }
    }
}

